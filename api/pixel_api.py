"""
BroyhillGOP E56 Pixel API Endpoint
FastAPI server to receive tracking data from JavaScript pixel

Endpoints:
  POST /v1/pixel/pageview - Track page views
  POST /v1/pixel/heartbeat - Track time on page
  POST /v1/pixel/event - Track custom events
  POST /v1/pixel/session - Track session end
"""

import os
import json
import hashlib
from datetime import datetime
from typing import Optional, Dict, Any
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
from dotenv import load_dotenv

load_dotenv('/opt/broyhillgop/config/supabase.env')

app = FastAPI(title="BroyhillGOP Pixel API", version="1.0.0")

# CORS for cross-origin pixel requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "OPTIONS"],
    allow_headers=["*"],
)

# Supabase config
SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://isbgjpnbocdkeslofota.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_KEY')

# ============================================
# MODELS
# ============================================

class PageViewEvent(BaseModel):
    candidate_id: str
    visitor_id: str
    session_id: str
    fingerprint: Optional[str] = None
    page_url: str
    page_path: str
    page_title: Optional[str] = None
    page_type: Optional[str] = None
    referrer: Optional[str] = None
    device_type: Optional[str] = None
    user_agent: Optional[str] = None
    utm_source: Optional[str] = None
    utm_medium: Optional[str] = None
    utm_campaign: Optional[str] = None
    utm_content: Optional[str] = None
    utm_term: Optional[str] = None
    timestamp: int

class HeartbeatEvent(BaseModel):
    candidate_id: str
    visitor_id: str
    session_id: str
    time_on_page: int
    scroll_depth: int
    form_interactions: int
    timestamp: int

class CustomEvent(BaseModel):
    candidate_id: str
    visitor_id: str
    session_id: str
    event_type: str
    event_data: Optional[Dict[str, Any]] = None
    page_url: Optional[str] = None
    timestamp: int

class SessionEndEvent(BaseModel):
    candidate_id: str
    visitor_id: str
    session_id: str
    total_time: int
    page_views: int
    max_scroll: int
    form_interactions: int
    events_count: int
    timestamp: int

# ============================================
# HELPERS
# ============================================

def hash_ip(ip: str) -> str:
    """Hash IP for privacy"""
    return hashlib.sha256(ip.encode()).hexdigest()[:16]

def hash_fingerprint(fp: str) -> str:
    """Normalize fingerprint hash"""
    return hashlib.sha256(fp.encode()).hexdigest()[:32] if fp else None

async def supabase_insert(table: str, data: dict):
    """Insert data into Supabase"""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/{table}",
            json=data,
            headers={
                "apikey": SUPABASE_KEY,
                "Authorization": f"Bearer {SUPABASE_KEY}",
                "Content-Type": "application/json",
                "Prefer": "return=minimal"
            }
        )
        if response.status_code not in (200, 201):
            print(f"Supabase error: {response.text}")
        return response.status_code in (200, 201)

async def supabase_upsert(table: str, data: dict, on_conflict: str = "session_id"):
    """Upsert data into Supabase"""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/{table}",
            json=data,
            headers={
                "apikey": SUPABASE_KEY,
                "Authorization": f"Bearer {SUPABASE_KEY}",
                "Content-Type": "application/json",
                "Prefer": f"resolution=merge-duplicates"
            }
        )
        return response.status_code in (200, 201)

def get_client_ip(request: Request) -> str:
    """Extract client IP from request"""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host

def detect_browser(user_agent: str) -> str:
    """Simple browser detection"""
    ua = user_agent.lower() if user_agent else ""
    if "chrome" in ua and "edg" not in ua:
        return "Chrome"
    if "firefox" in ua:
        return "Firefox"
    if "safari" in ua and "chrome" not in ua:
        return "Safari"
    if "edg" in ua:
        return "Edge"
    return "Other"

def detect_os(user_agent: str) -> str:
    """Simple OS detection"""
    ua = user_agent.lower() if user_agent else ""
    if "windows" in ua:
        return "Windows"
    if "mac" in ua:
        return "macOS"
    if "linux" in ua:
        return "Linux"
    if "android" in ua:
        return "Android"
    if "iphone" in ua or "ipad" in ua:
        return "iOS"
    return "Other"

# ============================================
# ENDPOINTS
# ============================================

@app.post("/v1/pixel/pageview")
async def track_pageview(event: PageViewEvent, request: Request):
    """Track page view and create/update session"""
    
    client_ip = get_client_ip(request)
    ip_hash = hash_ip(client_ip)
    fingerprint_hash = hash_fingerprint(event.fingerprint)
    
    # Session data
    session_data = {
        "session_id": event.session_id,
        "candidate_id": event.candidate_id,
        "visitor_id": event.visitor_id,
        "ip_hash": ip_hash,
        "fingerprint_hash": fingerprint_hash,
        "user_agent": event.user_agent,
        "device_type": event.device_type,
        "browser": detect_browser(event.user_agent),
        "os": detect_os(event.user_agent),
        "utm_source": event.utm_source,
        "utm_medium": event.utm_medium,
        "utm_campaign": event.utm_campaign,
        "utm_content": event.utm_content,
        "utm_term": event.utm_term,
        "referrer_url": event.referrer,
        "landing_page_url": event.page_url,
        "landing_page_slug": event.page_path,
        "page_views": 1,
        "resolution_status": "pending"
    }
    
    await supabase_upsert("visitor_sessions", session_data)
    
    # Page view data
    page_view_data = {
        "session_id": event.session_id,
        "candidate_id": event.candidate_id,
        "visitor_id": event.visitor_id,
        "page_url": event.page_url,
        "page_path": event.page_path,
        "page_title": event.page_title,
        "page_type": event.page_type,
        "is_high_intent": event.page_type in ("donate", "volunteer", "event")
    }
    
    await supabase_insert("visitor_page_views", page_view_data)
    
    return {"status": "ok"}

