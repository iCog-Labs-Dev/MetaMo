
(= (omegaClawRawStimulusAdapterFn $rawPerception)
    (case $rawPerception (
        ((omegaClawObservationRecord
                $turnId $wakeReason $timestamp
                $newMessage $messageId $messageText $channel
                $activeTask $taskStatus $autonomyPhase
                $previousAction $previousCommandResults $previousErrors
                $loopBudget $resourceSignals $semanticSignals)
            (omegaClawPerceptionFromObservation $rawPerception))
        ($_ $rawPerception)
    )))

(= (omegaClawFrameAdapters)
    ())

(= (omegaClawBundle)
    (applicationBundle
        omegaclaw
        (omegaClawSchema)
        (omegaClawAppraisalProfile)
        (omegaClawDecisionProfile)
        omegaClawOutcomeGoalChangeDeltaG
        (omegaClawStabilityPolicy)
        (omegaClawCoherencePolicy)
        (omegaClawMergePolicy)
        omegaClawRawStimulusAdapterFn
        omegaClawCandidateBuilderFn
        (omegaClawFrameAdapters)))

(= (omegaClawValidatedBundle)
    (validateApplicationBundle (omegaClawBundle)))

(= (omegaClawBimonad)
    (bundleBimonad (omegaClawBundle)))

(= (omegaClawDiagnosedStep $state $rawPerception $embody)
    (let* (
        ($bundle (omegaClawBundle))
        ($stimulus (eval (bundleAdaptStimulus $bundle $rawPerception)))
        ($candidates (eval (bundleBuildCandidates $bundle $state $stimulus)))
        ($bimonad (eval (bundleBimonad $bundle)))
    )
        (eval (stepWithDiagnostics $bimonad $state $stimulus $candidates $embody))
))
