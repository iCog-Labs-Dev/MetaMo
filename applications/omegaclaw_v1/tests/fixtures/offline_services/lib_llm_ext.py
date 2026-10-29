"""Test-only provider responses; appraisal weights and scoring remain real."""
_semantic_responses = {}
_confirmation_responses = {}


def semantic_response(message, response):
    _semantic_responses[message] = response
    return 1


def confirmation_response(message, score):
    _confirmation_responses[message] = score
    return 1


_calls = {"confirmation": 0, "semantics": 0}


def reset():
    _semantic_responses.clear()
    _confirmation_responses.clear()
    _calls.update(confirmation=0, semantics=0)
    return True


def call_count(kind):
    return _calls[kind]


def executionConfirmationScore(provider, message, active_task):
    if provider != "Offline":
        raise ValueError("fixture requires explicit Offline provider")
    _calls["confirmation"] += 1
    return _confirmation_responses.get(message, 0.0)


def extractSemantics(provider, message):
    if provider != "Offline":
        raise ValueError("fixture requires explicit Offline provider")
    _calls["semantics"] += 1
    return _semantic_responses.get(message, "()")


def parseMotivosState(raw):
    if raw not in ("", [], None):
        raise ValueError("offline fixture expects empty memory")
    return "()"
