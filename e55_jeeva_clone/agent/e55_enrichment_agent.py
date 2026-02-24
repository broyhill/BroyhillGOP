#!/usr/bin/env python3
"""
E55 Autonomous Intelligence Agent — Enrichment Engine
BroyhillGOP NEXUS Platform

WATERFALL ENRICHMENT PIPELINE:
  1. FEC Contribution lookup (free)
  2. NC Board of Elections voter file (free)
  3. NC Property Records (free)
  4. Social media scan (free)
  5. Business filings (free)
  6. Commercial data providers (paid, per-lookup)

ICP (Ideal Constituent Profile) SEARCH:
  Natural language → parsed filters → golden record matching → auto-enrich

PROSPECT ORIGIN TRACKING:
  Every prospect gets tagged with the issue group, news cycle event,
  or other source that first surfaced them.

DEPLOYMENT:
  - Runs on Hetzner server (5.9.99.109) as systemd service
  - Triggered by: n8n webhook, cron schedule, or manual API call
  - Connects to Supabase via service_role key

DEPENDENCIES:
  pip install supabase httpx openai python-dotenv
"""

import os
import json
import httpx
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, field, asdict

# ═══════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://isbgjpnbocdkeslofota.supabase.co")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")  # service_role key
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

# Enrichment source API keys (set in .env)
PDL_API_KEY = os.getenv("PDL_API_KEY", "")
PROXYCURL_API_KEY = os.getenv("PROXYCURL_API_KEY", "")
HUNTER_API_KEY = os.getenv("HUNTER_API_KEY", "")

FEC_API_KEY = os.getenv("FEC_API_KEY", "")  # openFEC free key

logging.basicConfig(level=logging.INFO, format='%(asctime)s [E55] %(message)s')
log = logging.getLogger("e55")


# ═══════════════════════════════════════════════════════════════
# DATA CLASSES
# ═══════════════════════════════════════════════════════════════

@dataclass
class ProspectOrigin:
    """Tracks WHERE a prospect was first discovered"""
    origin_type: str                           # 'issue_group_post', 'news_cycle_activation', etc.
    source_group_id: Optional[str] = None
    source_group_name: Optional[str] = None
    source_directory_category: Optional[str] = None
    source_issue: Optional[str] = None
    source_news_cycle_event: Optional[str] = None
    origin_content: Optional[str] = None       # what post/comment triggered discovery
    origin_url: Optional[str] = None
    referring_connector_id: Optional[int] = None
    referring_connector_name: Optional[str] = None
    attribution_confidence: float = 0.80


@dataclass
class EnrichmentResult:
    """Accumulated enrichment data from all sources"""
    # Contact
    emails: List[str] = field(default_factory=list)
    phones: List[str] = field(default_factory=list)
    addresses: List[Dict] = field(default_factory=list)

    # Professional
    employer: Optional[str] = None
    job_title: Optional[str] = None
    industry: Optional[str] = None
    linkedin_url: Optional[str] = None

    # Political
    party_affiliation: Optional[str] = None
    voter_status: Optional[str] = None
    vote_history: List[str] = field(default_factory=list)
    ncid: Optional[str] = None
    donation_history: List[Dict] = field(default_factory=list)
    total_donations_cents: int = 0

    # Wealth/Capacity
    property_values: List[Dict] = field(default_factory=list)
    estimated_capacity: Optional[str] = None
    capacity_signals: List[Dict] = field(default_factory=list)

    # Social
    social_profiles: Dict[str, str] = field(default_factory=dict)
    group_memberships: List[str] = field(default_factory=list)
    interests: List[str] = field(default_factory=list)

    # Scoring
    donor_propensity_score: float = 0.0
    volunteer_propensity_score: float = 0.0
    connector_score: float = 0.0
    engagement_score: float = 0.0

    # Metadata
    sources_queried: List[str] = field(default_factory=list)
    sources_with_data: List[str] = field(default_factory=list)
    enrichment_depth: str = "standard"
    last_enriched_at: Optional[str] = None


@dataclass
class ICPFilter:
    """Parsed from natural language ICP prompt"""
    counties: List[str] = field(default_factory=list)
    districts: List[str] = field(default_factory=list)
    party: Optional[str] = "REP"
    min_donation: Optional[int] = None
    max_donation: Optional[int] = None
    issue_groups: List[str] = field(default_factory=list)
    capacity_min: Optional[str] = None
    has_property: Optional[bool] = None
    age_range: Optional[List[int]] = None
    occupation_keywords: List[str] = field(default_factory=list)
    connector_score_min: Optional[int] = None
    exclude_already_contacted: bool = True
    exclude_existing_donors: bool = False


# ═══════════════════════════════════════════════════════════════
# SUPABASE CLIENT
# ═══════════════════════════════════════════════════════════════

