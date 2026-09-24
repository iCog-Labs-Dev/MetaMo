"""Test-only provider responses; appraisal weights and scoring remain real."""
_semantic_responses = {}


def semantic_response(message, response):
    _semantic_responses[message] = response
    return 1


_calls = {"confirmation": 0, "semantics": 0}


def reset():
    _semantic_responses.clear()
    _calls.update(confirmation=0, semantics=0)
    return True


def call_count(kind):
    return _calls[kind]


def executionConfirmationScore(provider, message, active_task):
    if provider != "Offline":
        raise ValueError("fixture requires explicit Offline provider")
    _calls["confirmation"] += 1
    return 0.0


def extractSemantics(provider, message):
    if provider != "Offline":
        raise ValueError("fixture requires explicit Offline provider")
    _calls["semantics"] += 1
    return _semantic_responses.get(message, "()")
