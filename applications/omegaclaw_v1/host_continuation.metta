;; Trusted host lifecycle, not motivational planning or a model skill.
;; One bounded read plan at a time, installed only at a guarded host safe point.
;; Failed, blocked, uncertain or displaced work stays held for host review.
!(bind! &continuation-plan-revision (new-state 0))
!(bind! &continuation-correction (new-state NoContinuationCorrection))
!(bind! &continuation-retries (new-state NoContinuationRetries))

;; Example: zero disables retries; the trusted per-plan limit is bounded to 16.
(= (continuationRetryLimitValid $limit)
   (if (tpQuantity $limit)
       (and (== $limit (floor-math $limit)) (<= $limit 16)) False))

;; Example: exactly one (ContinuationRetryPolicy 2) row permits two resumed attempts per step.
(= (continuationRetryPolicy)
   (case (collapse (match &self (ContinuationRetryPolicy $limit) $limit)) (
      (($limit) (if (continuationRetryLimitValid $limit)
          (ContinuationRetryPolicy $limit) (ContinuationRejected InvalidRetryPolicy)))
      ($_ (ContinuationRejected InvalidRetryPolicy)))))

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

;; Example: a successor plan receives independent counters under its exact commitment owner.
(= (continuationInstallWithRetries $session $id $steps $commitment $limit)
   (case $commitment (
      ((CommitmentSnapshot $owner $frame $revision Open $_)
       (if (== $frame (get-state &cfv2-current-frame-id))
           (progn
              (change-state! &host-continuation
                 (HostContinuation $session $owner $frame $revision $id Ready $steps))
              (change-state! &continuation-evidence
                 (ContinuationEvidence $session $commitment $id $steps ()))
              (change-state! &continuation-recovery NoContinuationRecovery)
              (change-state! &continuation-plan-revision 0)
              (change-state! &continuation-correction NoContinuationCorrection)
              (change-state! &continuation-retries
                 (ContinuationRetries $session $commitment $id $limit
                    (map-atom $steps $step (StepRetries (index-atom $step 1) 0))))
              (change-state! &continuation-clarification NoClarificationObservation)
              ;; Fence the previous task's retained observation without deleting its evidence.
              (change-state! &continuation-applied-decision
                 (case (get-state &last-operation-outcome) (
                    ((OperationOutcome $decision $_ $_ $_) $decision)
                    ($_ ()))))
              (change-state! &task-continuation-view NoContinuation)
              (ContinuationStarted $id))
           (ContinuationRejected WrongFrame)))
      ($_ (ContinuationRejected MissingCommitment)))))

(= (continuationInstall $session $id $steps $commitment)
   (case (continuationRetryPolicy) (
      ((ContinuationRetryPolicy $limit)
       (continuationInstallWithRetries $session $id $steps $commitment $limit))
      ($rejection $rejection))))

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

;; Example: the host supplies this target with a missing-file question.
;; The session/owner prevent an old reply attaching to a reused plan or step ID.
(= (hostCorrectionTarget)
   (case (hostContinuationRecovery) (
      ((HeldReadRecovery $session $owner $_ $_ $plan $step
          (ReadRecoveryNeed MissingInput $_) $_)
       (CorrectionTarget $session $owner $plan $step
          (get-state &continuation-plan-revision)))
      ($_ NoCorrectionTarget))))

;; Example: correlation retains a proposed path as inert data, leaving the cursor held.
;; Called by trusted ingress under Core's dispatch mutex, never by model dispatch.
(= (hostCorrelateCorrection $target $path)
   (case (and (!= $target NoCorrectionTarget) (== $target (hostCorrectionTarget))) (
      (False (HostInput Held StaleCorrection))
      (True
       (let $proposal (ContinuationCorrection $target (hostContinuationRecovery) $path)
          (case (get-state &continuation-correction) (
             (NoContinuationCorrection
              (progn
                 (change-state! &continuation-correction $proposal)
                 (HostInput CorrectionRecorded $target)))
             ($proposal (HostInput CorrectionRecorded $target))
             ($_ (HostInput Held CorrectionAlreadyPending)))))))))

;; Example: replacement, session reset, or a changed held step hides stale proposals.
(= (hostContinuationCorrection)
   (case (get-state &continuation-correction) (
      ((ContinuationCorrection $target $recovery $path)
       (if (and (== $target (hostCorrectionTarget))
                (== $recovery (hostContinuationRecovery)))
           (ContinuationCorrection $target $recovery $path)
           NoContinuationCorrection))
      ($_ NoContinuationCorrection))))

 ;; Example: replace only step "2", preserving completed steps and later pending reads.
