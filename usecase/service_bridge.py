import os, json

def get_session_id():
    """
    Retrieve the current Qwestor session identifier from the environment.

    """
    return os.environ["QWESTOR_SESSION_ID"]

def get_query():
    """
     Retrieve the current user query from the environment.

    """
    return os.environ["QWESTOR_QUERY"]


def _pairs_to_dict(pairs):
    """Convert a MeTTa list of key/value pairs to a JSON-compatible mapping."""

    return {str(key): float(value) for key, value in pairs}


def emit_defaults(goals, mods, anti_goals):
    """Emit Qwestor's canonical MeTTa defaults for the API service."""

    print("@@QWESTOR_DEFAULTS@@" + json.dumps({
        "goals": _pairs_to_dict(goals),
        "mods": _pairs_to_dict(mods),
        "anti_goals": _pairs_to_dict(anti_goals),
    }), flush=True)
    return True

def emit_result(action_name, answer):
    """
        Emit the final Qwestor response.

    """
    print("@@QWESTOR_RESULT@@" + json.dumps({
        "selected_action": str(action_name),
        "answer": str(answer),
    }), flush=True)
    
    return True