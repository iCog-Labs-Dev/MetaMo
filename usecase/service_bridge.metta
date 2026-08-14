; MeTTa-facing wrappers for the Python service bridge.

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
