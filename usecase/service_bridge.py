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

def emit_result(action_name, answer):
    """
        Emit the final Qwestor response.

    """
    print("@@QWESTOR_RESULT@@" + json.dumps({
        "selected_action": str(action_name),
        "answer": str(answer),
    }), flush=True)
    
    return True