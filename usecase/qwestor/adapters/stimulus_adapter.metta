; Translates Qwestor's 14-signal context list  into MetaMo's OpenPSI stimulus format:
;
;   (stimulus novelty conduciveness risk effort)
;
; Mapping rationale:
;
;   novelty       ← How unexpected, unfamiliar, or complex is a specific query
;                   high when topic_familiarity is low and complexity is high.
;                   Also boosted by reflective_intent and needs_external_evidence.
;                   
;
;   conduciveness ← how likely the current context leads to a good outcome.
;                   High when topic_familiarity is high, ambiguity is low,
;                   and valence is positive. Penalised by failure_signal.
;
;   risk          ← how likely the action causes harm or error.
;                   Driven by threshold and failure_signal. Boosted when
;                   verify_request=1 or ambiguity is high.
;
;   effort        ← cognitive cost of the current request.
;                   driven by complexity and needs_multi_source_integration.
;                   Boosted by needs_task_plan and ambiguity.
;


; ── contextToStimulus ────────────────────────────────────────────────────────
; Takes the context result list (as returned by context_parser) and
; returns a MetaMo stimulus atom.
;
; $context-list – the flat pair-list from context parser , e.g.
;   ((urgency 0.2) (complexity 0.6) (ambiguity 0.1) …)
;
; Returns: (stimulus novelty conduciveness risk effort)

(: contextToStimulus (-> Expression Expression))
(= (contextToStimulus $context-list)
  (let*
    (
      ; extract signals  
      ($complexity              (findByKey complexity               $context-list))
      ($ambiguity               (findByKey ambiguity                $context-list))
      ($threshold               (findByKey threshold                $context-list))
      ($familiarity_signal      (findByKey topic_familiarity       $context-list))
      ($failure_signal          (findByKey failure_signal           $context-list))
      ($reflective_intent       (findByKey reflective_intent        $context-list))
      ($valence                 (findByKey valence                  $context-list))
      ($needs_external_evidence (findByKey needs_external_evidence  $context-list))
      ($task                    (findByKey needs_task_plan          $context-list))
      ($ms                      (findByKey needs_multi_source_integration $context-list))
      ($verify_request          (findByKey verify_request           $context-list))
      ($urgency                 (findByKey urgent                  $context-list))

      ; NOVELTY  
      ; Boosted strictly by external evidence requirement to favor act_search
      ($ev_boost (if (> $needs_external_evidence 0.7) 0.30 0.0))
      ($novelty
        (eval (clampToUnitInterval
          (+  (* 0.30 (- 1.0 $familiarity_signal))
            (+ (* 0.25 $complexity)
              (+ (* 0.15 $reflective_intent)
                 $ev_boost)))
        )))

      ; CONDUCIVENESS  
      ; Tanked by verify_request (failure state) and ambiguity (confusion state)
      ($vr_penalty  (if (== $verify_request 1) 0.40 0.0))
      ($amb_penalty (if (> $ambiguity 0.7) 0.30 0.0))
      ($val_norm    (eval (clampToUnitInterval (* (+ $valence 1.0) 0.5))))
      ($conduciveness
        (eval (clampToUnitInterval
          (- (+  (* 0.40 $familiarity_signal)
               (+ (* 0.20 (- 1.0 $ambiguity))
                  (+ (* 0.20 $val_norm)
                     (* -0.20 $failure_signal))))
             (+ $vr_penalty $amb_penalty))
        )))

      ; RISK  
      ; Spiked by verify_request (forces act_verify) and ambiguity (forces act_clarify)
      ($vr_boost       (if (== $verify_request 1) 0.60 0.0))
      ($amb_risk_boost (if (> $ambiguity 0.7) 0.30 0.0))
      ($risk
        (eval (clampToUnitInterval
          (+ (* 0.30 $threshold)
            (+ (* 0.20 $failure_signal)
              (+ (* 0.10 (- 1.0 $familiarity_signal))
                 (+ $vr_boost $amb_risk_boost))))
        )))

      ; EFFORT  
      ; Spiked by task_plan (forces act_decompose) and multi_source (forces act_synthesize)
      ($task_boost (if (> $task 0.65) 0.50 0.0))
      ($ms_boost   (if (> $ms 0.65) 0.40 0.0))
      ($effort
        (eval (clampToUnitInterval
          (+ (* 0.20 $complexity)
            (+ (* 0.10 $ambiguity)
               (+ $task_boost $ms_boost)))
        )))
    )
    
    (stimulus ((novelty $novelty) (conduciveness $conduciveness) (risk $risk) (effort $effort)))
  )
)

(: projectStimulus (-> Expression Expression))
(= (projectStimulus $context-list)
  (let (stimulus $vals) (contextToStimulus $context-list) $vals)
)

; getStimulusValues
; Extracts the raw stimulus values from a stimulus atom
(= (getStimulusValues (stimulus $stimulus-list))
  (stimulus (
    (findByKey novelty $stimulus-list)
    (findByKey conduciveness $stimulus-list)
    (findByKey risk $stimulus-list)
    (findByKey effort $stimulus-list)
  ))
)
 
