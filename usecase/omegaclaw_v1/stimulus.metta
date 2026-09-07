
(= (omegaClawSignalFeatureContribution () $feature)
    0.0)

(= (omegaClawSignalFeatureContribution $signals $feature)
    (let* (
        (($head $tail) (decons $signals))
        ($kind (omegaClawSignalField $head kind))
        ($strength (omegaClawSignalField $head strength))
        ($weight
            (featurePairsGet
                (omegaClawSignalFeatureWeights $kind)
                $feature
                0.0))
    )
        (+ (* $strength $weight)
           (omegaClawSignalFeatureContribution $tail $feature))))

(= (omegaClawStimulusFeatureValue $signals $feature)
    (clipUnit
        (omegaClawSignalFeatureContribution $signals $feature)))

(= (omegaClawStimulusFeatures $perception)
    (let* (
        ($signals (omegaClawPerceptionField $perception signals))
    )
        (stimulusFeatures
            (
                (novelty
                    (omegaClawStimulusFeatureValue $signals novelty))
                (risk
                    (omegaClawStimulusFeatureValue $signals risk))
                (importance
                    (omegaClawStimulusFeatureValue $signals importance))
                (uncertainty
                    (omegaClawStimulusFeatureValue $signals uncertainty))
                (opportunity
                    (omegaClawStimulusFeatureValue $signals opportunity))
                (progress
                    (omegaClawStimulusFeatureValue $signals progress))
                (human_presence
                    (omegaClawStimulusFeatureValue
                        $signals human_presence))
                (ambiguity_load
                    (omegaClawStimulusFeatureValue
                        $signals ambiguity_load))
                (failure_load
                    (omegaClawStimulusFeatureValue
                        $signals failure_load))
                (evidence_strength
                    (omegaClawStimulusFeatureValue
                        $signals evidence_strength))
                (task_focus
                    (omegaClawStimulusFeatureValue
                        $signals task_focus))
                (goal_control
                    (omegaClawStimulusFeatureValue
                        $signals goal_control))
                (autonomy_drive
                    (omegaClawStimulusFeatureValue
                        $signals autonomy_drive))
            ))))

(= (omegaClawStimulusFeatureFn $state $perception)
    (omegaClawStimulusFeatures $perception))
