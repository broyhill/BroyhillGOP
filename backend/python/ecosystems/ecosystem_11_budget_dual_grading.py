#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 11: BUDGET MANAGEMENT - DUAL GRADING UPDATE
============================================================================
Allocates campaign budget based on dual grading

KEY INSIGHT:
- A++ statewide donor: $50 budget per contact
- A++ county donor (but C statewide): $50 for LOCAL campaigns, $0.50 for statewide

This prevents wasting major donor budget on people who are only big fish
in small ponds, while still treating them as VIPs for local races.
============================================================================
"""

from typing import Dict, List, Optional
from dataclasses import dataclass
from enum import Enum

# ============================================================================
# BUDGET ALLOCATION BY GRADE
# ============================================================================

class BudgetConfig:
    """Budget allocation per contact by grade"""
    
    # Cost per contact by grade
    BUDGET_PER_CONTACT = {
        'A++': 50.00,   # Personal visits, handwritten notes, premium events
        'A+':  25.00,   # Phone calls, personalized mail, events
        'A':   15.00,   # Quality direct mail, phone
        'A-':  10.00,   # Direct mail, email
        'B+':   5.00,   # Direct mail
        'B':    3.00,   # Standard mail
        'B-':   2.00,   # Bulk mail
        'C+':   1.00,   # Digital + occasional mail
        'C':    0.50,   # Digital only
        'C-':   0.25,   # Email only
        'D':    0.10,   # Minimal digital
        'U':    0.00,   # No budget
    }
    
    # Channel allocation by grade (% of budget)
    CHANNEL_ALLOCATION = {
        'A++': {'personal_visit': 30, 'phone': 25, 'mail': 20, 'event': 15, 'digital': 10},
        'A+':  {'phone': 30, 'mail': 30, 'event': 20, 'digital': 20},
        'A':   {'phone': 25, 'mail': 35, 'event': 15, 'digital': 25},
        'A-':  {'mail': 40, 'phone': 20, 'digital': 40},
        'B+':  {'mail': 50, 'digital': 50},
        'B':   {'mail': 40, 'digital': 60},
        'B-':  {'mail': 30, 'digital': 70},
        'C+':  {'mail': 20, 'digital': 80},
        'C':   {'digital': 100},
        'C-':  {'digital': 100},
        'D':   {'digital': 100},
    }
    
    # Expected ROI by grade
    EXPECTED_ROI = {
        'A++': 15.0,  # 15X return on investment
        'A+':  12.0,
        'A':   10.0,
        'A-':   8.0,
        'B+':   5.0,
        'B':    4.0,
        'B-':   3.0,
        'C+':   2.0,
        'C':    1.5,
        'C-':   1.2,
        'D':    0.8,  # Below break-even
    }


@dataclass
class BudgetAllocation:
    """Budget allocation for a campaign"""
    campaign_id: str
    campaign_type: str
    county: Optional[str]
    total_budget: float
    
    # Breakdown by grade
    grade_allocations: Dict[str, float]
    grade_counts: Dict[str, int]
    
    # Channel breakdown
    channel_allocations: Dict[str, float]
    
    # Expected returns
    expected_revenue: float
    expected_roi: float


def calculate_budget_allocation(
    campaign_type: str,
    total_budget: float,
    donor_counts_by_grade: Dict[str, int],
    county: Optional[str] = None
) -> BudgetAllocation:
    """
    Calculate optimal budget allocation based on donor grades
    
    Uses county grade for local campaigns, state grade for statewide
    """
    
    grade_allocations = {}
    channel_totals = {}
    expected_revenue = 0.0
    
    # Calculate budget needed per grade
    total_cost = 0.0
    for grade, count in donor_counts_by_grade.items():
        cost_per = BudgetConfig.BUDGET_PER_CONTACT.get(grade, 0)
        grade_allocations[grade] = cost_per * count
        total_cost += grade_allocations[grade]
    
    # Scale to fit budget if needed
    if total_cost > total_budget:
        scale_factor = total_budget / total_cost
        for grade in grade_allocations:
            grade_allocations[grade] *= scale_factor
    
    # Calculate channel allocations
    for grade, amount in grade_allocations.items():
        channels = BudgetConfig.CHANNEL_ALLOCATION.get(grade, {'digital': 100})
        for channel, pct in channels.items():
            if channel not in channel_totals:
                channel_totals[channel] = 0
            channel_totals[channel] += amount * (pct / 100)
    
    # Calculate expected revenue
    for grade, amount in grade_allocations.items():
        roi = BudgetConfig.EXPECTED_ROI.get(grade, 1.0)
        expected_revenue += amount * roi
    
    expected_roi = expected_revenue / total_budget if total_budget > 0 else 0
    
    return BudgetAllocation(
        campaign_id='',
        campaign_type=campaign_type,
        county=county,
        total_budget=total_budget,
        grade_allocations=grade_allocations,
        grade_counts=donor_counts_by_grade,
        channel_allocations=channel_totals,
        expected_revenue=expected_revenue,
        expected_roi=expected_roi
    )


def get_budget_query_state(campaign_budget: float) -> str:
    """SQL query to get donor counts by STATE grade for budget planning"""
    return """
        SELECT donor_grade_state as grade, COUNT(*) as count
        FROM donors
        WHERE donor_grade_state IS NOT NULL
        GROUP BY donor_grade_state
        ORDER BY CASE donor_grade_state
            WHEN 'A++' THEN 1 WHEN 'A+' THEN 2 WHEN 'A' THEN 3 WHEN 'A-' THEN 4
            WHEN 'B+' THEN 5 WHEN 'B' THEN 6 WHEN 'B-' THEN 7
            WHEN 'C+' THEN 8 WHEN 'C' THEN 9 WHEN 'C-' THEN 10
            WHEN 'D' THEN 11 ELSE 12 END
    """


def get_budget_query_county(county: str) -> str:
    """SQL query to get donor counts by COUNTY grade for local budget planning"""
    return f"""
        SELECT donor_grade_county as grade, COUNT(*) as count
        FROM donors
        WHERE county = '{county}'
          AND donor_grade_county IS NOT NULL
        GROUP BY donor_grade_county
        ORDER BY CASE donor_grade_county
            WHEN 'A++' THEN 1 WHEN 'A+' THEN 2 WHEN 'A' THEN 3 WHEN 'A-' THEN 4
            WHEN 'B+' THEN 5 WHEN 'B' THEN 6 WHEN 'B-' THEN 7
            WHEN 'C+' THEN 8 WHEN 'C' THEN 9 WHEN 'C-' THEN 10
            WHEN 'D' THEN 11 ELSE 12 END
    """


# ============================================================================
# BUDGET COMPARISON: STATE VS COUNTY GRADE
# ============================================================================

def compare_budget_approaches(county: str, budget: float) -> str:
    """
    Compare budget allocation using state vs county grades
    
    Shows why dual grading matters for local races
    """
    return f"""
    -- COMPARISON: State Grade vs County Grade Budget Allocation
    -- County: {county}
    -- Budget: ${budget:,.0f}
    
    -- Using STATE grade (wrong for local race):
    SELECT 'STATE_GRADE' as approach,
           donor_grade_state as grade,
           COUNT(*) as donors,
           COUNT(*) * {BudgetConfig.BUDGET_PER_CONTACT['A++']} as budget_needed
    FROM donors
    WHERE county = '{county}'
    GROUP BY donor_grade_state;
    
    -- Using COUNTY grade (correct for local race):
    SELECT 'COUNTY_GRADE' as approach,
           donor_grade_county as grade,
           COUNT(*) as donors,
           COUNT(*) * {BudgetConfig.BUDGET_PER_CONTACT['A++']} as budget_needed
    FROM donors
    WHERE county = '{county}'
    GROUP BY donor_grade_county;
    
    -- KEY INSIGHT:
    -- A donor who is C+ statewide but A++ in their county
    -- should get $50/contact budget for a COUNTY race
    -- but only $1/contact budget for a STATEWIDE race
    """


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("BUDGET ALLOCATION - DUAL GRADING")
    print("=" * 60)
    
    # Example: Statewide campaign with $100K budget
    print("\n1. STATEWIDE CAMPAIGN ($100K budget)")
    print("-" * 40)
    
    # Simulated donor counts by state grade
    state_counts = {
        'A++': 130,
        'A+': 1170,
        'A': 5200,
        'A-': 6500,
        'B+': 13000,
        'B': 13000,
        'B-': 13000,
        'C+': 13000,
        'C': 13000,
        'C-': 13000,
        'D': 39000,
    }
    
    allocation = calculate_budget_allocation(
        campaign_type='governor',
        total_budget=100000,
        donor_counts_by_grade=state_counts
    )
    
    print(f"Expected ROI: {allocation.expected_roi:.1f}X")
    print(f"Expected Revenue: ${allocation.expected_revenue:,.0f}")
    print("\nBudget by Grade:")
    for grade, amount in allocation.grade_allocations.items():
        if amount > 0:
            print(f"  {grade}: ${amount:,.0f}")
    
    # Example: County campaign with $10K budget
    print("\n\n2. FORSYTH COUNTY SHERIFF ($10K budget)")
    print("-" * 40)
    
    # Simulated donor counts by county grade (smaller pool)
    county_counts = {
        'A++': 8,
        'A+': 82,
        'A': 410,
        'A-': 820,
        'B+': 1640,
        'B': 1640,
        'B-': 1640,
        'C+': 1640,
        'C': 1640,
        'C-': 1640,
        'D': 4920,
    }
    
    allocation = calculate_budget_allocation(
        campaign_type='sheriff',
        total_budget=10000,
        donor_counts_by_grade=county_counts,
        county='Forsyth'
    )
    
    print(f"Expected ROI: {allocation.expected_roi:.1f}X")
    print(f"Expected Revenue: ${allocation.expected_revenue:,.0f}")
    print("\nBudget by Grade:")
    for grade, amount in allocation.grade_allocations.items():
        if amount > 0:
            print(f"  {grade}: ${amount:,.0f}")
    
    print("\n" + "=" * 60)
    print("DUAL GRADING BUDGET SYSTEM READY")
    print("=" * 60)
