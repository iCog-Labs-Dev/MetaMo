
;; Normalize raw Qwestor input for the application bundle
(= (qwestorRawStimulusAdapterFn $rawStimulus)
    (case $rawStimulus (
        ((qwestorPerception $context $previousOutcome) $rawStimulus)
        ((qwestorContext $pairs) (makeQwestorPerception $rawStimulus none))
        ($_
            (makeQwestorPerception
                (makeQwestorContext (qwestorNeutralContext))
                none))
    ))
)

;; Build the configured Qwestor coherence policy
(= (qwestorCoherencePolicy)
    (let* (
        ($config (qwestorCoherenceConfig))
    )
        (defaultCoherencePolicy
            (qwestorConfigGet $config ALPHA_0 0.10)
            (qwestorConfigGet $config BETA_0 0.15)
            (qwestorConfigGet $config MIN_ALPHA 0.000001)
            (qwestorConfigGet $config LIPSCHITZ_CONSTANT 1.00)
            (qwestorConfigGet $config MAX_ALLOWED_DRIFT 0.10)
            (qwestorConfigGet $config MIN_ALPHA_SCALE 0.125)
            (qwestorConfigGet $config STATE_DRIFT_WEIGHT 0.50)
            (qwestorConfigGet $config SELF_MODEL_DRIFT_WEIGHT 0.50)
            (threshold securing risk_aversion failure_wariness)
            (arousal approach creativity)
            resolution
            valence
        )
    )
)

;; Build the configured Qwestor parallel-merge policy
(= (qwestorMergePolicy)
    (defaultParallelMergePolicy
        (threshold securing risk_aversion failure_wariness)
        (arousal approach creativity)
        (valence resolution urgency error_tolerance user_expertise
         topic_familiarity)
        (qwestorConfigGet
            (qwestorCoherenceConfig) MERGE_COHERENCE_CORRECTION 0.05)
    )
)

;; Return application-owned frame adapters
(= (qwestorFrameAdapters)
    ()
)

;; Build the complete Qwestor application bundle
(= (qwestorBundle)
    (applicationBundle
        qwestor
        (qwestorSchema)
        (qwestorAppraisalProfile)
        (qwestorDecisionProfile)
        qwestorGoalChangeDeltaG
        (qwestorStabilityPolicy)
        (qwestorCoherencePolicy)
        (qwestorMergePolicy)
        qwestorRawStimulusAdapterFn
        qwestorBuildCandidates
        (qwestorFrameAdapters)
    )
)

;; Combine generic bundle validation with Qwestor policy validation
(= (qwestorValidateBundleFromChecks
        $bundle (validationOk $validatedBundle) (validationOk $validatedPolicy))
    (validationOk $bundle)
)

(= (qwestorValidateBundleFromChecks
        $bundle (validationOk $validatedBundle) (validationError $code $details))
    (validationError $code $details)
)

(= (qwestorValidateBundleFromChecks
        $bundle (validationError $code $details) $policyValidation)
    (validationError $code $details)
)

;; Validate the bundle and every Qwestor-specific policy contract
(= (qwestorValidatedBundle)
    (let* (
        ($bundle (qwestorBundle))
        ($bundleValidation (validateApplicationBundle $bundle))
        ($policyValidation
            (qwestorValidateStabilityPolicy (bundleStabilityPolicy $bundle)))
    )
        (qwestorValidateBundleFromChecks
            $bundle $bundleValidation $policyValidation)
    )
)

;; Build a bimonad only through the validated Qwestor bundle path
(= (qwestorBimonad)
    (bundleBimonadFromValidation (qwestorValidatedBundle))
)
