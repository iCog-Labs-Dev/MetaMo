;; Core owns final checks and invocation; this adapter supplies the existing
;; concrete MeTTa feasibility gate. Host bindings/policies default to absent.
!(import! &self (library OmegaClaw-Core src/dispatch))

!(import_prolog_functions_from_file
   (library MetaMo applications/omegaclaw_v1/dispatch.pl)
   (initMetaMoDispatch dispatchRoutingAllowed))

;; Core holds its dispatch mutex and the IRC route guard from the final snapshot
;; through handler invocation. Check actual transport routing, not just config.
;; Keep the pure feasibility API independent of channel/runtime configuration.
(= (dispatchOperationGate $origin $target $request $operation $global $frame)
   (let $decision (feasibilityGateForRequest $origin $target $request $operation $global $frame)
      (if (!= $decision (GateDecision Admitted Feasible)) $decision
          (case $operation (
             ((PolicyOperation $_ $_ (skill "send") $_ (egress $destinations) $_)
              (if (dispatchRoutingAllowed $destinations)
                  $decision (GateDecision Rejected DestinationMismatch)))
             ($_ $decision))))))

!(import! &self (library MetaMo applications/omegaclaw_v1/host_operations.py))
(= (captureHostOperations $bundle)
   (if (== $bundle (activeFrameBundle))
       (sread (py-call (host_operations.capture))) ()))
!(change-state! &operation-provider captureHostOperations)
;; Core loop hooks retain the pre-scoring ticket and exact selected arguments.
!(if (== (eval (configureCoreLoopDispatch selectedHostTicket dispatchSelectedHostCommand)) True)
     True (py-call (host_operations.incompatible_core)))
