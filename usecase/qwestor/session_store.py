import json
import os
from datetime import datetime

SESSIONS_DIR = os.path.join(os.path.dirname(__file__), "sessions")
LOGS_DIR = os.path.join(os.path.dirname(__file__), "logs")


def _path(session_id):
    os.makedirs(SESSIONS_DIR, exist_ok=True)
    return os.path.join(SESSIONS_DIR, session_id + ".json")


def has_session(session_id):
    return os.path.exists(_path(session_id))


def load_test_session(name):
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


def load_goals(session_id):
    with open(_path(session_id), "r", encoding="utf-8") as f:
        data = json.load(f)["goals"]
        return [[k, v] for k, v in data.items()] if isinstance(data, dict) else data

def load_mods(session_id):
    with open(_path(session_id), "r", encoding="utf-8") as f:
        data = json.load(f)["mods"]
        return [[k, v] for k, v in data.items()] if isinstance(data, dict) else data

def load_anti_goals(session_id):
    with open(_path(session_id), "r", encoding="utf-8") as f:
        data = json.load(f)["anti_goals"]
        return [[k, v] for k, v in data.items()] if isinstance(data, dict) else data

def save_session(session_id, goals, mods, anti_goals):
    data = {
        "goals": dict(goals) if isinstance(goals, list) else goals,
        "mods": dict(mods) if isinstance(mods, list) else mods,
        "anti_goals": dict(anti_goals) if isinstance(anti_goals, list) else anti_goals
    }
    
    with open(_path(session_id), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    return True


def log_turn(session_id, query, action, answer):
    os.makedirs(LOGS_DIR, exist_ok=True)
    log_path = os.path.join(LOGS_DIR, session_id + ".json")

    if os.path.exists(log_path):
        with open(log_path, "r", encoding="utf-8") as f:
            turns = json.load(f)
    else:
        turns = []

    turns.append({
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "query": query,
        "action": action,
        "answer": answer,
    })

    with open(log_path, "w", encoding="utf-8") as f:
        json.dump(turns, f, indent=2)
    return True

