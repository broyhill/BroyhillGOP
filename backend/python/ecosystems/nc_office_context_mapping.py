#!/usr/bin/env python3
"""
============================================================================
NC OFFICE CONTEXT MAPPING
============================================================================

Auto-selects the correct donor grade (State/District/County) based on
the candidate's office type.

Used by:
- E01 Donor Intelligence (grade selection)
- E41 Campaign Builder (audience targeting)
- E34 Events (donor sorting for reply cards)

============================================================================
"""

from enum import Enum
from typing import Dict, Optional, Tuple
from dataclasses import dataclass


class GradeContext(Enum):
    """Grade context levels"""
    STATE = "state"
    DISTRICT = "district"
    COUNTY = "county"


class OfficeType(Enum):
    """NC Office Types"""
    # FEDERAL
    US_SENATE = "us_senate"
    US_HOUSE = "us_house"
    
    # NC COUNCIL OF STATE (10 offices)
    GOVERNOR = "governor"
    LT_GOVERNOR = "lt_governor"
    ATTORNEY_GENERAL = "attorney_general"
    SECRETARY_OF_STATE = "secretary_of_state"
    STATE_AUDITOR = "state_auditor"
    STATE_TREASURER = "state_treasurer"
    SUPERINTENDENT_PUBLIC_INSTRUCTION = "superintendent_public_instruction"
    COMMISSIONER_AGRICULTURE = "commissioner_agriculture"
    COMMISSIONER_INSURANCE = "commissioner_insurance"
    COMMISSIONER_LABOR = "commissioner_labor"
    
    # NC GENERAL ASSEMBLY
    STATE_SENATE = "state_senate"
    STATE_HOUSE = "state_house"
    
    # JUDICIAL - STATEWIDE
    NC_SUPREME_COURT = "nc_supreme_court"
    NC_COURT_OF_APPEALS = "nc_court_of_appeals"
    
    # JUDICIAL - DISTRICT
    SUPERIOR_COURT = "superior_court"
    DISTRICT_COURT = "district_court"
    
    # COUNTY
    COUNTY_COMMISSIONER = "county_commissioner"
    SHERIFF = "sheriff"
    REGISTER_OF_DEEDS = "register_of_deeds"
    CLERK_OF_COURT = "clerk_of_court"
    
    # MUNICIPAL
    MAYOR = "mayor"
    CITY_COUNCIL = "city_council"
    TOWN_BOARD = "town_board"
    
    # LOCAL BOARDS
    SCHOOL_BOARD = "school_board"
    SOIL_WATER_CONSERVATION = "soil_water_conservation"


# Office to Grade Context Mapping
NC_OFFICE_CONTEXT: Dict[str, GradeContext] = {
    # FEDERAL
    OfficeType.US_SENATE.value: GradeContext.STATE,
    OfficeType.US_HOUSE.value: GradeContext.DISTRICT,
    
    # NC COUNCIL OF STATE (10 offices) - All statewide
    OfficeType.GOVERNOR.value: GradeContext.STATE,
    OfficeType.LT_GOVERNOR.value: GradeContext.STATE,
    OfficeType.ATTORNEY_GENERAL.value: GradeContext.STATE,
    OfficeType.SECRETARY_OF_STATE.value: GradeContext.STATE,
    OfficeType.STATE_AUDITOR.value: GradeContext.STATE,
    OfficeType.STATE_TREASURER.value: GradeContext.STATE,
    OfficeType.SUPERINTENDENT_PUBLIC_INSTRUCTION.value: GradeContext.STATE,
    OfficeType.COMMISSIONER_AGRICULTURE.value: GradeContext.STATE,
    OfficeType.COMMISSIONER_INSURANCE.value: GradeContext.STATE,
    OfficeType.COMMISSIONER_LABOR.value: GradeContext.STATE,
    
    # NC GENERAL ASSEMBLY - District-based
    OfficeType.STATE_SENATE.value: GradeContext.DISTRICT,
    OfficeType.STATE_HOUSE.value: GradeContext.DISTRICT,
    
    # JUDICIAL - STATEWIDE
    OfficeType.NC_SUPREME_COURT.value: GradeContext.STATE,
    OfficeType.NC_COURT_OF_APPEALS.value: GradeContext.STATE,
    
    # JUDICIAL - DISTRICT
    OfficeType.SUPERIOR_COURT.value: GradeContext.DISTRICT,
    OfficeType.DISTRICT_COURT.value: GradeContext.DISTRICT,
    
    # COUNTY
    OfficeType.COUNTY_COMMISSIONER.value: GradeContext.COUNTY,
    OfficeType.SHERIFF.value: GradeContext.COUNTY,
    OfficeType.REGISTER_OF_DEEDS.value: GradeContext.COUNTY,
    OfficeType.CLERK_OF_COURT.value: GradeContext.COUNTY,
    
    # MUNICIPAL
    OfficeType.MAYOR.value: GradeContext.COUNTY,
    OfficeType.CITY_COUNCIL.value: GradeContext.COUNTY,
    OfficeType.TOWN_BOARD.value: GradeContext.COUNTY,
    
    # LOCAL BOARDS
    OfficeType.SCHOOL_BOARD.value: GradeContext.COUNTY,
    OfficeType.SOIL_WATER_CONSERVATION.value: GradeContext.COUNTY,
}


