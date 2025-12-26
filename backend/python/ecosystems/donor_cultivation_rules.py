#!/usr/bin/env python3
"""
============================================================================
DONOR CULTIVATION INVESTMENT RULES
============================================================================

Cost/benefit rules for donor cultivation by grade level.
Integrates with E20 Intelligence Brain for budget enforcement.

Key Concepts:
- Higher grades = more investment allowed
- U donors = low cost, high volume cultivation (future pipeline)
- ML tracks engagement to identify promotion candidates
- Automatic grade promotion based on engagement triggers

============================================================================
"""

from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
from datetime import datetime, timedelta


class CultivationChannel(Enum):
    """Available cultivation channels"""
    EMAIL = "email"
    SMS = "sms"
    PHONE = "phone"
    DIRECT_MAIL = "direct_mail"
    EVENTS = "events"
    RVM = "rvm"


# ============================================================================
# INVESTMENT CAPS BY GRADE
# ============================================================================

CULTIVATION_INVESTMENT_CAPS: Dict[str, Dict] = {
    # Elite donors - unlimited investment
    'A++': {
        'annual_cap': None,  # No cap
        'channels': ['phone', 'direct_mail', 'email', 'events', 'sms', 'rvm'],
        'contact_frequency': 'unlimited',
        'personal_attention': True,
        'major_donor_program': True
    },
    'A+': {
        'annual_cap': 100.00,
        'channels': ['phone', 'direct_mail', 'email', 'events', 'sms'],
        'contact_frequency': 'weekly',
        'personal_attention': True,
        'major_donor_program': True
    },
    'A': {
        'annual_cap': 50.00,
        'channels': ['phone', 'direct_mail', 'email', 'events'],
        'contact_frequency': 'biweekly',
        'personal_attention': False,
        'major_donor_program': False
    },
    'A-': {
        'annual_cap': 35.00,
        'channels': ['direct_mail', 'email', 'events'],
        'contact_frequency': 'biweekly',
        'personal_attention': False,
        'major_donor_program': False
    },
    
    # Mid-tier donors
    'B+': {
        'annual_cap': 25.00,
        'channels': ['direct_mail', 'email', 'events'],
        'contact_frequency': 'monthly',
        'personal_attention': False,
        'major_donor_program': False
    },
    'B': {
        'annual_cap': 15.00,
        'channels': ['direct_mail', 'email'],
        'contact_frequency': 'monthly',
        'personal_attention': False,
        'major_donor_program': False
    },
    'B-': {
        'annual_cap': 10.00,
        'channels': ['email', 'sms'],
        'contact_frequency': 'monthly',
        'personal_attention': False,
        'major_donor_program': False
    },
    
    # Lower-tier donors
    'C+': {
        'annual_cap': 5.00,
        'channels': ['email'],
        'contact_frequency': 'monthly',
        'personal_attention': False,
        'major_donor_program': False
    },
    'C': {
        'annual_cap': 3.00,
        'channels': ['email'],
        'contact_frequency': 'bimonthly',
        'personal_attention': False,
        'major_donor_program': False
    },
    'C-': {
        'annual_cap': 2.00,
        'channels': ['email'],
        'contact_frequency': 'bimonthly',
        'personal_attention': False,
        'major_donor_program': False
    },
    
    # Bottom tier
    'D+': {
        'annual_cap': 1.00,
        'channels': ['email'],
        'contact_frequency': 'quarterly',
        'personal_attention': False,
        'major_donor_program': False
    },
    'D': {
        'annual_cap': 0.75,
        'channels': ['email'],
        'contact_frequency': 'quarterly',
        'personal_attention': False,
        'major_donor_program': False
    },
    'D-': {
        'annual_cap': 0.50,
        'channels': ['email'],
        'contact_frequency': 'quarterly',
        'personal_attention': False,
        'major_donor_program': False
    },
    
    # Unknown but qualified - FUTURE PIPELINE
    'U': {
        'annual_cap': 0.50,  # Low investment
        'channels': ['email'],  # Email only (cheapest)
        'contact_frequency': 'monthly',  # Consistent nurturing
        'personal_attention': False,
        'major_donor_program': False,
        'cultivation_priority': 'long_term',  # Special flag for U donors
        'ml_tracking': True  # Track engagement for promotion
    }
}


# ============================================================================
# CHANNEL COSTS (used to calculate investment)
# ============================================================================

CHANNEL_COSTS: Dict[str, float] = {
    'email': 0.01,      # $0.01 per email
    'sms': 0.02,        # $0.02 per SMS
    'rvm': 0.03,        # $0.03 per ringless voicemail
    'phone': 0.15,      # $0.15 per phone call (live)
    'direct_mail': 0.75, # $0.75 per mail piece
    'events': 25.00,    # $25 per event seat (average)
}


# ============================================================================
# PROMOTION TRIGGERS (when to upgrade donor grade)
# ============================================================================