class SupabaseClient:
    """Direct REST API client for Supabase (no SDK dependency issues)"""

    def __init__(self):
        self.url = SUPABASE_URL
        self.key = SUPABASE_SERVICE_KEY
        self.headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        }

    def query(self, table: str, params: Dict = None) -> List[Dict]:
        """GET from table with query params"""
        r = httpx.get(f"{self.url}/rest/v1/{table}", headers=self.headers, params=params or {}, timeout=30)
        r.raise_for_status()
        return r.json()

    def insert(self, table: str, data: Dict) -> Dict:
        """INSERT into table"""
        r = httpx.post(f"{self.url}/rest/v1/{table}", headers=self.headers, json=data, timeout=30)
        r.raise_for_status()
        result = r.json()
        return result[0] if isinstance(result, list) else result

    def update(self, table: str, match: Dict, data: Dict) -> List[Dict]:
        """UPDATE table WHERE match"""
        params = {f"{k}": f"eq.{v}" for k, v in match.items()}
        h = {**self.headers, "Prefer": "return=representation"}
        r = httpx.patch(f"{self.url}/rest/v1/{table}", headers=h, params=params, json=data, timeout=30)
        r.raise_for_status()
        return r.json()

    def rpc(self, fn_name: str, params: Dict = None) -> Any:
        """Call a Postgres function"""
        r = httpx.post(f"{self.url}/rest/v1/rpc/{fn_name}", headers=self.headers, json=params or {}, timeout=60)
        r.raise_for_status()
        return r.json()

    def upsert(self, table: str, data: Dict, on_conflict: str = "id") -> Dict:
        """UPSERT into table"""
        h = {**self.headers, "Prefer": "return=representation,resolution=merge-duplicates"}
        r = httpx.post(f"{self.url}/rest/v1/{table}", headers=h, json=data, timeout=30)
        r.raise_for_status()
        result = r.json()
        return result[0] if isinstance(result, list) else result


db = SupabaseClient()


# ═══════════════════════════════════════════════════════════════
# ICP ENGINE — Natural Language → Filters → Search
# ═══════════════════════════════════════════════════════════════

class ICPEngine:
    """
    Ideal Constituent Profile engine.
    Candidate types: "Find VPs of Marketing at B2B SaaS companies"
    → Parsed into structured filters
    → Executed against golden records
    → Results auto-enriched via waterfall
    """

    @staticmethod
    async def parse_natural_language(prompt: str) -> ICPFilter:
        """
        Use OpenAI to parse natural language ICP prompt into structured filters.
        Political adaptation of Jeeva's ICP builder.

        Examples:
        - "Find major donors in real estate who support 2A in Forsyth County"
        - "Find business owners over 50 in rural NC who donated over $500"
        - "Find active church leaders in Wake County with high connector scores"
        """
        system_prompt = """You are an ICP (Ideal Constituent Profile) parser for a political campaign platform.
Convert the user's natural language description into structured JSON filters.

Available filters:
- counties: list of NC counties
- districts: list of districts (e.g., "NC-5", "NC House 74")
- party: "REP", "DEM", "UNA", "LIB"
- min_donation / max_donation: in dollars
- issue_groups: from [official_gop, second_amendment, pro_life, business_economic, veterans_military, agricultural_rural, faith_based, education_parents, law_enforcement, civic_fraternal, professional, maga_populist, liberty_constitutional, heritage_historical]
- capacity_min: from [under_100, 100_500, 500_1000, 1000_5000, 5000_plus, major_donor]
- has_property: true/false
- age_range: [min, max]
- occupation_keywords: list of job/industry keywords
- connector_score_min: 0-100
- exclude_already_contacted: true/false
- exclude_existing_donors: true/false

Return ONLY valid JSON, no explanation."""

        async with httpx.AsyncClient() as client:
            r = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {OPENAI_API_KEY}"},
                json={
                    "model": "gpt-4o-mini",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": prompt}
                    ],
                    "temperature": 0.1,
                    "response_format": {"type": "json_object"}
                },
                timeout=30
            )
            r.raise_for_status()
            parsed = json.loads(r.json()["choices"][0]["message"]["content"])

        # Convert to ICPFilter
        return ICPFilter(**{k: v for k, v in parsed.items() if hasattr(ICPFilter, k)})

    @staticmethod
    def execute_search(agent_id: str, icp_id: str, filters: ICPFilter) -> List[Dict]:
        """Execute ICP search against donor_golden_records"""
        # Build query
        params = {"select": "golden_record_id,first_name,last_name,county,party_affiliation"}

        if filters.counties:
            params["county"] = f"in.({','.join(filters.counties)})"
        if filters.party:
            params["party_affiliation"] = f"eq.{filters.party}"

        results = db.query("donor_golden_records", params)

        # Update ICP profile with results
        db.update("e55_icp_profiles", {"id": icp_id}, {
            "matches_found": len(results),
            "last_run_at": datetime.utcnow().isoformat()
        })

        log.info(f"ICP search found {len(results)} matches for agent {agent_id}")
        return results

    @staticmethod
    def create_icp(agent_id: str, name: str, prompt: str, filters: Dict, auto_enrich: bool = True) -> Dict:
        """Create a new ICP profile"""
        return db.insert("e55_icp_profiles", {
            "agent_id": agent_id,
            "icp_name": name,
            "icp_prompt": prompt,
            "filters": json.dumps(filters),
            "auto_enrich": auto_enrich,
            "status": "active"
        })


# ═══════════════════════════════════════════════════════════════
# WATERFALL ENRICHMENT ENGINE
# ═══════════════════════════════════════════════════════════════

