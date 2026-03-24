"""
BroyhillGOP Relay — HTTP bridge between Perplexity (or any client) and the
Claude / E20 Brain stack running on Hetzner.

Port  : 8080  (set RELAY_PORT in .env to override)
Auth  : X-API-Key header must match RELAY_API_KEY in .env

Endpoints
─────────
GET  /health           → liveness check, returns versions + uptime
GET  /status           → Redis queue depths, brain container state
POST /ask              → synchronous Claude query, returns decision JSON
POST /event            → publish event to Redis (brain.py picks up async)
GET  /decisions        → last N decisions from Supabase brain_decisions table
POST /sql              → run a read-only SELECT against Supabase (Perplexity DB queries)
GET  /queue/outbound   → peek / pop messages from bgop:outbound
"""

import os
import json
import time
import logging
import hashlib
import hmac
from datetime import datetime, timezone
from typing import Optional, Any

import anthropic
import redis as redis_lib
from supabase import create_client, Client
from fastapi import FastAPI, HTTPException, Request, Depends, Header
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import uvicorn

# ── Logging ───────────────────────────────────────────────────────────────────
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

# ── FastAPI app ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="BroyhillGOP Relay",
    version="1.0.0",
    description="HTTP bridge: Perplexity ↔ Claude ↔ Supabase ↔ Redis",
)

# ── Auth dependency ───────────────────────────────────────────────────────────
def require_key(x_api_key: str = Header(...)):
    """Constant-time compare to prevent timing attacks."""
    if not hmac.compare_digest(x_api_key.encode(), RELAY_API_KEY.encode()):
        log.warning(f"Bad API key attempt: {x_api_key[:8]}…")
        raise HTTPException(status_code=401, detail="Invalid API key")
    return True


# ── Pydantic models ───────────────────────────────────────────────────────────
class AskRequest(BaseModel):
    prompt: str = Field(..., description="Free-form question or instruction for Claude")
    system: Optional[str] = Field(
        None,
        description="Override system prompt. Defaults to the E20 Brain persona."
    )
    max_tokens: int = Field(1024, ge=64, le=4096)
    context: Optional[dict] = Field(
        None,
        description="Optional structured context dict merged into the prompt"
    )


class EventRequest(BaseModel):
    type: str = Field(..., description="Event type, e.g. 'donor_action', 'trigger'")
    donor_id: Optional[int] = None
    candidate_id: Optional[int] = None
    data: Optional[dict] = Field(default_factory=dict)


class SqlRequest(BaseModel):
    sql: str = Field(..., description="SELECT statement only — writes are rejected")


class OutboundRequest(BaseModel):
    peek: bool = Field(True, description="True=non-destructive peek, False=pop (consume)")
    count: int = Field(10, ge=1, le=100)


