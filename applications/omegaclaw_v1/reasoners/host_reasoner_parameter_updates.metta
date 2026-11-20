;; Optional application adaptation. Derivation belongs to an explicitly configured learner.
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_trace))
(: HostReasonerParameterLearnerType Type)
(: HostReasonerParameterLearner (-> String String String Symbol HostReasonerParameterLearnerType))
(: HostReasonerParameterChangeType Type)
(: HostReasonerParameterChange (-> Expression Number Number String HostReasonerParameterChangeType))
(: HostReasonerParameterEditType Type)
(: HostReasonerParameterEdit (-> Expression Expression Expression HostReasonerParameterEditType))
(: HostReasonerParameterValueType Type)
(: HostReasonerParameterValue (-> Expression Expression HostReasonerParameterValueType))
(: HostReasonerParameterBatchType Type)
(: HostReasonerParameterBatch
    (-> Expression Expression Expression Expression Symbol Expression HostReasonerParameterBatchType))
(: ParameterUpdateResultType Type)
(: ParameterUpdateRejected (-> Symbol ParameterUpdateResultType))
(: ParameterUpdateDeferred (-> Symbol ParameterUpdateResultType))
!(bind! &host-reasoner-parameter-learners (new-state ()))
!(bind! &host-reasoner-parameter-batches (new-state ()))

;; Return the single trusted derivation rule bound to this adapter configuration.
;; Example: an unconfigured adapter cannot derive updates from prediction accuracy alone.
(= (hostReasonerParameterLearnerFor $adapter $configuration)
    (let $rows (filter-atom (get-state &host-reasoner-parameter-learners) $row
        (and (== (index-atom $row 1) $adapter) (== (index-atom $row 2) $configuration)))
        (if (== (size-atom $rows) 1) (car-atom $rows) ()))
)

;; Configure before intake; no built-in rule guesses motivational parameters from grades.
;; Example: (configureHostReasonerParameterLearner "adapter" "calibration-v1" deriveChanges).
(= (configureHostReasonerParameterLearner $adapter $version $function)
    (case (registeredHostReasoner $adapter) (
        ((HostReasonerAdapter $registration $_)
            (if (and (mrcText $version) (!= (collapse (translatePredicate (atom $function))) ()))
                (let* (
                    ($configuration (mrcValue $registration 3))
                    ($binding (quote (HostReasonerParameterLearner $adapter $configuration $version $function)))
                    ($old (hostReasonerParameterLearnerFor $adapter $configuration))
                    ($invoked (filter-atom (hostReasonerCycles) $row
                        (== (mrcValue (index-atom $row 2) 2) $adapter)))
                )
                    (if (== $old $binding) True
                        (if (!= $invoked ()) (ParameterUpdateRejected AlreadyInvoked)
                            (progn (change-state! &host-reasoner-parameter-learners
                                (cons-atom $binding (filter-atom (get-state &host-reasoner-parameter-learners) $r
                                    (!= $r $old))))
                                (change-state! &host-reasoner-parameter-boundary applyHostReasonerParameterUpdates) True))))
                (ParameterUpdateRejected InvalidLearner)))
        ($_ (ParameterUpdateRejected InvalidLearner))))
)

;; Expose the bounded adaptation audit independently of source reliability/native truth.
;; Example: a pending batch records its assessment identity, rule version and old/new rows.
(= (hostReasonerParameterBatches) (get-state &host-reasoner-parameter-batches))

;; Read exact mutable rows only; unsupported keys never become executable expressions.
;; Example: (hostReasonerParameterRows (ModeThreshold threat danger classifier-score Enter))
;; returns data, but cannot pass the writable whitelist.
(= (hostReasonerParameterRows $key)
    (case $key (
        ((AppraisalWeight $signal $dimension $transform)
            (collapse (match &self (SignalAppraisalRule $signal $dimension $transform $value)
                (SignalAppraisalRule $signal $dimension $transform $value))))
        ((ModeThreshold $group $signal $unit Enter)
            (collapse (match &self (ModeRatioTrigger $group $signal $unit $enter $exit)
                (ModeRatioTrigger $group $signal $unit $enter $exit))))
        ($_ ())))
)

;; Extract the value represented by a permitted row.
;; Example: mode entry changes leave the existing exit threshold intact.
(= (hostReasonerParameterValue $row)
    (case $row (
        ((SignalAppraisalRule $_ $_ $_ $value) $value)
        ((ModeRatioTrigger $_ $_ $_ $enter $_) $enter)
        ($_ NoParameter))))

;; Make a replacement as data; no callback runs during registry mutation.
;; Example: replacing an appraisal coefficient cannot change its signal or transform.
(= (hostReasonerParameterReplacement $row $value)
    (case $row (
        ((SignalAppraisalRule $s $d $t $_) (SignalAppraisalRule $s $d $t $value))
        ((ModeRatioTrigger $g $s $u $_ $exit) (ModeRatioTrigger $g $s $u $value $exit)))))

