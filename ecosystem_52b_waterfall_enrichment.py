
class EnrichmentStage(Enum):
    EMAIL_DISCOVERY     = 1
    EMAIL_VERIFICATION  = 2
    PERSON_ENRICHMENT   = 3
    PHONE_DISCOVERY     = 4
    SUPABASE_STORAGE    = 5

@dataclass
class EnrichmentResult:
    """Single provider enrichment attempt result"""
    provider: str
    stage: str
    success: bool
    data: Dict[str, Any] = field(default_factory=dict)
    credits_used: float = 0.0
    response_time_ms: int = 0
    error: str = ""

@dataclass
class Contact:
    """Master contact record — mirrors BetterContact's output schema"""
    first_name: str = ""
    last_name: str = ""
    company: str = ""
    domain: str = ""
    linkedin_url: str = ""
    email: str = ""
    email_verified: bool = False
    email_deliverability: str = ""
    phone: str = ""
    phone_type: str = ""
    job_title: str = ""
    location: str = ""
    gender: str = ""
    social_linkedin: str = ""
    social_twitter: str = ""
    social_facebook: str = ""
    donor_tier: str = ""
    donor_amount: float = 0.0
    enrichment_sources: List[str] = field(default_factory=list)
    enrichment_log: List[Dict] = field(default_factory=list)
    enrichment_score: float = 0.0
    created_at: str = ""
    updated_at: str = ""

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}".strip()

    def compute_score(self) -> float:
        fields_and_weights = {
            "email": 25, "email_verified": 10, "phone": 20,
            "job_title": 15, "location": 10, "social_linkedin": 10,
            "gender": 5, "social_twitter": 5,
        }
        score = 0.0
        for fld, weight in fields_and_weights.items():
            val = getattr(self, fld, None)
            if val and val not in (False, "", "unknown"):
                score += weight
        self.enrichment_score = score
        return score

    def to_dict(self) -> Dict:
        d = asdict(self)
        d["full_name"] = self.full_name
        d["enrichment_score"] = self.compute_score()
        return d


# ---------------------------------------------------------------------------
#  CREDIT TRACKER (SQLite)
# ---------------------------------------------------------------------------

