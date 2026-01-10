#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 1: DONOR INTELLIGENCE SYSTEM - DUAL GRADING UPDATE
============================================================================
UPDATED December 2024 to support DUAL GRADING:
- donor_grade_state (A++ to D based on NC statewide rank)
- donor_grade_county (A++ to D based on county rank)

This allows:
- Statewide campaigns to target by state grade
- Local campaigns to target by county grade
- Same donor can be A+ statewide but A++ in their county

Development Value: $100,000+
============================================================================
"""

import os
import logging
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem1.donor_intelligence')

# ============================================================================
# DUAL GRADING CONFIGURATION
# ============================================================================

class GradeType(Enum):
    STATE = "state"      # Rank against all NC donors
    COUNTY = "county"    # Rank within their county
    
class DualGradeConfig:
    """Configuration for dual grading system"""
    
    # Grade order (best to worst)
    GRADE_ORDER = ['A++', 'A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D', 'U']
    
    # Grade to percentile thresholds
    GRADE_THRESHOLDS = {
        'A++': 99.9,  # Top 0.1%
        'A+':  99.0,  # Top 1%
        'A':   95.0,  # Top 5%
        'A-':  90.0,  # Top 10%
        'B+':  80.0,  # Top 20%
        'B':   70.0,  # Top 30%
        'B-':  60.0,  # Top 40%
        'C+':  50.0,  # Top 50%
        'C':   40.0,  # Top 60%
        'C-':  30.0,  # Top 70%
        'D':   0.0,   # Bottom 30%
    }
    
    # Budget allocation by grade ($ per contact)
    BUDGET_PER_CONTACT = {
        'A++': 50.00,  # High-touch, personal
        'A+':  25.00,
        'A':   15.00,
        'A-':  10.00,
        'B+':   5.00,
        'B':    3.00,
        'B-':   2.00,
        'C+':   1.00,
        'C':    0.50,
        'C-':   0.25,
        'D':    0.10,  # Digital only
        'U':    0.00,  # No contact
    }
    
    # Communication channels by grade
    CHANNELS_BY_GRADE = {
        'A++': ['phone', 'personal_visit', 'handwritten', 'email', 'event_invite'],
        'A+':  ['phone', 'handwritten', 'email', 'event_invite'],
        'A':   ['phone', 'email', 'direct_mail', 'event_invite'],
        'A-':  ['phone', 'email', 'direct_mail'],
        'B+':  ['email', 'direct_mail', 'sms'],
        'B':   ['email', 'direct_mail', 'sms'],
        'B-':  ['email', 'sms'],
        'C+':  ['email', 'sms'],
        'C':   ['email'],
        'C-':  ['email'],
        'D':   ['email'],
        'U':   [],
    }
    
    # Blocked grades (cannot contact)
    BLOCKED_GRADES = ['U']
    
    # Restricted grades (requires approval)
    RESTRICTED_GRADES = ['D']


# ============================================================================
# DUAL GRADING QUERIES
# ============================================================================

class DualGradingQueries:
    """SQL queries optimized for dual grading"""
    
    @staticmethod
    def get_donors_by_state_grade(grade: str, limit: int = 1000) -> str:
        """Get donors by statewide grade"""
        return f"""
            SELECT donor_id, full_name, email, phone, county, total_donations,
                   donor_grade_state, donor_rank_state,
                   donor_grade_county, donor_rank_county
            FROM donors
            WHERE donor_grade_state = '{grade}'
            ORDER BY donor_rank_state ASC
            LIMIT {limit}
        """
    
    @staticmethod
    def get_donors_by_county_grade(county: str, grade: str, limit: int = 500) -> str:
        """Get donors by county grade"""
        return f"""
            SELECT donor_id, full_name, email, phone, county, total_donations,
                   donor_grade_state, donor_rank_state,
                   donor_grade_county, donor_rank_county
            FROM donors
            WHERE county = '{county}' AND donor_grade_county = '{grade}'
            ORDER BY donor_rank_county ASC
            LIMIT {limit}
        """
    
    @staticmethod
    def get_county_top_donors(county: str, limit: int = 100) -> str:
        """Get top donors in a specific county"""
        return f"""
            SELECT donor_id, full_name, email, phone, total_donations,
                   donor_grade_state, donor_rank_state,
                   donor_grade_county, donor_rank_county
            FROM donors
            WHERE county = '{county}'
            ORDER BY donor_rank_county ASC
            LIMIT {limit}
        """
    
    @staticmethod
    def get_statewide_leaderboard(limit: int = 100) -> str:
        """Get statewide donor leaderboard"""
        return f"""
            SELECT donor_id, full_name, county, total_donations,
                   donor_grade_state, donor_rank_state,
                   donor_grade_county, donor_rank_county
            FROM donors
            ORDER BY donor_rank_state ASC
            LIMIT {limit}
        """
    
    @staticmethod
    def get_grade_distribution() -> str:
        """Get count of donors by grade"""
        return """
            SELECT donor_grade_state as grade, COUNT(*) as count,
                   SUM(total_donations) as total_donations,
                   AVG(total_donations) as avg_donation
            FROM donors
            WHERE donor_grade_state IS NOT NULL
            GROUP BY donor_grade_state
            ORDER BY CASE donor_grade_state
                WHEN 'A++' THEN 1 WHEN 'A+' THEN 2 WHEN 'A' THEN 3 WHEN 'A-' THEN 4
                WHEN 'B+' THEN 5 WHEN 'B' THEN 6 WHEN 'B-' THEN 7
                WHEN 'C+' THEN 8 WHEN 'C' THEN 9 WHEN 'C-' THEN 10
                WHEN 'D' THEN 11 ELSE 12 END
        """
    
    @staticmethod
    def get_county_summary() -> str:
        """Get summary stats for each county"""
        return """
            SELECT county,
                   COUNT(*) as donor_count,
                   SUM(total_donations) as total_donations,
                   AVG(total_donations) as avg_donation,
                   COUNT(*) FILTER (WHERE donor_grade_county IN ('A++','A+','A')) as a_tier_count
            FROM donors
            WHERE county IS NOT NULL
            GROUP BY county
            ORDER BY total_donations DESC
        """
    
    @staticmethod
    def get_dual_grade_comparison() -> str:
        """Find donors where state grade differs from county grade"""
        return """
            SELECT donor_id, full_name, county, total_donations,
                   donor_grade_state, donor_rank_state,
                   donor_grade_county, donor_rank_county
            FROM donors
            WHERE donor_grade_state != donor_grade_county
              AND donor_grade_state IS NOT NULL
              AND donor_grade_county IS NOT NULL
            ORDER BY total_donations DESC
            LIMIT 100
        """


# ============================================================================
# DUAL GRADING FUNCTIONS
# ============================================================================

@dataclass
class DonorProfile:
    """Complete donor profile with dual grading"""
    donor_id: str
    full_name: str
    email: Optional[str]
    phone: Optional[str]
    county: Optional[str]
    total_donations: float
    
    # State ranking
    grade_state: str
    rank_state: int
    percentile_state: float
    
    # County ranking  
    grade_county: str
    rank_county: int
    percentile_county: float
    
    def get_best_grade(self) -> str:
        """Return the better of state or county grade"""
        state_idx = DualGradeConfig.GRADE_ORDER.index(self.grade_state) if self.grade_state in DualGradeConfig.GRADE_ORDER else 99
        county_idx = DualGradeConfig.GRADE_ORDER.index(self.grade_county) if self.grade_county in DualGradeConfig.GRADE_ORDER else 99
        return self.grade_state if state_idx <= county_idx else self.grade_county
    
    def get_budget_allocation(self, use_county: bool = False) -> float:
        """Get budget allocation based on grade"""
        grade = self.grade_county if use_county else self.grade_state
        return DualGradeConfig.BUDGET_PER_CONTACT.get(grade, 0)
    
    def get_channels(self, use_county: bool = False) -> List[str]:
        """Get allowed communication channels based on grade"""
        grade = self.grade_county if use_county else self.grade_state
        return DualGradeConfig.CHANNELS_BY_GRADE.get(grade, [])
    
    def can_contact(self) -> bool:
        """Check if this donor can be contacted"""
        return (self.grade_state not in DualGradeConfig.BLOCKED_GRADES and
                self.grade_county not in DualGradeConfig.BLOCKED_GRADES)


def select_grade_for_campaign(campaign_type: str, county: Optional[str] = None) -> GradeType:
    """
    Decide whether to use state or county grade based on campaign type
    
    - Statewide campaigns: Use state grade
    - Local/county campaigns: Use county grade
    - Major donor programs: Use state grade
    - Grassroots/volume: Use county grade (more A's per county)
    """
    if campaign_type in ['statewide', 'federal', 'major_donor', 'governor', 'senate']:
        return GradeType.STATE
    elif campaign_type in ['local', 'county', 'state_house', 'state_senate', 'sheriff', 'commissioner']:
        return GradeType.COUNTY
    elif county:
        return GradeType.COUNTY
    else:
        return GradeType.STATE


def get_target_list(
    campaign_type: str,
    target_grades: List[str],
    county: Optional[str] = None,
    limit: int = 1000
) -> str:
    """
    Generate SQL query for campaign target list
    
    Uses appropriate grading (state vs county) based on campaign type
    """
    grade_type = select_grade_for_campaign(campaign_type, county)
    
    grade_list = "'" + "','".join(target_grades) + "'"
    
    if grade_type == GradeType.COUNTY and county:
        return f"""
            SELECT donor_id, full_name, email, phone, county, total_donations,
                   donor_grade_state, donor_grade_county,
                   donor_rank_county
            FROM donors
            WHERE county = '{county}'
              AND donor_grade_county IN ({grade_list})
            ORDER BY donor_rank_county ASC
            LIMIT {limit}
        """
    else:
        return f"""
            SELECT donor_id, full_name, email, phone, county, total_donations,
                   donor_grade_state, donor_grade_county,
                   donor_rank_state
            FROM donors
            WHERE donor_grade_state IN ({grade_list})
            ORDER BY donor_rank_state ASC
            LIMIT {limit}
        """


# ============================================================================
# GRADE ENFORCEMENT
# ============================================================================

class GradeEnforcementError(Exception):
    """Raised when attempting to contact a blocked donor"""
    pass


def enforce_grade_rules(donor_grade: str, action: str) -> bool:
    """
    Enforce grade-based contact rules
    
    Raises GradeEnforcementError if action is not allowed
    """
    if donor_grade in DualGradeConfig.BLOCKED_GRADES:
        raise GradeEnforcementError(
            f"BLOCKED: Cannot perform '{action}' on donor with grade {donor_grade}. "
            f"Grades {DualGradeConfig.BLOCKED_GRADES} are blocked from all contact."
        )
    
    if donor_grade in DualGradeConfig.RESTRICTED_GRADES:
        logger.warning(f"RESTRICTED: Action '{action}' on grade {donor_grade} requires approval")
        return False  # Requires approval
    
    return True  # Allowed


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("DUAL GRADING SYSTEM - EXAMPLES")
    print("=" * 60)
    
    # Example 1: Statewide major donor campaign
    print("\n1. STATEWIDE MAJOR DONOR CAMPAIGN (targets A++, A+)")
    query = get_target_list(
        campaign_type='major_donor',
        target_grades=['A++', 'A+'],
        limit=100
    )
    print(query)
    
    # Example 2: Forsyth County local race
    print("\n2. FORSYTH COUNTY SHERIFF RACE (targets A-tier in county)")
    query = get_target_list(
        campaign_type='sheriff',
        target_grades=['A++', 'A+', 'A', 'A-'],
        county='Forsyth',
        limit=500
    )
    print(query)
    
    # Example 3: Grade comparison
    print("\n3. FIND DONORS WITH DIFFERENT STATE VS COUNTY GRADES")
    print(DualGradingQueries.get_dual_grade_comparison())
    
    print("\n" + "=" * 60)
    print("DUAL GRADING READY FOR ECOSYSTEM USE")
    print("=" * 60)
