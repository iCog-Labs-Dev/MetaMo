(= (inferenceControlDecisionProfile)
   (decisionProfile
     inference_control_magus_additive
     (inferenceControlSchema)
     ((query_progress (approach resolution))
      (evidence_quality (threshold securing))
      (exploration (arousal approach))
      (resource_efficiency (resolution threshold)))
     (evidence_quality resource_efficiency)
     (query_progress exploration)
     ()
     ((unreliable_inference 1.5)
      (low_information_gain 1.1))
     ((individuation individuation_target)
      (transcendence transcendence_target))
     ((unreliable_inference unreliable_inference_target)
      (low_information_gain low_information_gain_target))
     none
     0.01
     0.02
     0.05
     0.0
     0.1))

(= (inferenceControlDecision)
   (makeMagusDecision (inferenceControlDecisionProfile)))
