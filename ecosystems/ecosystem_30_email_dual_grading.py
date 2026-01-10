#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 30: EMAIL SYSTEM - DUAL GRADING UPDATE
============================================================================
Updated to route emails based on dual grading (state vs county)

- A++ donors get personalized, high-touch emails
- County campaigns use county grade for targeting
- Statewide campaigns use state grade
============================================================================
"""

from typing import List, Dict, Optional
from dataclasses import dataclass
from enum import Enum

# ============================================================================
# EMAIL ROUTING BY GRADE
# ============================================================================

class EmailTemplate(Enum):
    PERSONALIZED_VIP = "personalized_vip"       # A++, A+ (handcrafted)
    HIGH_VALUE = "high_value"                    # A, A- (personalized merge)
    STANDARD_SEGMENTED = "standard_segmented"    # B tier
    MASS_OPTIMIZED = "mass_optimized"            # C tier
    MINIMAL = "minimal"                          # D tier

class EmailConfig:
    """Email configuration by grade"""
    
    TEMPLATE_BY_GRADE = {
        'A++': EmailTemplate.PERSONALIZED_VIP,
        'A+':  EmailTemplate.PERSONALIZED_VIP,
        'A':   EmailTemplate.HIGH_VALUE,
        'A-':  EmailTemplate.HIGH_VALUE,
        'B+':  EmailTemplate.STANDARD_SEGMENTED,
        'B':   EmailTemplate.STANDARD_SEGMENTED,
        'B-':  EmailTemplate.STANDARD_SEGMENTED,
        'C+':  EmailTemplate.MASS_OPTIMIZED,
        'C':   EmailTemplate.MASS_OPTIMIZED,
        'C-':  EmailTemplate.MASS_OPTIMIZED,
        'D':   EmailTemplate.MINIMAL,
    }
    
    # Max emails per week by grade
    MAX_EMAILS_PER_WEEK = {
        'A++': 1,   # Very selective
        'A+':  1,
        'A':   2,
        'A-':  2,
        'B+':  3,
        'B':   3,
        'B-':  3,
        'C+':  4,
        'C':   4,
        'C-':  4,
        'D':   5,   # Higher frequency, lower value
    }
    
    # Personalization level by grade
    PERSONALIZATION = {
        'A++': ['first_name', 'last_name', 'donation_history', 'personal_note', 'handwritten_signature'],
        'A+':  ['first_name', 'last_name', 'donation_history', 'personal_note'],
        'A':   ['first_name', 'last_name', 'donation_history'],
        'A-':  ['first_name', 'last_name', 'last_donation'],
        'B+':  ['first_name', 'last_name'],
        'B':   ['first_name'],
        'B-':  ['first_name'],
        'C+':  ['first_name'],
        'C':   [],
        'C-':  [],
        'D':   [],
    }


@dataclass
class EmailRecipient:
    """Email recipient with dual grading info"""
    donor_id: str
    email: str
    full_name: str
    county: str
    
    # Dual grades
    grade_state: str
    rank_state: int
    grade_county: str
    rank_county: int
    
    # Donation info
    total_donations: float
    last_donation_date: str


def get_email_template(recipient: EmailRecipient, campaign_type: str) -> EmailTemplate:
    """
    Select email template based on grade and campaign type
    
    For local campaigns, use county grade
    For statewide campaigns, use state grade
    """
    if campaign_type in ['local', 'county', 'sheriff', 'commissioner', 'school_board']:
        grade = recipient.grade_county
    else:
        grade = recipient.grade_state
    
    return EmailConfig.TEMPLATE_BY_GRADE.get(grade, EmailTemplate.MINIMAL)


def get_email_query_by_grade(
    campaign_type: str,
    target_grades: List[str],
    county: Optional[str] = None,
    limit: int = 10000
) -> str:
    """
    Generate SQL query for email list based on campaign type and grades
    """
    grade_list = "'" + "','".join(target_grades) + "'"
    
    if campaign_type in ['local', 'county', 'sheriff', 'commissioner'] and county:
        # Local campaign - use county grade
        return f"""
            SELECT donor_id, email, full_name, county, total_donations,
                   donor_grade_state, donor_rank_state,
                   donor_grade_county, donor_rank_county,
                   last_donation_date
            FROM donors
            WHERE county = '{county}'
              AND donor_grade_county IN ({grade_list})
              AND email IS NOT NULL
              AND email != ''
            ORDER BY donor_rank_county ASC
            LIMIT {limit}
        """
    else:
        # Statewide campaign - use state grade
        return f"""
            SELECT donor_id, email, full_name, county, total_donations,
                   donor_grade_state, donor_rank_state,
                   donor_grade_county, donor_rank_county,
                   last_donation_date
            FROM donors
            WHERE donor_grade_state IN ({grade_list})
              AND email IS NOT NULL
              AND email != ''
            ORDER BY donor_rank_state ASC
            LIMIT {limit}
        """


def build_email_batches(
    recipients: List[EmailRecipient],
    campaign_type: str
) -> Dict[EmailTemplate, List[EmailRecipient]]:
    """
    Organize recipients into batches by email template
    """
    batches = {template: [] for template in EmailTemplate}
    
    for recipient in recipients:
        template = get_email_template(recipient, campaign_type)
        batches[template].append(recipient)
    
    return batches


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("EMAIL SYSTEM - DUAL GRADING QUERIES")
    print("=" * 60)
    
    # Example 1: Statewide fundraising email to A-tier
    print("\n1. STATEWIDE FUNDRAISING (A-tier, state grade)")
    query = get_email_query_by_grade(
        campaign_type='governor',
        target_grades=['A++', 'A+', 'A', 'A-'],
        limit=5000
    )
    print(query)
    
    # Example 2: Forsyth County sheriff race
    print("\n2. FORSYTH SHERIFF RACE (A-tier, county grade)")
    query = get_email_query_by_grade(
        campaign_type='sheriff',
        target_grades=['A++', 'A+', 'A', 'A-'],
        county='Forsyth',
        limit=1000
    )
    print(query)
    
    # Example 3: Mass email to B/C tier
    print("\n3. MASS EMAIL TO B/C TIER (state grade)")
    query = get_email_query_by_grade(
        campaign_type='statewide',
        target_grades=['B+', 'B', 'B-', 'C+', 'C'],
        limit=50000
    )
    print(query)
    
    print("\n" + "=" * 60)
    print("EMAIL SYSTEM READY WITH DUAL GRADING")
    print("=" * 60)