(= (continuationCorrectSteps $steps $replacement)
   (map-atom $steps $step
      (if (== (index-atom $step 1) (index-atom $replacement 1)) $replacement $step)))

;; Example: a correction cannot duplicate another required file or change completed evidence.
;; Preparation performs every check before the first write; callers hold Core's mutex.
(= (continuationPrepareCorrectedPlan $plan $evidence $replacement)
   (case ($plan $evidence) (
      (((HostContinuation $session $owner $frame $ownerRevision $id Held $pending)
        (ContinuationEvidence $session $commitment $id $all $outcomes))
       (let* (
          ($updated (continuationCorrectSteps $all $replacement))
          ($remaining (cons-atom $replacement (cdr-atom $pending)))
          ($valid (tpAllTrue ((== $commitment (commitmentSnapshot))
             (== (index-atom (car-atom $pending) 1) (index-atom $replacement 1))
             (tpContains $all (car-atom $pending))
             (continuationPlanValid $id $updated)
             (tpList ids (map-atom $updated $step (index-atom (index-atom $step 2) 1))))))
       )
          (if $valid
              (ContinuationResumePrepared
                 (HostContinuation $session $owner $frame $ownerRevision $id Ready $remaining)
                 (ContinuationEvidence $session $commitment $id $updated $outcomes)
                 (+ (get-state &continuation-plan-revision) 1))
              (ContinuationRejected InvalidPlan))))
      ($_ (ContinuationRejected InvalidResumeState)))))

;; Example: revision 0 advances to 1; malformed or exhausted revisions cannot wrap.
(= (continuationResumeRevision $revision)
   (if (if (tpQuantity $revision) (== $revision (floor-math $revision)) False)
       (if (< $revision 9007199254740991)
           (ContinuationRevision (+ $revision 1))
           (ContinuationRejected RevisionExhausted))
       (ContinuationRejected InvalidPlanRevision)))

;; Example: missing, duplicate or malformed stored counters cannot silently become zero.
(= (continuationRetryRowValid $row $limit)
   (case $row (
      ((StepRetries $step $count)
       (if (tpQuantity $count)
           (tpAllTrue ((continuationId $step) (== $count (floor-math $count)) (<= $count $limit)))
           False))
      ($_ False))))

;; Example: corrections preserve the ordered step IDs and original per-plan retry limit.
(= (continuationRetryStateValid $state $plan $evidence)
   (case ($state $plan $evidence) (
      (((ContinuationRetries $session (CommitmentSnapshot $owner $frame $revision Open $summary) $id $limit $counts)
        (HostContinuation $session $owner $frame $revision $id Ready $_)
        (ContinuationEvidence $session (CommitmentSnapshot $owner $frame $revision Open $summary) $id $steps $_))
       (if (and (continuationRetryLimitValid $limit) (== (get-metatype $counts) Expression))
           (if (tpAllTrue ((== (CommitmentSnapshot $owner $frame $revision Open $summary) (commitmentSnapshot))
              (== (size-atom $counts) (size-atom $steps))
              (<= (size-atom $counts) 16)
              (tpAllTrue (map-atom $counts $row (continuationRetryRowValid $row $limit)))))
               (== (map-atom $counts $row (index-atom $row 1))
                   (map-atom $steps $step (index-atom $step 1))) False)
           False))
      ($_ False))))

;; Example: after two resumes under limit 2, retain the held step for host review.
(= (continuationIncrementRetry (ContinuationRetries $session $owner $id $limit $counts) $plan $evidence $revision)
   (let* (
      ($step (index-atom (car-atom (index-atom $plan 7)) 1))
      ($matched (car-atom (filter-atom $counts $candidate (== (index-atom $candidate 1) $step))))
      ($count (index-atom $matched 2))
   )
      (if (< $count $limit)
          (ContinuationResumePrepared $plan $evidence $revision
             (ContinuationRetries $session $owner $id $limit
                (map-atom $counts $entry
                   (if (== (index-atom $entry 1) $step) (StepRetries $step (+ $count 1)) $entry))))
          (ContinuationRejected RetryLimitExceeded))))