# Standard Reply Card Donation Levels (used across all campaigns)
STANDARD_DONATION_MENU = [6800, 5000, 2500, 1000, 500, 100]


# Grade to Donation Level Mapping
GRADE_TO_DONATION_LEVEL: Dict[str, int] = {
    'A++': 6800,
    'A+': 5000,
    'A': 2500,
    'A-': 1000,
    'B+': 1000,
    'B': 500,
    'B-': 500,
    'C+': 500,
    'C': 100,
    'C-': 100,
    'D+': 100,
    'D': 100,
    'D-': 100,
    'U': 100,  # Unknown but qualified - still gets asked
}


@dataclass
class DonorContextualGrade:
    """A donor's grades across all three contexts"""
    donor_id: str
    grade_state: str
    grade_district: str
    grade_county: str
    rank_state: int
    rank_district: int
    rank_county: int


def get_grade_context(office_type: str) -> GradeContext:
    """
    Get the appropriate grade context for an office type.
    
    Args:
        office_type: The type of office (e.g., 'state_house', 'governor')
        
    Returns:
        GradeContext enum value (STATE, DISTRICT, or COUNTY)
    """
    return NC_OFFICE_CONTEXT.get(office_type, GradeContext.COUNTY)


def get_contextual_grade(donor: DonorContextualGrade, office_type: str) -> Tuple[str, int]:
    """
    Get the appropriate grade and rank for a donor based on candidate's office.
    
    Args:
        donor: DonorContextualGrade object with all three grades
        office_type: The candidate's office type
        
    Returns:
        Tuple of (grade, rank) appropriate for the office context
    """
    context = get_grade_context(office_type)
    
    if context == GradeContext.STATE:
        return (donor.grade_state, donor.rank_state)
    elif context == GradeContext.DISTRICT:
        return (donor.grade_district, donor.rank_district)
    else:
        return (donor.grade_county, donor.rank_county)


def get_donation_level_for_grade(grade: str) -> int:
    """
    Get the recommended donation ask level for a grade.
    
    Args:
        grade: The donor's contextual grade (e.g., 'A+', 'B', 'C-')
        
    Returns:
        Recommended donation amount from standard menu
    """
    return GRADE_TO_DONATION_LEVEL.get(grade, 100)


def get_donation_level_for_donor(donor: DonorContextualGrade, office_type: str) -> int:
    """
    Get the recommended donation ask for a donor based on candidate's office.
    
    This is the main function used by Campaign Builder to assign donors to
    reply card levels.
    
    Args:
        donor: DonorContextualGrade object
        office_type: The candidate's office type
        
    Returns:
        Recommended donation amount from standard menu
    """
    grade, _ = get_contextual_grade(donor, office_type)
    return get_donation_level_for_grade(grade)


def calculate_realistic_capacity(
    donors_by_grade: Dict[str, int],
    office_type: str,
    response_rates: Dict[str, float] = None
) -> Dict[str, any]:
    """
    Calculate realistic fundraising capacity based on donor universe.
    
    Args:
        donors_by_grade: Dict mapping grade to count (e.g., {'A++': 3, 'A+': 28, ...})
        office_type: The candidate's office type (for context)
        response_rates: Optional custom response rates by grade
        
    Returns:
        Dict with capacity calculations
    """
    # Default response rates by grade (from historical data)
    default_rates = {
        'A++': 0.35,  # 35% of A++ donors respond
        'A+': 0.28,
        'A': 0.22,
        'A-': 0.18,
        'B+': 0.15,
        'B': 0.12,
        'B-': 0.10,
        'C+': 0.08,
        'C': 0.06,
        'C-': 0.05,
        'D+': 0.04,
        'D': 0.03,
        'D-': 0.02,
        'U': 0.02,
    }
    
    rates = response_rates or default_rates
    
    expected_revenue = 0
    expected_donors = 0
    breakdown = {}
    
    for grade, count in donors_by_grade.items():
        ask_level = GRADE_TO_DONATION_LEVEL.get(grade, 100)
        rate = rates.get(grade, 0.05)
        
        grade_revenue = count * ask_level * rate
        grade_donors = int(count * rate)
        
        expected_revenue += grade_revenue
        expected_donors += grade_donors
        
        breakdown[grade] = {
            'count': count,
            'ask_level': ask_level,
            'response_rate': rate,
            'expected_donors': grade_donors,
            'expected_revenue': grade_revenue
        }
    
    return {
        'realistic_max': round(expected_revenue, 2),
        'conservative_estimate': round(expected_revenue * 0.7, 2),
        'aggressive_estimate': round(expected_revenue * 1.3, 2),
        'expected_donors': expected_donors,
        'breakdown': breakdown
    }


