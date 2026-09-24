;; Trusted host lifecycle, not motivational planning or a model skill.
;; One bounded read plan per session, installed before the first selection.
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

(= (continuationInstall $session $id $steps $commitment)
   (case $commitment (
      ((CommitmentSnapshot $owner $frame $revision Open $_)
       (if (== $frame (get-state &cfv2-current-frame-id))
           (progn
              (change-state! &host-continuation
                 (HostContinuation $session $owner $frame $revision $id Ready $steps))
              (ContinuationStarted $id))
           (ContinuationRejected WrongFrame)))
      ($_ (ContinuationRejected MissingCommitment)))))

(= (continuationStartInSession $id $steps)
   (case (get-state &operation-context) (
      ((OperationContext $session 0 $_)
       (continuationInstall $session $id $steps (commitmentSnapshot)))
      ($_ (ContinuationRejected SessionAlreadyActive)))))

(= (hostBeginContinuation $id $steps)
   (case (continuationPlanValid $id $steps) (
      (False (ContinuationRejected InvalidPlan))
      (True
       (if (and (== (get-state &host-continuation) ())
                (== (get-state &selected-operation-decision) ()))
           (continuationStartInSession $id $steps)
           (ContinuationRejected AlreadyStarted))))))

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

(= (continuationApplyStatus $decision $outcome $steps)
   (let $_ (change-state! &continuation-applied-decision $decision)
      (case $outcome (
         (Success
          (let $tail (cdr-atom $steps)
             ((if (== $tail ()) AwaitingCompletion Ready) $tail)))
         ($_ (Held $steps))))))

(= (continuationConsume $session $frame $steps $observation)
   (case $observation (
      ((OperationOutcome $decision $_ $outcome $_)
       (if (tpAllTrue ((== $decision (get-state &applied-operation-decision))
                       (!= $decision (get-state &continuation-applied-decision))
                       (continuationDecisionMatches $session $frame $steps $decision)))
           (continuationApplyStatus $decision $outcome $steps)
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