class WaterfallEnrichment:
    """
    Waterfall enrichment from 100+ sources.
    Tries sources in priority order, stops when we have enough data.

    Tiers:
      1. Government/Free (FEC, NCBOE, property, SoS, courts)
      2. Social Media (Facebook, LinkedIn, Truth Social, etc.)
      3. Commercial Data (PDL, Proxycurl, Hunter, Clearbit, etc.)
      4. Political-Specific (DataTrust, L2, TargetSmart, etc.)
      5. Business/Professional (D&B, Crunchbase, licenses)
      6. Media/Public (news mentions, podcasts, events)
      7. Wealth/Capacity (Zillow, vehicle, boat, clubs)
    """

    def __init__(self):
        self.sources = self._load_sources()

    def _load_sources(self) -> List[Dict]:
        """Load active enrichment sources sorted by waterfall priority"""
        try:
            return db.query("e55_enrichment_sources", {
                "is_active": "eq.true",
                "order": "waterfall_priority.asc"
            })
        except Exception:
            return []

    async def enrich_prospect(
        self,
        queue_id: str,
        person_name: str,
        email: Optional[str] = None,
        address: Optional[str] = None,
        depth: str = "standard"
    ) -> EnrichmentResult:
        """
        Run waterfall enrichment on a prospect.

        Depth levels:
          basic:      FEC + NCBOE only (free, fast)
          standard:   + property + social media (free, moderate)
          deep:       + commercial data providers (paid, thorough)
          exhaustive: all 100+ sources (expensive, comprehensive)
        """
        result = EnrichmentResult(enrichment_depth=depth)

        # Determine which tiers to run based on depth
        max_priority = {
            "basic": 10,       # Government only
            "standard": 25,    # + Social media
            "deep": 60,        # + Commercial + Political
            "exhaustive": 100  # Everything
        }.get(depth, 25)

        # Update queue status
        db.update("e55_enrichment_queue", {"id": queue_id}, {"pipeline_status": "fec_lookup"})

        for source in self.sources:
            if source["waterfall_priority"] > max_priority:
                break

            source_name = source["source_name"]
            result.sources_queried.append(source_name)

            try:
                data = await self._query_source(source, person_name, email, address)
                if data:
                    result.sources_with_data.append(source_name)
                    self._merge_data(result, data, source)

                    # Update source hit stats
                    db.update("e55_enrichment_sources", {"id": source["id"]}, {
                        "total_lookups": source.get("total_lookups", 0) + 1,
                        "successful_lookups": source.get("successful_lookups", 0) + 1
                    })
                else:
                    db.update("e55_enrichment_sources", {"id": source["id"]}, {
                        "total_lookups": source.get("total_lookups", 0) + 1
                    })

            except Exception as e:
                log.warning(f"Source {source_name} failed: {e}")
                continue

        # Score the prospect
        result = self._calculate_scores(result)
        result.last_enriched_at = datetime.utcnow().isoformat()

        # Update enrichment queue with results
        db.update("e55_enrichment_queue", {"id": queue_id}, {
            "pipeline_status": "complete",
            "enrichment_data": json.dumps(asdict(result)),
            "donor_propensity_score": result.donor_propensity_score,
            "volunteer_propensity_score": result.volunteer_propensity_score,
            "connector_score": result.connector_score,
            "engagement_score": result.engagement_score,
            "estimated_capacity": result.estimated_capacity,
            "completed_at": datetime.utcnow().isoformat()
        })

        log.info(f"Enrichment complete: {person_name} | "
                 f"{len(result.sources_with_data)}/{len(result.sources_queried)} sources hit | "
                 f"Donor score: {result.donor_propensity_score}")

        return result

    async def _query_source(self, source: Dict, name: str, email: str = None, address: str = None) -> Optional[Dict]:
        """Query a specific enrichment source"""
        source_name = source["source_name"]

        # ── TIER 1: Government/Free ──
        if source_name == "FEC Contributions":
            return await self._query_fec(name)
        elif source_name == "NC Board of Elections":
            return await self._query_ncboe(name)
        elif source_name == "NC Property Records":
            return await self._query_property(name, address)

        # ── TIER 2: Social Media ──
        elif source_name == "Facebook Public Profiles":
            return await self._query_facebook(name)
        elif source_name == "LinkedIn Public":
            return await self._query_linkedin(name, email)

        # ── TIER 3: Commercial Data ──
        elif source_name == "People Data Labs (PDL)":
            return await self._query_pdl(name, email)
        elif source_name == "Proxycurl":
            return await self._query_proxycurl(name, email)
        elif source_name == "Hunter.io":
            return await self._query_hunter(email)

        # ── TIER 4: Political ──
        elif source_name == "DataTrust Voter File":
            return await self._query_datatrust(name)

        # Default: source not implemented yet
        return None

    # ── FEC Lookup ──
    async def _query_fec(self, name: str) -> Optional[Dict]:
        """Query openFEC API for contribution history"""
        if not FEC_API_KEY:
            return None

        parts = name.split()
        if len(parts) < 2:
            return None

        async with httpx.AsyncClient() as client:
            r = await client.get(
                "https://api.open.fec.gov/v1/schedules/schedule_a/",
                params={
                    "api_key": FEC_API_KEY,
                    "contributor_name": name,
                    "contributor_state": "NC",
                    "sort": "-contribution_receipt_date",
                    "per_page": 20
                },
                timeout=15
            )
            if r.status_code != 200:
                return None

            data = r.json()
            results = data.get("results", [])
            if not results:
                return None

            total = sum(r.get("contribution_receipt_amount", 0) for r in results)
            return {
                "donation_history": [
                    {
                        "committee": r.get("committee", {}).get("name", ""),
                        "amount": r.get("contribution_receipt_amount", 0),
                        "date": r.get("contribution_receipt_date", ""),
                        "employer": r.get("contributor_employer", ""),
                        "occupation": r.get("contributor_occupation", "")
                    }
                    for r in results
                ],
                "total_donations_cents": int(total * 100),
                "employer": results[0].get("contributor_employer", ""),
                "occupation": results[0].get("contributor_occupation", "")
            }

    # ── NCBOE Lookup ──
    async def _query_ncboe(self, name: str) -> Optional[Dict]:
        """Query NC Board of Elections voter data from our Supabase store"""
        parts = name.upper().split()
        if len(parts) < 2:
            return None

        # Check our voter table
        voters = db.query("datatrust_nc_full", {
            "last_name": f"eq.{parts[-1]}",
            "first_name": f"like.{parts[0]}*",
            "select": "ncid,party,county,res_street_address,res_city_desc,zip_code,voter_status_desc",
            "limit": 5
        })

        if not voters:
            return None

        v = voters[0]
        return {
            "ncid": v.get("ncid"),
            "party_affiliation": v.get("party"),
            "voter_status": v.get("voter_status_desc"),
            "address": {
                "street": v.get("res_street_address", ""),
                "city": v.get("res_city_desc", ""),
                "zip": v.get("zip_code", "")
            },
            "county": v.get("county")
        }

    # ── Property Records ──
    async def _query_property(self, name: str, address: str = None) -> Optional[Dict]:
        """Lookup NC property records (placeholder — implement county-specific APIs)"""
        # This would integrate with county GIS/tax record APIs
        # For now, return None — to be implemented per-county
        return None

    # ── Facebook ──
    async def _query_facebook(self, name: str) -> Optional[Dict]:
        """Scan public Facebook presence (limited without Graph API)"""
        # Would use social monitoring tools / RSS feeds
        return None

    # ── LinkedIn ──
    async def _query_linkedin(self, name: str, email: str = None) -> Optional[Dict]:
        """LinkedIn enrichment via Proxycurl or direct"""
        if PROXYCURL_API_KEY and email:
            return await self._query_proxycurl(name, email)
        return None

    # ── People Data Labs ──
    async def _query_pdl(self, name: str, email: str = None) -> Optional[Dict]:
        """PDL waterfall enrichment — best hit rate for contact data"""
        if not PDL_API_KEY:
            return None

        async with httpx.AsyncClient() as client:
            params = {"api_key": PDL_API_KEY, "pretty": True}
            if email:
                params["email"] = email
            else:
                parts = name.split()
                if len(parts) >= 2:
                    params["first_name"] = parts[0]
                    params["last_name"] = parts[-1]
                    params["location"] = "North Carolina"

            r = await client.get(
                "https://api.peopledatalabs.com/v5/person/enrich",
                params=params,
                timeout=15
            )
            if r.status_code != 200:
                return None

            data = r.json()
            if data.get("status") != 200:
                return None

            return {
                "emails": [e.get("address") for e in data.get("emails", [])],
                "phones": [p.get("number") for p in data.get("phone_numbers", [])],
                "employer": data.get("job_company_name"),
                "job_title": data.get("job_title"),
                "linkedin_url": data.get("linkedin_url"),
                "industry": data.get("industry"),
                "interests": data.get("interests", [])
            }

    # ── Proxycurl ──
    async def _query_proxycurl(self, name: str, email: str = None) -> Optional[Dict]:
        """Proxycurl for LinkedIn profile enrichment"""
        if not PROXYCURL_API_KEY:
            return None
        # Would query Proxycurl API for LinkedIn profile data
        return None

    # ── Hunter.io ──
    async def _query_hunter(self, email: str = None) -> Optional[Dict]:
        """Hunter.io for email verification"""
        if not HUNTER_API_KEY or not email:
            return None

        async with httpx.AsyncClient() as client:
            r = await client.get(
                "https://api.hunter.io/v2/email-verifier",
                params={"email": email, "api_key": HUNTER_API_KEY},
                timeout=10
            )
            if r.status_code == 200:
                data = r.json().get("data", {})
                return {"email_verified": data.get("result") == "deliverable"}
        return None

    # ── DataTrust ──
    async def _query_datatrust(self, name: str) -> Optional[Dict]:
        """DataTrust voter file lookup from our imported data"""
        parts = name.upper().split()
        if len(parts) < 2:
            return None

        records = db.query("datatrust_nc_full", {
            "last_name": f"eq.{parts[-1]}",
            "first_name": f"like.{parts[0]}*",
            "select": "rnc_id,state_voter_id,modeled_party_id,modeled_turnout_score",
            "limit": 3
        })

        if records:
            r = records[0]
            return {
                "rnc_id": r.get("rnc_id"),
                "modeled_party": r.get("modeled_party_id"),
                "turnout_score": r.get("modeled_turnout_score")
            }
        return None

    def _merge_data(self, result: EnrichmentResult, data: Dict, source: Dict):
        """Merge source data into accumulated enrichment result"""
        if "emails" in data:
            for e in data["emails"]:
                if e and e not in result.emails:
                    result.emails.append(e)

        if "phones" in data:
            for p in data["phones"]:
                if p and p not in result.phones:
                    result.phones.append(p)

        if "employer" in data and data["employer"]:
            result.employer = result.employer or data["employer"]
        if "job_title" in data and data["job_title"]:
            result.job_title = result.job_title or data["job_title"]
        if "linkedin_url" in data and data["linkedin_url"]:
            result.linkedin_url = result.linkedin_url or data["linkedin_url"]
        if "industry" in data and data["industry"]:
            result.industry = result.industry or data["industry"]

        if "party_affiliation" in data:
            result.party_affiliation = data["party_affiliation"]
        if "voter_status" in data:
            result.voter_status = data["voter_status"]
        if "ncid" in data:
            result.ncid = data["ncid"]

        if "donation_history" in data:
            result.donation_history.extend(data["donation_history"])
        if "total_donations_cents" in data:
            result.total_donations_cents += data["total_donations_cents"]

        if "interests" in data:
            for i in data["interests"]:
                if i not in result.interests:
                    result.interests.append(i)

        if "address" in data and isinstance(data["address"], dict):
            result.addresses.append(data["address"])

    def _calculate_scores(self, result: EnrichmentResult) -> EnrichmentResult:
        """Calculate propensity scores based on enrichment data"""

        # Donor propensity: based on donation history + capacity signals
        donor_score = 0
        if result.total_donations_cents > 0:
            donor_score += 30  # has donated before
            if result.total_donations_cents > 50000:  # $500+
                donor_score += 20
            if result.total_donations_cents > 200000:  # $2000+
                donor_score += 20
        if result.employer:
            donor_score += 10
        if result.linkedin_url:
            donor_score += 5
        if len(result.property_values) > 0:
            donor_score += 15
        result.donor_propensity_score = min(donor_score, 100)

        # Volunteer propensity: based on group memberships + social presence
        vol_score = 0
        if len(result.group_memberships) > 0:
            vol_score += 20 + min(len(result.group_memberships) * 5, 30)
        if result.party_affiliation == "REP":
            vol_score += 15
        if len(result.interests) > 3:
            vol_score += 10
        if result.voter_status == "ACTIVE":
            vol_score += 15
        result.volunteer_propensity_score = min(vol_score, 100)

        # Connector score: based on group count + social reach
        conn_score = len(result.group_memberships) * 15
        if len(result.social_profiles) > 2:
            conn_score += 10
        result.connector_score = min(conn_score, 100)

        # Engagement score: average of all signals
        signals = [s for s in [result.donor_propensity_score, result.volunteer_propensity_score, result.connector_score] if s > 0]
        result.engagement_score = sum(signals) / max(len(signals), 1)

        # Capacity estimate
        if result.total_donations_cents > 500000:
            result.estimated_capacity = "major_donor"
        elif result.total_donations_cents > 200000:
            result.estimated_capacity = "5000_plus"
        elif result.total_donations_cents > 100000:
            result.estimated_capacity = "1000_5000"
        elif result.total_donations_cents > 50000:
            result.estimated_capacity = "500_1000"
        elif result.total_donations_cents > 10000:
            result.estimated_capacity = "100_500"
        else:
            result.estimated_capacity = "under_100"

        return result


