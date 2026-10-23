;; Core owns final checks and invocation; this adapter supplies the existing
;; concrete MeTTa feasibility gate. Host bindings/policies default to absent.
!(import! &self (library OmegaClaw-Core src/dispatch))

!(import_prolog_functions_from_file
   (library MetaMo applications/omegaclaw_v1/dispatch.pl)
   (initMetaMoDispatch dispatchRoutingAllowed completeHostConversation hostReadPlanRequired))

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

;; Example: the ordinary cycle prepares a read plan before publishing its selection snapshot.
(= (prepareAutomaticReadPlan)
   (progn
      (py-call (host_operations.prepare_automatic_read_plan))
      (hostRefreshContinuation)))

;; Example: (hostAdmitContinuation "plan" proposed-steps) checks the live host catalog.
;; Resolved steps remain data until hostInstallAdmittedContinuation installs them.
(= (hostAdmitContinuation $id $steps)
   (sread (py-call (host_operations.admit_read_plan $id (repr $steps)))))

;; Example: install F3.3's result only for the context/commitment that requested it.
;; Admission is rechecked under the same lock as F3.4 installation and invalidation.
(= (hostInstallAdmittedContinuation $context $commitment $admission)
   (sread (py-call (host_operations.install_admitted_continuation
      (repr $context) (repr $commitment) (repr $admission)))))

;; Example: relative file references become cwd-relative absolute command arguments.
(= (continuationResolveRead $step)
   (let* (
      ($id (index-atom $step 1))
      ($path (index-atom (index-atom $step 2) 1))
      ($resolved (sread (py-call (host_operations.resolve_read_reference $path))))
      ($command (cons-atom read-file (cons-atom $resolved ())))
   )
      (ExecutionStep $id $command)))

;; Example: an unbound read is rejected even if its candidate name is supported.
(= (continuationReadGate $step $bindings $bundle $global $frame)
   (let* (
      ((ExecutionStep $_ $command) $step)
      ($matches (filter-atom $bindings $binding
         (let (HostCommandBinding $bound $_ $_) $binding (== $command $bound))))
   )
      (case $matches (
         (() (GateDecision Rejected UnsupportedOperation))
         (($only) (let (HostCommandBinding $_ $request $operation) $only
            (dispatchOperationGate $bundle $bundle $request $operation $global $frame)))
         ($_ (GateDecision Rejected AmbiguousOperation))))))

;; Example: one denied read rejects the whole proposal without returning partial work.
(= (continuationAdmitReads $id $steps $bindings $bundle $global $frame)
   (let* (
      ($resolved (map-atom $steps $step (continuationResolveRead $step)))
      ($gates (map-atom $resolved $step
         (continuationReadGate $step $bindings $bundle $global $frame)))
      ($rejected (filter-atom $gates $gate (!= $gate (GateDecision Admitted Feasible))))
   )
      (case (and (continuationPlanValid $id $resolved)
                 (tpList ids (map-atom $resolved $step (index-atom (index-atom $step 2) 1)))) (
         (False (ContinuationRejected InvalidPlan))
         (True (case $rejected (
            (() (ContinuationAdmitted $id $resolved))
            ($_ (let (GateDecision $_ $reason) (car-atom $rejected)
               (ContinuationRejected $reason))))))))))

(= (captureHostOperations $bundle)
   (if (== $bundle (activeFrameBundle))
       (sread (py-call (host_operations.capture))) ()))
!(change-state! &operation-provider captureHostOperations)
;; Core loop hooks retain the pre-scoring ticket and exact selected arguments.
!(if (== (eval (configureCoreLoopDispatch selectedHostTicket dispatchSelectedHostCommand)) True)
     True (py-call (host_operations.incompatible_core)))
