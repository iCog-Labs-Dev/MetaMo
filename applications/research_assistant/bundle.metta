
;; Adapt a raw Research Assistant perception into the calibrated perception used by runtime.
(= (researchAssistantRawStimulusAdapterFn $rawPerception)
    (researchAssistantCalibrationPerception
        (calibrateResearchAssistantPerception $rawPerception)
    )
)

;; Build the compact mood map expected by the deterministic planner.
(= (researchAssistantMoodFromState $state)
    (
        (arousal (stateModulator $state arousal))
        (caution (stateModulator $state securing))
    )
)

;; Bundle callback for deterministic candidate construction.
(= (researchAssistantCandidateBuilderFn $state $perception)
    (researchAssistantBuildCandidates
        $perception
        (researchAssistantMoodFromState $state)
    )
)

;; Return application-owned frame adapters.
(= (researchAssistantFrameAdapters)
    (
        (agentFrameAdapter
            (researchAssistantCuriosityToEthicsTranslation)
            none
            none
            none
        )
    )
)

;; Build the Research Assistant application bundle.
(= (researchAssistantBundle)
    (let* (
        ($schema (researchAssistantSchema))
        ($appraisal (researchAssistantAppraisalProfile))
        ($decision (researchAssistantDecisionProfile))
        ($stability (makeDefaultStabilityPolicy))
        ($coherence (makeDefaultCoherencePolicy))
        ($merge (makeDefaultParallelMergePolicy))
        ($frameAdapters (researchAssistantFrameAdapters))
    )
        (applicationBundle
            research_assistant
            $schema
            $appraisal
            $decision
            defaultGoalChangeDeltaG
            $stability
            $coherence
            $merge
            researchAssistantRawStimulusAdapterFn
            researchAssistantCandidateBuilderFn
            $frameAdapters
        )
    )
)

;; Validate the Research Assistant bundle.
(= (researchAssistantValidatedBundle)
    (validateApplicationBundle (researchAssistantBundle))
)

;; Build the Research Assistant bimonad from the validated bundle path.
(= (researchAssistantBimonad)
    (bundleBimonad (researchAssistantBundle))
)
