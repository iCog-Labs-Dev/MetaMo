(= (inferenceAppraisalFeaturesFromSignals
      $rule $relevance $novelty $confidence $cost $risk)
   (stimulusFeatures
     ((novelty $novelty)
      (conduciveness (* $relevance $confidence))
      (risk $risk)
      (effort $cost)
      (low_information_gain
        (inferenceLowInformationGain $rule $relevance $novelty)))))

(= (inferenceAppraisalFeatures
      $state
      (inferenceAnnotatedProposal
        (plnProposal $rule $first $second) $term $context $raw))
   (inferenceAppraisalFeaturesFromSignals
     $rule
     (featureMapNumericUnit $raw query_relevance 0.0)
     (featureMapNumericUnit $raw novelty 0.0)
     (featureMapNumericUnit $raw premise_confidence 0.0)
     (featureMapNumericUnit $raw estimated_cost 1.0)
     (featureMapNumericUnit $raw estimated_risk 1.0)))

(= (inferenceCoreDeltas $state $features)
   (commonOpenPsiCoreDeltas $state $features))

(= (inferenceApplicationDeltas $state $features) ())

(= (inferenceGoalFeedback $state $stimulus $features)
   (let $common (commonOpenPsiGoalFeedback $state $stimulus $features)
        (goalChangeFeedback
          (append
            (featureMapPairs $common)
            ((unreliable_inference_target
               (featureMapNumericUnit $features risk 0.0))
             (low_information_gain_target
               (featureMapNumericUnit $features low_information_gain 0.0)))))))

(= (inferenceControlAppraisalProfile)
   (appraisalProfile
     inference_control_openpsi
     (inferenceControlModulatorNames)
     inferenceAppraisalFeatures
     inferenceCoreDeltas
     inferenceApplicationDeltas
     inferenceGoalFeedback
     1.0
     ()))