PROMOTION_TRIGGERS: Dict[str, Dict] = {
    # U → D: Any sign of life
    'U_to_D': {
        'email_opens': 3,      # Opened 3 emails
        'clicks': 1,           # Clicked 1 link
        'or_donation': True,   # OR made any donation
        'timeframe_days': 180  # Within 6 months
    },
    
    # D → C: Showing real interest
    'D_to_C': {
        'email_opens': 5,
        'clicks': 2,
        'or_donation': 25,     # OR donated $25+
        'event_rsvp': 1,       # OR RSVP'd to event
        'timeframe_days': 180
    },
    
    # C → B: Becoming active
    'C_to_B': {
        'total_donated': 100,  # Cumulative donations
        'or_engagement_score': 60,  # OR high engagement
        'event_attendance': 1,  # Attended an event
        'timeframe_days': 365
    },
    
    # B → A: Significant contributor
    'B_to_A': {
        'total_donated': 500,
        'donation_count': 3,   # Multiple donations
        'or_event_host': True, # OR hosted an event
        'timeframe_days': 365
    },
    
    # A → A+: Major donor territory
    'A_to_A+': {
        'total_donated': 2500,
        'or_bundler': True,    # OR brought in other donors
        'timeframe_days': 730  # 2 years
    },
    
    # A+ → A++: Elite status
    'A+_to_A++': {
        'total_donated': 10000,
        'or_max_out': True,    # OR maxed out to multiple candidates
        'timeframe_days': 730
    }
}


# ============================================================================
# DEMOTION TRIGGERS (when to downgrade donor grade)
# ============================================================================

DEMOTION_TRIGGERS: Dict[str, Dict] = {
    # A++ → A+: Reduced giving
    'A++_to_A+': {
        'no_donation_days': 730,  # 2 years without donation
        'and_no_engagement_days': 365  # AND no engagement for 1 year
    },
    
    # Any grade: Lapsed status
    'any_to_lapsed': {
        'no_donation_days': 365,
        'no_engagement_days': 180
    },
    
    # Lapsed → Inactive
    'lapsed_to_inactive': {
        'no_donation_days': 730,
        'no_engagement_days': 365
    }
}


# ============================================================================
# U DONOR CULTIVATION STRATEGY
# ============================================================================

U_DONOR_CULTIVATION_STRATEGY = {
    'goal': 'Move U donors up the ladder over time through consistent, low-cost nurturing',
    
    'channels': {
        'primary': 'email',
        'secondary': None,  # No secondary until promoted
        'forbidden': ['phone', 'direct_mail']  # Too expensive
    },
    
    'content_types': [
        'newsletter',           # Issue updates
        'welcome_series',       # Onboarding
        'rally_invites',        # Free events only
        'volunteer_asks',       # Free engagement
        'survey_requests',      # Low cost engagement
        'social_share_asks'     # Zero cost
    ],
    
    'frequency': {
        'max_emails_per_month': 4,
        'min_emails_per_month': 1
    },
    
    'investment_rules': {
        'max_annual_spend': 0.50,
        'roi_floor': 0.0,  # Accept $0 return initially
        'roi_review_months': 12,  # Review after 1 year
        'promotion_check_frequency': 'monthly'
    },
    
    'ml_tracking': {
        'track_email_opens': True,
        'track_clicks': True,
        'track_time_on_page': True,
        'track_social_engagement': True,
        'track_event_rsvps': True,
        'score_threshold_for_upgrade': 50
    },
    
    'success_metrics': {
        'conversion_to_donor_rate': 0.05,  # 5% become donors
        'average_time_to_first_donation': 180,  # 6 months
        'average_first_donation_amount': 50
    }
}


# ============================================================================
# FUNCTIONS
# ============================================================================

def get_investment_cap(grade: str) -> Optional[float]:
    """Get annual investment cap for a grade"""
    config = CULTIVATION_INVESTMENT_CAPS.get(grade, CULTIVATION_INVESTMENT_CAPS['U'])
    return config.get('annual_cap')


def get_allowed_channels(grade: str) -> List[str]:
    """Get allowed cultivation channels for a grade"""
    config = CULTIVATION_INVESTMENT_CAPS.get(grade, CULTIVATION_INVESTMENT_CAPS['U'])
    return config.get('channels', ['email'])


def can_use_channel(grade: str, channel: str) -> bool:
    """Check if a channel is allowed for a grade"""
    allowed = get_allowed_channels(grade)
    return channel in allowed


def calculate_cultivation_cost(grade: str, channels_used: Dict[str, int]) -> float:
    """
    Calculate total cultivation cost for a donor.
    
    Args:
        grade: Donor's grade
        channels_used: Dict of channel -> count (e.g., {'email': 12, 'direct_mail': 2})
    
    Returns:
        Total cost
    """
    total = 0.0
    for channel, count in channels_used.items():
        cost_per = CHANNEL_COSTS.get(channel, 0.01)
        total += cost_per * count
    return round(total, 2)


def is_over_budget(grade: str, spent: float) -> bool:
    """Check if cultivation spend exceeds cap"""
    cap = get_investment_cap(grade)
    if cap is None:  # No cap (A++)
        return False
    return spent > cap


