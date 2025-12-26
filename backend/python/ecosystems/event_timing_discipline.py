#!/usr/bin/env python3
"""
============================================================================
EVENT TIMING DISCIPLINE
============================================================================

Enforces timing rules for event solicitation:

RULE: Paid solicitation comes FIRST, volunteer file activated LAST

Timeline:
- Day -30 to -5: PAID SOLICITATION ONLY (top-down by grade)
- Day -4 to -1: UNDERSELL RECOVERY (volunteer file, free invites only)
- Day 0: EVENT DAY

This prevents:
1. Giving away seats that could have been sold
2. Cannibalizing paid asks with free invites
3. Underselling events due to poor timing

============================================================================
"""

from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum


class EventPhase(Enum):
    """Event solicitation phases"""
    PAID_SOLICITATION = "paid_solicitation"
    UNDERSELL_RECOVERY = "undersell_recovery"
    EVENT_SOLD = "event_sold"
    EVENT_DAY = "event_day"
    POST_EVENT = "post_event"


class AudienceType(Enum):
    """Audience types for event invitations"""
    DONOR_FILE = "donor_file"      # Paid solicitation
    VOLUNTEER_FILE = "volunteer_file"  # Free invites


@dataclass
class EventCapacity:
    """Event capacity tracking"""
    total_seats: int
    sold_seats: int = 0
    comped_seats: int = 0
    reserved_seats: int = 0  # For VIPs, staff, etc.
    
    @property
    def available_seats(self) -> int:
        return self.total_seats - self.sold_seats - self.comped_seats - self.reserved_seats
    
    @property
    def fill_rate(self) -> float:
        return (self.sold_seats + self.comped_seats) / self.total_seats if self.total_seats > 0 else 0
    
    @property
    def is_undersold(self) -> bool:
        """Event is undersold if <80% filled"""
        return self.fill_rate < 0.80
    
    @property
    def is_sold_out(self) -> bool:
        return self.available_seats <= 0


# ============================================================================
# TIMING RULES
# ============================================================================

TIMING_RULES = {
    'paid_solicitation_start_days': 30,  # Start 30 days before event
    'paid_solicitation_end_days': 5,     # End paid asks 5 days before
    'undersell_recovery_start_days': 4,  # Volunteer file activated Day -4
    'undersell_recovery_end_days': 1,    # Until day before event
    'undersell_threshold': 0.80,         # 80% fill rate target
}


# ============================================================================
# VOLUNTEER GRADE SYSTEM (V-grades for prioritizing free invites)
# ============================================================================

VOLUNTEER_GRADES = {
    'V-A++': {
        'description': 'Super volunteers - hosted events, major time commitment',
        'priority': 1,
        'criteria': {'hours_logged': 100, 'events_hosted': 1}
    },
    'V-A+': {
        'description': 'Core volunteers - regular shifts, reliable',
        'priority': 2,
        'criteria': {'hours_logged': 50, 'shifts_completed': 10}
    },
    'V-A': {
        'description': 'Active volunteers - multiple shifts completed',
        'priority': 3,
        'criteria': {'hours_logged': 20, 'shifts_completed': 5}
    },
    'V-B': {
        'description': 'Occasional volunteers - some participation',
        'priority': 4,
        'criteria': {'hours_logged': 5, 'shifts_completed': 2}
    },
    'V-C': {
        'description': 'New volunteers - signed up, minimal activity',
        'priority': 5,
        'criteria': {'hours_logged': 0, 'signed_up': True}
    },
    'V-U': {
        'description': 'Volunteer prospects - expressed interest only',
        'priority': 6,
        'criteria': {'expressed_interest': True}
    }
}


# ============================================================================
# CORE FUNCTIONS
# ============================================================================

def get_event_phase(event_date: datetime, current_date: datetime = None) -> EventPhase:
    """
    Determine current phase of event solicitation.
    
    Args:
        event_date: Date of the event
        current_date: Current date (defaults to now)
    
    Returns:
        EventPhase enum
    """
    if current_date is None:
        current_date = datetime.now()
    
    days_until = (event_date - current_date).days
    
    if days_until < 0:
        return EventPhase.POST_EVENT
    elif days_until == 0:
        return EventPhase.EVENT_DAY
    elif days_until <= TIMING_RULES['undersell_recovery_end_days']:
        return EventPhase.UNDERSELL_RECOVERY
    elif days_until <= TIMING_RULES['undersell_recovery_start_days']:
        return EventPhase.UNDERSELL_RECOVERY
    elif days_until <= TIMING_RULES['paid_solicitation_start_days']:
        return EventPhase.PAID_SOLICITATION
    else:
        return EventPhase.PAID_SOLICITATION  # Pre-event but ok to start


