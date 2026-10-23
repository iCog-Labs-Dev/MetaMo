;; Trusted host lifecycle, not motivational planning or a model skill.
;; One bounded read plan at a time, installed only at a guarded host safe point.
;; Failed, blocked, uncertain or displaced work stays held for host review.
(= (continuationId $id)
   (if (tpId $id) (<= (string_length $id) 256) False))

(= (continuationCommandFields $command)
   (if (== (size-atom $command) 2)
       (and (== (index-atom $command 0) read-file)
            (continuationId (index-atom $command 1))) False))

(= (continuationCommand $command)
   (if (== (get-metatype $command) Expression)
       (continuationCommandFields $command) False))

(= (continuationStepValid $step $seen)
   (case $step (
      ((ExecutionStep $id $command)
       (tpAllTrue ((continuationId $id) (not (tpContains $seen $id))
                   (continuationCommand $command))))
      ($_ False))))

(= (continuationStepsValid $steps $left $seen)
   (case $steps (
      (() True)
      ($_ (if (and (> $left 0) (== (get-metatype $steps) Expression))
              (let ($head $tail) (decons-atom $steps)
                 (if (continuationStepValid $head $seen)
                     (let (ExecutionStep $id $_) $head
                        (continuationStepsValid $tail (- $left 1) (cons-atom $id $seen)))
                     False))
              False)))))

(= (continuationPlanValid $id $steps)
   (if (is-ground ($id $steps))
       (tpAllTrue ((continuationId $id) (!= $steps ())
                   (continuationStepsValid $steps 16 ()))) False))

;; Example: (hostPrepareContinuation "plan" (quote ((ExecutionStep "1" (read-file "a.txt")))))
;; validates data only; the prepared result grants no catalog or dispatch authority.
(= (hostPrepareContinuation $id $steps)
   (case (continuationPlanValid $id $steps) (
      (True (ContinuationPrepared $id $steps))
      ($_ (ContinuationRejected InvalidPlan)))))

(= (continuationInstall $session $id $steps $commitment)
   (case $commitment (
      ((CommitmentSnapshot $owner $frame $revision Open $_)
       (if (== $frame (get-state &cfv2-current-frame-id))
           (progn
              (change-state! &host-continuation
                 (HostContinuation $session $owner $frame $revision $id Ready $steps))
              (change-state! &continuation-evidence
                 (ContinuationEvidence $session $commitment $id $steps ()))
              (change-state! &continuation-recovery NoContinuationRecovery)
              ;; Fence the previous task's retained observation without deleting its evidence.
              (change-state! &continuation-applied-decision
                 (case (get-state &last-operation-outcome) (
                    ((OperationOutcome $decision $_ $_ $_) $decision)
                    ($_ ()))))
              (change-state! &task-continuation-view NoContinuation)
              (ContinuationStarted $id))
           (ContinuationRejected WrongFrame)))
      ($_ (ContinuationRejected MissingCommitment)))))

(= (continuationStartInSession $id $steps)
   (case (get-state &operation-context) (
      ((OperationContext $session $cycle $frame)
       (if (tpAllTrue ((continuationId $session) (tpQuantity $cycle)
                      (or (== $cycle 0) (== $frame (get-state &cfv2-current-frame-id)))))
           (continuationInstallAtSafePoint $session $id $steps (commitmentSnapshot))
           (ContinuationRejected SessionAlreadyActive)))
      ($_ (ContinuationRejected SessionAlreadyActive)))))

;; Example: only the host's accepted terminal event releases a predecessor plan.
(= (continuationTerminalEvent $owner $revision $event)
   (case $event (
      ((CommitmentEvent $_ $eventOwner $eventRevision $change)
       (tpAllTrue ((== $owner $eventOwner) (== $revision $eventRevision)
          (tpContains (Completed Abandoned Superseded) (car-atom $change)))))
      ($_ False))))