# ═══════════════════════════════════════════════════════════════
# SOCIAL GROUP MONITOR
# ═══════════════════════════════════════════════════════════════

class SocialGroupMonitor:
    """
    Monitors social groups for prospect discovery.
    When a new person is found in an issue group, they get:
    1. Tagged with prospect_origin (which group, which issue)
    2. Queued for waterfall enrichment
    3. Added to relevant newsletter
    4. Scored for connector potential
    """

    @staticmethod
    def discover_prospect(
        agent_id: str,
        golden_record_id: int,
        origin: ProspectOrigin
    ) -> str:
        """Record a new prospect discovery with full origin tracking"""

        # Call the database function that handles everything
        result = db.rpc("e55_record_prospect_discovery", {
            "p_agent_id": agent_id,
            "p_golden_record_id": golden_record_id,
            "p_origin_type": origin.origin_type,
            "p_group_id": origin.source_group_id,
            "p_issue": origin.source_issue,
            "p_news_event": origin.source_news_cycle_event,
            "p_content": origin.origin_content,
            "p_url": origin.origin_url,
            "p_connector_id": origin.referring_connector_id,
            "p_connector_name": origin.referring_connector_name
        })

        log.info(f"Prospect discovered: GR#{golden_record_id} via {origin.origin_type} "
                 f"from {origin.source_group_name or 'unknown group'}")

        return result

    @staticmethod
    def subscribe_to_newsletter(
        agent_id: str,
        golden_record_id: int,
        newsletter_name: str,
        newsletter_category: str,
        origin_group_id: str = None,
        origin_group_name: str = None
    ) -> Dict:
        """Add prospect to issue-specific newsletter with origin tracking"""

        return db.insert("e55_newsletter_tracking", {
            "agent_id": agent_id,
            "golden_record_id": golden_record_id,
            "newsletter_name": newsletter_name,
            "newsletter_category": newsletter_category,
            "origin_group_id": origin_group_id,
            "origin_group_name": origin_group_name,
            "origin_directory_category": newsletter_category
        })

    @staticmethod
    def update_funnel_stage(
        golden_record_id: int,
        agent_id: str,
        new_stage: str
    ):
        """Update prospect's funnel stage"""
        db.update("e55_prospect_origins",
            {"golden_record_id": str(golden_record_id), "agent_id": agent_id},
            {"funnel_stage": new_stage, "funnel_stage_updated_at": datetime.utcnow().isoformat()}
        )

    @staticmethod
    def identify_connector(
        agent_id: str,
        golden_record_id: int,
        groups_in_common: List[str],
        leadership_positions: List[Dict]
    ) -> Dict:
        """Identify and score a super-connector"""
        group_count = len(groups_in_common)
        leadership_count = len(leadership_positions)
        score = min((group_count * 15) + (leadership_count * 25), 100)

        return db.insert("e55_connector_scores", {
            "agent_id": agent_id,
            "golden_record_id": golden_record_id,
            "connector_score": score,
            "group_count": group_count,
            "leadership_roles": leadership_count,
            "groups_in_common": groups_in_common,
            "leadership_positions": json.dumps(leadership_positions),
            "engagement_status": "identified"
        })