def get_eligible_audience(
    event_date: datetime,
    capacity: EventCapacity,
    current_date: datetime = None
) -> Dict:
    """
    Determine who can be invited based on timing and capacity.
    
    Returns:
        Dict with audience_type, grades_to_target, and reasoning
    """
    phase = get_event_phase(event_date, current_date)
    
    if phase == EventPhase.POST_EVENT:
        return {
            'audience_type': None,
            'can_invite': False,
            'reason': 'Event has already occurred'
        }
    
    if phase == EventPhase.EVENT_DAY:
        return {
            'audience_type': None,
            'can_invite': False,
            'reason': 'Event day - no new invitations'
        }
    
    if capacity.is_sold_out:
        return {
            'audience_type': None,
            'can_invite': False,
            'reason': 'Event is sold out',
            'phase': EventPhase.EVENT_SOLD.value
        }
    
    if phase == EventPhase.PAID_SOLICITATION:
        return {
            'audience_type': AudienceType.DONOR_FILE.value,
            'can_invite': True,
            'grades_to_target': ['A++', 'A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C'],
            'invitation_type': 'paid',
            'reason': 'Paid solicitation phase - donor file only',
            'phase': phase.value
        }
    
    if phase == EventPhase.UNDERSELL_RECOVERY:
        if capacity.is_undersold:
            return {
                'audience_type': AudienceType.VOLUNTEER_FILE.value,
                'can_invite': True,
                'grades_to_target': ['V-A++', 'V-A+', 'V-A', 'V-B', 'V-C'],
                'invitation_type': 'free',
                'reason': f'Undersell recovery - {capacity.fill_rate:.0%} filled, activating volunteer file',
                'phase': phase.value,
                'seats_to_fill': capacity.available_seats
            }
        else:
            return {
                'audience_type': AudienceType.DONOR_FILE.value,
                'can_invite': True,
                'grades_to_target': ['A++', 'A+', 'A', 'A-', 'B+'],  # Top grades only for last-minute
                'invitation_type': 'paid',
                'reason': f'Event on track ({capacity.fill_rate:.0%} filled) - continue paid solicitation',
                'phase': phase.value
            }
    
    return {
        'audience_type': None,
        'can_invite': False,
        'reason': 'Unknown phase'
    }


def sort_donors_for_event(
    donors: List[Dict],
    event_type: str = 'fundraiser'
) -> List[Dict]:
    """
    Sort donors top-down by contextual grade for event solicitation.
    
    Args:
        donors: List of donor dicts with 'grade' key
        event_type: Type of event
    
    Returns:
        Sorted list (highest grade first)
    """
    grade_order = [
        'A++', 'A+', 'A', 'A-',
        'B+', 'B', 'B-',
        'C+', 'C', 'C-',
        'D+', 'D', 'D-',
        'U'
    ]
    
    def grade_sort_key(donor):
        grade = donor.get('grade', 'U')
        try:
            return grade_order.index(grade)
        except ValueError:
            return len(grade_order)
    
    return sorted(donors, key=grade_sort_key)


def sort_volunteers_for_free_invites(
    volunteers: List[Dict]
) -> List[Dict]:
    """
    Sort volunteers by V-grade for free invite prioritization.
    
    Args:
        volunteers: List of volunteer dicts with 'v_grade' key
    
    Returns:
        Sorted list (highest V-grade first)
    """
    v_grade_order = ['V-A++', 'V-A+', 'V-A', 'V-B', 'V-C', 'V-U']
    
    def v_grade_sort_key(volunteer):
        grade = volunteer.get('v_grade', 'V-U')
        try:
            return v_grade_order.index(grade)
        except ValueError:
            return len(v_grade_order)
    
    return sorted(volunteers, key=v_grade_sort_key)


def calculate_undersell_recovery_plan(
    capacity: EventCapacity,
    volunteer_counts: Dict[str, int]
) -> Dict:
    """
    Calculate how many volunteers to invite from each V-grade to fill event.
    
    Args:
        capacity: EventCapacity object
        volunteer_counts: Dict of V-grade -> count available
    
    Returns:
        Dict with invitation plan by V-grade
    """
    seats_needed = capacity.available_seats
    
    if seats_needed <= 0:
        return {
            'seats_needed': 0,
            'plan': {},
            'message': 'Event is full, no volunteers needed'
        }
    
    # Assume 30% response rate for free invites
    response_rate = 0.30
    invites_needed = int(seats_needed / response_rate)
    
    plan = {}
    remaining_invites = invites_needed
    
    v_grade_order = ['V-A++', 'V-A+', 'V-A', 'V-B', 'V-C', 'V-U']
    
    for grade in v_grade_order:
        available = volunteer_counts.get(grade, 0)
        to_invite = min(available, remaining_invites)
        
        if to_invite > 0:
            plan[grade] = {
                'available': available,
                'to_invite': to_invite,
                'expected_accepts': int(to_invite * response_rate)
            }
            remaining_invites -= to_invite
        
        if remaining_invites <= 0:
            break
    
    return {
        'seats_needed': seats_needed,
        'invites_needed': invites_needed,
        'plan': plan,
        'total_to_invite': sum(p['to_invite'] for p in plan.values()),
        'expected_fills': sum(p['expected_accepts'] for p in plan.values())
    }