;; Example: only an accepted resume of step "2" increments step "2"; preparation never writes.
(= (continuationPrepareRetry $prepared)
   (case $prepared (
      ((ContinuationResumePrepared $plan $evidence $revision)
       (let $state (get-state &continuation-retries)
          (if (continuationRetryStateValid $state $plan $evidence)
              (continuationIncrementRetry $state $plan $evidence $revision)
              (ContinuationRejected InvalidRetryState))))
      ($rejection $rejection))))

;; Example: a selected command or exhausted revision leaves the held plan untouched.
(= (continuationPrepareResume $replacement)
   (case (continuationResumeRevision (get-state &continuation-plan-revision)) (
      ((ContinuationRevision $_)
       (if (and (== (get-state &selected-operation-decision) ())
                (== (get-state &selected-host-operation) ()))
           (continuationPrepareRetry
              (continuationPrepareCorrectedPlan (get-state &host-continuation)
                 (get-state &continuation-evidence) $replacement))
           (ContinuationRejected OutstandingInvocation)))
      ($rejection $rejection))))

;; Example: successful resume changes only pending work and fences all pre-resume feedback.
;; The locked bridge advances Core's epoch once after this transition succeeds.
(= (continuationApplyResume $plan $evidence $revision $retries)
   (let (HostContinuation $_ $_ $_ $_ $id Ready $pending) $plan
      (progn
         (change-state! &host-continuation $plan)
         (change-state! &continuation-evidence $evidence)
         (change-state! &continuation-plan-revision $revision)
         (change-state! &continuation-retries $retries)
         (change-state! &continuation-applied-decision
            (case (get-state &last-operation-outcome) (
               ((OperationOutcome $decision $_ $_ $_) $decision)
               ($_ ()))))
         (change-state! &continuation-recovery NoContinuationRecovery)
         (change-state! &continuation-correction NoContinuationCorrection)
         (change-state! &continuation-clarification NoClarificationObservation)
         (change-state! &selected-clarification-recovery NoClarificationSelection)
         (change-state! &prepared-host-operation ())
         (change-state! &selected-answer-key ())
         (change-state! &task-continuation-view NoContinuation)
         (ContinuationResumed $id (index-atom (car-atom $pending) 1) $revision))))

;; Example: a held missing input can ask once through the configured clarification binding.
;; The bundle identifies the held plan; exact owner and failure evidence remain host-owned.
(= (heldMissingInputForBundle $bundle)
   (case (hostContinuationRecovery) (
      ((HeldReadRecovery $_ $_ $frame $_ $plan $_ (ReadRecoveryNeed MissingInput $_) $_)
       (tpAllTrue ((frameRuntimeTaskOpen $bundle)
          (== $frame (frameBundleCurrentId $bundle))
          (== (frameRuntimeContinuation $bundle) (ContinuationView $plan None Held ())))))
      ($_ False))))

;; Example: a receipt for another plan cannot suppress this held step's question.
(= (clarificationObservedForRecovery $recovery)
   (case (get-state &continuation-clarification) (
      ((ClarificationObservation $recovery $_ $_) True)
      ($_ False))))

;; Example: an observed question attempt holds further sends until explicit recovery work.
(= (missingInputClarificationNeededForBundle $bundle)
   (and (heldMissingInputForBundle $bundle)
        (not (clarificationObservedForRecovery (hostContinuationRecovery)))))

;; Example: selection alone is not delivery; retain its exact recovery/decision association.
(= (retainClarificationSelection $candidate $bundle)
   (change-state! &selected-clarification-recovery
      (if (and (== $candidate ask-clarification)
               (missingInputClarificationNeededForBundle $bundle))
          (ClarificationSelection (hostContinuationRecovery)
             (get-state &selected-operation-decision))
          NoClarificationSelection)))

;; Example: one validated local Accepted or IRC Submitted outcome records the question once.
;; Blocked/uncertain attempts remain observed holds, not a reason to send again while idle.
(= (recordContinuationClarification $observation)
   (case ((get-state &selected-clarification-recovery) $observation) (
      (((ClarificationSelection $recovery $decision)
        (OperationOutcome $decision $_ $status $_))
       (if (and (== $recovery (hostContinuationRecovery))
                (not (clarificationObservedForRecovery $recovery)))
           (change-state! &continuation-clarification
              (ClarificationObservation $recovery
                 (if (== $status Success) Delivered Held) $observation))
           False))
      ($_ False))))

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
