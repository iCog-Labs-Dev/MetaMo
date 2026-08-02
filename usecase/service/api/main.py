import hashlib, json, uuid
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel,Field
from sqlalchemy import text

from .db import engine as db_engine
from .redis_client import redis_client, acquire_lock, release_lock
from .engine import engine as metta_engine
from .defaults import DEFAULT_GOALS, DEFAULT_MODS, DEFAULT_ANTI_GOALS
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
import logging, time

"""
Qwestor API service.

Provides REST endpoints for managing Qwestor sessions, executing
reasoning cycles through the MeTTa engine, handling idempotent requests,
and exposing service health and metrics information.
"""


app = FastAPI()
logger = logging.getLogger("qwestor")

@app.middleware("http")
async def log_requests(request, call_next):
    """
    Log incoming HTTP requests with status and execution duration.
    """
    start = time.monotonic()
    response = await call_next(request)
    logger.info(json.dumps({
        "path": request.url.path, "method": request.method,
        "status": response.status_code,
        "duration_ms": round((time.monotonic() - start) * 1000, 1),
    }))
    return response


class CycleRequest(BaseModel):
    """
    Request payload for executing a Qwestor reasoning cycle.

    Contains the user query and expected session state version
    for optimistic concurrency control.
    """

    query: str = Field(min_length=1, max_length=4000)
    expected_state_version: int = Field(ge=0)


@app.post("/v1/sessions")
def create_session():
    """Create a new Qwestor session with default reasoning state."""

    session_id = str(uuid.uuid4())
    now = datetime.utcnow()
    exp = now + timedelta(days=30)
    with db_engine.begin() as conn:
        conn.execute(text("""
            INSERT INTO sessions (session_id, goals, mods, anti_goals, state_version,
                                   status, created_at, updated_at, expires_at)
            VALUES (:sid, :g, :m, :a, 0, 'active', :now, :now, :exp)
        """), {"sid": session_id, "g": json.dumps(DEFAULT_GOALS), "m": json.dumps(DEFAULT_MODS),
                "a": json.dumps(DEFAULT_ANTI_GOALS), "now": now, "exp": exp})
    return {"session_id": session_id, "state_version": 0, "config_version": "v1",
            "expires_at": exp.isoformat()}


@app.get("/v1/sessions/{session_id}")
def get_session(session_id: str):
    """Retrieve the current state of an active session."""

    with db_engine.connect() as conn:
        row = conn.execute(text("SELECT * FROM sessions WHERE session_id=:sid AND status='active'"),
                            {"sid": session_id}).mappings().first()
    if not row:
        raise HTTPException(404, "session not found")
    return dict(row)


@app.delete("/v1/sessions/{session_id}")
def delete_session(session_id: str):
    """Mark a session as deleted and clear cached state."""

    with db_engine.begin() as conn:
        result = conn.execute(text("UPDATE sessions SET status='deleted' WHERE session_id=:sid AND status='active'"),
                               {"sid": session_id})
    redis_client.delete(f"session:{session_id}")
    if result.rowcount == 0:
        raise HTTPException(404, "session not found")
    return {"status": "deleted"}


@app.post("/v1/sessions/{session_id}/cycles")
def run_cycle(session_id: str, body: CycleRequest,
              idempotency_key: str = Header(..., alias="Idempotency-Key")):
    """Execute a Qwestor reasoning cycle."""

    request_hash = hashlib.sha256(body.model_dump_json().encode()).hexdigest()

    with db_engine.connect() as conn:
        existing = conn.execute(text("""
            SELECT request_hash, status, response FROM idempotency_keys
            WHERE session_id=:sid AND idempotency_key=:key
        """), {"sid": session_id, "key": idempotency_key}).mappings().first()
    if existing:
        if existing["request_hash"] != request_hash:
            raise HTTPException(409, "idempotency key reused with a different request body")
        if existing["status"] == "completed":
            return existing["response"]
        raise HTTPException(409, "request with this idempotency key is already in flight")

    lock_key = f"lock:session:{session_id}"
    try:
        token = acquire_lock(lock_key, timeout=15)
    except Exception:
        token = None  # Redis down — fall through to Postgres row lock below

    try:
        with db_engine.begin() as conn:
            row = conn.execute(
                text("SELECT state_version FROM sessions WHERE session_id=:sid AND status='active' FOR UPDATE"),
                {"sid": session_id},
            ).mappings().first()
            if not row:
                raise HTTPException(404, "session not found")
            if row["state_version"] != body.expected_state_version:
                raise HTTPException(409, "state version conflict")

            conn.execute(text("""
                INSERT INTO idempotency_keys (session_id, idempotency_key, request_hash, status)
                VALUES (:sid, :key, :hash, 'pending')
            """), {"sid": session_id, "key": idempotency_key, "hash": request_hash})

        try:
            metta_engine.run_cycle(session_id, body.query)
        except Exception as exc:
            with db_engine.begin() as conn:
                conn.execute(text("DELETE FROM idempotency_keys WHERE session_id=:sid AND idempotency_key=:key"),
                             {"sid": session_id, "key": idempotency_key})
            raise HTTPException(503, f"engine error: {exc}")

        with db_engine.connect() as conn:
            session_row = conn.execute(text("SELECT * FROM sessions WHERE session_id=:sid"),
                                        {"sid": session_id}).mappings().first()
            decision_row = conn.execute(text("""
                SELECT * FROM cycle_decisions WHERE session_id=:sid ORDER BY id DESC LIMIT 1
            """), {"sid": session_id}).mappings().first()

        response = {
            "selected_action": decision_row["selected_action"] if decision_row else None,
            "answer": decision_row["answer"] if decision_row else None,
            "state_version": session_row["state_version"],
            "goals": session_row["goals"],
            "mods": session_row["mods"],
        }

        with db_engine.begin() as conn:
            conn.execute(text("""
                UPDATE idempotency_keys SET status='completed', response=:resp
                WHERE session_id=:sid AND idempotency_key=:key
            """), {"resp": json.dumps(response), "sid": session_id, "key": idempotency_key})

        redis_client.delete(f"session:{session_id}")
        return response
    finally:
        if token:
            release_lock(lock_key, token)


@app.get("/health/live")
def live():
    """Return service liveness status."""

    return {"status": "ok"}


@app.get("/health/ready")
def ready():
    """Check database and Redis availability."""

    try:
        with db_engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception:
        raise HTTPException(503, "database unavailable")
    try:
        redis_client.ping()
        redis_ok = True
    except Exception:
        redis_ok = False
    return {"status": "ok", "redis": redis_ok}

# added 

@app.get("/metrics")
def metrics():
    """Return basic service metrics."""

    with db_engine.connect() as conn:
        active = conn.execute(text("SELECT count(*) FROM sessions WHERE status='active'")).scalar()
    return {"active_sessions": active}


@app.exception_handler(HTTPException)
async def problem_json_handler(request, exc: HTTPException):
    """Return HTTP errors using RFC 7807 problem details format."""

    return JSONResponse(
        status_code=exc.status_code,
        media_type="application/problem+json",
        content={"type": "about:blank", "title": exc.detail, "status": exc.status_code},
    )

@app.exception_handler(RequestValidationError)
async def validation_problem_handler(request, exc: RequestValidationError):
    """Return validation errors using RFC 7807 problem details format."""
    
    return JSONResponse(
        status_code=422,
        media_type="application/problem+json",
        content={"type": "about:blank", "title": "Invalid request", "status": 422, "errors": exc.errors()},
    )