# ═══════════════════════════════════════════════════════════════
# NEWS CYCLE REACTOR
# ═══════════════════════════════════════════════════════════════

class NewsCycleReactor:
    """
    Detects trending issues and auto-activates relevant groups.
    When a news event fires:
    1. AI classifies the issue category
    2. Related directories are identified
    3. Agents with news_cycle_auto=true get activated
    4. Newsletter blasts are triggered
    5. Talking points are generated
    """

    @staticmethod
    def register_event(
        headline: str,
        summary: str,
        issue_category: str,
        related_directories: List[str],
        impact_level: str = "medium",
        source_url: str = None,
        affected_counties: List[str] = None,
        ai_talking_points: List[Dict] = None
    ) -> Dict:
        """Register a news cycle event and trigger activations"""

        event = db.insert("e55_news_cycle_events", {
            "headline": headline,
            "summary": summary,
            "issue_category": issue_category,
            "related_directories": related_directories,
            "impact_level": impact_level,
            "source_url": source_url,
            "affected_counties": affected_counties or [],
            "ai_talking_points": json.dumps(ai_talking_points or []),
            "status": "active"
        })

        # Trigger auto-activation via database function
        activated = db.rpc("e55_activate_news_cycle", {"p_news_event_id": event["id"]})

        log.info(f"News cycle event: {headline} | Impact: {impact_level} | "
                 f"Activated {activated} agents")

        return event

    @staticmethod
    def generate_talking_points(headline: str, issue_category: str) -> List[Dict]:
        """AI-generate talking points for a news event (placeholder for OpenAI call)"""
        # This would call OpenAI to generate candidate-specific talking points
        return [
            {"point": f"Regarding {headline}, our position is...", "tone": "strong"},
            {"point": "This affects NC families because...", "tone": "empathetic"},
            {"point": "My plan to address this includes...", "tone": "action-oriented"}
        ]


