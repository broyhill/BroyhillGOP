"""
E58 Finance Committee Ecosystem
BroyhillGOP Political Platform

Manages Finance Committees for candidates at all office levels (US Senate to School Board).
Handles committee creation, budget planning, member management, fundraising coordination,
and AI-powered recruitment recommendations.

Architecture:
- DistrictAuditor: Analyzes districts to produce audit records
- BudgetEngine: Creates and maintains budget plans with daily/weekly targets
- CommitteeManager: CRUD and lifecycle management for committees
- AIRecommender: ML-powered committee member recruitment suggestions
- ProspectTracker: Donor prospect pipeline management
- EventCoordinator: Fundraising event management
- PerformanceEngine: Scoring, reporting, and dashboard generation
- BrainConnector: Integration with E20 Intelligence Brain
- QuestionnaireProcessor: Candidate onboarding
- FinanceCommitteeAPI: FastAPI REST endpoints
"""

import os
import json
import logging
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Optional, Dict, List, Any, Tuple
from enum import Enum
from dataclasses import dataclass, asdict
from functools import lru_cache

import httpx
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from scipy.optimize import minimize
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field, validator

# ============================================================================
# LOGGING
# ============================================================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ============================================================================
# ENUMS & DATA CLASSES
# ============================================================================

class MemberRole(str, Enum):
    """Finance committee member roles."""
    CHAIR = "chair"
    VICE_CHAIR = "vice_chair"
    TREASURER = "treasurer"
    SECRETARY = "secretary"
    MAJOR_DONOR = "major_donor"
    BUNDLER = "bundler"
    EVENT_HOST = "event_host"
    GRASSROOTS_COORDINATOR = "grassroots_coordinator"


class DifficultyTier(str, Enum):
    """District difficulty ratings D1-D10."""
    D1 = "D1"
    D2 = "D2"
    D3 = "D3"
    D4 = "D4"
    D5 = "D5"
    D6 = "D6"
    D7 = "D7"
    D8 = "D8"
    D9 = "D9"
    D10 = "D10"


class RepublicanBaseline(str, Enum):
    """Republican performance baseline R1-R10."""
    R1 = "R1"
    R2 = "R2"
    R3 = "R3"
    R4 = "R4"
    R5 = "R5"
    R6 = "R6"
    R7 = "R7"
    R8 = "R8"
    R9 = "R9"
    R10 = "R10"


class ProspectStage(str, Enum):
    """Donor prospect pipeline stages."""
    IDENTIFIED = "identified"
    CONTACTED = "contacted"
    CULTIVATING = "cultivating"
    ASK_SCHEDULED = "ask_scheduled"
    ASKED = "asked"
    COMMITTED = "committed"
    RECEIVED = "received"


@dataclass
class DistrictAuditRecord:
    """Output from DistrictAuditor analysis."""
    district_code: str
    difficulty_score: DifficultyTier
    republican_baseline: RepublicanBaseline
    estimated_budget: float
    voter_count: int
    known_republican_donors: int
    major_donors_count: int
    mid_tier_donors_count: int
    grassroots_donors_count: int
    top_microsegments: List[str]
    partisan_lean_pct: float
    opponent_strength_score: float
    historical_win_rate: float
    created_at: datetime


@dataclass
class BudgetPlan:
    """Budget allocation plan."""
    committee_id: str
    total_budget: float
    election_date: datetime
    daily_target: float
    weekly_target: float
    budget_by_source: Dict[str, float]
    member_goals: Dict[str, float]
    pace_current: float
    pace_trend: str
    created_at: datetime
    updated_at: datetime


@dataclass
class CommitteeMember:
    """Finance committee member record."""
    id: str
    committee_id: str
    person_id: str
    role: MemberRole
    target_amount: float
    personal_gifts: float
    fundraised_total: float
    activity_score: float
    status: str
    joined_at: datetime
    updated_at: datetime


@dataclass
class Prospect:
    """Donor prospect record."""
    id: str
    committee_id: str
    member_id: str
    person_id: str
    stage: ProspectStage
    estimated_capacity: float
    last_activity_date: Optional[datetime]
    contacted_date: Optional[datetime]
    created_at: datetime


# ============================================================================
# PYDANTIC MODELS (API)
# ============================================================================

class CommitteeCreate(BaseModel):
    """Create committee request."""
    candidate_id: str
    office_level: str
    district_code: str
    election_date: datetime
    initial_member_count: int = 5
    target_budget: Optional[float] = None


class CommitteeResponse(BaseModel):
    """Committee response."""
    id: str
    candidate_id: str
    office_level: str
    district_code: str
    status: str
    member_count: int
    current_pace: float
    pace_status: str


class MemberResponse(BaseModel):
    """Committee member response."""
    id: str
    committee_id: str
    name: str
    role: str
    target: float
    raised: float
    performance_grade: str


class WeeklyReport(BaseModel):
    """Member weekly performance report."""
    member_id: str
    week_ending: datetime
    activity_count: int
    asks_made: int
    commitments: int
    amount_raised: float
    pace_vs_target: float
    grade: str
    status_color: str


class EventCreate(BaseModel):
    """Create fundraising event."""
    committee_id: str
    host_member_id: str
    event_date: datetime
    target_revenue: float
    expected_guests: int
    description: Optional[str] = None


class ProspectCreate(BaseModel):
    """Add prospect to pipeline."""
    committee_id: str
    member_id: str
    person_id: str
    estimated_capacity: float


class BrainDirective(BaseModel):
    """Directive from E20 Intelligence Brain."""
    id: str
    committee_id: str
    directive_type: str
    content: Dict[str, Any]
    status: str
    created_at: datetime


# ============================================================================
# SUPABASE CLIENT
# ============================================================================

