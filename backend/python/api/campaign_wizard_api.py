#!/usr/bin/env python3
"""
============================================================================
CAMPAIGN WIZARD API ENDPOINTS
============================================================================

FastAPI endpoints for the Campaign Wizard with December 2024 enhancements:
- Triple Grading
- Office Context Selection
- Realistic Capacity Calculation
- Event Timing Discipline
- Cultivation Intelligence

============================================================================
"""

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Dict, List, Optional, Any
from datetime import datetime, date
from decimal import Decimal
import sys
import os

# Add ecosystems to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'ecosystems'))

# Import our integration module
from december_2024_integration import (
    December2024API,
    TripleGradingAPI,
    CampaignWizardAPI,
    EventManagementAPI,
    CultivationAPI
)

# ============================================================================
# FASTAPI APP
# ============================================================================

app = FastAPI(
    title="BroyhillGOP Campaign Wizard API",
    description="API for campaign creation with triple grading and AI intelligence",
    version="2.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API instances
api = December2024API()
grading = TripleGradingAPI()
wizard = CampaignWizardAPI()
events = EventManagementAPI()
cultivation = CultivationAPI()


# ============================================================================
# PYDANTIC MODELS
# ============================================================================

class CampaignCreateRequest(BaseModel):
    name: str
    candidate_id: str
    office_type: str
    goal: float
    event_date: Optional[date] = None
    special_guest_type: Optional[str] = None

class CampaignGoalValidation(BaseModel):
    goal: float
    office_type: str
    donor_universe_size: int

class EventInvitationRequest(BaseModel):
    event_id: str
    person_ids: List[str]
    invitation_type: str  # 'paid' or 'free'
    audience_source: str  # 'donor_file' or 'volunteer_file'

class SegmentDefinition(BaseModel):
    grade: Optional[str] = None
    county: Optional[str] = None
    district: Optional[str] = None
    age_range: Optional[str] = None
    donation_range: Optional[str] = None

class SegmentActivityRequest(BaseModel):
    segment_definition: Dict
    activity_type: str
    count: int = 1
    amount: float = 0


# ============================================================================
# OFFICE TYPES & CONFIGURATION ENDPOINTS
# ============================================================================

@app.get("/api/v2/office-types")
async def get_office_types():
    """Get all NC office types with grade context mapping"""
    return {
        "success": True,
        "data": api.get_all_office_types()
    }

@app.get("/api/v2/office-types/{office_type}")
async def get_office_type_detail(office_type: str):
    """Get details for a specific office type"""
    from nc_office_context_mapping import NC_OFFICE_CONTEXT, get_grade_context
    
    context = get_grade_context(office_type)
    return {
        "success": True,
        "data": {
            "office_type": office_type,
            "grade_context": context.value,
            "description": f"Uses {context.value} grade for donor sorting"
        }
    }

@app.get("/api/v2/special-guests")
async def get_special_guest_types():
    """Get all special guest types with multipliers"""
    return {
        "success": True,
        "data": api.get_special_guest_types()
    }

@app.get("/api/v2/donation-menu")
async def get_donation_menu():
    """Get standard donation menu levels"""
    return {
        "success": True,
        "data": api.get_donation_menu_levels()
    }


# ============================================================================
# TRIPLE GRADING ENDPOINTS
# ============================================================================

@app.get("/api/v2/donors/{donor_id}/grades")
async def get_donor_grades(donor_id: str):
    """Get all three grades for a donor"""
    grades = grading.get_donor_grades(donor_id)
    if not grades:
        raise HTTPException(status_code=404, detail="Donor not found")
    return {
        "success": True,
        "data": grades
    }

@app.get("/api/v2/donors/{donor_id}/contextual-grade")
async def get_contextual_grade(donor_id: str, office_type: str):
    """Get the appropriate grade for a donor based on office type"""
    grade = grading.get_contextual_grade_for_campaign(donor_id, office_type)
    return {
        "success": True,
        "data": grade
    }

@app.get("/api/v2/districts/{district_id}")
async def get_district_summary(district_id: str):
    """Get summary for a district"""
    summary = grading.get_district_summary(district_id)
    if not summary:
        raise HTTPException(status_code=404, detail="District not found")
    return {
        "success": True,
        "data": summary
    }

@app.get("/api/v2/districts/{district_id}/donors")
async def get_district_donors(
    district_id: str,
    grades: Optional[str] = None,
    limit: int = Query(default=100, le=500)
):
    """Get donors in a district, optionally filtered by grade"""
    grade_list = grades.split(',') if grades else None
    donors = grading.get_donors_by_district_grade(district_id, grade_list, limit)
    return {
        "success": True,
        "data": donors,
        "count": len(donors)
    }


# ============================================================================
# CAMPAIGN WIZARD ENDPOINTS
# ============================================================================

@app.post("/api/v2/campaigns/validate-goal")
async def validate_campaign_goal(request: CampaignGoalValidation):
    """Validate if a campaign goal is realistic"""
    result = wizard.validate_campaign_goal(
        goal=request.goal,
        office_type=request.office_type,
        donor_universe_size=request.donor_universe_size
    )
    return {
        "success": True,
        "data": result
    }

@app.post("/api/v2/campaigns")
async def create_campaign(request: CampaignCreateRequest):
    """Create a new campaign with proper context selection"""
    result = wizard.create_campaign_with_context(
        name=request.name,
        candidate_id=request.candidate_id,
        office_type=request.office_type,
        goal=request.goal,
        event_date=datetime.combine(request.event_date, datetime.min.time()) if request.event_date else None,
        special_guest_type=request.special_guest_type
    )
    return {
        "success": True,
        "data": result
    }

@app.post("/api/v2/campaigns/{campaign_id}/build-audience")
async def build_campaign_audience(campaign_id: str, office_type: str):
    """Build audience list with contextual grades and ask amounts"""
    result = wizard.build_campaign_audience(campaign_id, office_type)
    return {
        "success": True,
        "data": result
    }

@app.get("/api/v2/campaigns/{campaign_id}/capacity")
async def get_campaign_capacity(
    campaign_id: str,
    office_type: str,
    special_guest_type: Optional[str] = None
):
    """Calculate realistic capacity for a campaign"""
    from nc_office_context_mapping import calculate_realistic_capacity, calculate_expanded_capacity
    
    # Mock donor distribution (in production, query from DB)
    donors_by_grade = {
        'A++': 3, 'A+': 28, 'A': 114, 'A-': 140,
        'B+': 285, 'B': 285, 'B-': 312,
        'C+': 280, 'C': 289, 'C-': 280,
        'D+': 200, 'D': 200, 'D-': 154,
        'U': 277
    }
    
    capacity = calculate_realistic_capacity(donors_by_grade, office_type)
    
    result = {
        "realistic_max": capacity['realistic_max'],
        "conservative_estimate": capacity['conservative_estimate'],
        "aggressive_estimate": capacity['aggressive_estimate'],
        "expected_donors": capacity['expected_donors']
    }
    
    if special_guest_type:
        expanded = calculate_expanded_capacity(capacity['realistic_max'], special_guest_type)
        result['with_special_guest'] = expanded
    
    return {
        "success": True,
        "data": result
    }


# ============================================================================
# EVENT MANAGEMENT ENDPOINTS
# ============================================================================

@app.get("/api/v2/events/{event_id}/status")
async def get_event_status(event_id: str):
    """Get current status of an event including timing phase"""
    result = events.get_event_status(event_id)
    if 'error' in result:
        raise HTTPException(status_code=404, detail=result['error'])
    return {
        "success": True,
        "data": result
    }

@app.post("/api/v2/events/{event_id}/undersell-recovery")
async def activate_undersell_recovery(event_id: str):
    """Activate undersell recovery for an event"""
    result = events.activate_undersell_recovery(event_id)
    if not result.get('success'):
        raise HTTPException(status_code=400, detail=result.get('error'))
    return result

@app.post("/api/v2/events/invitations")
async def send_event_invitations(request: EventInvitationRequest):
    """Send event invitations with timing validation"""
    result = events.send_event_invitations(
        event_id=request.event_id,
        person_ids=request.person_ids,
        invitation_type=request.invitation_type,
        audience_source=request.audience_source
    )
    if not result.get('success'):
        raise HTTPException(status_code=400, detail=result.get('error'))
    return result

@app.get("/api/v2/events/{event_id}/timing-validation")
async def validate_event_timing(
    event_id: str,
    audience_type: str,
    invitation_type: str
):
    """Validate if an invitation is allowed based on timing rules"""
    from event_timing_discipline import validate_invitation_timing
    from december_2024_integration import db
    
    # Get event date
    event = db.execute_query("""
        SELECT event_date FROM events WHERE event_id = %s
    """, (event_id,))
    
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    validation = validate_invitation_timing(
        event_date=event[0]['event_date'],
        audience_type=audience_type,
        invitation_type=invitation_type
    )
    
    return {
        "success": True,
        "data": validation
    }


# ============================================================================
# CULTIVATION INTELLIGENCE ENDPOINTS
# ============================================================================

@app.post("/api/v2/cultivation/segment-strategy")
async def get_segment_strategy(request: SegmentDefinition):
    """Get AI-recommended strategy for a microsegment"""
    segment_def = request.dict(exclude_none=True)
    result = cultivation.get_segment_strategy(segment_def)
    return {
        "success": True,
        "data": result
    }

@app.post("/api/v2/cultivation/record-activity")
async def record_segment_activity(request: SegmentActivityRequest):
    """Record activity for a segment"""
    success = cultivation.record_segment_activity(
        segment_definition=request.segment_definition,
        activity_type=request.activity_type,
        count=request.count,
        amount=request.amount
    )
    return {
        "success": success
    }

@app.get("/api/v2/cultivation/top-segments")
async def get_top_segments(limit: int = Query(default=10, le=50)):
    """Get top performing microsegments by ROI"""
    segments = cultivation.get_top_performing_segments(limit)
    return {
        "success": True,
        "data": segments
    }

@app.get("/api/v2/cultivation/attention-needed")
async def get_segments_needing_attention():
    """Get segments that need strategy adjustment"""
    segments = cultivation.get_segments_needing_attention()
    return {
        "success": True,
        "data": segments
    }


# ============================================================================
# HEALTH CHECK
# ============================================================================

@app.get("/api/v2/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "2.0.0",
        "features": [
            "triple_grading",
            "office_context_mapping",
            "cultivation_intelligence",
            "event_timing_discipline"
        ]
    }


# ============================================================================
# RUN SERVER
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "campaign_wizard_api:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
