!(import! &self main-loop)
!(import! &self "service_bridge.py")

!(let*
    (
      ($session-id   (py-call (service_bridge.get_session_id)))
      ($query        (py-call (service_bridge.get_query)))
      ($_set-session (setSessionId $session-id))

      ($old-state    (match &space ($g $m $a) ($g $m $a)))
      ($_remove      (remove-atom &space $old-state))
      ($_init        (initializeSessionSpace &space))

      ($turn-result  (runQwestor &space $query))
      ($action-name  (index-atom $turn-result 0))
      ($answer       (index-atom $turn-result 1))

      ($_save        (saveCurrentSession &space))
      ($_log         (py-call (session_store.log_turn $session-id $query $action-name $answer)))

      ($_emit        (py-call (service_bridge.emit_result $action-name $answer)))
    )
    done
)