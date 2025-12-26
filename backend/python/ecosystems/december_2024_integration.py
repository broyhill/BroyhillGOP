#!/usr/bin/env python3
"""
============================================================================
DECEMBER 2024 ENHANCEMENT INTEGRATION
============================================================================

Central integration module that connects:
- Triple Grading System
- Office Context Mapping
- Cultivation Intelligence
- Event Timing Discipline

This module provides the unified API for the Campaign Wizard and other
ecosystems to use the new features.

============================================================================
"""

import os
import json
import uuid
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from decimal import Decimal

# Import our new modules
from nc_office_context_mapping import (
    NC_OFFICE_CONTEXT,
    STANDARD_DONATION_MENU,
    GRADE_TO_DONATION_LEVEL,
    SPECIAL_GUEST_MULTIPLIERS,
    get_grade_context,
    get_contextual_grade,
    get_donation_level_for_donor,
    calculate_realistic_capacity,
    calculate_expanded_capacity,
    GradeContext,
    DonorContextualGrade
)

from donor_cultivation_intelligence import (
    CultivationIntelligence,
    MicrosegmentPerformance,
    InvestmentStrategy,
    GRADE_STARTING_ASSUMPTIONS
)

from event_timing_discipline import (
    get_event_phase,
    get_eligible_audience,
    sort_donors_for_event,
    sort_volunteers_for_free_invites,
    calculate_undersell_recovery_plan,
    validate_invitation_timing,
    EventPhase,
    EventCapacity,
    VOLUNTEER_GRADES
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('december2024.integration')


# ============================================================================
# DATABASE CONNECTION
# ============================================================================

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
    HAS_DB = True
except ImportError:
    HAS_DB = False
    logger.warning("psycopg2 not available - running in standalone mode")


class DatabaseConnection:
    """Database connection manager"""
    
    def __init__(self):
        self.db_url = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")
    
    def get_connection(self):
        if not HAS_DB:
            return None
        return psycopg2.connect(self.db_url)
    
    def execute_query(self, query: str, params: tuple = None) -> List[Dict]:
        """Execute a query and return results"""
        conn = self.get_connection()
        if not conn:
            return []
        
        try:
            cur = conn.cursor(cursor_factory=RealDictCursor)
            cur.execute(query, params)
            results = [dict(row) for row in cur.fetchall()]
            conn.close()
            return results
        except Exception as e:
            logger.error(f"Query error: {e}")
            conn.close()
            return []
    
    def execute_update(self, query: str, params: tuple = None) -> bool:
        """Execute an update query"""
        conn = self.get_connection()
        if not conn:
            return False
        
        try:
            cur = conn.cursor()
            cur.execute(query, params)
            conn.commit()
            conn.close()
            return True
        except Exception as e:
            logger.error(f"Update error: {e}")
            conn.rollback()
            conn.close()
            return False


db = DatabaseConnection()


# ============================================================================
# TRIPLE GRADING API
# ============================================================================

class TripleGradingAPI:
    """API for triple grading operations"""
    
    @staticmethod
    def get_donor_grades(donor_id: str) -> Optional[Dict]:
        """Get all three grades for a donor"""
        results = db.execute_query("""
            SELECT 
                id, full_name,
                donor_grade_state, donor_rank_state,
                donor_grade_district, donor_rank_district,
                donor_grade_county, donor_rank_county,
                county, district_state_house
            FROM persons
            WHERE id = %s
        """, (donor_id,))
        
        return results[0] if results else None
    
    @staticmethod
    def get_contextual_grade_for_campaign(donor_id: str, office_type: str) -> Dict:
        """Get the appropriate grade for a donor based on campaign office type"""
        results = db.execute_query("""
            SELECT * FROM get_contextual_grade(%s, %s)
        """, (donor_id, office_type))
        
        if results:
            return results[0]
        
        # Fallback to Python logic
        donor = TripleGradingAPI.get_donor_grades(donor_id)
        if not donor:
            return {'grade': 'U', 'rank': None, 'context': 'unknown'}
        
        context = get_grade_context(office_type)
        
        if context == GradeContext.STATE:
            return {
                'grade': donor.get('donor_grade_state', 'U'),
                'rank': donor.get('donor_rank_state'),
                'context': 'state'
            }
        elif context == GradeContext.DISTRICT:
            return {
                'grade': donor.get('donor_grade_district') or donor.get('donor_grade_county', 'U'),
                'rank': donor.get('donor_rank_district') or donor.get('donor_rank_county'),
                'context': 'district'
            }
        else:
            return {
                'grade': donor.get('donor_grade_county', 'U'),
                'rank': donor.get('donor_rank_county'),
                'context': 'county'
            }
    
    @staticmethod
    def get_district_summary(district_id: str) -> Optional[Dict]:
        """Get summary for a district"""
        results = db.execute_query("""
            SELECT * FROM v_district_summary
            WHERE district_id = %s
        """, (district_id,))
        
        return results[0] if results else None
    
    @staticmethod
    def get_donors_by_district_grade(
        district_id: str, 
        grades: List[str] = None,
        limit: int = 100
    ) -> List[Dict]:
        """Get donors in a district filtered by grade"""
        query = """
            SELECT 
                id, full_name, email, donation_total,
                donor_grade_district, donor_rank_district
            FROM persons
            WHERE district_state_house = %s
            AND is_donor = TRUE
        """
        params = [district_id]
        
        if grades:
            query += " AND donor_grade_district = ANY(%s)"
            params.append(grades)
        
        query += " ORDER BY donor_rank_district LIMIT %s"
        params.append(limit)
        
        return db.execute_query(query, tuple(params))


# ============================================================================
# CAMPAIGN WIZARD API
# ============================================================================

class CampaignWizardAPI:
    """API for Campaign Wizard operations"""
    
    def __init__(self):
        self.cultivation = CultivationIntelligence()
    
    def create_campaign_with_context(
        self,
        name: str,
        candidate_id: str,
        office_type: str,
        goal: float,
        event_date: datetime = None,
        special_guest_type: str = None
    ) -> Dict:
        """Create a campaign with proper context selection"""
        
        # Determine grade context
        context = get_grade_context(office_type)
        
        # Calculate realistic capacity
        donors_by_grade = self._get_donor_distribution(candidate_id, context.value)
        capacity = calculate_realistic_capacity(donors_by_grade, office_type)
        
        # Check if special guest needed
        requires_guest = goal > capacity['realistic_max']
        
        # Apply special guest multiplier if provided
        multiplier = 1.0
        expanded_capacity = capacity['realistic_max']
        if special_guest_type:
            expanded = calculate_expanded_capacity(capacity['realistic_max'], special_guest_type)
            multiplier = expanded['multiplier']
            expanded_capacity = expanded['expanded_capacity']
        
        # Create campaign record
        campaign_id = str(uuid.uuid4())
        
        success = db.execute_update("""
            INSERT INTO campaigns (
                campaign_id, name, candidate_id, office_type,
                grade_context, goal, special_guest_type,
                capacity_multiplier, realistic_capacity,
                requires_special_guest, start_date, status
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'draft')
        """, (
            campaign_id, name, candidate_id, office_type,
            context.value, goal, special_guest_type,
            multiplier, expanded_capacity,
            requires_guest, event_date
        ))
        
        return {
            'campaign_id': campaign_id,
            'name': name,
            'office_type': office_type,
            'grade_context': context.value,
            'goal': goal,
            'realistic_capacity': capacity['realistic_max'],
            'expanded_capacity': expanded_capacity if special_guest_type else None,
            'requires_special_guest': requires_guest and not special_guest_type,
            'multiplier': multiplier,
            'capacity_breakdown': capacity['breakdown'] if 'breakdown' in capacity else None,
            'success': success
        }
    
    def _get_donor_distribution(self, candidate_id: str, context: str) -> Dict[str, int]:
        """Get donor count by grade for capacity calculation"""
        grade_column = f"donor_grade_{context}"
        
        results = db.execute_query(f"""
            SELECT {grade_column} as grade, COUNT(*) as count
            FROM persons
            WHERE is_donor = TRUE
            GROUP BY {grade_column}
        """)
        
        return {r['grade']: r['count'] for r in results if r['grade']}
    
    def build_campaign_audience(
        self,
        campaign_id: str,
        office_type: str
    ) -> Dict:
        """Build audience list with contextual grades and ask amounts"""
        
        context = get_grade_context(office_type)
        grade_column = f"donor_grade_{context.value}"
        rank_column = f"donor_rank_{context.value}"
        
        # Get donors sorted by contextual grade
        donors = db.execute_query(f"""
            SELECT 
                id, full_name, email,
                {grade_column} as contextual_grade,
                {rank_column} as contextual_rank,
                donation_total
            FROM persons
            WHERE is_donor = TRUE
            AND {grade_column} IS NOT NULL
            ORDER BY {rank_column}
        """)
        
        # Assign donation levels
        audience = []
        for donor in donors:
            grade = donor['contextual_grade']
            ask_amount = GRADE_TO_DONATION_LEVEL.get(grade, 100)
            
            audience.append({
                'person_id': donor['id'],
                'name': donor['full_name'],
                'grade': grade,
                'rank': donor['contextual_rank'],
                'ask_amount': ask_amount,
                'donation_level': self._get_level_name(ask_amount)
            })
            
            # Record in database
            db.execute_update("""
                INSERT INTO campaign_audience_grades (
                    campaign_id, person_id, grade_context,
                    contextual_grade, contextual_rank,
                    ask_amount
                ) VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
            """, (
                campaign_id, donor['id'], context.value,
                grade, donor['contextual_rank'], ask_amount
            ))
        
        return {
            'campaign_id': campaign_id,
            'total_audience': len(audience),
            'grade_context': context.value,
            'audience_by_level': self._group_by_level(audience),
            'audience': audience[:100]  # Return first 100 for preview
        }
    
    def _get_level_name(self, amount: int) -> str:
        """Get donation level name from amount"""
        levels = {
            6800: 'Leadership Circle',
            5000: "Chairman's Club",
            2500: 'Patriot Level',
            1000: 'Founder Level',
            500: 'Supporter Level',
            100: 'Friend Level'
        }
        return levels.get(amount, 'Friend Level')
    
    def _group_by_level(self, audience: List[Dict]) -> Dict:
        """Group audience by donation level"""
        groups = {}
        for donor in audience:
            level = donor['donation_level']
            if level not in groups:
                groups[level] = {'count': 0, 'total_potential': 0}
            groups[level]['count'] += 1
            groups[level]['total_potential'] += donor['ask_amount']
        return groups
    
    def validate_campaign_goal(
        self,
        goal: float,
        office_type: str,
        donor_universe_size: int
    ) -> Dict:
        """Validate if campaign goal is realistic"""
        
        # Mock donor distribution for validation
        donors_by_grade = {
            'A++': int(donor_universe_size * 0.001),
            'A+': int(donor_universe_size * 0.009),
            'A': int(donor_universe_size * 0.04),
            'A-': int(donor_universe_size * 0.05),
            'B+': int(donor_universe_size * 0.10),
            'B': int(donor_universe_size * 0.10),
            'B-': int(donor_universe_size * 0.10),
            'C+': int(donor_universe_size * 0.10),
            'C': int(donor_universe_size * 0.10),
            'C-': int(donor_universe_size * 0.10),
            'D': int(donor_universe_size * 0.20),
            'U': int(donor_universe_size * 0.10)
        }
        
        capacity = calculate_realistic_capacity(donors_by_grade, office_type)
        
        is_achievable = goal <= capacity['realistic_max']
        is_aggressive = goal <= capacity['aggressive_estimate']
        
        recommendation = None
        if not is_achievable:
            shortfall = goal - capacity['realistic_max']
            # Find guest type that would cover shortfall
            for guest_type, multiplier in SPECIAL_GUEST_MULTIPLIERS.items():
                expanded = capacity['realistic_max'] * multiplier
                if expanded >= goal:
                    recommendation = {
                        'action': 'add_special_guest',
                        'guest_type': guest_type,
                        'expanded_capacity': expanded
                    }
                    break
            
            if not recommendation:
                recommendation = {
                    'action': 'reduce_goal_or_multiple_events',
                    'suggested_goal': capacity['realistic_max'],
                    'events_needed': int(goal / capacity['realistic_max']) + 1
                }
        
        return {
            'goal': goal,
            'realistic_max': capacity['realistic_max'],
            'conservative': capacity['conservative_estimate'],
            'aggressive': capacity['aggressive_estimate'],
            'is_achievable': is_achievable,
            'is_aggressive': is_aggressive and not is_achievable,
            'recommendation': recommendation
        }


# ============================================================================
# EVENT MANAGEMENT API
# ============================================================================

class EventManagementAPI:
    """API for event timing and management"""
    
    @staticmethod
    def get_event_status(event_id: str) -> Dict:
        """Get current status of an event including timing phase"""
        results = db.execute_query("""
            SELECT * FROM v_event_timing_status
            WHERE event_id = %s
        """, (event_id,))
        
        if not results:
            return {'error': 'Event not found'}
        
        event = results[0]
        
        # Get eligible audience
        capacity = EventCapacity(
            total_seats=event['capacity'],
            sold_seats=event['sold_seats'],
            comped_seats=event['comped_seats']
        )
        
        audience = get_eligible_audience(
            event_date=event['event_date'],
            capacity=capacity
        )
        
        return {
            'event_id': event_id,
            'name': event['name'],
            'event_date': event['event_date'],
            'days_until': event['days_until_event'],
            'phase': event['calculated_phase'],
            'capacity': {
                'total': event['capacity'],
                'sold': event['sold_seats'],
                'comped': event['comped_seats'],
                'available': capacity.available_seats,
                'fill_rate': f"{event['fill_rate']:.0%}"
            },
            'is_undersold': event['is_undersold'],
            'eligible_audience': audience
        }
    
    @staticmethod
    def activate_undersell_recovery(event_id: str) -> Dict:
        """Activate undersell recovery for an event"""
        # Get event details
        status = EventManagementAPI.get_event_status(event_id)
        
        if status.get('error'):
            return status
        
        if status['phase'] != 'undersell_recovery':
            return {
                'success': False,
                'error': f"Event is in {status['phase']} phase, not undersell_recovery"
            }
        
        if not status['is_undersold']:
            return {
                'success': False,
                'error': 'Event is not undersold (>=80% filled)'
            }
        
        # Get volunteer counts by grade
        volunteer_counts = db.execute_query("""
            SELECT v_grade, COUNT(*) as count
            FROM volunteer_grades
            GROUP BY v_grade
        """)
        
        counts_dict = {r['v_grade']: r['count'] for r in volunteer_counts}
        
        # Calculate recovery plan
        capacity = EventCapacity(
            total_seats=status['capacity']['total'],
            sold_seats=status['capacity']['sold'],
            comped_seats=status['capacity']['comped']
        )
        
        plan = calculate_undersell_recovery_plan(capacity, counts_dict)
        
        # Update event status
        db.execute_update("""
            UPDATE events 
            SET undersell_recovery_activated = TRUE,
                current_phase = 'undersell_recovery'
            WHERE event_id = %s
        """, (event_id,))
        
        return {
            'success': True,
            'event_id': event_id,
            'recovery_plan': plan,
            'message': f"Undersell recovery activated. Invite {plan['total_to_invite']} volunteers."
        }
    
    @staticmethod
    def send_event_invitations(
        event_id: str,
        person_ids: List[str],
        invitation_type: str,
        audience_source: str
    ) -> Dict:
        """Send event invitations with timing validation"""
        
        # Get event details
        event = db.execute_query("""
            SELECT event_date FROM events WHERE event_id = %s
        """, (event_id,))
        
        if not event:
            return {'error': 'Event not found'}
        
        event_date = event[0]['event_date']
        
        # Validate timing
        validation = validate_invitation_timing(
            event_date=event_date,
            audience_type=audience_source,
            invitation_type=invitation_type
        )
        
        if not validation['allowed']:
            return {
                'success': False,
                'error': validation['reason'],
                'recommendation': validation.get('recommendation')
            }
        
        # Record invitations
        sent_count = 0
        for person_id in person_ids:
            success = db.execute_update("""
                INSERT INTO event_invitations (
                    event_id, person_id, invitation_type,
                    audience_source, event_phase,
                    days_before_event
                ) VALUES (%s, %s, %s, %s, %s, %s)
            """, (
                event_id, person_id, invitation_type,
                audience_source, get_event_phase(event_date).value,
                (event_date - datetime.now()).days
            ))
            if success:
                sent_count += 1
        
        return {
            'success': True,
            'event_id': event_id,
            'invitations_sent': sent_count,
            'invitation_type': invitation_type,
            'phase': get_event_phase(event_date).value
        }


# ============================================================================
# CULTIVATION INTELLIGENCE API
# ============================================================================

class CultivationAPI:
    """API for cultivation intelligence operations"""
    
    def __init__(self):
        self.intelligence = CultivationIntelligence()
    
    def get_segment_strategy(self, segment_definition: Dict) -> Dict:
        """Get AI-recommended strategy for a microsegment"""
        
        # Get or create segment performance record
        segment = self._get_or_create_segment(segment_definition)
        
        if not segment:
            return {
                'strategy': 'testing',
                'reason': 'New segment - insufficient data',
                'recommendation': 'Begin testing with email channel'
            }
        
        # Create performance object
        perf = MicrosegmentPerformance(
            segment_id=segment['segment_id'],
            segment_definition=segment['segment_definition'],
            total_invested=float(segment['total_invested'] or 0),
            total_revenue=float(segment['total_revenue'] or 0),
            conversions=segment['conversions'] or 0,
            emails_sent=segment['emails_sent'] or 0,
            emails_opened=segment['emails_opened'] or 0,
            clicks=segment['emails_clicked'] or 0
        )
        
        # Get AI recommendation
        strategy = self.intelligence.determine_investment_strategy(perf)
        
        return {
            'segment_id': str(segment['segment_id']),
            'segment_definition': segment_definition,
            'current_performance': {
                'roi': perf.roi,
                'open_rate': perf.open_rate,
                'conversion_rate': perf.conversion_rate,
                'total_invested': perf.total_invested,
                'total_revenue': perf.total_revenue
            },
            'strategy': strategy['strategy'],
            'reason': strategy['reason'],
            'recommendation': strategy['recommended_action'],
            'investment_modifier': strategy['investment_modifier']
        }
    
    def _get_or_create_segment(self, segment_definition: Dict) -> Optional[Dict]:
        """Get existing segment or create new one"""
        results = db.execute_query("""
            SELECT * FROM microsegment_performance
            WHERE segment_definition = %s
        """, (json.dumps(segment_definition),))
        
        if results:
            return results[0]
        
        # Create new segment
        db.execute_update("""
            INSERT INTO microsegment_performance (segment_definition)
            VALUES (%s)
        """, (json.dumps(segment_definition),))
        
        return db.execute_query("""
            SELECT * FROM microsegment_performance
            WHERE segment_definition = %s
        """, (json.dumps(segment_definition),))[0] if db else None
    
    def record_segment_activity(
        self,
        segment_definition: Dict,
        activity_type: str,
        count: int = 1,
        amount: float = 0
    ) -> bool:
        """Record activity for a segment"""
        
        column_map = {
            'email_sent': 'emails_sent',
            'email_opened': 'emails_opened',
            'email_clicked': 'emails_clicked',
            'sms_sent': 'sms_sent',
            'sms_replied': 'sms_replied',
            'conversion': 'conversions',
            'revenue': 'total_revenue',
            'investment': 'total_invested'
        }
        
        column = column_map.get(activity_type)
        if not column:
            return False
        
        if activity_type in ['revenue', 'investment']:
            return db.execute_update(f"""
                UPDATE microsegment_performance
                SET {column} = {column} + %s
                WHERE segment_definition = %s
            """, (amount, json.dumps(segment_definition)))
        else:
            return db.execute_update(f"""
                UPDATE microsegment_performance
                SET {column} = {column} + %s
                WHERE segment_definition = %s
            """, (count, json.dumps(segment_definition)))
    
    def get_top_performing_segments(self, limit: int = 10) -> List[Dict]:
        """Get top performing microsegments by ROI"""
        return db.execute_query("""
            SELECT * FROM v_microsegment_performance
            WHERE conversions > 0
            ORDER BY roi DESC
            LIMIT %s
        """, (limit,))
    
    def get_segments_needing_attention(self) -> List[Dict]:
        """Get segments that need strategy adjustment"""
        return db.execute_query("""
            SELECT * FROM v_microsegment_performance
            WHERE 
                (emails_sent >= 100 AND roi < 1.0)
                OR (emails_sent < 100 AND emails_sent > 0)
            ORDER BY 
                CASE 
                    WHEN emails_sent >= 100 AND roi < 1.0 THEN 1
                    ELSE 2
                END,
                emails_sent DESC
            LIMIT 20
        """)


# ============================================================================
# UNIFIED API
# ============================================================================

class December2024API:
    """Unified API for all December 2024 enhancements"""
    
    def __init__(self):
        self.grading = TripleGradingAPI()
        self.campaign = CampaignWizardAPI()
        self.events = EventManagementAPI()
        self.cultivation = CultivationAPI()
    
    def get_all_office_types(self) -> List[Dict]:
        """Get all NC office types with grade context"""
        return db.execute_query("""
            SELECT * FROM nc_office_types
            ORDER BY 
                CASE office_category
                    WHEN 'federal' THEN 1
                    WHEN 'council_of_state' THEN 2
                    WHEN 'general_assembly' THEN 3
                    WHEN 'judicial' THEN 4
                    WHEN 'county' THEN 5
                    WHEN 'municipal' THEN 6
                    ELSE 7
                END,
                office_name
        """)
    
    def get_special_guest_types(self) -> List[Dict]:
        """Get all special guest types with multipliers"""
        return db.execute_query("""
            SELECT * FROM special_guest_types
            ORDER BY multiplier DESC
        """)
    
    def get_donation_menu_levels(self) -> List[Dict]:
        """Get standard donation menu levels"""
        return db.execute_query("""
            SELECT * FROM donation_menu_levels
            WHERE is_active = TRUE
            ORDER BY display_order
        """)


# ============================================================================
# SINGLETON INSTANCE
# ============================================================================

api = December2024API()


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("DECEMBER 2024 ENHANCEMENT INTEGRATION")
    print("=" * 60)
    
    # Example: Create campaign with context
    print("\n1. CREATE CAMPAIGN WITH CONTEXT")
    print("-" * 40)
    
    wizard = CampaignWizardAPI()
    
    # Validate goal before creating
    validation = wizard.validate_campaign_goal(
        goal=75000,
        office_type='state_house',
        donor_universe_size=2500
    )
    
    print(f"Goal: $75,000")
    print(f"Realistic Max: ${validation['realistic_max']:,.2f}")
    print(f"Is Achievable: {validation['is_achievable']}")
    if validation['recommendation']:
        print(f"Recommendation: {validation['recommendation']}")
    
    # Example: Get contextual grade
    print("\n2. CONTEXTUAL GRADING")
    print("-" * 40)
    
    # Simulate donor with different grades
    print("Same donor, different contexts:")
    print("  State House race → Use DISTRICT grade")
    print("  Governor race → Use STATE grade")
    print("  Sheriff race → Use COUNTY grade")
    
    # Example: Event timing
    print("\n3. EVENT TIMING DISCIPLINE")
    print("-" * 40)
    
    from datetime import datetime, timedelta
    
    event_date = datetime.now() + timedelta(days=3)
    phase = get_event_phase(event_date)
    print(f"Event in 3 days: Phase = {phase.value}")
    
    event_date = datetime.now() + timedelta(days=10)
    phase = get_event_phase(event_date)
    print(f"Event in 10 days: Phase = {phase.value}")
    
    # Example: Cultivation intelligence
    print("\n4. CULTIVATION INTELLIGENCE")
    print("-" * 40)
    
    cult = CultivationAPI()
    strategy = cult.get_segment_strategy({
        'grade': 'U',
        'county': 'Wake',
        'age_range': '25-34'
    })
    
    print(f"U donors in Wake County (25-34):")
    print(f"  Strategy: {strategy['strategy']}")
    print(f"  Reason: {strategy['reason']}")
    
    print("\n" + "=" * 60)
    print("Integration module ready!")
    print("=" * 60)