;; Validate whitelist, finite values, expected old value, step bound and justification.
;; Example: a valid grade does not permit editing scheduling priorities or safety rules.
(= (validateHostReasonerParameterChange $change)
    (case $change (
        ((HostReasonerParameterChange $key $before $after $reason)
            (case (collapse (match &self (LearnableParameter $key $min $max $step) ($min $max $step))) (
                ((($min $max $step))
                    (if (and (and (fsNumberIn $before $min $max) (fsNumberIn $after $min $max))
                            (reasonerProposalTextValid $reason 256))
                        (if (<= (abs-math (- $after $before)) (+ $step 0.000000000001))
                            (validateHostReasonerParameterRow $change $key $before $after)
                            (ParameterUpdateRejected StepLimit))
                        (ParameterUpdateRejected InvalidValue)))
                ($_ (ParameterUpdateRejected NotWritable)))))
        ($_ (ParameterUpdateRejected InvalidChange))))
)

;; Revalidate the current unique row; record the full original for later stale checks.
;; Example: a changed exit threshold or coefficient invalidates an earlier queued edit.
(= (validateHostReasonerParameterRow $change $key $before $after)
    (case (hostReasonerParameterRows $key) (
        (($row) (if (== (hostReasonerParameterValue $row) $before)
            (let $replacement (hostReasonerParameterReplacement $row $after)
                (quote (HostReasonerParameterEdit $change $row $replacement)))
            (ParameterUpdateRejected StaleParameter)))
        ($_ (ParameterUpdateRejected MissingParameter))))
)

;; Resolve grades by immutable identity; preview/reliability/native feedback are separate.
;; Example: (deriveHostReasonerParameterUpdates OUTCOME-REF) queues only with learning enabled.
(= (deriveHostReasonerParameterUpdates $id)
    (let $assessments (filter-atom (hostReasonerAssessments) $row (== (index-atom $row 1) $id))
        (case $assessments (
            (($assessment) (let* (
                ($invocation (mrcValue (index-atom $assessment 2) 2))
                ($adapter (mrcValue $invocation 2))
                ($learner (hostReasonerParameterLearnerFor $adapter (mrcValue $invocation 4)))
            )
                (if (hostReasonerStageEnabledFor $adapter learning)
                    (case $learner (
                        ((HostReasonerParameterLearner $_ $_ $_ $_)
                            (collectHostReasonerParameterChanges $id $assessment $invocation $learner))
                        ($_ (ParameterUpdateDeferred NoLearner))))
                    (ParameterUpdateDeferred LearningDisabled))))
            ($_ (ParameterUpdateDeferred MissingAssessment)))))
)

;; The configured learner receives a retained grade and current whitelisted rows as data.
;; Example: identical successful derivation skips the callback and returns the existing batch.
(= (collectHostReasonerParameterChanges $id $assessment $invocation $learner)
    (let $prior (filter-atom (hostReasonerParameterBatches) $row (== (index-atom $row 1) $id))
        (case $prior (
            (($batch) $batch)
            (() (let* (
                ($keys (collapse (match &self (LearnableParameter $key $_ $_ $_) $key)))
                ($parameters (map-atom $keys $key
                    (let $rows (hostReasonerParameterRows $key)
                        (quote (HostReasonerParameterValue $key $rows)))))
                ($changes (reasonerRuntimeCall (mrcValue (mrcValue $invocation 12) 9)
                    (index-atom $learner 4) ($assessment $parameters)))
            ) (queueHostReasonerParameterChanges $id $invocation $learner $changes)))
            ($_ (ParameterUpdateRejected ConflictingReplay)))))
)

;; Validate the whole batch before queueing, with one pending change per key.
;; Example: one invalid or duplicate key rejects all changes without partial application.
(= (queueHostReasonerParameterChanges $id $invocation $learner $changes)
    (if (== $changes ()) (ParameterUpdateDeferred NoChanges)
        (validateHostReasonerParameterChanges $id $invocation $learner $changes))
)

;; Validate shape before accessing keys, so callback failures remain explicit rejections.
;; Example: a timed-out learner cannot create malformed queue records.
(= (validateHostReasonerParameterChanges $id $invocation $learner $changes)
    (if (and (== (get-metatype $changes) Expression)
            (>= (reasonerProposalDataRemaining (quote $changes) 16 (mrcValue (mrcValue $invocation 12) 2)) 0))
        (let* (
            ($edits (map-atom $changes $change (validateHostReasonerParameterChange $change)))
            ($valid (== (filter-atom $edits $edit (!= (car-atom $edit) HostReasonerParameterEdit)) ()))
        )
            (if $valid
                (let $keys (map-atom $changes $change (index-atom $change 1))
                    (if (== (size-atom $keys) (size-atom (hostReasonerDistinctReferences $keys)))
                        (retainHostReasonerParameterBatch $id $invocation $learner $edits $keys)
                        (ParameterUpdateRejected InvalidChanges)))
                (ParameterUpdateRejected InvalidChanges)))
        (ParameterUpdateRejected InvalidChanges))
)