class SupabaseClient:
    """Async HTTP client for Supabase."""

    def __init__(self):
        self.url = os.getenv('SUPABASE_URL', 'https://example.supabase.co')
        self.key = os.getenv('SUPABASE_KEY', 'fake-key')
        self.client = httpx.AsyncClient(
            base_url=f"{self.url}/rest/v1",
            headers={
                'apikey': self.key,
                'Authorization': f'Bearer {self.key}',
                'Content-Type': 'application/json'
            }
        )

    async def get(self, table: str, filters: Optional[Dict] = None) -> List[Dict]:
        """GET from table with optional filters."""
        query = f"/{table}"
        params = {}
        if filters:
            for key, value in filters.items():
                params[key] = f'eq.{value}'
        try:
            response = await self.client.get(query, params=params)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Error fetching from {table}: {e}")
            return []

    async def post(self, table: str, data: Dict) -> Dict:
        """POST to table."""
        try:
            response = await self.client.post(f"/{table}", json=data)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Error posting to {table}: {e}")
            raise

    async def update(self, table: str, record_id: str, data: Dict) -> Dict:
        """UPDATE record in table."""
        try:
            response = await self.client.patch(
                f"/{table}?id=eq.{record_id}",
                json=data
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Error updating {table}: {e}")
            raise

    async def close(self):
        """Close client."""
        await self.client.aclose()


# ============================================================================
# DISTRICT AUDITOR
# ============================================================================

class DistrictAuditor:
    """Analyzes districts to produce fc_district_audit records."""

    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase

    async def analyze_district(self, district_code: str) -> DistrictAuditRecord:
        """
        Analyze district and produce audit record.
        
        Queries person_spine, contribution_map, nc_datatrust, candidate_profiles.
        Calculates difficulty score, republican baseline, budget estimate,
        and identifies top microsegments.
        """
        logger.info(f"Analyzing district {district_code}")

        # Get district voter data
        persons = await self.supabase.get('person_spine', {'district': district_code})
        voters = [p for p in persons if p.get('voter_flag')]
        
        # Get contribution history for Republicans
        contributions = await self.supabase.get('contribution_map', {})
        r_contributions = [c for c in contributions if c.get('party') == 'R']
        
        # Fetch candidate profiles for competitive analysis
        candidates = await self.supabase.get('candidate_profiles', {})
        district_candidates = [c for c in candidates if c.get('district') == district_code]

        # Calculate metrics
        voter_count = len(voters)
        
        # Partisan lean: % of registered Republicans
        r_voters = len([v for v in voters if v.get('party') == 'R'])
        partisan_lean_pct = (r_voters / voter_count * 100) if voter_count > 0 else 50.0
        
        # Opponent strength (placeholder: use from latest candidate)
        opponent_strength_score = self._calculate_opponent_strength(district_candidates)
        
        # Historical win rate for Republicans in district
        historical_win_rate = self._calculate_historical_winrate(district_candidates)
        
        # Difficulty score D1-D10
        difficulty_score = self._calculate_difficulty(
            partisan_lean_pct, opponent_strength_score, historical_win_rate
        )
        
        # Republican baseline R1-R10
        republican_baseline = self._calculate_republican_baseline(
            r_voters, voter_count, historical_win_rate
        )
        
        # Budget estimate based on office tier and competitiveness
        office_tier_multiplier = self._get_office_tier_multiplier(district_code)
        competitiveness_factor = self._get_competitiveness_factor(difficulty_score)
        base_budget = 100000.0
        estimated_budget = base_budget * office_tier_multiplier * competitiveness_factor
        
        # Count donors by tier
        known_r_donors = len([d for d in r_contributions])
        major_donors = len([d for d in r_contributions if d.get('amount', 0) > 10000])
        mid_tier = len([d for d in r_contributions if 1000 < d.get('amount', 0) <= 10000])
        grassroots = len([d for d in r_contributions if 0 < d.get('amount', 0) <= 1000])
        
        # Top microsegments from voter data
        top_microsegments = self._identify_microsegments(voters)

        record = DistrictAuditRecord(
            district_code=district_code,
            difficulty_score=difficulty_score,
            republican_baseline=republican_baseline,
            estimated_budget=round(estimated_budget, 2),
            voter_count=voter_count,
            known_republican_donors=known_r_donors,
            major_donors_count=major_donors,
            mid_tier_donors_count=mid_tier,
            grassroots_donors_count=grassroots,
            top_microsegments=top_microsegments,
            partisan_lean_pct=round(partisan_lean_pct, 2),
            opponent_strength_score=round(opponent_strength_score, 2),
            historical_win_rate=round(historical_win_rate, 2),
            created_at=datetime.utcnow()
        )
        
        logger.info(f"District {district_code} audit: D{difficulty_score.value} / R{republican_baseline.value}")
        return record

    def _calculate_difficulty(self, partisan_lean: float, opponent: float, winrate: float) -> DifficultyTier:
        """D1 = easiest, D10 = hardest."""
        score = (100 - partisan_lean) * 0.4 + opponent * 40 + (100 - winrate) * 0.3
        score = max(1, min(10, round(score / 10)))
        return DifficultyTier[f"D{score}"]

    def _calculate_republican_baseline(self, r_voters: int, total: int, winrate: float) -> RepublicanBaseline:
        """R1 = weakest baseline, R10 = strongest."""
        if total == 0:
            baseline = 5
        else:
            r_pct = r_voters / total * 100
            baseline = min(10, max(1, round(r_pct / 10 * winrate / 100)))
        return RepublicanBaseline[f"R{baseline}"]

    def _calculate_opponent_strength(self, candidates: List[Dict]) -> float:
        """0-100 score of strongest opponent."""
        if not candidates:
            return 50.0
        return max([c.get('strength_score', 50) for c in candidates])

    def _calculate_historical_winrate(self, candidates: List[Dict]) -> float:
        """Historical win rate for Republicans in district (0-100)."""
        if not candidates:
            return 50.0
        r_candidates = [c for c in candidates if c.get('party') == 'R']
        if not r_candidates:
            return 50.0
        wins = len([c for c in r_candidates if c.get('win_flag')])
        return (wins / len(r_candidates) * 100) if r_candidates else 50.0

    def _get_office_tier_multiplier(self, district_code: str) -> float:
        """Multiplier by office level."""
        if district_code.startswith('US-S'):  # US Senate
            return 3.0
        elif district_code.startswith('US-H'):  # House
            return 2.0
        elif district_code.startswith('STATE-S'):  # State Senate
            return 1.5
        elif district_code.startswith('STATE-H'):  # State House
            return 1.2
        else:  # Local
            return 0.8

    def _get_competitiveness_factor(self, difficulty: DifficultyTier) -> float:
        """Higher difficulty = higher competitiveness factor."""
        tier_map = {
            'D1': 0.6, 'D2': 0.7, 'D3': 0.8, 'D4': 0.85, 'D5': 0.9,
            'D6': 1.1, 'D7': 1.2, 'D8': 1.3, 'D9': 1.4, 'D10': 1.5
        }
        return tier_map.get(difficulty.value, 1.0)

    def _identify_microsegments(self, voters: List[Dict]) -> List[str]:
        """Identify top voter microsegments."""
        segments = {}
        for voter in voters[:100]:  # Sample
            seg = voter.get('micro_segment', 'unknown')
            segments[seg] = segments.get(seg, 0) + 1
        
        sorted_segs = sorted(segments.items(), key=lambda x: x[1], reverse=True)
        return [seg for seg, _ in sorted_segs[:5]]


# ============================================================================
# BUDGET ENGINE
# ============================================================================

class BudgetEngine:
    """Creates and maintains budget plans with allocation targets."""

    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase

    async def create_budget_plan(
        self,
        committee_id: str,
        total_budget: float,
        election_date: datetime
    ) -> BudgetPlan:
        """
        Create budget plan with daily/weekly targets.
        Early-weighting: first 60% of timeline = 70% of budget.
        """
        logger.info(f"Creating budget plan for committee {committee_id}: ${total_budget}")

        days_until_election = (election_date - datetime.utcnow()).days
        weeks_until_election = max(1, days_until_election // 7)

        # Early-weighted allocation
        early_pct = 0.70
        early_days = int(days_until_election * 0.6)
        
        early_daily = (total_budget * early_pct) / early_days if early_days > 0 else 0
        late_daily = (total_budget * (1 - early_pct)) / max(1, days_until_election - early_days)
        
        daily_target = (early_daily + late_daily) / 2
        weekly_target = daily_target * 7

        # Budget allocation by source
        budget_by_source = {
            'bundlers': total_budget * 0.60,
            'events': total_budget * 0.30,
            'direct_online_pac_self': total_budget * 0.10
        }

        # Get committee member goals
        members = await self.supabase.get('fc_committee_members', {'committee_id': committee_id})
        member_goals = self._distribute_member_goals(members, total_budget)

        plan = BudgetPlan(
            committee_id=committee_id,
            total_budget=round(total_budget, 2),
            election_date=election_date,
            daily_target=round(daily_target, 2),
            weekly_target=round(weekly_target, 2),
            budget_by_source={k: round(v, 2) for k, v in budget_by_source.items()},
            member_goals=member_goals,
            pace_current=0.0,
            pace_trend="neutral",
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        return plan

    def _distribute_member_goals(self, members: List[Dict], total_budget: float) -> Dict[str, float]:
        """Distribute goals based on role and tier."""
        goals = {}
        
        if not members:
            return goals

        role_weights = {
            MemberRole.CHAIR.value: 0.20,
            MemberRole.VICE_CHAIR.value: 0.15,
            MemberRole.TREASURER.value: 0.10,
            MemberRole.MAJOR_DONOR.value: 0.15,
            MemberRole.BUNDLER.value: 0.20,
            MemberRole.EVENT_HOST.value: 0.12,
            MemberRole.GRASSROOTS_COORDINATOR.value: 0.08,
        }

        for member in members:
            member_id = member.get('id')
            role = member.get('role', MemberRole.GRASSROOTS_COORDINATOR.value)
            weight = role_weights.get(role, 0.08)
            goals[member_id] = round(total_budget * weight, 2)

        return goals

    async def recalculate_pace(self, plan_id: str) -> BudgetPlan:
        """Recalculate pace daily."""
        # Fetch plan and actual progress
        # Update pace_current and pace_trend
        # This is a placeholder for the logic
        logger.info(f"Recalculating pace for plan {plan_id}")
        return BudgetPlan(
            committee_id=plan_id,
            total_budget=0,
            election_date=datetime.utcnow(),
            daily_target=0,
            weekly_target=0,
            budget_by_source={},
            member_goals={},
            pace_current=1.0,
            pace_trend="neutral",
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )


# ============================================================================
# COMMITTEE MANAGER
# ============================================================================

class CommitteeManager:
    """CRUD and lifecycle management for Finance Committees."""

    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase

    async def create_committee(
        self,
        candidate_id: str,
        office_level: str,
        district_code: str,
        election_date: datetime,
        target_budget: Optional[float] = None
    ) -> str:
        """Create new Finance Committee."""
        logger.info(f"Creating committee for candidate {candidate_id}")

        committee_data = {
            'candidate_id': candidate_id,
            'office_level': office_level,
            'district_code': district_code,
            'election_date': election_date.isoformat(),
            'status': 'active',
            'target_budget': target_budget or 100000.0,
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }

        result = await self.supabase.post('fc_committees', committee_data)
        return result.get('id', 'unknown')

    async def add_member(
        self,
        committee_id: str,
        person_id: str,
        role: MemberRole,
        target_amount: float
    ) -> str:
        """Add member to committee."""
        logger.info(f"Adding {role.value} to committee {committee_id}")

        member_data = {
            'committee_id': committee_id,
            'person_id': person_id,
            'role': role.value,
            'target_amount': target_amount,
            'personal_gifts': 0.0,
            'fundraised_total': 0.0,
            'activity_score': 0.0,
            'status': 'invited',
            'joined_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }

        result = await self.supabase.post('fc_committee_members', member_data)
        return result.get('id', 'unknown')

    async def update_member_status(self, member_id: str, status: str) -> None:
        """Update member status (invited → accepted → active → paused/removed)."""
        await self.supabase.update(
            'fc_committee_members',
            member_id,
            {'status': status, 'updated_at': datetime.utcnow().isoformat()}
        )

    async def get_committee(self, committee_id: str) -> Dict:
        """Fetch committee with members."""
        committees = await self.supabase.get('fc_committees', {'id': committee_id})
        if not committees:
            raise HTTPException(status_code=404, detail="Committee not found")
        
        committee = committees[0]
        members = await self.supabase.get('fc_committee_members', {'committee_id': committee_id})
        committee['members'] = members
        
        return committee

    async def get_committee_members(self, committee_id: str) -> List[Dict]:
        """Fetch committee members."""
        return await self.supabase.get('fc_committee_members', {'committee_id': committee_id})


# ============================================================================
# AI RECOMMENDER
# ============================================================================

class AIRecommender:
    """ML-powered committee member recruitment suggestions."""

    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase

    async def recommend_members(self, district_code: str, committee_size: int) -> List[Dict]:
        """
        Score candidates for each role based on:
        - Lifetime giving (30%)
        - Event hosting history (20%)
        - Network size (20%)
        - Industry leadership (15%)
        - Geographic coverage (15%)
        
        Uses IsolationForest for outlier detection.
        """
        logger.info(f"Generating AI recommendations for district {district_code}")

        # Fetch potential members from district
        persons = await self.supabase.get('person_spine', {'district': district_code})
        contributions = await self.supabase.get('contribution_map', {})

        # Score each person
        scored_candidates = []
        for person in persons:
            person_id = person.get('id')
            person_contributions = [c for c in contributions if c.get('person_id') == person_id]
            
            lifetime_giving = sum([c.get('amount', 0) for c in person_contributions])
            event_count = person.get('event_count', 0)
            network_size = len(person_contributions)
            industry = person.get('employer', 'unknown')
            is_leader = person.get('leadership_flag', False)
            
            score = (
                min(lifetime_giving / 100000, 1.0) * 0.30 +
                min(event_count / 10, 1.0) * 0.20 +
                min(network_size / 100, 1.0) * 0.20 +
                (1.0 if is_leader else 0.5) * 0.15 +
                1.0 * 0.15  # Geographic coverage placeholder
            )

            scored_candidates.append({
                'person_id': person_id,
                'name': person.get('name', 'Unknown'),
                'score': score,
                'lifetime_giving': lifetime_giving,
                'event_count': event_count,
                'network_size': network_size,
                'industry': industry
            })

        # Detect outliers (unusually generous donors)
        outliers = self._detect_outliers(scored_candidates)

        # Sort by score
        scored_candidates.sort(key=lambda x: x['score'], reverse=True)

        # Assign roles and build recommendations
        recommendations = []
        roles_to_fill = [
            (MemberRole.CHAIR, 1, 0.30),
            (MemberRole.VICE_CHAIR, 1, 0.25),
            (MemberRole.TREASURER, 1, 0.20),
            (MemberRole.MAJOR_DONOR, 2, 0.25),
            (MemberRole.BUNDLER, 2, 0.22),
        ]

        idx = 0
        for role, count, min_score in roles_to_fill:
            for _ in range(count):
                if idx < len(scored_candidates) and scored_candidates[idx]['score'] >= min_score:
                    cand = scored_candidates[idx]
                    recommendation = {
                        'person_id': cand['person_id'],
                        'name': cand['name'],
                        'recommended_role': role.value,
                        'recommendation_score': round(cand['score'], 3),
                        'reason_narrative': self._generate_reason(cand, role, outliers),
                        'lifetime_giving': cand['lifetime_giving'],
                        'network_size': cand['network_size']
                    }
                    recommendations.append(recommendation)
                    idx += 1

        return recommendations[:committee_size]

    def _detect_outliers(self, candidates: List[Dict]) -> set:
        """Use IsolationForest to detect unusually generous donors."""
        if len(candidates) < 10:
            return set()

        giving_scores = np.array([[c['lifetime_giving']] for c in candidates])
        
        if giving_scores.std() == 0:
            return set()

        scaler = StandardScaler()
        scaled = scaler.fit_transform(giving_scores)
        
        iso_forest = IsolationForest(contamination=0.1, random_state=42)
        outlier_labels = iso_forest.fit_predict(scaled)
        
        outlier_ids = set()
        for i, label in enumerate(outlier_labels):
            if label == -1:
                outlier_ids.add(candidates[i]['person_id'])
        
        return outlier_ids

    def _generate_reason(self, candidate: Dict, role: MemberRole, outliers: set) -> str:
        """Generate narrative reason for recommendation."""
        reasons = []
        
        if candidate['lifetime_giving'] > 50000:
            reasons.append(f"${candidate['lifetime_giving']:,.0f} lifetime giving")
        
        if candidate['event_count'] > 0:
            reasons.append(f"{candidate['event_count']} prior events hosted")
        
        if candidate['network_size'] > 50:
            reasons.append(f"Large network ({candidate['network_size']} connections)")
        
        if candidate['person_id'] in outliers:
            reasons.append("Exceptional donor profile")
        
        return " | ".join(reasons) if reasons else "Strong candidate profile"


# ============================================================================
# PROSPECT TRACKER
# ============================================================================

class ProspectTracker:
    """Donor prospect pipeline management."""

    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase

    async def add_prospect(
        self,
        committee_id: str,
        member_id: str,
        person_id: str,
        estimated_capacity: float
    ) -> str:
        """Add prospect to pipeline."""
        prospect_data = {
            'committee_id': committee_id,
            'member_id': member_id,
            'person_id': person_id,
            'stage': ProspectStage.IDENTIFIED.value,
            'estimated_capacity': estimated_capacity,
            'last_activity_date': None,
            'contacted_date': None,
            'created_at': datetime.utcnow().isoformat()
        }
        
        result = await self.supabase.post('fc_prospects', prospect_data)
        return result.get('id', 'unknown')

    async def update_prospect_stage(self, prospect_id: str, stage: ProspectStage) -> None:
        """Move prospect through pipeline stages."""
        update_data = {
            'stage': stage.value,
            'updated_at': datetime.utcnow().isoformat()
        }
        
        if stage == ProspectStage.CONTACTED:
            update_data['contacted_date'] = datetime.utcnow().isoformat()
        
        if stage in [ProspectStage.ASKED, ProspectStage.COMMITTED, ProspectStage.RECEIVED]:
            update_data['last_activity_date'] = datetime.utcnow().isoformat()
        
        await self.supabase.update('fc_prospects', prospect_id, update_data)

    async def get_stale_prospects(self, committee_id: str, days_inactive: int = 14) -> List[Dict]:
        """Flag prospects with no activity in N days."""
        prospects = await self.supabase.get('fc_prospects', {'committee_id': committee_id})
        
        cutoff = datetime.utcnow() - timedelta(days=days_inactive)
        stale = []
        
        for prospect in prospects:
            last_activity = prospect.get('last_activity_date')
            if not last_activity or datetime.fromisoformat(last_activity) < cutoff:
                stale.append(prospect)
        
        return stale

    async def get_conversion_rate(self, member_id: str) -> float:
        """Calculate member's prospect-to-commitment conversion rate."""
        prospects = await self.supabase.get('fc_prospects', {'member_id': member_id})
        
        if not prospects:
            return 0.0
        
        committed = len([p for p in prospects if p.get('stage') in [
            ProspectStage.COMMITTED.value,
            ProspectStage.RECEIVED.value
        ]])
        
        return (committed / len(prospects)) if prospects else 0.0


# ============================================================================
# EVENT COORDINATOR
# ============================================================================

class EventCoordinator:
    """Fundraising event management."""

    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase

    async def create_event(
        self,
        committee_id: str,
        host_member_id: str,
        event_date: datetime,
        target_revenue: float,
        expected_guests: int,
        description: Optional[str] = None
    ) -> str:
        """Create fundraising event."""
        logger.info(f"Creating event for committee {committee_id}")

        event_data = {
            'committee_id': committee_id,
            'host_member_id': host_member_id,
            'event_date': event_date.isoformat(),
            'target_revenue': target_revenue,
            'expected_guests': expected_guests,
            'description': description or '',
            'status': 'scheduled',
            'actual_revenue': 0.0,
            'actual_guests': 0,
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }

        result = await self.supabase.post('fc_events', event_data)
        return result.get('id', 'unknown')

    async def update_event_results(
        self,
        event_id: str,
        actual_revenue: float,
        actual_guests: int
    ) -> None:
        """Post-event update with results."""
        await self.supabase.update(
            'fc_events',
            event_id,
            {
                'actual_revenue': actual_revenue,
                'actual_guests': actual_guests,
                'status': 'completed',
                'updated_at': datetime.utcnow().isoformat()
            }
        )

    async def generate_followup_list(self, event_id: str) -> List[Dict]:
        """Generate follow-up list from event attendees."""
        # Fetch event attendees and create follow-up tasks
        logger.info(f"Generating follow-up list for event {event_id}")
        return []  # Placeholder


# ============================================================================
# PERFORMANCE ENGINE
# ============================================================================

class PerformanceEngine:
    """Scoring, reporting, and dashboard generation."""

    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase

    async def generate_daily_snapshot(self, committee_id: str) -> Dict:
        """Generate daily performance snapshot."""
        members = await self.supabase.get('fc_committee_members', {'committee_id': committee_id})
        
        total_raised = sum([m.get('fundraised_total', 0) for m in members])
        total_goal = sum([m.get('target_amount', 0) for m in members])
        pace = (total_raised / total_goal) if total_goal > 0 else 0.0

        snapshot = {
            'committee_id': committee_id,
            'timestamp': datetime.utcnow().isoformat(),
            'total_raised': round(total_raised, 2),
            'total_goal': round(total_goal, 2),
            'pace': round(pace, 3),
            'member_count': len(members),
            'active_members': len([m for m in members if m.get('status') == 'active'])
        }

        await self.supabase.post('fc_performance_snapshots', snapshot)
        return snapshot

    async def generate_weekly_report(self, member_id: str) -> WeeklyReport:
        """Generate weekly performance report for member."""
        # Fetch member activity from past 7 days
        logger.info(f"Generating weekly report for member {member_id}")
        
        week_end = datetime.utcnow()
        week_start = week_end - timedelta(days=7)

        # Placeholder: fetch activities and calculate metrics
        report = WeeklyReport(
            member_id=member_id,
            week_ending=week_end,
            activity_count=5,
            asks_made=3,
            commitments=1,
            amount_raised=2500.0,
            pace_vs_target=0.95,
            grade='A',
            status_color='green'
        )

        return report

    def _calculate_performance_grade(self, pace: float) -> str:
        """Grade based on pace vs target."""
        if pace >= 0.95:
            return 'A+' if pace >= 1.0 else 'A'
        elif pace >= 0.85:
            return 'A'
        elif pace >= 0.75:
            return 'B'
        elif pace >= 0.60:
            return 'C'
        elif pace >= 0.40:
            return 'D'
        else:
            return 'F'

    def _get_status_color(self, pace: float, activity_score: float) -> str:
        """Status color: green (on_track/star), yellow (behind), red (inactive)."""
        if activity_score == 0:
            return 'red'
        elif pace >= 0.95:
            return 'green'
        elif pace >= 0.70:
            return 'yellow'
        else:
            return 'red'

    async def generate_candidate_briefing(self, committee_id: str) -> Dict:
        """Generate monthly candidate briefing."""
        members = await self.supabase.get('fc_committee_members', {'committee_id': committee_id})
        
        briefing = {
            'committee_id': committee_id,
            'generated_at': datetime.utcnow().isoformat(),
            'total_members': len(members),
            'top_performers': sorted(members, key=lambda m: m.get('fundraised_total', 0), reverse=True)[:3],
            'underperformers': sorted(members, key=lambda m: m.get('fundraised_total', 0))[:3],
            'summary': 'Monthly briefing summary'
        }
        
        return briefing


# ============================================================================
# BRAIN CONNECTOR
# ============================================================================

class BrainConnector:
    """E20 Intelligence Brain integration."""

    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase

    async def get_pending_directives(self, committee_id: str) -> List[BrainDirective]:
        """Fetch pending directives from E20."""
        directives = await self.supabase.get('fc_brain_directives', {
            'committee_id': committee_id
        })
        
        pending = [
            BrainDirective(
                id=d.get('id'),
                committee_id=d.get('committee_id'),
                directive_type=d.get('directive_type'),
                content=d.get('content', {}),
                status=d.get('status', 'pending'),
                created_at=datetime.fromisoformat(d.get('created_at', datetime.utcnow().isoformat()))
            )
            for d in directives if d.get('status') == 'pending'
        ]
        
        return pending

    async def execute_directive(self, directive: BrainDirective) -> None:
        """Execute directive: adjust_target, recommend_recruit, etc."""
        directive_type = directive.directive_type
        content = directive.content
        committee_id = directive.committee_id

        logger.info(f"Executing directive {directive_type} for committee {committee_id}")

        if directive_type == 'adjust_target':
            member_id = content.get('member_id')
            new_target = content.get('new_target')
            await self.supabase.update(
                'fc_committee_members',
                member_id,
                {'target_amount': new_target}
            )

        elif directive_type == 'recommend_recruit':
            person_id = content.get('person_id')
            role = content.get('role')
            target = content.get('target')
            await self.supabase.post('fc_ai_recommendations', {
                'committee_id': committee_id,
                'person_id': person_id,
                'recommended_role': role,
                'target_amount': target,
                'created_at': datetime.utcnow().isoformat()
            })

        elif directive_type == 'flag_underperformer':
            member_id = content.get('member_id')
            await self.supabase.update(
                'fc_committee_members',
                member_id,
                {'status': 'flagged_underperformer'}
            )

        elif directive_type == 'suggest_event':
            host_id = content.get('host_member_id')
            event_date = content.get('event_date')
            target_revenue = content.get('target_revenue')
            await self.supabase.post('fc_event_suggestions', {
                'committee_id': committee_id,
                'host_member_id': host_id,
                'suggested_date': event_date,
                'target_revenue': target_revenue,
                'created_at': datetime.utcnow().isoformat()
            })

        # Mark directive as executed
        await self.supabase.update(
            'fc_brain_directives',
            directive.id,
            {'status': 'executed', 'executed_at': datetime.utcnow().isoformat()}
        )

        # Send event to agent_events for E59 monitoring
        await self.supabase.post('agent_events', {
            'event_type': f'fc_directive_executed',
            'committee_id': committee_id,
            'directive_id': directive.id,
            'directive_type': directive_type,
            'timestamp': datetime.utcnow().isoformat()
        })

    async def send_performance_data_to_ml(self, committee_id: str) -> None:
        """Feed performance data to E21 ML Clustering for pattern detection."""
        members = await self.supabase.get('fc_committee_members', {'committee_id': committee_id})
        
        ml_data = {
            'committee_id': committee_id,
            'timestamp': datetime.utcnow().isoformat(),
            'member_profiles': [
                {
                    'member_id': m.get('id'),
                    'role': m.get('role'),
                    'target': m.get('target_amount'),
                    'raised': m.get('fundraised_total'),
                    'activity_score': m.get('activity_score')
                }
                for m in members
            ]
        }
        
        await self.supabase.post('ml_clustering_inputs', ml_data)


# ============================================================================
# QUESTIONNAIRE PROCESSOR
# ============================================================================

class QuestionnaireProcessor:
    """Candidate onboarding via questionnaire."""

    def __init__(self, supabase: SupabaseClient, ai_recommender: AIRecommender):
        self.supabase = supabase
        self.ai_recommender = ai_recommender

    async def process_questionnaire(
        self,
        candidate_id: str,
        questionnaire_data: Dict
    ) -> str:
        """
        Process questionnaire:
        - Merge candidate-proposed names with AI recommendations
        - Create initial committee structure
        - Seed prospect pipeline
        """
        logger.info(f"Processing questionnaire for candidate {candidate_id}")

        # Extract data
        district_code = questionnaire_data.get('district_code')
        election_date_str = questionnaire_data.get('election_date')
        office_level = questionnaire_data.get('office_level')
        proposed_members = questionnaire_data.get('proposed_members', [])
        personal_network = questionnaire_data.get('personal_network', [])

        election_date = datetime.fromisoformat(election_date_str)

        # Get AI recommendations
        ai_recs = await self.ai_recommender.recommend_members(district_code, 5)

        # Merge candidate proposals with AI recommendations
        merged_members = self._merge_recommendations(proposed_members, ai_recs)

        # Create committee
        committee_id = await self.supabase.post('fc_committees', {
            'candidate_id': candidate_id,
            'office_level': office_level,
            'district_code': district_code,
            'election_date': election_date.isoformat(),
            'status': 'forming',
            'created_at': datetime.utcnow().isoformat()
        }).get('id', 'unknown')

        # Add merged members
        for member in merged_members:
            await self.supabase.post('fc_committee_members', {
                'committee_id': committee_id,
                'person_id': member.get('person_id'),
                'role': member.get('role'),
                'target_amount': member.get('target_amount', 50000),
                'status': 'proposed',
                'created_at': datetime.utcnow().isoformat()
            })

        # Seed prospect pipeline from personal network
        for person in personal_network:
            await self.supabase.post('fc_prospects', {
                'committee_id': committee_id,
                'person_id': person.get('person_id'),
                'stage': ProspectStage.IDENTIFIED.value,
                'estimated_capacity': person.get('estimated_capacity', 5000),
                'created_at': datetime.utcnow().isoformat()
            })

        return committee_id

    def _merge_recommendations(self, proposed: List[Dict], ai_recs: List[Dict]) -> List[Dict]:
        """Merge candidate proposals with AI recommendations."""
        merged = []
        
        # Add proposed members
        for prop in proposed:
            merged.append(prop)
        
        # Add AI recommendations not in proposed
        proposed_ids = {p.get('person_id') for p in proposed}
        for rec in ai_recs:
            if rec.get('person_id') not in proposed_ids:
                merged.append({
                    'person_id': rec.get('person_id'),
                    'role': rec.get('recommended_role'),
                    'target_amount': 50000,
                    'source': 'ai_recommendation'
                })
        
        return merged


# ============================================================================
# FASTAPI APP
# ============================================================================

def create_app(supabase: SupabaseClient) -> FastAPI:
    """Create and configure FastAPI app."""
    
    app = FastAPI(
        title="E58 Finance Committee API",
        version="1.0.0",
        description="Finance Committee management for BroyhillGOP"
    )

    # Initialize services
    auditor = DistrictAuditor(supabase)
    budget_engine = BudgetEngine(supabase)
    committee_manager = CommitteeManager(supabase)
    ai_recommender = AIRecommender(supabase)
    prospect_tracker = ProspectTracker(supabase)
    event_coordinator = EventCoordinator(supabase)
    performance_engine = PerformanceEngine(supabase)
    brain_connector = BrainConnector(supabase)
    questionnaire_processor = QuestionnaireProcessor(supabase, ai_recommender)

    # ===== COMMITTEE ENDPOINTS =====

    @app.get("/committees", response_model=List[CommitteeResponse])
    async def list_committees():
        """List all committees."""
        committees = await supabase.get('fc_committees', {})
        return [CommitteeResponse(
            id=c.get('id'),
            candidate_id=c.get('candidate_id'),
            office_level=c.get('office_level'),
            district_code=c.get('district_code'),
            status=c.get('status'),
            member_count=0,
            current_pace=0.0,
            pace_status='neutral'
        ) for c in committees]

    @app.post("/committees", response_model=CommitteeResponse)
    async def create_committee(req: CommitteeCreate):
        """Create new committee."""
        committee_id = await committee_manager.create_committee(
            req.candidate_id,
            req.office_level,
            req.district_code,
            req.election_date,
            req.target_budget
        )
        
        committee = await committee_manager.get_committee(committee_id)
        return CommitteeResponse(
            id=committee_id,
            candidate_id=req.candidate_id,
            office_level=req.office_level,
            district_code=req.district_code,
            status='active',
            member_count=0,
            current_pace=0.0,
            pace_status='neutral'
        )

    @app.get("/committees/{committee_id}")
    async def get_committee(committee_id: str):
        """Get committee details."""
        return await committee_manager.get_committee(committee_id)

    @app.put("/committees/{committee_id}")
    async def update_committee(committee_id: str, data: Dict):
        """Update committee."""
        await supabase.update('fc_committees', committee_id, data)
        return await committee_manager.get_committee(committee_id)

    # ===== MEMBER ENDPOINTS =====

    @app.get("/committees/{committee_id}/members", response_model=List[MemberResponse])
    async def list_members(committee_id: str):
        """List committee members."""
        members = await committee_manager.get_committee_members(committee_id)
        return [MemberResponse(
            id=m.get('id'),
            committee_id=m.get('committee_id'),
            name=f"Member {m.get('id')[:4]}",
            role=m.get('role'),
            target=m.get('target_amount'),
            raised=m.get('fundraised_total'),
            performance_grade='A'
        ) for m in members]

    @app.post("/committees/{committee_id}/members")
    async def add_member(committee_id: str, role: str, person_id: str, target: float = 50000):
        """Add member to committee."""
        member_id = await committee_manager.add_member(
            committee_id,
            person_id,
            MemberRole(role),
            target
        )
        return {'id': member_id, 'status': 'invited'}

    @app.put("/members/{member_id}")
    async def update_member(member_id: str, data: Dict):
        """Update member."""
        await supabase.update('fc_committee_members', member_id, data)
        return {'status': 'updated'}

    @app.get("/members/{member_id}/weekly-reports")
    async def get_member_reports(member_id: str):
        """Get member weekly reports."""
        report = await performance_engine.generate_weekly_report(member_id)
        return [asdict(report)]

    # ===== EVENT ENDPOINTS =====

    @app.get("/committees/{committee_id}/events")
    async def list_events(committee_id: str):
        """List committee events."""
        return await supabase.get('fc_events', {'committee_id': committee_id})

    @app.post("/committees/{committee_id}/events")
    async def create_event(committee_id: str, req: EventCreate):
        """Create fundraising event."""
        event_id = await event_coordinator.create_event(
            committee_id,
            req.host_member_id,
            req.event_date,
            req.target_revenue,
            req.expected_guests,
            req.description
        )
        return {'id': event_id, 'status': 'scheduled'}

    # ===== PROSPECT ENDPOINTS =====

    @app.get("/committees/{committee_id}/prospects")
    async def list_prospects(committee_id: str):
        """List committee prospects."""
        return await supabase.get('fc_prospects', {'committee_id': committee_id})

    @app.post("/committees/{committee_id}/prospects")
    async def add_prospect(committee_id: str, req: ProspectCreate):
        """Add prospect to pipeline."""
        prospect_id = await prospect_tracker.add_prospect(
            committee_id,
            req.member_id,
            req.person_id,
            req.estimated_capacity
        )
        return {'id': prospect_id, 'stage': 'identified'}

    @app.put("/prospects/{prospect_id}")
    async def update_prospect(prospect_id: str, stage: str):
        """Update prospect stage."""
        await prospect_tracker.update_prospect_stage(prospect_id, ProspectStage(stage))
        return {'status': 'updated'}

    # ===== DASHBOARD ENDPOINTS =====

    @app.get("/committees/{committee_id}/dashboard")
    async def get_dashboard(committee_id: str):
        """Full committee dashboard."""
        committee = await committee_manager.get_committee(committee_id)
        members = committee.get('members', [])
        snapshot = await performance_engine.generate_daily_snapshot(committee_id)
        briefing = await performance_engine.generate_candidate_briefing(committee_id)
        
        return {
            'committee': committee,
            'snapshot': snapshot,
            'briefing': briefing,
            'members': members
        }

    @app.get("/committees/{committee_id}/leaderboard")
    async def get_leaderboard(committee_id: str):
        """Member rankings."""
        members = await committee_manager.get_committee_members(committee_id)
        ranked = sorted(members, key=lambda m: m.get('fundraised_total', 0), reverse=True)
        return [MemberResponse(
            id=m.get('id'),
            committee_id=m.get('committee_id'),
            name=f"Member {m.get('id')[:4]}",
            role=m.get('role'),
            target=m.get('target_amount'),
            raised=m.get('fundraised_total'),
            performance_grade='A'
        ) for m in ranked]

    @app.post("/committees/{committee_id}/ai-recommend")
    async def trigger_ai_recommendations(committee_id: str):
        """Trigger AI member recommendations."""
        committee = await committee_manager.get_committee(committee_id)
        district_code = committee.get('district_code')
        
        recommendations = await ai_recommender.recommend_members(district_code, 5)
        return {'recommendations': recommendations, 'count': len(recommendations)}

    @app.get("/committees/{committee_id}/brain-directives")
    async def get_brain_directives(committee_id: str):
        """Get pending Brain directives."""
        directives = await brain_connector.get_pending_directives(committee_id)
        return [asdict(d) for d in directives]

    @app.put("/brain-directives/{directive_id}/approve")
    async def approve_brain_directive(directive_id: str):
        """Approve and execute directive."""
        directives = await supabase.get('fc_brain_directives', {'id': directive_id})
        if not directives:
            raise HTTPException(status_code=404, detail="Directive not found")
        
        directive_data = directives[0]
        directive = BrainDirective(
            id=directive_data.get('id'),
            committee_id=directive_data.get('committee_id'),
            directive_type=directive_data.get('directive_type'),
            content=directive_data.get('content', {}),
            status=directive_data.get('status'),
            created_at=datetime.fromisoformat(directive_data.get('created_at'))
        )
        
        await brain_connector.execute_directive(directive)
        return {'status': 'executed'}

    # ===== QUESTIONNAIRE ENDPOINTS =====

    @app.post("/candidates/{candidate_id}/questionnaire")
    async def submit_questionnaire(candidate_id: str, data: Dict):
        """Submit candidate questionnaire."""
        committee_id = await questionnaire_processor.process_questionnaire(candidate_id, data)
        return {'committee_id': committee_id, 'status': 'formed'}

    # ===== DISTRICT ENDPOINTS =====

    @app.get("/districts/{district_code}/audit")
    async def get_district_audit(district_code: str):
        """Get district audit."""
        audits = await supabase.get('fc_district_audits', {'district_code': district_code})
        if not audits:
            raise HTTPException(status_code=404, detail="Audit not found")
        return audits[0]

    @app.post("/districts/{district_code}/audit")
    async def trigger_district_audit(district_code: str):
        """Trigger new district audit."""
        record = await auditor.analyze_district(district_code)
        
        audit_data = asdict(record)
        audit_data['created_at'] = audit_data['created_at'].isoformat()
        audit_data['difficulty_score'] = record.difficulty_score.value
        audit_data['republican_baseline'] = record.republican_baseline.value
        
        result = await supabase.post('fc_district_audits', audit_data)
        return result

    # ===== BUDGET ENDPOINTS =====

    @app.get("/budget-plans/{plan_id}")
    async def get_budget_plan(plan_id: str):
        """Get budget plan."""
        plans = await supabase.get('fc_budget_plans', {'id': plan_id})
        if not plans:
            raise HTTPException(status_code=404, detail="Plan not found")
        return plans[0]

    @app.post("/budget-plans/{plan_id}/recalculate")
    async def recalculate_budget_pace(plan_id: str):
        """Recalculate budget pace."""
        plan = await budget_engine.recalculate_pace(plan_id)
        return asdict(plan)

    # ===== PERFORMANCE ENDPOINTS =====

    @app.get("/committees/{committee_id}/snapshots")
    async def get_performance_snapshots(committee_id: str):
        """Get historical performance snapshots."""
        return await supabase.get('fc_performance_snapshots', {'committee_id': committee_id})

    # ===== OFFICE TIERS =====

    @app.get("/tiers")
    async def list_office_tiers():
        """List office tiers and multipliers."""
        return {
            'US_SENATE': 3.0,
            'US_HOUSE': 2.0,
            'STATE_SENATE': 1.5,
            'STATE_HOUSE': 1.2,
            'LOCAL': 0.8
        }

    # ===== HEALTH CHECK =====

    @app.get("/health")
    async def health_check():
        """Health check endpoint."""
        return {'status': 'ok', 'service': 'E58 Finance Committee'}

    return app


# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    import uvicorn

    supabase_client = SupabaseClient()
    app = create_app(supabase_client)

    uvicorn.run(
        app,
        host='0.0.0.0',
        port=8058,
        log_level='info'
    )
