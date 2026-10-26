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

;; Example: publish a retained uncertain invocation even if its original callback was lost.
;; This reads Core's ledger, never infers an outcome from time or model text.
(= (observeHostUncertainty)
   (sread (py-call (host_operations.observe_pending_invocation))))

;; Example: the ordinary cycle prepares a read plan before publishing its selection snapshot.
(= (prepareAutomaticReadPlan)
   (progn
      (py-call (host_operations.prepare_automatic_read_plan))
      (hostRefreshContinuation)))

;; Example: (hostAdmitContinuation "plan" proposed-steps) checks the live host catalog.
;; Resolved steps remain data until hostInstallAdmittedContinuation installs them.
(= (hostAdmitContinuation $id $steps)
   (sread (py-call (host_operations.admit_read_plan $id (repr $steps)))))

;; Example: validate the exact recorded correction without resuming its held read.
;; Ownership comparison and current catalog/policy admission share Core's mutex.
(= (hostAdmitCorrection $correction)
   (sread (py-call (host_operations.admit_correction (repr $correction)))))

;; Example: resume F4.4's admitted correction at a cleared host selection slot.
;; Revalidation, state replacement and decision invalidation share Core's mutex.
(= (hostResumeContinuation $admission)
   (sread (py-call (host_operations.resume_continuation (repr $admission)))))

;; Example: revocation after F4.4 admission cannot make the corrected read Ready.
;; Called only by the locked host bridge; a changed resolved command is rejected.
(= (continuationResumeAdmission $admission)
   (case $admission (
      ((ContinuationCorrectionAdmitted $correction $step)
       (let $current (hostAdmitCorrection $correction)
          (case $current (
             ($admission
              (case (continuationPrepareResume $step) (
                 ((ContinuationResumePrepared $plan $evidence $revision $retries)
                  (continuationApplyResume $plan $evidence $revision $retries))
                 ($rejection $rejection))))
             ((ContinuationCorrectionAdmitted $_ $_) (ContinuationRejected StaleAdmission))
             ($_ $current)))))
      ($_ (ContinuationRejected InvalidAdmission)))))

;; Example: an old correction cannot borrow a successor's read permissions.
;; Called under the host lock; the returned step is data, not retry authority.
(= (continuationAdmitCorrection $correction)
   (case (and (!= $correction NoContinuationCorrection)
              (== $correction (hostContinuationCorrection))) (
      (False (ContinuationRejected StaleCorrection))
      (True
       (let* (
          ((ContinuationCorrection (CorrectionTarget $_ $_ $plan $step $_) $_ $path) $correction)
          ($command (cons-atom read-file (cons-atom $path ())))
          ($steps (cons-atom (ExecutionStep $step $command) ()))
          ($admission (hostAdmitContinuation $plan $steps))
       )
          (case $admission (
             ((ContinuationAdmitted $plan ($resolved))
              (ContinuationCorrectionAdmitted $correction $resolved))
             ($_ $admission))))))))

;; Example: an explicit recorded correction resumes before normal capture issues its ticket.
;; F4.5 revalidates under the host lock; absent or rejected corrections never execute.
(= (prepareAutomaticContinuationResume)
   (case (hostContinuationCorrection) (
      (NoContinuationCorrection (ContinuationSkipped NoCorrection))
      ($correction
       (let $admission (hostAdmitCorrection $correction)
          (case $admission (
             ((ContinuationCorrectionAdmitted $_ $_) (hostResumeContinuation $admission))
             ($_ $admission))))))))

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