;; Queue immutable evidence with bounds; conflicting pending edits cannot stack deltas.
;; Example: queued coefficients remain unchanged until a later native cycle begins.
(= (retainHostReasonerParameterBatch $id $invocation $learner $edits $keys)
    (with_mutex omegaclaw_dispatch
        (let* (
            ($prior (filter-atom (hostReasonerParameterBatches) $row (== (index-atom $row 1) $id)))
            ($pending (filter-atom (hostReasonerParameterBatches) $row (== (index-atom $row 5) Pending)))
            ($busy (filter-atom $pending $row
                (!= (filter-atom (index-atom $row 4) $edit
                    (tpContains $keys (index-atom (index-atom $edit 1) 1))) ())))
            ($context (get-state &operation-context))
            ($batch (quote (HostReasonerParameterBatch $id $learner $context $edits Pending ())))
            ($limits (mrcValue $invocation 12))
        )
            (case $prior (
                (($existing) $existing)
                (() (if (and (== $busy ())
                    (and (< (size-atom (hostReasonerParameterBatches)) (mrcValue $limits 4))
                        (>= (reasonerProposalDataRemaining (quote $batch) 32 (* 2 (mrcValue $limits 2))) 0)))
                (appendHostReasonerParameterBatch $batch)
                    (ParameterUpdateRejected PendingConflictOrLimit)))
                ($_ (ParameterUpdateRejected ConflictingReplay))))))
)

;; Keep record construction separate from rejection results in PeTTa's compiler.
;; Example: appending a validated batch returns exactly that immutable batch.
(= (appendHostReasonerParameterBatch $batch)
    (progn (change-state! &host-reasoner-parameter-batches
        (cons-atom $batch (hostReasonerParameterBatches)))
        (collapse (catch (recordHostReasonerParameterTrace $batch))) $batch))

;; Only the current native cycle before mode evaluation can apply pending changes.
;; Example: calling again later in the same cycle cannot revise an in-flight decision.
(= (applyHostReasonerParameterUpdates $context)
    (if (and (== $context (get-state &operation-context))
            (not (hostReasonerModeAlreadyObserved $context)))
        (map-atom (filter-atom (hostReasonerParameterBatches) $row (== (index-atom $row 5) Pending))
            $batch (applyHostReasonerParameterBatch $batch $context))
        (ParameterUpdateRejected LateBoundary))
)

;; A different session rejects old pending edits; the queueing cycle cannot consume them.
;; Example: session S cycle 4 consumes updates queued in S cycle 3, never cycle 3 itself.
(= (applyHostReasonerParameterBatch $batch $context)
    (case ($context (index-atom $batch 3)) (
        (((OperationContext $session $cycle $_) (OperationContext $origin $queued $_))
            (if (!= $session $origin)
                (setHostReasonerParameterBatchStatus $batch StaleSession $context)
                (if (> $cycle $queued)
                    (with_mutex omegaclaw_dispatch
                        (transaction (commitHostReasonerParameterBatch $batch $context))) True)))
        ($_ (ParameterUpdateRejected MissingCycle))))
)

;; Recheck every original row and current whitelist before atomically changing the registry.
;; Example: one stale edit rejects the whole batch and leaves every other parameter intact.
(= (commitHostReasonerParameterBatch $batch $context)
    (let* (
        ($edits (index-atom $batch 4))
        ($invalid (filter-atom $edits $edit
            (!= (validateHostReasonerParameterChange (index-atom $edit 1)) $edit)))
    )
        (if (tpContains (hostReasonerParameterBatches) $batch)
            (if (and (== $invalid ())
                    (hostReasonerStageEnabledFor (index-atom (index-atom $batch 2) 1) learning))
                (progn (map-atom $edits $edit (writeHostReasonerParameterEdit $edit))
                    (setHostReasonerParameterBatchStatus $batch Applied $context))
                (setHostReasonerParameterBatchStatus $batch StaleParameter $context)) True))
)

;; Registry mutation has no evaluator, source-reliability update or engine-learning call.
;; Example: replacing a permitted coefficient cannot change scheduling or dispatch policy.
(= (writeHostReasonerParameterEdit $edit)
    (let (HostReasonerParameterEdit $_ $before $after) $edit
        (progn (remove-atom &self $before) (add-atom &self $after) True)))

;; Retain final status and application context beside the original assessment and rule version.
;; Example: an applied batch remains auditable and cannot be applied on the following cycle.
(= (setHostReasonerParameterBatchStatus $batch $status $context)
    (let (HostReasonerParameterBatch $id $learner $queued $edits $_ $_) $batch
        (let $updated (quote (HostReasonerParameterBatch $id $learner $queued $edits $status $context))
        (progn (change-state! &host-reasoner-parameter-batches
            (map-atom (hostReasonerParameterBatches) $old
                (if (== $old $batch)
                    $updated $old)))
            (if (tpContains (hostReasonerParameterBatches) $updated)
                (collapse (catch (recordHostReasonerParameterTrace $updated))) True) True)))
)