# ═══════════════════════════════════════════════════════════════
# PRE-CALL BRIEFING GENERATOR
# ═══════════════════════════════════════════════════════════════

class BriefingGenerator:
    """Generate AI-powered pre-call briefings for candidate meetings"""

    @staticmethod
    def generate_briefing(
        agent_id: str,
        golden_record_id: int,
        meeting_type: str = "one_on_one",
        meeting_date: str = None
    ) -> Dict:
        """Generate a comprehensive briefing for meeting with a prospect"""

        # Gather all data about this person
        origins = db.query("e55_prospect_origins", {
            "golden_record_id": f"eq.{golden_record_id}",
            "agent_id": f"eq.{agent_id}",
            "order": "discovered_at.desc"
        })

        enrichment = db.query("e55_enrichment_queue", {
            "golden_record_id": f"eq.{golden_record_id}",
            "agent_id": f"eq.{agent_id}",
            "pipeline_status": "eq.complete",
            "limit": 1
        })

        newsletters = db.query("e55_newsletter_tracking", {
            "golden_record_id": f"eq.{golden_record_id}",
            "agent_id": f"eq.{agent_id}"
        })

        connector = db.query("e55_connector_scores", {
            "golden_record_id": f"eq.{golden_record_id}",
            "agent_id": f"eq.{agent_id}",
            "limit": 1
        })

        # Build briefing
        relevant_groups = [o.get("source_group_name") for o in origins if o.get("source_group_name")]
        relevant_issues = list(set(o.get("source_issue") for o in origins if o.get("source_issue")))

        enrichment_data = json.loads(enrichment[0].get("enrichment_data", "{}")) if enrichment else {}

        briefing_summary = f"""
PROSPECT BRIEFING
Origin: Discovered via {origins[0]['origin_type'] if origins else 'unknown'}
{f"From group: {origins[0]['source_group_name']}" if origins and origins[0].get('source_group_name') else ''}
Issues they care about: {', '.join(relevant_issues) if relevant_issues else 'TBD'}
Newsletters subscribed: {len(newsletters)}
Connector score: {connector[0]['connector_score'] if connector else 'N/A'}
Donor capacity: {enrichment_data.get('estimated_capacity', 'Unknown')}
Total past donations: ${enrichment_data.get('total_donations_cents', 0) / 100:.0f}
Employer: {enrichment_data.get('employer', 'Unknown')}
""".strip()

        talking_points = []
        if relevant_issues:
            talking_points.append({"point": f"Shared interest in {relevant_issues[0]}", "category": "rapport"})
        if relevant_groups:
            talking_points.append({"point": f"Active in {relevant_groups[0]}", "category": "connection"})
        if enrichment_data.get("total_donations_cents", 0) > 100000:
            talking_points.append({"point": "History of political giving — appropriate to discuss campaign support", "category": "ask"})

        return db.insert("e55_precall_briefings", {
            "agent_id": agent_id,
            "golden_record_id": golden_record_id,
            "meeting_type": meeting_type,
            "meeting_date": meeting_date,
            "briefing_summary": briefing_summary,
            "key_talking_points": json.dumps(talking_points),
            "relevant_groups": json.dumps([{"name": g} for g in relevant_groups]),
            "relevant_issues": relevant_issues,
            "donation_history_summary": f"${enrichment_data.get('total_donations_cents', 0) / 100:.0f} total",
            "issue_alignment": json.dumps({i: "aligned" for i in relevant_issues}),
            "suggested_ask": "Donor cultivation" if enrichment_data.get("total_donations_cents", 0) > 50000 else "Volunteer recruitment",
            "status": "generated"
        })