;; Example: a Held plan with an open owner remains live; a terminal predecessor can retire.
(= (continuationSlotAvailable $session $commitment)
   (case (get-state &host-continuation) (
      (() True)
      ((HostContinuation $oldSession $owner $_ $revision $_ $_ $_)
       (case $commitment (
          ((CommitmentSnapshot $current $_ $_ Open $_)
           (tpAllTrue ((== $session $oldSession) (!= $owner $current)
              (!= (filter-atom (commitmentEvents) $event
                     (continuationTerminalEvent $owner $revision $event)) ()))))
          ($_ False))))
      ($_ False))))

;; Example: a later task installs only after selection clears and its predecessor terminates.
(= (continuationInstallAtSafePoint $session $id $steps $commitment)
   (if (tpAllTrue ((== (get-state &selected-operation-decision) ())
                  (== (get-state &selected-host-operation) ())
                  (continuationSlotAvailable $session $commitment)))
       (continuationInstall $session $id $steps $commitment)
       (ContinuationRejected AlreadyStarted)))

;; Example: guard and installation run together under the existing Core dispatch lock.
(= (hostBeginContinuation $id $steps)
   (case (continuationPlanValid $id $steps) (
      (False (ContinuationRejected InvalidPlan))
      (True (sread (py-call (host_operations.begin_continuation $id (repr $steps))))))))

(= (continuationSessionMatches $session)
   (case (get-state &operation-context) (
      ((OperationContext $current $_ $_) (== $session $current))
      ($_ False))))

(= (continuationCommitmentMatches $owner $frame $revision)
   (case (commitmentSnapshot) (
      ((CommitmentSnapshot $id $origin $rev Open $_)
       (== ($id $origin $rev) ($owner $frame $revision)))
      ($_ False))))

(= (continuationOwnerCurrent $session $owner $frame $revision)
   (tpAllTrue ((== $frame (get-state &cfv2-current-frame-id))
      (continuationSessionMatches $session)
      (continuationCommitmentMatches $owner $frame $revision))))

;; Only already-validated, freshly consumed feedback can advance this cursor.
(= (continuationDecisionMatches $session $frame $steps $decision)
   (case $decision (
      ;; No admitted command is a blocked attempt for the pending plan, not
      ;; permission to retry it automatically on a later cycle.
      ((OperationDecision (OperationContext $originSession $_ $originFrame)
          none () (DispatchUnavailable MissingDecision))
       (== ($session $frame) ($originSession $originFrame)))
      ((OperationDecision (OperationContext $originSession $_ $originFrame) execute-skill $command $_)
       (let (ExecutionStep $_ $expected) (car-atom $steps)
          (== ($session $frame $expected) ($originSession $originFrame $command))))
      ($_ False))))

;; Example: consume each successful read once, retaining its actual outcome for an answer.
;; Keep original steps separate from the shrinking cursor; later collectors can interpret outcomes.
(= (continuationRetainOutcome)
   (case (get-state &continuation-evidence) (
      ((ContinuationEvidence $session $owner $id $steps $outcomes)
       (change-state! &continuation-evidence
          (ContinuationEvidence $session $owner $id $steps
             (cons-atom (get-state &last-operation-outcome) $outcomes))))
      ($_ False))))

;; Example: FileUnavailable needs input; it does not establish why the file is unavailable.
;; Only typed host outcomes classify recovery. Modes and free-form error text do not.
(= (continuationReadRecoveryNeed $result)
   (case $result (
      ((DispatchResult Executed $_ (Error read-file FileUnavailable))
       (ReadRecoveryNeed MissingInput FileUnavailable))
      ((DispatchResult Blocked PermissionDenied $_)
       (ReadRecoveryNeed PermissionDenied PermissionDenied))
      ((DispatchResult Executed $_ (Error $_ $reason))
       (ReadRecoveryNeed DefiniteFailure $reason))
      ((DispatchResult Blocked $reason $_)
       (ReadRecoveryNeed DefiniteFailure $reason))
      ((DispatchResult Unobserved $reason $_)
       (ReadRecoveryNeed Uncertainty $reason))
      ($_ (ReadRecoveryNeed Uncertainty UnknownOutcome)))))

