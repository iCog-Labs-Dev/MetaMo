;; Core owns final checks and invocation; this adapter supplies the existing
;; concrete MeTTa feasibility gate. Host bindings/policies default to absent.
!(import! &self (library OmegaClaw-Core src/dispatch))

;; The admitted send binding is local/stdout only. Core's send uses mutable
;; commchannel routing, so recheck it under Core's dispatch lock before effects.
;; Keep the pure feasibility API independent of channel/runtime configuration.
(= (dispatchOperationGate $origin $target $request $operation $global $frame)
   (let $decision (feasibilityGateForRequest $origin $target $request $operation $global $frame)
      (if (!= $decision (GateDecision Admitted Feasible)) $decision
          (case $operation (
             ((PolicyOperation $_ $_ (skill "send") $_ (egress $destinations) $_)
              (if (and (== $destinations ("local:stdout"))
                       (== (eval (commchannel)) local))
                  $decision (GateDecision Rejected DestinationMismatch)))
             ($_ $decision))))))

!(import_prolog_functions_from_file
   (library MetaMo applications/omegaclaw_v1/dispatch.pl)
   (initMetaMoDispatch))

!(import! &self (library MetaMo applications/omegaclaw_v1/host_operations.py))
(= (captureHostOperations $bundle)
   (if (== $bundle (activeFrameBundle))
       (sread (py-call (host_operations.capture))) ()))
!(change-state! &operation-provider captureHostOperations)
;; Core loop hooks retain the pre-scoring ticket and exact selected arguments.
!(if (== (eval (configureCoreLoopDispatch selectedHostTicket dispatchSelectedHostCommand)) True)
     True (py-call (host_operations.incompatible_core)))