class CreditTracker:
    """Track API usage to prevent budget overruns — persists across runs"""

    def __init__(self, db_path: str = "e52b_credits.db"):
        self.db = sqlite3.connect(db_path)
        self.db.execute("""
            CREATE TABLE IF NOT EXISTS api_usage (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                provider TEXT NOT NULL,
                endpoint TEXT,
                credits_used REAL DEFAULT 1.0,
                contact_id TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        self.db.execute("""
            CREATE TABLE IF NOT EXISTS enrichment_cache (
                contact_hash TEXT PRIMARY KEY,
                enriched_data TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        self.db.commit()

    def log_usage(self, provider: str, endpoint: str, credits: float, contact_id: str = ""):
        self.db.execute(
            "INSERT INTO api_usage (provider, endpoint, credits_used, contact_id) VALUES (?, ?, ?, ?)",
            (provider, endpoint, credits, contact_id)
        )
        self.db.commit()

    def get_monthly_usage(self, provider: str) -> float:
        cursor = self.db.execute(
            "SELECT COALESCE(SUM(credits_used), 0) FROM api_usage "
            "WHERE provider = ? AND timestamp >= date('now', '-30 days')",
            (provider,)
        )
        return cursor.fetchone()[0]

    def can_use(self, provider: str, credits_needed: float = 1.0) -> bool:
        limit_key = {
            "hunter": "hunter_searches", "hunter_verify": "hunter_verifications",
            "apollo": "apollo_credits", "snov": "snov_credits",
            "abstract": "abstract_validations", "zerobounce": "zerobounce_validations",
        }.get(provider, provider)
        limit = FREE_TIER_LIMITS.get(limit_key, 999999)
        current = self.get_monthly_usage(provider)
        return (current + credits_needed) <= limit

    def cache_contact(self, contact_hash: str, data: Dict):
        self.db.execute(
            "INSERT OR REPLACE INTO enrichment_cache (contact_hash, enriched_data) VALUES (?, ?)",
            (contact_hash, json.dumps(data))
        )
        self.db.commit()

    def get_cached(self, contact_hash: str) -> Optional[Dict]:
        cursor = self.db.execute(
            "SELECT enriched_data FROM enrichment_cache WHERE contact_hash = ?",
            (contact_hash,)
        )
        row = cursor.fetchone()
        return json.loads(row[0]) if row else None

    def get_usage_report(self) -> Dict[str, str]:
        report = {}
        for provider, limit_key in [
            ("hunter", "hunter_searches"), ("apollo", "apollo_credits"),
            ("snov", "snov_credits"), ("abstract", "abstract_validations"),
            ("zerobounce", "zerobounce_validations"),
        ]:
            used = self.get_monthly_usage(provider)
            limit = FREE_TIER_LIMITS[limit_key]
            report[provider] = f"{used:.0f}/{limit} ({used/limit*100:.0f}%)"
        return report


# ---------------------------------------------------------------------------
#  API CLIENTS
# ---------------------------------------------------------------------------

class BaseClient:
    """Base API client with retry, rate limiting, and credit tracking"""

    def __init__(self, name: str, base_url: str, tracker: CreditTracker):
        self.name = name
        self.base_url = base_url
        self.tracker = tracker
        self.session = requests.Session()
        self.session.headers.update({"Content-Type": "application/json"})
        self._last_request_time = 0
        self._min_interval = 1.0

    def _throttle(self):
        elapsed = time.time() - self._last_request_time
        if elapsed < self._min_interval:
            time.sleep(self._min_interval - elapsed)
        self._last_request_time = time.time()

    def _request(self, method: str, endpoint: str,
                 params: Dict = None, json_data: Dict = None,
                 retries: int = 3) -> Optional[Dict]:
        self._throttle()
        url = f"{self.base_url}{endpoint}"
        for attempt in range(retries):
            try:
                start = time.time()
                if method == "GET":
                    resp = self.session.get(url, params=params, timeout=15)
                else:
                    resp = self.session.post(url, json=json_data or params, timeout=15)
                if resp.status_code == 200:
                    return resp.json()
                elif resp.status_code == 429:
                    wait = 2 ** (attempt + 1)
                    logger.warning(f"[{self.name}] Rate limited. Waiting {wait}s...")
                    time.sleep(wait)
                    continue
                elif resp.status_code == 401:
                    logger.error(f"[{self.name}] Auth failed — check API key")
                    return None
                elif resp.status_code == 402:
                    logger.error(f"[{self.name}] Payment required — free tier exhausted")
                    return None
                else:
                    logger.warning(f"[{self.name}] HTTP {resp.status_code}: {resp.text[:200]}")
                    return None
            except requests.RequestException as e:
                logger.warning(f"[{self.name}] Request error: {e}")
                if attempt < retries - 1:
                    time.sleep(2 ** attempt)
                    continue
                return None
        return None


class HunterClient(BaseClient):
    """Hunter.io — email discovery + verification + enrichment"""

    def __init__(self, api_key: str, tracker: CreditTracker):
        super().__init__("Hunter.io", "https://api.hunter.io/v2", tracker)
        self.api_key = api_key

    def find_email(self, domain: str, first_name: str = "", last_name: str = "") -> EnrichmentResult:
        if not self.tracker.can_use("hunter"):
            return EnrichmentResult("Hunter.io", "email_discovery", False, error="Monthly quota exhausted")
        params = {"domain": domain, "api_key": self.api_key}
        if first_name: params["first_name"] = first_name
        if last_name:  params["last_name"] = last_name
        start = time.time()
        data = self._request("GET", "/email-finder", params=params)
        ms = int((time.time() - start) * 1000)
        if data and "data" in data and data["data"].get("email"):
            self.tracker.log_usage("hunter", "email-finder", 1.0)
            return EnrichmentResult("Hunter.io", "email_discovery", True,
                                    data=data["data"], credits_used=1.0, response_time_ms=ms)
        return EnrichmentResult("Hunter.io", "email_discovery", False, response_time_ms=ms,
                                error=data.get("errors", [{}])[0].get("details", "No email found") if data else "Request failed")

    def verify_email(self, email: str) -> EnrichmentResult:
        if not self.tracker.can_use("hunter_verify"):
            return EnrichmentResult("Hunter.io", "email_verification", False, error="Verification quota exhausted")
        params = {"email": email, "api_key": self.api_key}
        start = time.time()
        data = self._request("GET", "/email-verifier", params=params)
        ms = int((time.time() - start) * 1000)
        if data and "data" in data:
            self.tracker.log_usage("hunter_verify", "email-verifier", 1.0)
            return EnrichmentResult("Hunter.io", "email_verification", True,
                                    data=data["data"], credits_used=1.0, response_time_ms=ms)
        return EnrichmentResult("Hunter.io", "email_verification", False, response_time_ms=ms, error="Verification failed")


class ApolloClient(BaseClient):
    """Apollo.io — person enrichment (email, phone, title, company)"""

    def __init__(self, api_key: str, tracker: CreditTracker):
        super().__init__("Apollo.io", "https://api.apollo.io/api/v1", tracker)
        self.session.headers.update({"X-Api-Key": api_key})

    def enrich_person(self, first_name: str, last_name: str,
                      domain: str = "", email: str = "",
                      linkedin_url: str = "") -> EnrichmentResult:
        if not self.tracker.can_use("apollo"):
            return EnrichmentResult("Apollo.io", "person_enrichment", False, error="Monthly quota exhausted")
        payload = {"first_name": first_name, "last_name": last_name,
                   "reveal_personal_emails": True, "reveal_phone_number": True}
        if domain:       payload["domain"] = domain
        if email:        payload["email"] = email
        if linkedin_url: payload["linkedin_url"] = linkedin_url
        start = time.time()
        data = self._request("POST", "/people/match", json_data=payload)
        ms = int((time.time() - start) * 1000)
        if data and data.get("person"):
            self.tracker.log_usage("apollo", "people/match", 1.0)
            return EnrichmentResult("Apollo.io", "person_enrichment", True,
                                    data=data["person"], credits_used=1.0, response_time_ms=ms)
        return EnrichmentResult("Apollo.io", "person_enrichment", False, response_time_ms=ms, error="No match found")


class SnovClient(BaseClient):
    """Snov.io — email finder + phone search (OAuth with 1hr token expiry)"""

    def __init__(self, user_id: str, secret: str, tracker: CreditTracker):
        super().__init__("Snov.io", "https://api.snov.io/v1", tracker)
        self.user_id = user_id
        self.secret = secret
        self._token = None
        self._token_expiry = datetime.min

    def _ensure_token(self):
        if datetime.now() < self._token_expiry and self._token:
            return
        resp = requests.post("https://api.snov.io/v1/oauth/access_token", json={
            "grant_type": "client_credentials",
            "client_id": self.user_id, "client_secret": self.secret
        })
        if resp.status_code == 200:
            data = resp.json()
            self._token = data.get("access_token")
            self._token_expiry = datetime.now() + timedelta(minutes=55)
            self.session.headers.update({"Authorization": f"Bearer {self._token}"})
            logger.info("[Snov.io] Token refreshed, expires in 55 min")
        else:
            logger.error(f"[Snov.io] Token refresh failed: {resp.status_code}")

    def find_email(self, domain: str, first_name: str, last_name: str) -> EnrichmentResult:
        if not self.tracker.can_use("snov"):
            return EnrichmentResult("Snov.io", "email_discovery", False, error="Monthly quota exhausted")
        self._ensure_token()
        payload = {"domain": domain, "firstName": first_name, "lastName": last_name}
        start = time.time()
        data = self._request("POST", "/get-emails-from-names", json_data=payload)
        ms = int((time.time() - start) * 1000)
        if data and data.get("success") and data.get("data", {}).get("emails"):
            self.tracker.log_usage("snov", "email-from-names", 1.0)
            return EnrichmentResult("Snov.io", "email_discovery", True,
                                    data=data["data"], credits_used=1.0, response_time_ms=ms)
        return EnrichmentResult("Snov.io", "email_discovery", False, response_time_ms=ms, error="No email found")


class ZeroBounceClient(BaseClient):
    """ZeroBounce — email verification (99.6% accuracy)"""

    def __init__(self, api_key: str, tracker: CreditTracker):
        super().__init__("ZeroBounce", "https://api.zerobounce.net/v2", tracker)
        self.api_key = api_key

    def validate_email(self, email: str) -> EnrichmentResult:
        if not self.tracker.can_use("zerobounce"):
            return EnrichmentResult("ZeroBounce", "email_verification", False, error="Monthly quota exhausted")
        params = {"api_key": self.api_key, "email": email}
        start = time.time()
        data = self._request("GET", "/validate", params=params)
        ms = int((time.time() - start) * 1000)
        if data and "status" in data:
            self.tracker.log_usage("zerobounce", "validate", 1.0)
            return EnrichmentResult("ZeroBounce", "email_verification", True,
                                    data=data, credits_used=1.0, response_time_ms=ms)
        return EnrichmentResult("ZeroBounce", "email_verification", False, response_time_ms=ms, error="Validation failed")


class AbstractClient(BaseClient):
    """Abstract API — email validation (syntax + MX + deliverability)"""

    def __init__(self, api_key: str, tracker: CreditTracker):
        super().__init__("Abstract", "https://emailvalidation.abstractapi.com/v1", tracker)
        self.api_key = api_key

    def validate_email(self, email: str) -> EnrichmentResult:
        if not self.tracker.can_use("abstract"):
            return EnrichmentResult("Abstract", "email_verification", False, error="Monthly quota exhausted")
        params = {"api_key": self.api_key, "email": email}
        start = time.time()
        data = self._request("GET", "/", params=params)
        ms = int((time.time() - start) * 1000)
        if data and "email" in data:
            self.tracker.log_usage("abstract", "validate", 1.0)
            return EnrichmentResult("Abstract", "email_verification", True,
                                    data=data, credits_used=1.0, response_time_ms=ms)
        return EnrichmentResult("Abstract", "email_verification", False, response_time_ms=ms, error="Validation failed")


# ---------------------------------------------------------------------------
#  WATERFALL ENRICHER (ORCHESTRATOR)
# ---------------------------------------------------------------------------

class WaterfallEnricher:
    """
    Master orchestrator — chains providers in waterfall sequence.
    Mirrors BetterContact's logic:
      1. Try primary provider for each stage
      2. If fail/quota → fall through to secondary
      3. Track all credits consumed
      4. Cache results to avoid duplicate enrichments
      5. Respect donor tier (MEGA gets everything, MINOR gets email only)
    """

    def __init__(self, api_keys: Dict[str, str] = None, db_path: str = "e52b_credits.db"):
        keys = api_keys or API_KEYS
        self.tracker = CreditTracker(db_path)
        self.hunter   = HunterClient(keys.get("hunter", ""), self.tracker) if keys.get("hunter") else None
        self.apollo   = ApolloClient(keys.get("apollo", ""), self.tracker) if keys.get("apollo") else None
        self.snov     = SnovClient(keys.get("snov_id", ""), keys.get("snov_secret", ""), self.tracker) if keys.get("snov_id") else None
        self.zbounce  = ZeroBounceClient(keys.get("zerobounce", ""), self.tracker) if keys.get("zerobounce") else None
        self.abstract = AbstractClient(keys.get("abstract", ""), self.tracker) if keys.get("abstract") else None
        self._active_providers = [p for p in [self.hunter, self.apollo, self.snov, self.zbounce, self.abstract] if p]
        logger.info(f"Waterfall initialized with {len(self._active_providers)} providers: "
                    f"{[p.name for p in self._active_providers]}")

    def classify_tier(self, amount: float) -> DonorTier:
        if amount >= DONOR_TIERS["MEGA"]:  return DonorTier.MEGA
        if amount >= DONOR_TIERS["MAJOR"]: return DonorTier.MAJOR
        if amount >= DONOR_TIERS["MID"]:   return DonorTier.MID
        return DonorTier.MINOR

    def _contact_hash(self, contact: Contact) -> str:
        key = f"{contact.first_name}|{contact.last_name}|{contact.company}|{contact.domain}".lower()
        return hashlib.sha256(key.encode()).hexdigest()[:16]

    def _max_stage_for_tier(self, tier: DonorTier) -> int:
        return {
            DonorTier.MEGA: 5, DonorTier.MAJOR: 4,
            DonorTier.MID: 3, DonorTier.MINOR: 2,
        }[tier]

    # --- STAGE 1: EMAIL DISCOVERY ---
    def _stage1_email_discovery(self, contact: Contact) -> Contact:
        if contact.email:
            logger.info(f"  [Stage 1] Email already present: {contact.email}")
            return contact
        if not contact.domain and not contact.company:
            logger.warning(f"  [Stage 1] No domain or company — skipping")
            return contact
        domain = contact.domain or contact.company
        if self.hunter:
            result = self.hunter.find_email(domain, contact.first_name, contact.last_name)
            if result.success:
                contact.email = result.data.get("email", "")
                contact.enrichment_sources.append("Hunter.io")
                logger.info(f"  [Stage 1] Hunter found: {contact.email}")
                return contact
        if self.snov and contact.first_name and contact.last_name:
            result = self.snov.find_email(domain, contact.first_name, contact.last_name)
            if result.success:
                emails = result.data.get("emails", [])
                if emails:
                    contact.email = emails[0].get("email", "")
                    contact.enrichment_sources.append("Snov.io")
                    logger.info(f"  [Stage 1] Snov found: {contact.email}")
                    return contact
        logger.warning(f"  [Stage 1] No email found for {contact.full_name} @ {domain}")
        return contact

    # --- STAGE 2: EMAIL VERIFICATION ---
    def _stage2_email_verification(self, contact: Contact) -> Contact:
        if not contact.email:
            return contact
        if self.zbounce:
            result = self.zbounce.validate_email(contact.email)
            if result.success:
                status = result.data.get("status", "unknown").lower()
                contact.email_deliverability = status
                contact.email_verified = status == "valid"
                contact.gender = result.data.get("gender", "")
                contact.enrichment_sources.append("ZeroBounce")
                logger.info(f"  [Stage 2] ZeroBounce: {status}")
                return contact
        if self.abstract:
            result = self.abstract.validate_email(contact.email)
            if result.success:
                deliverability = result.data.get("deliverability", "unknown")
                contact.email_deliverability = deliverability.lower()
                contact.email_verified = deliverability == "DELIVERABLE"
                contact.enrichment_sources.append("Abstract")
                logger.info(f"  [Stage 2] Abstract: {deliverability}")
                return contact
        if self.hunter:
            result = self.hunter.verify_email(contact.email)
            if result.success:
                status = result.data.get("status", "unknown")
                contact.email_deliverability = status
                contact.email_verified = status == "valid"
                contact.enrichment_sources.append("Hunter.io (verify)")
                logger.info(f"  [Stage 2] Hunter verify: {status}")
                return contact
        logger.warning(f"  [Stage 2] Could not verify {contact.email}")
        return contact

    # --- STAGE 3: PERSON ENRICHMENT ---
    def _stage3_person_enrichment(self, contact: Contact) -> Contact:
        if self.apollo:
            result = self.apollo.enrich_person(
                contact.first_name, contact.last_name,
                domain=contact.domain, email=contact.email,
                linkedin_url=contact.linkedin_url
            )
            if result.success:
                person = result.data
                contact.job_title = person.get("title", contact.job_title)
                contact.location = person.get("city", "")
                if person.get("state"): contact.location += f", {person['state']}"
                contact.social_linkedin = person.get("linkedin_url", "")
                contact.social_twitter = person.get("twitter_url", "")
                contact.social_facebook = person.get("facebook_url", "")
                phones = person.get("phone_numbers", [])
                if phones:
                    phone_data = phones[0] if isinstance(phones[0], dict) else {"raw_number": phones[0]}
                    contact.phone = phone_data.get("raw_number", phone_data.get("sanitized_number", ""))
                    contact.phone_type = phone_data.get("type", "")
                if not contact.email:
                    contact.email = person.get("email", "")
                contact.enrichment_sources.append("Apollo.io")
                logger.info(f"  [Stage 3] Apollo enriched: title={contact.job_title}")
                return contact
        logger.info(f"  [Stage 3] Apollo unavailable or no match")
        return contact

    # --- STAGE 4: PHONE DISCOVERY ---
    def _stage4_phone_discovery(self, contact: Contact) -> Contact:
        if contact.phone:
            logger.info(f"  [Stage 4] Phone already found: {contact.phone}")
            return contact
        logger.info(f"  [Stage 4] No additional phone providers configured")
        return contact

    # --- STAGE 5: SUPABASE STORAGE ---
    def _stage5_supabase_storage(self, contact: Contact) -> Contact:
        if not SUPABASE_URL or not SUPABASE_KEY:
            logger.info(f"  [Stage 5] Supabase not configured — skipping DB write")
            return contact
        try:
            headers = {
                "apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}",
                "Content-Type": "application/json", "Prefer": "return=representation"
            }
            payload = {
                "first_name": contact.first_name, "last_name": contact.last_name,
                "email": contact.email, "email_verified": contact.email_verified,
                "phone": contact.phone, "company": contact.company,
                "job_title": contact.job_title, "location": contact.location,
                "linkedin_url": contact.social_linkedin, "donor_tier": contact.donor_tier,
                "enrichment_score": contact.compute_score(),
                "enrichment_sources": json.dumps(contact.enrichment_sources),
                "updated_at": datetime.utcnow().isoformat()
            }
            resp = requests.post(f"{SUPABASE_URL}/rest/v1/enriched_contacts",
                                 headers=headers, json=payload, timeout=10)
            if resp.status_code in (200, 201):
                contact.enrichment_sources.append("Supabase")
                logger.info(f"  [Stage 5] Stored in Supabase")
            else:
                logger.warning(f"  [Stage 5] Supabase write failed: {resp.status_code}")
        except Exception as e:
            logger.error(f"  [Stage 5] Supabase error: {e}")
        return contact

    # --- MAIN WATERFALL ---
    def enrich(self, contact: Contact, force: bool = False) -> Contact:
        contact_hash = self._contact_hash(contact)
        if not force:
            cached = self.tracker.get_cached(contact_hash)
            if cached:
                logger.info(f"Cache hit for {contact.full_name}")
                return Contact(**{k: v for k, v in cached.items() if k in Contact.__dataclass_fields__})
        tier = self.classify_tier(contact.donor_amount)
        contact.donor_tier = tier.value
        max_stage = self._max_stage_for_tier(tier)
        logger.info(f"\n{'='*60}")
        logger.info(f"ENRICHING: {contact.full_name} @ {contact.domain or contact.company}")
        logger.info(f"  Tier: {tier.value} (${contact.donor_amount:,.0f}) -> Stages 1-{max_stage}")
        logger.info(f"{'='*60}")
        contact.created_at = datetime.utcnow().isoformat()
        stages = [
            (1, self._stage1_email_discovery),
            (2, self._stage2_email_verification),
            (3, self._stage3_person_enrichment),
            (4, self._stage4_phone_discovery),
            (5, self._stage5_supabase_storage),
        ]
        for stage_num, stage_fn in stages:
            if stage_num > max_stage:
                break
            try:
                contact = stage_fn(contact)
            except Exception as e:
                logger.error(f"  Stage {stage_num} error: {e}")
                continue
        contact.compute_score()
        contact.updated_at = datetime.utcnow().isoformat()
        self.tracker.cache_contact(contact_hash, contact.to_dict())
        logger.info(f"\n  RESULT: score={contact.enrichment_score}/100, "
                    f"email={'Y' if contact.email else 'N'}, "
                    f"verified={'Y' if contact.email_verified else 'N'}, "
                    f"phone={'Y' if contact.phone else 'N'}, "
                    f"title={'Y' if contact.job_title else 'N'}")
        logger.info(f"  Sources: {', '.join(contact.enrichment_sources)}")
        return contact

    def enrich_batch(self, contacts: List[Contact],
                     max_count: int = 5, force: bool = False) -> List[Contact]:
        """Enrich a batch with safety limit to prevent accidental overuse."""
        if len(contacts) > max_count:
            logger.warning(f"SAFETY LIMIT: Processing only {max_count} of {len(contacts)} contacts")
            contacts = contacts[:max_count]
        results = []
        for i, contact in enumerate(contacts):
            logger.info(f"\n[{i+1}/{len(contacts)}] Processing {contact.full_name}...")
            enriched = self.enrich(contact, force=force)
            results.append(enriched)
            if i < len(contacts) - 1:
                time.sleep(1)
        return results

    def usage_report(self) -> str:
        report = self.tracker.get_usage_report()
        lines = ["\n" + "="*50, "  API USAGE REPORT (Free Tier)", "="*50]
        for provider, usage_str in report.items():
            lines.append(f"  {provider:15s} : {usage_str}")
        lines.append("="*50)
        return "\n".join(lines)


# ---------------------------------------------------------------------------
#  CLI INTERFACE
# ---------------------------------------------------------------------------

def demo_test():
    """Run a safe demo test with 2 sample contacts."""
    enricher = WaterfallEnricher()
    test_contacts = [
        Contact(first_name="Tim", last_name="Cook", company="Apple",
                domain="apple.com", donor_amount=1000),
        Contact(first_name="Satya", last_name="Nadella", company="Microsoft",
                domain="microsoft.com", donor_amount=500),
    ]
    print("\n" + "="*70)
    print("  E52b WATERFALL ENRICHMENT — DEMO TEST (2 contacts)")
    print("  BetterContact Clone — $0 cost, free-tier APIs only")
    print("="*70)
    results = enricher.enrich_batch(test_contacts, max_count=5)
    print("\n\n" + "="*70)
    print("  ENRICHMENT RESULTS")
    print("="*70)
    for c in results:
        print(f"\n  {c.full_name} ({c.donor_tier})")
        print(f"    Email:    {c.email or '-'} {'verified' if c.email_verified else ''}")
        print(f"    Phone:    {c.phone or '-'} {c.phone_type}")
        print(f"    Title:    {c.job_title or '-'}")
        print(f"    Location: {c.location or '-'}")
        print(f"    LinkedIn: {c.social_linkedin or '-'}")
        print(f"    Score:    {c.enrichment_score}/100")
        print(f"    Sources:  {', '.join(c.enrichment_sources) or 'none'}")
    print(enricher.usage_report())
    return results


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--demo":
        demo_test()
    elif len(sys.argv) > 1 and sys.argv[1] == "--usage":
        enricher = WaterfallEnricher()
        print(enricher.usage_report())
    elif len(sys.argv) > 1 and sys.argv[1] == "--enrich":
        if len(sys.argv) < 5:
            print("Usage: --enrich <first> <last> <domain> [amount]")
            sys.exit(1)
        contact = Contact(first_name=sys.argv[2], last_name=sys.argv[3],
                          domain=sys.argv[4],
                          donor_amount=float(sys.argv[5]) if len(sys.argv) > 5 else 100)
        enricher = WaterfallEnricher()
        result = enricher.enrich(contact)
        print(json.dumps(result.to_dict(), indent=2))
    else:
        print("""
E52b WATERFALL ENRICHMENT — BetterContact Clone (Free Tier)
Usage:
  --demo              Run test with 2 sample contacts
  --usage             Show current API usage report
  --enrich F L D [A]  Enrich single contact (name, domain, $)

Environment Variables (required):
  HUNTER_API_KEY, APOLLO_API_KEY, SNOV_USER_ID, SNOV_API_SECRET,
  ABSTRACT_API_KEY, ZEROBOUNCE_API_KEY
  SUPABASE_URL, SUPABASE_SERVICE_KEY (optional)

Free Tier Capacity: ~100-150 contacts/month at $0
""")


if __name__ == "__main__":
    main()
