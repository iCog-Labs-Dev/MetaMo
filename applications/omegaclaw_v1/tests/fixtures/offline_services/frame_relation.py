"""Test-only in-memory replacement for the external relation composer.

Returns the host provider's wire shape, not a FrameStateBundle. Previous frame
IDs stand in for vector retrieval; classification is deliberately deterministic.
Never import this module in production composition.
"""
import json
import re

_frames = []
_calls = 0


def reset():
    global _calls
    _frames.clear()
    _calls = 0
    return True


def call_count():
    return _calls


def cfv2_compose_frame_relations(frames, query_frame_id, allowed_classes, provider, k=5):
    global _calls
    token = str(query_frame_id).strip()
    # Preserve the exact ID token from MeTTa repr, including string quoting.
    if not re.fullmatch(r'"[^"\\\n]+"|[A-Za-z0-9_&-]+', token):
        raise ValueError("invalid fixture frame ID")
    if "(Frame " not in str(frames) or "RelatedButSeparate" not in str(allowed_classes):
        raise ValueError("unexpected relation composer input")
    if str(provider).strip('"') != "Offline":
        raise ValueError("fixture requires explicit Offline provider")
    _calls += 1
    prior = [item for item in _frames if item != token][:max(0, min(int(k), 5))]
    if token not in _frames:
        _frames.append(token)
    reason = json.dumps("offline fixture: prior admitted frame; no semantic inference")
    relations = [f"(Relation (FrameID-1 {token}) (FrameID-2 {other}) "
                 f"(Class RelatedButSeparate) (Reason {reason}) (Confidence 0.5))"
                 for other in prior]
    return "(" + " ".join(relations) + ")"