def validate_invitation_timing(
    event_date: datetime,
    audience_type: str,
    invitation_type: str,
    current_date: datetime = None
) -> Dict:
    """
    Validate if an invitation is allowed based on timing rules.
    
    Args:
        event_date: Date of event
        audience_type: 'donor_file' or 'volunteer_file'
        invitation_type: 'paid' or 'free'
        current_date: Current date
    
    Returns:
        Dict with 'allowed', 'reason', and 'recommendation'
    """
    phase = get_event_phase(event_date, current_date)
    
    # Paid solicitation to donors
    if audience_type == 'donor_file' and invitation_type == 'paid':
        if phase == EventPhase.PAID_SOLICITATION:
            return {
                'allowed': True,
                'reason': 'Within paid solicitation window'
            }
        elif phase == EventPhase.UNDERSELL_RECOVERY:
            return {
                'allowed': True,
                'reason': 'Can still solicit donors during undersell recovery',
                'warning': 'Consider focusing on volunteer file if undersold'
            }
        else:
            return {
                'allowed': False,
                'reason': f'Outside solicitation window (phase: {phase.value})'
            }
    
    # Free invites to volunteers
    if audience_type == 'volunteer_file' and invitation_type == 'free':
        if phase == EventPhase.UNDERSELL_RECOVERY:
            return {
                'allowed': True,
                'reason': 'Within undersell recovery window (Day -4 to -1)'
            }
        elif phase == EventPhase.PAID_SOLICITATION:
            return {
                'allowed': False,
                'reason': 'Too early for free invites - paid solicitation phase',
                'recommendation': 'Wait until Day -4 to activate volunteer file',
                'days_until_allowed': (event_date - (current_date or datetime.now())).days - TIMING_RULES['undersell_recovery_start_days']
            }
        else:
            return {
                'allowed': False,
                'reason': f'Outside invitation window (phase: {phase.value})'
            }
    
    # Free invites to donors (comped seats)
    if audience_type == 'donor_file' and invitation_type == 'free':
        return {
            'allowed': True,
            'reason': 'Comped seats for VIP donors allowed anytime',
            'warning': 'Ensure this is strategic, not defaulting to free'
        }
    
    return {
        'allowed': False,
        'reason': 'Invalid audience/invitation combination'
    }


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("EVENT TIMING DISCIPLINE")
    print("=" * 60)
    
    # Example event
    event_date = datetime.now() + timedelta(days=3)  # 3 days from now
    capacity = EventCapacity(total_seats=100, sold_seats=60, comped_seats=5, reserved_seats=5)
    
    print(f"\nEvent Date: {event_date.strftime('%Y-%m-%d')}")
    print(f"Capacity: {capacity.total_seats} seats")
    print(f"Sold: {capacity.sold_seats}")
    print(f"Comped: {capacity.comped_seats}")
    print(f"Available: {capacity.available_seats}")
    print(f"Fill Rate: {capacity.fill_rate:.0%}")
    print(f"Is Undersold: {capacity.is_undersold}")
    
    # Get current phase
    phase = get_event_phase(event_date)
    print(f"\nCurrent Phase: {phase.value}")
    
    # Get eligible audience
    audience = get_eligible_audience(event_date, capacity)
    print(f"\n{'-' * 40}")
    print("ELIGIBLE AUDIENCE:")
    print(f"  Type: {audience.get('audience_type')}")
    print(f"  Can Invite: {audience.get('can_invite')}")
    print(f"  Invitation Type: {audience.get('invitation_type')}")
    print(f"  Reason: {audience.get('reason')}")
    
    if audience.get('grades_to_target'):
        print(f"  Grades to Target: {', '.join(audience['grades_to_target'])}")
    
    # Undersell recovery plan
    if capacity.is_undersold and phase == EventPhase.UNDERSELL_RECOVERY:
        print(f"\n{'-' * 40}")
        print("UNDERSELL RECOVERY PLAN:")
        
        volunteer_counts = {
            'V-A++': 5,
            'V-A+': 15,
            'V-A': 30,
            'V-B': 50,
            'V-C': 100,
            'V-U': 200
        }
        
        plan = calculate_undersell_recovery_plan(capacity, volunteer_counts)
        print(f"  Seats Needed: {plan['seats_needed']}")
        print(f"  Invites to Send: {plan['invites_needed']}")
        print(f"  Expected Fills: {plan['expected_fills']}")
        print(f"\n  By V-Grade:")
        for grade, details in plan.get('plan', {}).items():
            print(f"    {grade}: Invite {details['to_invite']} → Expect {details['expected_accepts']} accepts")
    
    # Validation examples
    print(f"\n{'-' * 40}")
    print("VALIDATION EXAMPLES:")
    
    # Try to send free volunteer invites during paid phase
    test_date = datetime.now() + timedelta(days=10)
    validation = validate_invitation_timing(
        event_date=datetime.now() + timedelta(days=10),
        audience_type='volunteer_file',
        invitation_type='free'
    )
    print(f"\n  Free volunteer invites 10 days before event:")
    print(f"    Allowed: {validation['allowed']}")
    print(f"    Reason: {validation['reason']}")
    if validation.get('recommendation'):
        print(f"    Recommendation: {validation['recommendation']}")
