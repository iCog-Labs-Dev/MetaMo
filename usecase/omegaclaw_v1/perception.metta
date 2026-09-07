(= (omegaClawListAppend () $right)
    $right)

(= (omegaClawListAppend $left $right)
    (let* (
        (($head $tail) (decons $left))
    )
        (cons-atom
            $head
            (omegaClawListAppend $tail $right))))

(= (omegaClawEvidencePresent $value)
    (not (== $value ())))

(= (omegaClawObservationHasResults $observation)
    (omegaClawEvidencePresent
        (omegaClawObservationField
            $observation previous-command-results)))

(= (omegaClawObservationHasErrors $observation)
    (omegaClawEvidencePresent
        (omegaClawObservationField $observation previous-errors)))

(= (omegaClawObservationTaskActive $observation)
    (case (omegaClawObservationField $observation task-status) (
        (active True)
        (open True)
        (blocked True)
        (ready True)
        (verifying True)
        (verified True)
        ($_ False)
    )))

(= (omegaClawAutonomyPhaseActive $phase)
    (case $phase (
        (plan True)
        (act True)
        (verify True)
        (integrate True)
        ($_ False)
    )))

(= (omegaClawObservationResourceMetric $observation $name $default)
    (featurePairsGet
        (omegaClawObservationField $observation resource-signals)
        $name
        $default))

(= (omegaClawRepeatedFailureObserved $observation)
    (and
        (omegaClawObservationHasErrors $observation)
        (> (omegaClawObservationResourceMetric
                $observation failure-streak 0.0)
           1.0)))

(= (omegaClawProgressObserved $observation)
    (and
        (not (omegaClawObservationHasErrors $observation))
        (or
            (> (omegaClawObservationResourceMetric
                    $observation task-progress 0.0)
               0.0)
            (> (omegaClawObservationResourceMetric
                    $observation evidence-quality 0.0)
               0.0))))

(= (omegaClawStalledProgressObserved $observation)
    (and
        (omegaClawObservationTaskActive $observation)
        (and
            (not (omegaClawObservationHasResults $observation))
            (not (omegaClawObservationHasErrors $observation)))))

(= (omegaClawMaybeDefaultSignal $condition $kind $source)
    (if $condition
        ((omegaClawDefaultSignal $kind $source))
        ()))

(= (omegaClawObservationLifecycleSignals $observation)
    (let* (
        ($wakeReason
            (omegaClawObservationField $observation wake-reason))
        ($autonomyPhase
            (omegaClawObservationField $observation autonomy-phase))
    )
        (omegaClawListAppend
            (omegaClawMaybeDefaultSignal
                (== $wakeReason scheduled-wake)
                scheduled-wake
                wake-reason)
            (omegaClawListAppend
                (omegaClawMaybeDefaultSignal
                    (and
                        (== $wakeReason continuation)
                        (omegaClawObservationTaskActive $observation))
                    continuation-due
                    wake-reason)
                (omegaClawListAppend
                    (omegaClawMaybeDefaultSignal
                        (omegaClawAutonomyPhaseActive $autonomyPhase)
                        active-goal
                        autonomy-state)
                    (omegaClawListAppend
                        (omegaClawMaybeDefaultSignal
                            (== $autonomyPhase invent)
                            goal-missing
                            autonomy-state)
                        (omegaClawListAppend
                            (omegaClawMaybeDefaultSignal
                                (== $autonomyPhase verify)
                                verification-needed
                                autonomy-state)
                            (omegaClawListAppend
                                (omegaClawMaybeDefaultSignal
                                    (== $autonomyPhase integrate)
                                    goal-complete
                                    autonomy-state)
                                (omegaClawMaybeDefaultSignal
                                    (> (omegaClawObservationResourceMetric
                                            $observation blocked-count 0.0)
                                       0.0)
                                    blocked-command
                                    command-boundary)))))))))

(= (omegaClawObservationEffectSignals $observation)
    (case (omegaClawObservationResourceMetric
                $observation effect-class none) (
        (reversible
            ((omegaClawDefaultSignal
                effect-reversible capability-policy)))
        (external
            ((omegaClawDefaultSignal
                effect-external capability-policy)))
        (destructive
            ((omegaClawDefaultSignal
                effect-destructive capability-policy)))
        ($_ ())
    )))