# ═══════════════════════════════════════════════════════════════
# OUTREACH SEQUENCE ENGINE
# ═══════════════════════════════════════════════════════════════

class OutreachEngine:
    """
    Automated multi-step outreach sequences.
    Each prospect gets a personalized sequence based on their origin + issue alignment.
    """

    SEQUENCE_TEMPLATES = {
        "newsletter_welcome": {
            "steps": [
                {"day": 0, "channel": "email", "template": "welcome_to_{newsletter_name}"},
                {"day": 3, "channel": "email", "template": "top_stories_this_week"},
                {"day": 7, "channel": "email", "template": "invite_to_event"},
                {"day": 14, "channel": "email", "template": "volunteer_opportunity"}
            ]
        },
        "donor_cultivation": {
            "steps": [
                {"day": 0, "channel": "email", "template": "personal_introduction"},
                {"day": 5, "channel": "email", "template": "issue_alignment_share"},
                {"day": 10, "channel": "phone", "template": "personal_call_script"},
                {"day": 15, "channel": "email", "template": "event_invitation"},
                {"day": 21, "channel": "email", "template": "soft_ask"},
                {"day": 30, "channel": "phone", "template": "follow_up_call"}
            ]
        },
        "connector_engage": {
            "steps": [
                {"day": 0, "channel": "social_dm", "template": "mutual_connection_intro"},
                {"day": 3, "channel": "email", "template": "leadership_recognition"},
                {"day": 7, "channel": "phone", "template": "coffee_meeting_invite"},
                {"day": 14, "channel": "email", "template": "coalition_building_ask"}
            ]
        },
        "news_cycle_response": {
            "steps": [
                {"day": 0, "channel": "email", "template": "breaking_news_position"},
                {"day": 1, "channel": "email", "template": "action_item_ask"},
                {"day": 3, "channel": "email", "template": "follow_up_impact"}
            ]
        }
    }

    @staticmethod
    def create_sequence(
        agent_id: str,
        golden_record_id: int,
        sequence_type: str,
        origin_group_id: str = None,
        origin_issue: str = None
    ) -> Dict:
        """Create a new outreach sequence for a prospect"""
        template = OutreachEngine.SEQUENCE_TEMPLATES.get(sequence_type, {})
        steps = template.get("steps", [])

        return db.insert("e55_outreach_sequences", {
            "agent_id": agent_id,
            "golden_record_id": golden_record_id,
            "sequence_name": f"{sequence_type} — GR#{golden_record_id}",
            "sequence_type": sequence_type,
            "origin_group_id": origin_group_id,
            "origin_issue": origin_issue,
            "total_steps": len(steps),
            "current_step": 0,
            "steps_config": json.dumps(steps),
            "channel": steps[0]["channel"] if steps else "email",
            "status": "active",
            "next_step_at": datetime.utcnow().isoformat()
        })


# ═══════════════════════════════════════════════════════════════
# UNIFIED INBOX CLASSIFIER
# ═══════════════════════════════════════════════════════════════

class InboxClassifier:
    """AI-powered message classification for the unified inbox"""

    INTENT_KEYWORDS = {
        "donation_intent": ["donate", "contribute", "give", "support financially", "write a check"],
        "volunteer_offer": ["volunteer", "help out", "sign up", "get involved", "canvass", "phone bank"],
        "event_interest": ["event", "rally", "meeting", "attend", "when is", "where is"],
        "issue_question": ["what is your position", "where do you stand", "policy on", "thoughts on"],
        "endorsement": ["endorse", "support", "backing", "recommend"],
        "complaint": ["disappointed", "upset", "disagree", "wrong", "terrible"],
        "positive_feedback": ["great", "amazing", "thank you", "love", "impressed", "proud"],
    }

    @staticmethod
    def classify_message(
        agent_id: str,
        golden_record_id: int,
        channel: str,
        subject: str = "",
        body: str = "",
        origin_group_id: str = None,
        origin_sequence_id: str = None
    ) -> Dict:
        """Classify and store an inbound message"""

        # Simple keyword-based classification (would use OpenAI in production)
        text = f"{subject} {body}".lower()
        intent = "other"
        for category, keywords in InboxClassifier.INTENT_KEYWORDS.items():
            if any(kw in text for kw in keywords):
                intent = category
                break

        # Sentiment (simplified)
        positive_words = ["great", "thank", "love", "amazing", "excellent", "proud", "happy"]
        negative_words = ["upset", "angry", "disappointed", "terrible", "wrong", "hate"]
        pos_count = sum(1 for w in positive_words if w in text)
        neg_count = sum(1 for w in negative_words if w in text)
        sentiment = "positive" if pos_count > neg_count else "negative" if neg_count > pos_count else "neutral"

        # Urgency
        urgent_words = ["urgent", "asap", "immediately", "emergency", "time sensitive"]
        urgency = "high" if any(w in text for w in urgent_words) else "normal"

        return db.insert("e55_unified_inbox", {
            "agent_id": agent_id,
            "golden_record_id": golden_record_id,
            "channel": channel,
            "direction": "inbound",
            "subject": subject,
            "body": body,
            "intent_category": intent,
            "sentiment": sentiment,
            "urgency": urgency,
            "status": "unread",
            "origin_group_id": origin_group_id,
            "origin_sequence_id": origin_sequence_id
        })


