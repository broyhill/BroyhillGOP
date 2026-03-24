"""
BroyhillGOP Relay v1.1 — HTTP bridge + inter-agent message channel
Port  : 8080  (RELAY_PORT in .env)
Auth  : X-API-Key header must match RELAY_API_KEY in .env

Endpoints
─────────
GET  /health                  → liveness, no auth
GET  /status                  → Redis queue depths + subscriber counts
POST /ask                     → synchronous Claude query → decision JSON
POST /event                   → publish to bgop:events (brain.py async path)
GET  /decisions               → last N rows from brain_decisions table
POST /queue/outbound          → peek or pop bgop:outbound messages

── Inter-agent channel (Perplexity ↔ Claude) ─────────────────────────────────
POST /message                 → send a message to the other agent
GET  /inbox                   → unread messages addressed to you (or 'both')
POST /reply                   → post a reply (marks parent read)
GET  /thread/{thread_id}      → full thread history
PATCH /message/{id}/read      → mark a message read
"""

import os
import json
import time
import uuid
import logging
import hmac
from datetime import datetime, timezone
from typing import Optional, Any

import anthropic
import redis as redis_lib
from supabase import create_client, Client
from fastapi import FastAPI, HTTPException, Request, Depends, Header, Path, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import uvicorn

# ── Logging ───────────────────────────────────────────────────────────────────
os.makedirs("/app/logs", exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [RELAY] %(levelname)s %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("/app/logs/relay.log", mode="a"),
    ],
)
log = logging.getLogger("relay")

# ── Credentials ───────────────────────────────────────────────────────────────
CLAUDE_API_KEY = os.environ["CLAUDE_API_KEY"]
SUPABASE_URL   = os.environ["SUPABASE_URL"]
SUPABASE_KEY   = os.environ["SUPABASE_KEY"]
REDIS_HOST     = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT     = int(os.environ.get("REDIS_PORT", 6379))
RELAY_API_KEY  = os.environ.get("RELAY_API_KEY", "bgop-relay-changeme")
RELAY_PORT     = int(os.environ.get("RELAY_PORT", 8080))

# ── Clients ───────────────────────────────────────────────────────────────────
claude: anthropic.Anthropic = anthropic.Anthropic(api_key=CLAUDE_API_KEY)
supabase: Client            = create_client(SUPABASE_URL, SUPABASE_KEY)
r: redis_lib.Redis          = redis_lib.Redis(
    host=REDIS_HOST, port=REDIS_PORT, decode_responses=True, socket_connect_timeout=3
)

START_TIME = time.time()

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="BroyhillGOP Relay",
    version="1.1.0",
    description="HTTP bridge: Perplexity ↔ Claude ↔ Supabase ↔ Redis",
)

# ── Auth ──────────────────────────────────────────────────────────────────────
def require_key(x_api_key: str = Header(...)):
    if not hmac.compare_digest(x_api_key.encode(), RELAY_API_KEY.encode()):
        log.warning(f"Bad API key: {x_api_key[:8]}…")
        raise HTTPException(status_code=401, detail="Invalid API key")
    return True

# ── Models ────────────────────────────────────────────────────────────────────
class AskRequest(BaseModel):
    prompt: str
    system: Optional[str] = None
    max_tokens: int = Field(1024, ge=64, le=4096)
    context: Optional[dict] = None

class EventRequest(BaseModel):
    type: str
    donor_id: Optional[int] = None
    candidate_id: Optional[int] = None
    data: Optional[dict] = Field(default_factory=dict)

class OutboundRequest(BaseModel):
    peek: bool = True
    count: int = Field(10, ge=1, le=100)

class MessageRequest(BaseModel):
    from_agent: str = Field(..., description="'perplexity' or 'claude'")
    to_agent: str   = Field(..., description="'perplexity', 'claude', or 'both'")
    subject: Optional[str] = None
    body: str
    payload: Optional[dict] = None
    thread_id: Optional[str] = None

class ReplyRequest(BaseModel):
    from_agent: str
    body: str
    payload: Optional[dict] = None
    parent_id: Optional[int] = Field(None, description="ID of message being replied to")

# ── Default system prompt ─────────────────────────────────────────────────────
DEFAULT_SYSTEM = """
You are the E20 Brain Hub for BroyhillGOP — a quantifiable reasoning engine that
orchestrates campaign decisions for NC Republican candidates.

For event decisions output ONLY valid JSON:
{
  "action": "SEND_MESSAGE | PAUSE | ESCALATE | DO_NOTHING",
  "channel": "sms | email | phone | social | none",
  "message": "exact message or null",
  "ask_amount": 0,
  "reasoning": "brief explanation",
  "expected_value": 0.0,
  "next_trigger_days": 0
}

For open questions, answer clearly in plain text.
Rules:
- If fatigue score > 0.7, action must be PAUSE
- Only SEND_MESSAGE if expected_value > 25
- For major donors ($10K+), human review required for asks > $500
""".strip()