def check_promotion_eligibility(
    current_grade: str,
    email_opens: int = 0,
    clicks: int = 0,
    total_donated: float = 0,
    donation_count: int = 0,
    event_attendance: int = 0,
    engagement_score: float = 0,
    days_tracked: int = 180
) -> Optional[str]:
    """
    Check if donor is eligible for grade promotion.
    
    Returns new grade if eligible, None if not.
    """
    # Determine which promotion to check
    promotion_key = f"{current_grade}_to_"
    
    # Find matching promotion trigger
    for key, trigger in PROMOTION_TRIGGERS.items():
        if key.startswith(current_grade + '_to_'):
            new_grade = key.split('_to_')[1]
            
            # Check if within timeframe
            if days_tracked > trigger.get('timeframe_days', 365):
                continue
            
            # Check criteria (OR logic for most)
            if trigger.get('or_donation') and total_donated > 0:
                return new_grade
            if trigger.get('or_donation') and isinstance(trigger.get('or_donation'), (int, float)):
                if total_donated >= trigger['or_donation']:
                    return new_grade
            if email_opens >= trigger.get('email_opens', 999):
                if clicks >= trigger.get('clicks', 999):
                    return new_grade
            if total_donated >= trigger.get('total_donated', 999999):
                return new_grade
            if engagement_score >= trigger.get('or_engagement_score', 999):
                return new_grade
    
    return None


def get_u_donor_next_action(
    email_opens: int,
    clicks: int,
    last_contact_days: int
) -> Dict:
    """
    Determine next action for U donor cultivation.
    
    Returns recommended action and reasoning.
    """
    # Check for promotion eligibility first
    if email_opens >= 3 and clicks >= 1:
        return {
            'action': 'PROMOTE_TO_D',
            'reason': 'Engagement threshold met',
            'next_step': 'Add to D-tier cultivation program'
        }
    
    # Determine nurture action
    if last_contact_days > 30:
        return {
            'action': 'SEND_NURTURE_EMAIL',
            'reason': f'No contact in {last_contact_days} days',
            'content_type': 'newsletter' if email_opens > 0 else 'welcome_series'
        }
    
    if email_opens == 0 and last_contact_days > 60:
        return {
            'action': 'REDUCE_FREQUENCY',
            'reason': 'No engagement, reduce investment',
            'new_frequency': 'quarterly'
        }
    
    return {
        'action': 'CONTINUE_NURTURE',
        'reason': 'On track, continue current cadence',
        'next_contact_days': 30 - last_contact_days
    }


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("DONOR CULTIVATION INVESTMENT RULES")
    print("=" * 60)
    
    # Show investment caps by grade
    print("\nANNUAL INVESTMENT CAPS BY GRADE:")
    print("-" * 40)
    for grade, config in CULTIVATION_INVESTMENT_CAPS.items():
        cap = config['annual_cap']
        cap_str = f"${cap:.2f}" if cap else "Unlimited"
        channels = ", ".join(config['channels'])
        print(f"  {grade:4} | {cap_str:10} | {channels}")
    
    # Example: Check if can use channel
    print("\n" + "=" * 60)
    print("CHANNEL ELIGIBILITY EXAMPLES:")
    print("-" * 40)
    print(f"  A++ can use phone: {can_use_channel('A++', 'phone')}")
    print(f"  B can use phone: {can_use_channel('B', 'phone')}")
    print(f"  U can use phone: {can_use_channel('U', 'phone')}")
    print(f"  U can use email: {can_use_channel('U', 'email')}")
    
    # Example: Calculate cultivation cost
    print("\n" + "=" * 60)
    print("CULTIVATION COST EXAMPLE:")
    print("-" * 40)
    channels_used = {'email': 24, 'direct_mail': 4}
    cost = calculate_cultivation_cost('B+', channels_used)
    cap = get_investment_cap('B+')
    over = is_over_budget('B+', cost)
    print(f"  B+ donor: 24 emails + 4 mail pieces")
    print(f"  Total cost: ${cost:.2f}")
    print(f"  Annual cap: ${cap:.2f}")
    print(f"  Over budget: {over}")
    
    # Example: U donor promotion check
    print("\n" + "=" * 60)
    print("U DONOR PROMOTION CHECK:")
    print("-" * 40)
    new_grade = check_promotion_eligibility(
        current_grade='U',
        email_opens=4,
        clicks=2,
        total_donated=0
    )
    print(f"  U donor with 4 opens, 2 clicks, $0 donated")
    print(f"  Eligible for promotion to: {new_grade}")
    
    # Example: U donor next action
    print("\n" + "=" * 60)
    print("U DONOR NEXT ACTION:")
    print("-" * 40)
    action = get_u_donor_next_action(
        email_opens=2,
        clicks=0,
        last_contact_days=35
    )
    print(f"  U donor: 2 opens, 0 clicks, 35 days since contact")
    print(f"  Recommended: {action['action']}")
    print(f"  Reason: {action['reason']}")
