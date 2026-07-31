;; Dynamic feature maps for stimuli and goal-change feedback.

(: StimulusFeatures Type)
(: stimulusFeatures (-> Expression StimulusFeatures))

(: GoalChangeFeedback Type)
(: goalChangeFeedback (-> Expression GoalChangeFeedback))

;; Return pairs from stimulus features.
;; Example: (featureMapPairs (stimulusFeatures ((novelty 0.3)))) -> ((novelty 0.3))
(= (featureMapPairs (stimulusFeatures $pairs))
    $pairs
)

;; Return pairs from goal-change feedback.
;; Example: (featureMapPairs (goalChangeFeedback ((progress 0.8)))) -> ((progress 0.8))
(= (featureMapPairs (goalChangeFeedback $pairs))
    $pairs
)

;; Return the name from a feature pair.
;; Example: (featurePairName (novelty 0.3)) -> novelty
(= (featurePairName ($name $value))
    $name
)

;; Return the value from a feature pair.
;; Example: (featurePairValue (novelty 0.3)) -> 0.3
(= (featurePairValue ($name $value))
    $value
)

;; Retrieve a feature value from raw pairs, falling back to a default.
;; Example: (featurePairsGet ((novelty 0.3)) novelty 0.0) -> 0.3
(= (featurePairsGet $pairs $name $default)
    (if (== $pairs ())
        $default
        (let* (
            (($head $tail) (decons $pairs))
            ($featureName (featurePairName $head))
            ($featureValue (featurePairValue $head))
        )
            (if (== $featureName $name)
                $featureValue
                (featurePairsGet $tail $name $default)
            )
        )
    )
)

;; Test whether a feature exists.
;; Example: (featurePairsHas ((novelty 0.3)) novelty) -> True
(= (featurePairsHas $pairs $name)
    (if (== $pairs ())
        False
        (let* (
            (($head $tail) (decons $pairs))
            ($featureName (featurePairName $head))
        )
            (if (== $featureName $name)
                True
                (featurePairsHas $tail $name)
            )
        )
    )
)

;; Retrieve a value from any canonical feature map.
;; Example: (featureMapGet (stimulusFeatures ((risk 0.2))) risk 0.0) -> 0.2
(= (featureMapGet $featureMap $name $default)
    (featurePairsGet (featureMapPairs $featureMap) $name $default)
)

;; Test whether a feature map carries a feature.
;; Example: (featureMapHas (goalChangeFeedback ((progress 0.8))) progress) -> True
(= (featureMapHas $featureMap $name)
    (featurePairsHas (featureMapPairs $featureMap) $name)
)

;; Retrieve a numeric feature value, using the default when absent.
;; Example: (featureMapNumeric (stimulusFeatures ((risk 0.2))) risk 0.0) -> 0.2
(= (featureMapNumeric $featureMap $name $default)
    (featureMapGet $featureMap $name $default)
)

;; Retrieve a numeric feature clipped to the unit interval.
;; Example: (featureMapNumericUnit (stimulusFeatures ((risk 1.2))) risk 0.0) -> 1.0
(= (featureMapNumericUnit $featureMap $name $default)
    (clipUnit (featureMapNumeric $featureMap $name $default))
)

;; Return a new stimulus feature map.
;; Example: (makeStimulusFeatures ((novelty 0.3))) -> (stimulusFeatures ((novelty 0.3)))
(= (makeStimulusFeatures $pairs)
    (stimulusFeatures $pairs)
)

;; Return a new goal-change feedback feature map.
;; Example: (makeGoalChangeFeedback ((progress 0.8))) -> (goalChangeFeedback ((progress 0.8)))
(= (makeGoalChangeFeedback $pairs)
    (goalChangeFeedback $pairs)
)