# ─────────────────────────────────────────────────────────────────────────────
# Core endpoints
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    uptime = int(time.time() - START_TIME)
    redis_ok = False
    try:
        redis_ok = r.ping()
    except Exception:
        pass
    return {
        "status": "ok",
        "uptime_seconds": uptime,
        "relay_version": "1.1.0",
        "redis": "ok" if redis_ok else "unreachable",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

@app.get("/status", dependencies=[Depends(require_key)])
async def status():
    try:
        outbound = r.llen("bgop:outbound")
        events   = r.llen("bgop:events")
        subs     = r.pubsub_numsub("bgop:events", "bgop:triggers")
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Redis unreachable: {e}")
    return {
        "queues": {"bgop:outbound": outbound, "bgop:events": events},
        "subscribers": dict(zip(subs[::2], subs[1::2])),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

@app.post("/ask", dependencies=[Depends(require_key)])
async def ask(req: AskRequest):
    system = req.system or DEFAULT_SYSTEM
    content = req.prompt
    if req.context:
        content = f"CONTEXT:\n{json.dumps(req.context, indent=2)}\n\n{req.prompt}"
    t0 = time.time()
    try:
        resp = claude.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=req.max_tokens,
            system=system,
            messages=[{"role": "user", "content": content}],
        )
    except anthropic.APIError as e:
        raise HTTPException(status_code=502, detail=f"Claude API error: {e}")
    raw = resp.content[0].text.strip()
    elapsed = round(time.time() - t0, 2)
    parsed: Any = raw
    is_json = False
    try:
        parsed = json.loads(raw)
        is_json = True
    except json.JSONDecodeError:
        pass
    log.info(f"/ask {elapsed}s json={is_json} tokens={resp.usage.output_tokens}")
    return {
        "response": parsed,
        "is_json": is_json,
        "elapsed_seconds": elapsed,
        "input_tokens": resp.usage.input_tokens,
        "output_tokens": resp.usage.output_tokens,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

@app.post("/event", dependencies=[Depends(require_key)])
async def publish_event(req: EventRequest):
    payload = {
        "type": req.type, "donor_id": req.donor_id,
        "candidate_id": req.candidate_id, "data": req.data or {},
        "published_at": datetime.now(timezone.utc).isoformat(),
    }
    try:
        delivered = r.publish("bgop:events", json.dumps(payload))
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Redis publish failed: {e}")
    log.info(f"/event type={req.type} → {delivered} subscriber(s)")
    return {"published": True, "subscribers_reached": delivered, "payload": payload}

@app.get("/decisions", dependencies=[Depends(require_key)])
async def decisions(limit: int = 20, action: Optional[str] = None):
    try:
        q = supabase.table("brain_decisions").select("*").order("created_at", desc=True).limit(limit)
        if action:
            q = q.eq("action", action.upper())
        result = q.execute()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Supabase error: {e}")
    return {"count": len(result.data), "decisions": result.data,
            "timestamp": datetime.now(timezone.utc).isoformat()}

@app.post("/queue/outbound", dependencies=[Depends(require_key)])
async def peek_outbound(req: OutboundRequest):
    messages = []
    try:
        if req.peek:
            raw = r.lrange("bgop:outbound", 0, req.count - 1)
        else:
            raw = []
            for _ in range(req.count):
                item = r.lpop("bgop:outbound")
                if item is None:
                    break
                raw.append(item)
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Redis error: {e}")
    for item in raw:
        try:
            messages.append(json.loads(item))
        except json.JSONDecodeError:
            messages.append({"raw": item})
    return {"mode": "peek" if req.peek else "pop", "count": len(messages), "messages": messages}


# ─────────────────────────────────────────────────────────────────────────────
# Inter-agent message channel
# ─────────────────────────────────────────────────────────────────────────────

def _validate_agent(name: str, field: str):
    valid = {"perplexity", "claude", "both", "system"}
    if name not in valid:
        raise HTTPException(status_code=400, detail=f"{field} must be one of {valid}")

@app.post("/message", dependencies=[Depends(require_key)])
async def send_message(req: MessageRequest):
    """
    Send a message from one agent to the other.
    Stored in Supabase agent_messages AND published to Redis bgop:agent_channel
    so the recipient can react in real time if they're polling.
    """
    _validate_agent(req.from_agent, "from_agent")
    _validate_agent(req.to_agent,   "to_agent")

    thread = req.thread_id or str(uuid.uuid4())[:8]

    try:
        result = supabase.table("agent_messages").insert({
            "from_agent": req.from_agent,
            "to_agent":   req.to_agent,
            "subject":    req.subject,
            "body":       req.body,
            "payload":    req.payload,
            "thread_id":  thread,
        }).execute()
        row = result.data[0]
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Supabase insert failed: {e}")

    # Also publish to Redis so a live listener catches it instantly
    try:
        r.publish("bgop:agent_channel", json.dumps({
            "id":         row["id"],
            "from_agent": req.from_agent,
            "to_agent":   req.to_agent,
            "subject":    req.subject,
            "body":       req.body,
            "thread_id":  thread,
            "created_at": row["created_at"],
        }))
    except Exception:
        pass  # Redis failure doesn't block Supabase write

    log.info(f"/message {req.from_agent}→{req.to_agent} thread={thread} id={row['id']}")
    return {
        "sent": True,
        "id": row["id"],
        "thread_id": thread,
        "timestamp": row["created_at"],
    }


@app.get("/inbox", dependencies=[Depends(require_key)])
async def inbox(
    agent: str = Query(..., description="'perplexity' or 'claude' — whose inbox to read"),
    include_both: bool = Query(True, description="Include messages sent to 'both'"),
    unread_only: bool  = Query(True),
    limit: int         = Query(50, ge=1, le=200),
):
    """
    Return unread messages for an agent.
    Call this at the start of every session to catch messages left by the other agent.
    """
    _validate_agent(agent, "agent")
    try:
        q = (
            supabase.table("agent_messages")
            .select("*")
            .order("created_at", desc=False)
            .limit(limit)
        )
        if include_both:
            # Supabase REST: filter to_agent IN ('agent', 'both')
            q = q.in_("to_agent", [agent, "both"])
        else:
            q = q.eq("to_agent", agent)
        if unread_only:
            q = q.is_("read_at", "null")
        result = q.execute()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Supabase error: {e}")

    return {
        "agent": agent,
        "unread_count": len(result.data),
        "messages": result.data,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/reply", dependencies=[Depends(require_key)])
async def reply(req: ReplyRequest):
    """
    Post a reply. If parent_id is provided, marks that message as read first.
    Auto-detects thread_id from parent if not supplied.
    """
    _validate_agent(req.from_agent, "from_agent")

    # Resolve thread_id and to_agent from parent
    thread_id = None
    to_agent  = "both"
    if req.parent_id:
        try:
            parent = supabase.table("agent_messages").select("*").eq("id", req.parent_id).execute()
            if parent.data:
                p = parent.data[0]
                thread_id = p.get("thread_id")
                # Reply goes to whoever sent the parent
                to_agent = p["from_agent"] if p["from_agent"] != req.from_agent else p["to_agent"]
                # Mark parent read
                supabase.table("agent_messages").update(
                    {"read_at": datetime.now(timezone.utc).isoformat()}
                ).eq("id", req.parent_id).execute()
        except Exception as e:
            log.warning(f"Could not resolve parent {req.parent_id}: {e}")

    thread_id = thread_id or str(uuid.uuid4())[:8]

    try:
        result = supabase.table("agent_messages").insert({
            "from_agent": req.from_agent,
            "to_agent":   to_agent,
            "subject":    None,
            "body":       req.body,
            "payload":    req.payload,
            "thread_id":  thread_id,
        }).execute()
        row = result.data[0]
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Supabase insert failed: {e}")

    try:
        r.publish("bgop:agent_channel", json.dumps({
            "id": row["id"], "from_agent": req.from_agent,
            "to_agent": to_agent, "body": req.body,
            "thread_id": thread_id, "created_at": row["created_at"],
        }))
    except Exception:
        pass

    log.info(f"/reply {req.from_agent}→{to_agent} thread={thread_id} id={row['id']}")
    return {"sent": True, "id": row["id"], "thread_id": thread_id,
            "to_agent": to_agent, "timestamp": row["created_at"]}


@app.get("/thread/{thread_id}", dependencies=[Depends(require_key)])
async def get_thread(thread_id: str = Path(...)):
    """Full chronological thread — all messages sharing a thread_id."""
    try:
        result = (
            supabase.table("agent_messages")
            .select("*")
            .eq("thread_id", thread_id)
            .order("created_at", desc=False)
            .execute()
        )
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Supabase error: {e}")
    return {
        "thread_id": thread_id,
        "message_count": len(result.data),
        "messages": result.data,
    }


@app.patch("/message/{msg_id}/read", dependencies=[Depends(require_key)])
async def mark_read(msg_id: int = Path(...)):
    """Mark a single message as read."""
    try:
        supabase.table("agent_messages").update(
            {"read_at": datetime.now(timezone.utc).isoformat()}
        ).eq("id", msg_id).execute()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Supabase error: {e}")
    return {"marked_read": True, "id": msg_id}


# ─────────────────────────────────────────────────────────────────────────────
# 404
# ─────────────────────────────────────────────────────────────────────────────

@app.exception_handler(404)
async def not_found(request: Request, exc):
    return JSONResponse(status_code=404, content={
        "error": "Not found",
        "endpoints": [
            "GET  /health", "GET  /status",
            "POST /ask", "POST /event",
            "GET  /decisions", "POST /queue/outbound",
            "POST /message", "GET  /inbox?agent=perplexity|claude",
            "POST /reply", "GET  /thread/{thread_id}",
            "PATCH /message/{id}/read",
        ],
    })


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info(f"BroyhillGOP Relay v1.1 starting on port {RELAY_PORT}")
    uvicorn.run("relay:app", host="0.0.0.0", port=RELAY_PORT,
                log_level="info", access_log=True, reload=False)