(= (omegaClawObservationStructuralSignals $observation)
    (omegaClawListAppend
        (omegaClawMaybeDefaultSignal
            (omegaClawObservationField $observation new-message)
            human-message
            observation)
        (omegaClawListAppend
            (omegaClawMaybeDefaultSignal
                (omegaClawObservationField $observation new-message)
                user-waiting
                observation)
            (omegaClawListAppend
                (omegaClawMaybeDefaultSignal
                    (not (omegaClawObservationField
                            $observation new-message))
                    autonomous-turn
                    observation)
                (omegaClawListAppend
                    (omegaClawMaybeDefaultSignal
                        (omegaClawObservationHasErrors $observation)
                        failure
                        previous-errors)
                    (omegaClawListAppend
                        (omegaClawMaybeDefaultSignal
                            (omegaClawRepeatedFailureObserved $observation)
                            repeated-failure
                            failure-streak)
                        (omegaClawListAppend
                            (omegaClawMaybeDefaultSignal
                                (omegaClawProgressObserved $observation)
                                progress-made
                                previous-results)
                            (omegaClawListAppend
                                (omegaClawMaybeDefaultSignal
                                    (omegaClawStalledProgressObserved
                                        $observation)
                                    stalled-progress
                                    task-state)
                                (omegaClawListAppend
                                    (omegaClawMaybeDefaultSignal
                                        (<= (omegaClawObservationField
                                                $observation loop-budget)
                                            1)
                                        budget-low
                                        loop-budget)
                                    (omegaClawListAppend
                                        (omegaClawMaybeDefaultSignal
                                            (> (omegaClawObservationResourceMetric
                                                    $observation
                                                    proposal-repeated 0.0)
                                               0.0)
                                            proposal-repeated
                                            proposal-fingerprint)
                                        (omegaClawListAppend
                                            (omegaClawMaybeDefaultSignal
                                                (> (omegaClawObservationResourceMetric
                                                        $observation
                                                        task-execution-authorized
                                                        0.0)
                                                   0.0)
                                                task-execution-authorized
                                                task-state)
                                            (omegaClawObservationEffectSignals
                                                $observation))))))))))))

(= (omegaClawObservationSemanticSignals $observation)
    (omegaClawObservationField $observation semantic-signals))

(= (omegaClawObservationHasOutcomeEvidence $observation)
    (or
        (omegaClawObservationHasResults $observation)
        (or
            (omegaClawObservationHasErrors $observation)
            (> (omegaClawObservationResourceMetric
                    $observation blocked-count 0.0)
               0.0))))

(= (omegaClawObservationSuccessCount $observation)
    (if (omegaClawProgressObserved $observation)
        1.0
        0.0))

(= (omegaClawObservationFailureCount $observation)
    (if (omegaClawObservationHasErrors $observation)
        1.0
        0.0))

(= (omegaClawOutcomeFromObservation $observation)
    (if (omegaClawObservationHasOutcomeEvidence $observation)
        (omegaClawOutcome
            (omegaClawObservationField $observation turn-id)
            (omegaClawObservationField $observation previous-action)
            (unknown)
            (unknown)
            (omegaClawObservationField
                $observation previous-command-results)
            (omegaClawObservationSuccessCount $observation)
            (omegaClawObservationFailureCount $observation)
            (omegaClawObservationResourceMetric
                $observation blocked-count 0.0)
            (omegaClawObservationField
                $observation previous-command-results)
            (omegaClawObservationResourceMetric
                $observation task-progress
                (if (omegaClawProgressObserved $observation) 0.50 0.0))
            (omegaClawObservationResourceMetric
                $observation evidence-quality
                (if (omegaClawProgressObserved $observation) 0.70 0.0))
            (omegaClawObservationResourceMetric
                $observation safety-events 0.0)
            (omegaClawObservationResourceMetric
                $observation resource-cost 0.0)
            (omegaClawObservationResourceMetric
                $observation contradiction-evidence 0.0))
        none))

(= (omegaClawOutcomeSignals none)
    ())

