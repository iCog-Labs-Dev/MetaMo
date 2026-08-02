import os, json
from datetime import datetime, timedelta
from sqlalchemy import create_engine, text
import redis

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql+psycopg2://metamo:metamo@localhost:5432/metamo")
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
SESSION_TTL_SECONDS = 24 * 3600

_engine = create_engine(DATABASE_URL, pool_pre_ping=True)
_redis = redis.Redis.from_url(REDIS_URL, decode_responses=True)


def _cache_key(session_id):
    """Generate Redis cache key for a session."""

    return f"session:{session_id}"


def has_session(session_id):
    """Check whether an active session exists in the database."""

    with _engine.connect() as conn:
        row = conn.execute(
            text("SELECT 1 FROM sessions WHERE session_id=:sid AND status='active'"),
            {"sid": session_id},
        ).first()
    return row is not None


def _load_state(session_id):
    """Load session state from Redis cache or database."""

    cached = _redis.get(_cache_key(session_id))
    if cached:
        return json.loads(cached)

    with _engine.connect() as conn:
        row = conn.execute(
            text("""SELECT goals, mods, anti_goals, state_version
                     FROM sessions WHERE session_id=:sid AND status='active'"""),
            {"sid": session_id},
        ).mappings().first()

    if row is None:
        return None

    state = {"goals": row["goals"], "mods": row["mods"],
             "anti_goals": row["anti_goals"], "state_version": row["state_version"]}
    _redis.setex(_cache_key(session_id), SESSION_TTL_SECONDS, json.dumps(state))
    return state


def load_goals(session_id):
    """Retrieve session goals as key-value pairs."""

    return [[k, v] for k, v in _load_state(session_id)["goals"].items()]


def load_mods(session_id):
    """Retrieve session modulators as key-value pairs."""

    return [[k, v] for k, v in _load_state(session_id)["mods"].items()]


def load_anti_goals(session_id):
    """Retrieve session anti-goals as key-value pairs."""

    return [[k, v] for k, v in _load_state(session_id)["anti_goals"].items()]


def save_session(session_id, goals, mods, anti_goals):
    """Persist session state updates and invalidate cached state."""

    goals_d = dict(goals) if isinstance(goals, list) else goals
    mods_d = dict(mods) if isinstance(mods, list) else mods
    anti_d = dict(anti_goals) if isinstance(anti_goals, list) else anti_goals
    now = datetime.utcnow()

    with _engine.begin() as conn:
        result = conn.execute(
            text("""UPDATE sessions
                     SET goals=:goals, mods=:mods, anti_goals=:anti,
                         state_version = state_version + 1, updated_at=:now
                     WHERE session_id=:sid AND status='active'
                     RETURNING state_version"""),
            {"goals": json.dumps(goals_d), "mods": json.dumps(mods_d),
             "anti": json.dumps(anti_d), "now": now, "sid": session_id},
        )
        row = result.first()
        if row is None:
            conn.execute(
                text("""INSERT INTO sessions
                        (session_id, goals, mods, anti_goals, state_version, status,
                         created_at, updated_at, expires_at)
                        VALUES (:sid, :goals, :mods, :anti, 0, 'active', :now, :now, :exp)"""),
                {"sid": session_id, "goals": json.dumps(goals_d), "mods": json.dumps(mods_d),
                 "anti": json.dumps(anti_d), "now": now, "exp": now + timedelta(days=30)},
            )

    _redis.delete(_cache_key(session_id))   
    return True


def log_turn(session_id, query, action, answer):
    """Store a completed cycle decision and response."""

    with _engine.begin() as conn:
        conn.execute(
            text("""INSERT INTO cycle_decisions (session_id, query, selected_action, answer, created_at)
                     VALUES (:sid, :q, :a, :ans, :now)"""),
            {"sid": session_id, "q": query, "a": action, "ans": answer, "now": datetime.utcnow()},
        )
    return True


def load_test_session(name):
    """Load predefined test session queries by session name."""

    import importlib.util
    here = os.path.dirname(__file__)
    test_file = os.path.join(here, "tests", "session_short.py")
    spec = importlib.util.spec_from_file_location("session_short", test_file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    for session in module.SESSIONS:
        if session["name"] == name:
            return session["queries"]
    return []