;; Example: a canonical no-action result can retain the exact pending read's typed denial.
;; Candidate admission runs later in composition; defer this read until the host cycle.
(= (continuationRecoveryNeed $observation)
   (case $observation (
      ((OperationOutcome
          (OperationDecision $_ none () (DispatchUnavailable MissingDecision)) $_ Blocked
          (DispatchResult Blocked MissingDecision none))
       (if (tpContains (eval (candidateRejections))
               (CandidateRejection execute-skill PermissionDenied))
           (ReadRecoveryNeed PermissionDenied (CandidateRejection execute-skill PermissionDenied))
           (ReadRecoveryNeed DefiniteFailure MissingDecision)))
      ((OperationOutcome $_ $_ $_ $result) (continuationReadRecoveryNeed $result))
      ($_ (ReadRecoveryNeed Uncertainty UnknownOutcome)))))

;; Example: retain the failed second read with its owner and step, preserving first-read evidence.
;; Called only after the existing consumed-decision checks; unrelated observations cannot attach.
(= (continuationRetainRecovery $steps $observation)
   (case ((get-state &host-continuation) $observation) (
      (((HostContinuation $session $owner $frame $revision $id Ready $steps)
        (OperationOutcome $decision $_ $_ $result))
       (if (tpAllTrue ((continuationOwnerCurrent $session $owner $frame $revision)
                      (continuationDecisionMatches $session $frame $steps $decision)))
           (let (ExecutionStep $step $_command) (car-atom $steps)
              (change-state! &continuation-recovery
                 (HeldReadRecovery $session $owner $frame $revision $id $step
                    (continuationRecoveryNeed $observation) $observation)))
           False))
      ($_ False))))

;; Example: an old owner's retained diagnostic is not recovery evidence for a successor.
(= (hostContinuationRecovery)
   (case ((get-state &host-continuation) (get-state &continuation-recovery)) (
      (((HostContinuation $session $owner $frame $revision $id Held $steps)
        (HeldReadRecovery $session $owner $frame $revision $id $step $need $observation))
       (if (and (continuationOwnerCurrent $session $owner $frame $revision)
                (== $step (index-atom (car-atom $steps) 1)))
           (HeldReadRecovery $session $owner $frame $revision $id $step $need $observation)
           NoContinuationRecovery))
      ($_ NoContinuationRecovery))))

(= (continuationApplyStatus $decision $outcome $steps)
   (let $_ (change-state! &continuation-applied-decision $decision)
      (case $outcome (
         (Success
          (let* (($_ (continuationRetainOutcome)) ($tail (cdr-atom $steps)))
             ((if (== $tail ()) AwaitingCompletion Ready) $tail)))
         ($_ (Held $steps))))))

(= (continuationConsume $session $frame $steps $observation)
   (case $observation (
      ((OperationOutcome $decision $_ $outcome $_)
       (if (tpAllTrue ((== $decision (get-state &applied-operation-decision))
                       (!= $decision (get-state &continuation-applied-decision))
                       (continuationDecisionMatches $session $frame $steps $decision)))
           (progn
              (if (== $outcome Success) True
                  (continuationRetainRecovery $steps $observation))
              (continuationApplyStatus $decision $outcome $steps))
           (Ready $steps)))
      ($_ (Ready $steps)))))

(= (continuationNext $session $frame $status $steps)
   (if (and (== $status Ready) (!= $steps ()))
       (continuationConsume $session $frame $steps (get-state &last-operation-outcome))
       ($status $steps)))

(= (continuationView $id $status $steps)
   (if (and (== $status Ready) (!= $steps ()))
       (let (ExecutionStep $step $command) (car-atom $steps)
          (ContinuationView $id $step Ready (repr $command)))
       (ContinuationView $id None $status ())))

(= (hostRefreshContinuation)
   (case (get-state &host-continuation) (
      ((HostContinuation $session $owner $frame $revision $id $status $steps)
       (let* (
          (($nextStatus $nextSteps)
             (if (continuationOwnerCurrent $session $owner $frame $revision)
                 (continuationNext $session $frame $status $steps)
                 (Held $steps)))
          ($_ (change-state! &host-continuation
                 (HostContinuation $session $owner $frame $revision $id $nextStatus $nextSteps))))
          (change-state! &task-continuation-view (continuationView $id $nextStatus $nextSteps))))
      ($_ (change-state! &task-continuation-view NoContinuation)))))