(= (omegaClawOutcomeSignals $outcome)
    (let* (
        ($proposed
            (omegaClawOutcomeField $outcome commands-proposed))
        ($authorized
            (omegaClawOutcomeField $outcome commands-authorized))
        ($executed
            (omegaClawOutcomeField $outcome commands-executed))
        ($visible
            (omegaClawOutcomeField $outcome user-visible-result))
        ($evidenceQuality
            (omegaClawOutcomeField $outcome evidence-quality))
        ($taskProgress
            (omegaClawOutcomeField $outcome task-progress))
        ($proposalStatus
            (omegaClawOutcomeField $outcome proposal-status))
        ($proposalRepeated
            (or
                (== (omegaClawOutcomeField
                        $outcome failure-reason)
                    repeated-proposal)
                (> (omegaClawOutcomeField
                        $outcome proposal-attempt)
                    (omegaClawProposalRetryLimit))))
        ($dispatchStatus
            (omegaClawOutcomeField $outcome dispatch-status))
        ($resultUtility
            (omegaClawOutcomeField $outcome result-utility))
        ($verificationStatus
            (omegaClawOutcomeField $outcome verification-status))
        ($success
            (> (omegaClawOutcomeField $outcome success-count) 0.0))
        ($failed
            (> (omegaClawOutcomeField $outcome failure-count) 0.0))
        ($blocked
            (> (omegaClawOutcomeField $outcome blocked-count) 0.0))
        ($evidenceSufficient
            (== $verificationStatus passed))
        ($expectedEmpty
            (omegaClawOutcomeExpectedEmpty $outcome))
        ($useful
            (and
                (not (== $visible ()))
                (or (> $taskProgress 0.0)
                    (> $evidenceQuality 0.0))))
    )
        (omegaClawListAppend
            (omegaClawMaybeDefaultSignal
                (== $proposalStatus empty) proposal-empty outcome)
            (omegaClawListAppend
                (omegaClawMaybeDefaultSignal
                    (== $proposalStatus invalid)
                    proposal-invalid outcome)
                (omegaClawListAppend
                    (omegaClawMaybeDefaultSignal
                        $proposalRepeated proposal-repeated outcome)
                    (omegaClawListAppend
                    (omegaClawMaybeDefaultSignal
                        (or $failed
                            (or (== $dispatchStatus failed)
                                (== $dispatchStatus partial)))
                        execution-failure outcome)
                    (omegaClawListAppend
                        (omegaClawMaybeDefaultSignal
                            (and
                                (== $resultUtility empty)
                                (not $expectedEmpty))
                            result-empty outcome)
                        (omegaClawListAppend
                            (omegaClawMaybeDefaultSignal
                                $useful
                                result-useful outcome)
                            (omegaClawListAppend
                                (omegaClawMaybeDefaultSignal
                                    $evidenceSufficient
                                    evidence-sufficient outcome)
                                (omegaClawListAppend
                                    (omegaClawMaybeDefaultSignal
                                        (and
                                            (not (== $executed ()))
                                            (and
                                                (== $verificationStatus pending)
                                                (not $evidenceSufficient)))
                                        evidence-insufficient outcome)
                                    (omegaClawListAppend
                                        (omegaClawMaybeDefaultSignal
                                            (== $verificationStatus passed)
                                            verification-passed outcome)
                                        (omegaClawListAppend
                                            (omegaClawMaybeDefaultSignal
                                                (== $verificationStatus failed)
                                                verification-failed outcome)
                                            (omegaClawListAppend
                                                (omegaClawMaybeDefaultSignal
                                                    (and
                                                        (== $verificationStatus passed)
                                                        (== $resultUtility useful))
                                                    verified-success outcome)
                                                (omegaClawMaybeDefaultSignal
                                                    (> (omegaClawOutcomeField
                                                            $outcome
                                                            safety-events)
                                                       0.0)
                                                    danger outcome))))))))))))))

(= (omegaClawPerceptionFromObservation $observation)
    (let $outcome (omegaClawOutcomeFromObservation $observation)
        (omegaClawPerceptionFromParts
            $observation
            $outcome
            (omegaClawListAppend
                (omegaClawObservationStructuralSignals $observation)
                (omegaClawObservationLifecycleSignals $observation))
            (omegaClawObservationSemanticSignals $observation)
            (omegaClawOutcomeSignals $outcome))))

(= (omegaClawPerceptionFromObservationAndOutcome $observation $outcome)
    (omegaClawPerceptionFromParts
        $observation
        $outcome
        (omegaClawListAppend
            (omegaClawObservationStructuralSignals $observation)
            (omegaClawObservationLifecycleSignals $observation))
        (omegaClawObservationSemanticSignals $observation)
        (omegaClawOutcomeSignals $outcome)))

(= (omegaClawPerceptionFeatures $perception)
    (omegaClawStimulusFeatures $perception))

(= (omegaClawAppraisePerception $state $perception)
    (appraisalProfileAppraise
        (omegaClawAppraisalProfile)
        $state
        $perception))

(= (omegaClawAppraisalTrace
        $perception $features $coreDeltas
        $applicationDeltas $goalFeedback $nextState)
    (omegaClawAppraisalTraceRecord
        $perception $features $coreDeltas
        $applicationDeltas $goalFeedback $nextState))

(= (omegaClawAppraisalTraceField $trace $field)
    (let (omegaClawAppraisalTraceRecord
            $perception $features $coreDeltas
            $applicationDeltas $goalFeedback $nextState)
        $trace
        (case $field (
            (perception $perception)
            (features $features)
            (core-deltas $coreDeltas)
            (application-deltas $applicationDeltas)
            (goal-feedback $goalFeedback)
            (next-state $nextState)
            ($_ (empty))
        ))))

(= (omegaClawAppraisalTraceForPerception $state $perception)
    (let* (
        ($profile (omegaClawAppraisalProfile))
        ($features
            (appraisalProfileStimulusFeatures
                $profile $state $perception))
        ($coreDeltas
            (appraisalProfileCoreDeltas
                $profile $state $features))
        ($afterCore
            (applyCoreModulatorDeltas
                $profile $state $coreDeltas))
        ($applicationDeltas
            (appraisalProfileApplicationDeltas
                $profile $afterCore $features))
        ($goalFeedback
            (appraisalProfileGoalChangeFeedback
                $profile $state $perception $features))
        ($nextState
            (appraisalProfileAppraise
                $profile $state $perception))
    )
        (omegaClawAppraisalTrace
            $perception $features $coreDeltas
            $applicationDeltas $goalFeedback $nextState)))
