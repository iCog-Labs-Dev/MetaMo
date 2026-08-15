; MeTTa-facing wrappers for the Python service bridge.
;
; This module deliberately has a different basename from service_bridge.py.
; PeTTa uses basenames as module identifiers, so giving both modules the same
; name makes imports ambiguous and can recurse during service startup.

!(import! &self "service_bridge.py")

(= (serviceSessionId)
    (py-call (service_bridge.get_session_id))
)

(= (serviceQuery)
    (py-call (service_bridge.get_query))
)

(= (emitServiceResult $action-name $answer)
    (py-call (service_bridge.emit_result $action-name $answer))
)

(= (emitServiceDefaults $goals $mods $anti-goals)
    (py-call (service_bridge.emit_defaults $goals $mods $anti-goals))
)