# ═══════════════════════════════════════════════════════════════
# AGENT ORCHESTRATOR — Main entry point
# ═══════════════════════════════════════════════════════════════

class E55Agent:
    """
    Main orchestrator for the E55 Autonomous Intelligence Agent.
    Coordinates all subsystems: ICP, enrichment, groups, news, outreach.
    """

    def __init__(self, agent_id: str):
        self.agent_id = agent_id
        self.enrichment = WaterfallEnrichment()
        self.monitor = SocialGroupMonitor()
        self.news = NewsCycleReactor()
        self.briefing = BriefingGenerator()
        self.outreach = OutreachEngine()
        self.inbox = InboxClassifier()
        self.icp = ICPEngine()

    def get_status(self) -> Dict:
        """Get agent dashboard stats"""
        dashboard = db.query("e55_agent_dashboard", {"agent_id": f"eq.{self.agent_id}"})
        return dashboard[0] if dashboard else {}

    def get_origin_report(self) -> List[Dict]:
        """Get prospect origin attribution report"""
        return db.rpc("e55_origin_attribution_report", {"p_agent_id": self.agent_id})

    async def process_enrichment_queue(self, batch_size: int = 10):
        """Process pending enrichment requests"""
        queue = db.query("e55_enrichment_queue", {
            "agent_id": f"eq.{self.agent_id}",
            "pipeline_status": "eq.queued",
            "order": "priority.asc,created_at.asc",
            "limit": batch_size
        })

        for item in queue:
            try:
                await self.enrichment.enrich_prospect(
                    queue_id=item["id"],
                    person_name=item.get("person_name", ""),
                    email=item.get("email"),
                    address=item.get("address"),
                    depth="standard"
                )
            except Exception as e:
                log.error(f"Enrichment failed for queue {item['id']}: {e}")
                db.update("e55_enrichment_queue", {"id": item["id"]}, {
                    "pipeline_status": "failed",
                    "last_error": str(e),
                    "attempts": item.get("attempts", 0) + 1
                })

    def log_activity(self, activity_type: str, detail: str, target_id: str = None,
                     origin_group_id: str = None, metadata: Dict = None):
        """Log an agent activity"""
        db.insert("e55_agent_activity_log", {
            "agent_id": self.agent_id,
            "activity_type": activity_type,
            "detail": detail,
            "target_id": target_id,
            "origin_group_id": origin_group_id,
            "metadata": json.dumps(metadata or {})
        })


# ═══════════════════════════════════════════════════════════════
# CLI INTERFACE
# ═══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("""
E55 Autonomous Intelligence Agent — CLI

Usage:
  python e55_enrichment_agent.py status <agent_id>
  python e55_enrichment_agent.py origins <agent_id>
  python e55_enrichment_agent.py enrich <agent_id> [batch_size]
  python e55_enrichment_agent.py news <headline> <issue_category> <impact>
  python e55_enrichment_agent.py sources
  python e55_enrichment_agent.py icp <agent_id> <name> <prompt>
""")
        sys.exit(0)

    cmd = sys.argv[1]

    if cmd == "sources":
        sources = db.query("e55_enrichment_sources", {
            "order": "waterfall_priority.asc",
            "select": "source_name,source_category,waterfall_priority,avg_hit_rate,cost_per_lookup_cents"
        })
        print(f"\n{'Source':<35} {'Category':<18} {'Priority':<10} {'Hit Rate':<10} {'Cost'}")
        print("─" * 90)
        for s in sources:
            cost = f"${s['cost_per_lookup_cents']/100:.2f}" if s['cost_per_lookup_cents'] > 0 else "Free"
            print(f"{s['source_name']:<35} {s['source_category']:<18} {s['waterfall_priority']:<10} {s['avg_hit_rate']}%{'':<5} {cost}")
        print(f"\nTotal sources: {len(sources)}")

    elif cmd == "status":
        agent_id = sys.argv[2]
        agent = E55Agent(agent_id)
        status = agent.get_status()
        if status:
            print(json.dumps(status, indent=2, default=str))
        else:
            print(f"No agent found: {agent_id}")

    elif cmd == "origins":
        agent_id = sys.argv[2]
        agent = E55Agent(agent_id)
        report = agent.get_origin_report()
        print(json.dumps(report, indent=2, default=str))

    else:
        print(f"Unknown command: {cmd}")