# ── System prompt (same as brain.py so /ask is consistent) ───────────────────
DEFAULT_SYSTEM = """
You are the E20 Brain Hub for BroyhillGOP — a quantifiable reasoning engine that
orchestrates campaign decisions for NC Republican candidates.

Your job is to analyze events or questions and return a structured JSON decision.

For event decisions, output ONLY valid JSON:
{
  "action": "SEND_MESSAGE | PAUSE | ESCALATE | DO_NOTHING",
  "channel": "sms | email | phone | social | none",
  "message": "The exact message to send (or null)",
  "ask_amount": 0,
  "reasoning": "Brief explanation",
  "expected_value": 0.0,
  "next_trigger_days": 0
}

For open-ended questions, answer clearly and concisely in plain text.
Rules:
- NEVER treat donation records as duplicate contacts
- If fatigue score > 0.7, action must be PAUSE
- Expected value = (predicted_amount * conversion_rate) - fatigue_cost
- Only SEND_MESSAGE if expected_value > 25
- For major donors ($10K+), always recommend human review for asks > $500
""".strip()


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    """Liveness check — no auth required."""
    uptime = int(time.time() - START_TIME)
    redis_ok = False
    try:
        redis_ok = r.ping()
    except Exception:
        pass
    return {
        "status": "ok",
        "uptime_seconds": uptime,
        "relay_version": "1.0.0",
        "redis": "ok" if redis_ok else "unreachable",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/status", dependencies=[Depends(require_key)])
async def status():
    """Queue depths and Redis channel subscribers."""
    try:
        outbound_depth = r.llen("bgop:outbound")
        events_depth   = r.llen("bgop:events")
        subscribers    = r.pubsub_numsub("bgop:events", "bgop:triggers")
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Redis unreachable: {e}")

    return {
        "queues": {
            "bgop:outbound": outbound_depth,
            "bgop:events":   events_depth,
        },
        "subscribers": dict(zip(subscribers[::2], subscribers[1::2])),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/ask", dependencies=[Depends(require_key)])
async def ask(req: AskRequest):
    """
    Synchronous Claude query.  Perplexity sends a prompt, gets a response back
    in the same HTTP call.  No Redis involved — direct API round-trip.
    """
    system = req.system or DEFAULT_SYSTEM
    user_content = req.prompt
    if req.context:
        user_content = f"CONTEXT:\n{json.dumps(req.context, indent=2)}\n\n{req.prompt}"

    t0 = time.time()
    try:
        response = claude.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=req.max_tokens,
            system=system,
            messages=[{"role": "user", "content": user_content}],
        )
    except anthropic.APIError as e:
        log.error(f"/ask Claude error: {e}")
        raise HTTPException(status_code=502, detail=f"Claude API error: {e}")

    raw = response.content[0].text.strip()
    elapsed = round(time.time() - t0, 2)

    # Try to parse as JSON; if not, return as plain text
    parsed: Any = raw
    is_json = False
    try:
        parsed = json.loads(raw)
        is_json = True
    except json.JSONDecodeError:
        pass

    log.info(f"/ask → {elapsed}s | json={is_json} | tokens={response.usage.output_tokens}")
    return {
        "response": parsed,
        "is_json": is_json,
        "elapsed_seconds": elapsed,
        "input_tokens": response.usage.input_tokens,
        "output_tokens": response.usage.output_tokens,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/event", dependencies=[Depends(require_key)])
async def publish_event(req: EventRequest):
    """
    Publish an event to bgop:events — brain.py picks it up asynchronously,
    calls Claude, logs decision to Supabase, pushes to bgop:outbound.
    Returns immediately (fire-and-forget).
    """
    payload = {
        "type":         req.type,
        "donor_id":     req.donor_id,
        "candidate_id": req.candidate_id,
        "data":         req.data or {},
        "published_at": datetime.now(timezone.utc).isoformat(),
    }
    try:
        delivered = r.publish("bgop:events", json.dumps(payload))
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Redis publish failed: {e}")

    log.info(f"/event type={req.type} donor={req.donor_id} → {delivered} subscriber(s)")
    return {
        "published": True,
        "subscribers_reached": delivered,
        "payload": payload,
    }


@app.get("/decisions", dependencies=[Depends(require_key)])
async def decisions(limit: int = 20, action: Optional[str] = None):
    """
    Last N decisions from the Supabase brain_decisions table.
    Optionally filter by action type (SEND_MESSAGE, PAUSE, etc.)
    """
    try:
        query = (
            supabase.table("brain_decisions")
            .select("*")
            .order("created_at", desc=True)
            .limit(limit)
        )
        if action:
            query = query.eq("action", action.upper())
        result = query.execute()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Supabase error: {e}")

    return {
        "count": len(result.data),
        "decisions": result.data,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/sql", dependencies=[Depends(require_key)])
async def run_sql(req: SqlRequest):
    """
    Run a read-only SELECT against Supabase via the REST API.
    Perplexity can use this to query the DB without needing psql.
    WRITES ARE REJECTED — any statement containing INSERT/UPDATE/DELETE/DROP/TRUNCATE
    will be refused before it reaches the database.
    """
    forbidden = ["insert", "update", "delete", "drop", "truncate", "alter", "create"]
    stmt_lower = req.sql.lower().strip()
    for kw in forbidden:
        if kw in stmt_lower:
            raise HTTPException(
                status_code=400,
                detail=f"Write operation '{kw}' is not permitted via /sql. Use psql directly."
            )
    if not stmt_lower.startswith("select"):
        raise HTTPException(status_code=400, detail="Only SELECT statements are allowed.")

    try:
        result = supabase.rpc("execute_sql", {"query": req.sql}).execute()
        rows = result.data
    except Exception as e:
        # Supabase REST doesn't support arbitrary SQL — fall through to psql hint
        log.warning(f"/sql Supabase RPC failed: {e}")
        raise HTTPException(
            status_code=501,
            detail=(
                "Supabase REST doesn't support arbitrary SQL. "
                "Use /ask with your query as a prompt and Claude will run it via psql, "
                "or run it directly in the ttyd terminal."
            )
        )

    return {"rows": rows, "count": len(rows) if isinstance(rows, list) else None}


@app.post("/queue/outbound", dependencies=[Depends(require_key)])
async def peek_outbound(req: OutboundRequest):
    """
    Peek or pop messages from bgop:outbound — the queue brain.py pushes
    outbound SMS/email jobs to.
    """
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

    return {
        "mode": "peek" if req.peek else "pop",
        "count": len(messages),
        "messages": messages,
    }


# ── 404 catch-all ─────────────────────────────────────────────────────────────
@app.exception_handler(404)
async def not_found(request: Request, exc):
    return JSONResponse(
        status_code=404,
        content={
            "error": "Not found",
            "available_endpoints": [
                "GET  /health",
                "GET  /status",
                "POST /ask",
                "POST /event",
                "GET  /decisions",
                "POST /sql",
                "POST /queue/outbound",
            ],
        },
    )


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info(f"BroyhillGOP Relay starting on port {RELAY_PORT}")
    uvicorn.run(
        "relay:app",
        host="0.0.0.0",
        port=RELAY_PORT,
        log_level="info",
        access_log=True,
        reload=False,
    )