@app.post("/v1/pixel/heartbeat")
async def track_heartbeat(event: HeartbeatEvent, request: Request):
    """Update session with engagement metrics"""
    
    # Update session metrics
    session_update = {
        "session_id": event.session_id,
        "candidate_id": event.candidate_id,
        "visitor_id": event.visitor_id,
        "time_on_site_seconds": event.time_on_page,
        "max_scroll_depth": event.scroll_depth,
        "form_interactions": event.form_interactions,
        "updated_at": datetime.utcnow().isoformat()
    }
    
    await supabase_upsert("visitor_sessions", session_update)
    
    return {"status": "ok"}

@app.post("/v1/pixel/event")
async def track_event(event: CustomEvent, request: Request):
    """Track custom events"""
    
    event_data = {
        "session_id": event.session_id,
        "candidate_id": event.candidate_id,
        "visitor_id": event.visitor_id,
        "event_type": event.event_type,
        "event_category": categorize_event(event.event_type),
        "event_data": event.event_data,
        "page_url": event.page_url
    }
    
    await supabase_insert("visitor_events", event_data)
    
    # High-value events trigger immediate processing
    if event.event_type in ("donate_click", "volunteer_click"):
        await trigger_high_intent_check(event.session_id, event.candidate_id)
    
    return {"status": "ok"}

@app.post("/v1/pixel/session")
async def track_session_end(event: SessionEndEvent, request: Request):
    """Finalize session and trigger intent scoring"""
    
    # Final session update
    session_update = {
        "session_id": event.session_id,
        "candidate_id": event.candidate_id,
        "visitor_id": event.visitor_id,
        "time_on_site_seconds": event.total_time,
        "page_views": event.page_views,
        "max_scroll_depth": event.max_scroll,
        "form_interactions": event.form_interactions,
        "updated_at": datetime.utcnow().isoformat()
    }
    
    await supabase_upsert("visitor_sessions", session_update)
    
    # Trigger intent scoring
    await calculate_intent_score(event.session_id, event)
    
    return {"status": "ok"}

# ============================================
# SCORING & INTEGRATION
# ============================================

def categorize_event(event_type: str) -> str:
    """Categorize event types"""
    high_intent = ["donate_click", "volunteer_click", "form_submit"]
    engagement = ["scroll", "video_play", "download"]
    navigation = ["page_view", "outbound_click"]
    
    if event_type in high_intent:
        return "high_intent"
    if event_type in engagement:
        return "engagement"
    if event_type in navigation:
        return "navigation"
    return "other"

async def calculate_intent_score(session_id: str, event: SessionEndEvent) -> int:
    """Calculate visitor intent score (0-100)"""
    
    score = 0
    multiplier = 1.0
    
    # Base time score (max 20 points)
    if event.total_time >= 180:  # 3+ minutes
        score += 20
        multiplier *= 1.3
    elif event.total_time >= 120:  # 2+ minutes
        score += 15
        multiplier *= 1.2
    elif event.total_time >= 60:  # 1+ minute
        score += 10
        multiplier *= 1.1
    elif event.total_time >= 30:
        score += 5
    
    # Page views (max 15 points)
    if event.page_views >= 5:
        score += 15
        multiplier *= 1.2
    elif event.page_views >= 3:
        score += 10
    elif event.page_views >= 2:
        score += 5
    
    # Scroll depth (max 15 points)
    if event.max_scroll >= 75:
        score += 15
        multiplier *= 1.15
    elif event.max_scroll >= 50:
        score += 10
    elif event.max_scroll >= 25:
        score += 5
    
    # Form interactions (max 20 points)
    if event.form_interactions >= 3:
        score += 20
        multiplier *= 1.3
    elif event.form_interactions >= 1:
        score += 10
        multiplier *= 1.15
    
    # Apply multiplier and cap at 100
    final_score = min(100, int(score * multiplier))
    
    # Update session with score
    await supabase_upsert("visitor_sessions", {
        "session_id": session_id,
        "candidate_id": event.candidate_id,
        "visitor_id": event.visitor_id,
        "raw_intent_score": score,
        "behavior_multiplier": multiplier,
        "adjusted_intent_score": final_score,
        "intent_category": categorize_intent(final_score)
    })
    
    # Check if trigger eligible
    if final_score >= 60:
        await trigger_high_intent_check(session_id, event.candidate_id)
    
    return final_score

def categorize_intent(score: int) -> str:
    """Categorize intent score"""
    if score >= 80:
        return "high"
    if score >= 50:
        return "medium"
    if score >= 25:
        return "low"
    return "minimal"

async def trigger_high_intent_check(session_id: str, candidate_id: str):
    """Trigger E56 identity resolution for high-intent visitors"""
    
    # Queue for E20 Brain processing
    brain_event = {
        "candidate_id": candidate_id,
        "event_type": "high_intent_visitor",
        "event_data": {"session_id": session_id},
        "source_ecosystem": "E56",
        "priority": 80,
        "processed": False
    }
    
    await supabase_insert("brain_events", brain_event)

# ============================================
# HEALTH CHECK
# ============================================

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "E56 Pixel API", "version": "1.0.0"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8056)