# Special Guest Multipliers
SPECIAL_GUEST_MULTIPLIERS: Dict[str, float] = {
    'us_senator': 4.0,
    'governor': 3.5,
    'us_congressman': 2.5,
    'state_speaker': 2.0,
    'lt_governor': 2.0,
    'celebrity': 2.0,
    'state_senate_leader': 1.5,
    'state_senator': 1.3,
    'state_house_leader': 1.3,
    'former_governor': 1.5,
    'former_senator': 1.3,
}


def calculate_expanded_capacity(
    base_capacity: float,
    guest_type: str
) -> Dict[str, any]:
    """
    Calculate expanded capacity with a special guest.
    
    Args:
        base_capacity: The realistic max without a guest
        guest_type: Type of special guest
        
    Returns:
        Dict with expanded capacity calculations
    """
    multiplier = SPECIAL_GUEST_MULTIPLIERS.get(guest_type, 1.0)
    
    return {
        'base_capacity': base_capacity,
        'guest_type': guest_type,
        'multiplier': multiplier,
        'expanded_capacity': round(base_capacity * multiplier, 2),
        'additional_capacity': round(base_capacity * (multiplier - 1), 2)
    }


# Example usage
if __name__ == "__main__":
    # Example: Destin Hall running for State House
    print("=" * 60)
    print("NC OFFICE CONTEXT MAPPING - EXAMPLE")
    print("=" * 60)
    
    # Create a sample donor
    donor = DonorContextualGrade(
        donor_id="12345",
        grade_state="B+",
        grade_district="A+",
        grade_county="A++",
        rank_state=8234,
        rank_district=2,
        rank_county=1
    )
    
    print(f"\nDonor: Sarah Mitchell")
    print(f"  State Grade: {donor.grade_state} (#{donor.rank_state})")
    print(f"  District Grade: {donor.grade_district} (#{donor.rank_district})")
    print(f"  County Grade: {donor.grade_county} (#{donor.rank_county})")
    
    # For Destin Hall (State House)
    grade, rank = get_contextual_grade(donor, "state_house")
    ask = get_donation_level_for_donor(donor, "state_house")
    print(f"\nFor State House race (HD-87):")
    print(f"  Use Grade: {grade} (#{rank})")
    print(f"  Recommended Ask: ${ask:,}")
    
    # For Governor race
    grade, rank = get_contextual_grade(donor, "governor")
    ask = get_donation_level_for_donor(donor, "governor")
    print(f"\nFor Governor race:")
    print(f"  Use Grade: {grade} (#{rank})")
    print(f"  Recommended Ask: ${ask:,}")
    
    # Capacity calculation example
    print(f"\n" + "=" * 60)
    print("CAPACITY CALCULATION - HD-87")
    print("=" * 60)
    
    donors_by_grade = {
        'A++': 3,
        'A+': 28,
        'A': 114,
        'A-': 140,
        'B+': 285,
        'B': 285,
        'B-': 312,
        'C+': 280,
        'C': 289,
        'C-': 280,
        'D+': 200,
        'D': 200,
        'D-': 154,
        'U': 277
    }
    
    capacity = calculate_realistic_capacity(donors_by_grade, "state_house")
    print(f"\nTotal Donors: {sum(donors_by_grade.values())}")
    print(f"Realistic Max: ${capacity['realistic_max']:,.2f}")
    print(f"Conservative: ${capacity['conservative_estimate']:,.2f}")
    print(f"Aggressive: ${capacity['aggressive_estimate']:,.2f}")
    print(f"Expected Responding: {capacity['expected_donors']} donors")
    
    # With special guest
    expanded = calculate_expanded_capacity(capacity['realistic_max'], 'us_senator')
    print(f"\nWith US Senator as Special Guest ({expanded['multiplier']}x):")
    print(f"  Expanded Capacity: ${expanded['expanded_capacity']:,.2f}")
    print(f"  Additional from Guest: ${expanded['additional_capacity']:,.2f}")
