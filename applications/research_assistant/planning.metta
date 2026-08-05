
;; Return the current mood value for a name, defaulting to 0.5.
;; Example: (researchAssistantMoodValue ((caution 0.8)) caution) -> 0.8
(= (researchAssistantMoodValue $currentMood $name)
    (clipUnit (featurePairsGet $currentMood $name 0.5))
)

;; Return the canonical action for a task intent.
;; Example: (researchAssistantIntentAction answer) -> safe_answer
(= (researchAssistantIntentAction $taskIntent)
    (symbolMapGet
        (
            (answer safe_answer)
            (summarize summarize_source)
            (compare compare_options)
            (clarify ask_clarifying_question)
            (explore guided_explore)
            (decline decline_risky_request)
        )
        $taskIntent
        none
    )
)

;; Return the task-intent boost value.
;; Example: (researchAssistantIntentBoostValue answer) -> 0.18
(= (researchAssistantIntentBoostValue $taskIntent)
    (symbolMapGet
        (
            (answer 0.18)
            (summarize 0.30)
            (compare 0.34)
            (clarify 0.34)
            (explore 0.45)
            (decline 0.45)
        )
        $taskIntent
        0.20
    )
)

;; Return the boost for an action under the current task intent.
;; Example: (researchAssistantIntentBoost signals safe_answer) -> 0.18
(= (researchAssistantIntentBoost $signals $actionId)
    (let* (
        ($taskIntent (researchAssistantSignalTaskIntent $signals))
    )
        (if (== (researchAssistantIntentAction $taskIntent) $actionId)
            (researchAssistantIntentBoostValue $taskIntent)
            0.0
        )
    )
)

;; Build candidate metadata.
;; Example: (researchAssistantCandidateMetadata safe_answer signals 0.1) -> metadata
(= (researchAssistantCandidateMetadata $actionId $signals $risk)
    (
        (risk (clipUnit $risk))
        (generated_by deterministic_research_assistant_profile)
        (task_intent (researchAssistantSignalTaskIntent $signals))
        (action_policy $actionId)
    )
)

;; Build a safe-answer candidate.
;; Example: (researchAssistantSafeAnswerCandidate perception mood) -> actionCandidate
(= (researchAssistantSafeAnswerCandidate $perception $currentMood)
    (let* (
        ($signals (researchAssistantPerceptionSignals $perception))
        ($citation (researchAssistantSignalCitationNeed $signals))
        ($exploration (researchAssistantSignalExplorationNeed $signals))
        ($unsafe (researchAssistantSignalUnsafePressure $signals))
        ($privacy (researchAssistantSignalPrivacyPressure $signals))
        ($unsupported (researchAssistantSignalUnsupportedClaimPressure $signals))
        ($contextLoss (researchAssistantSignalContextLossPressure $signals))
        ($safety (maxNumber $unsafe $privacy))
        ($caution (researchAssistantMoodValue $currentMood caution))
        ($help (+ (+ (+ 0.78 (* 0.10 $citation)) (- 0.0 (* 0.25 $safety))) (researchAssistantIntentBoost $signals safe_answer)))
        ($corrs (researchAssistantCorrelationVector
            (
                (help $help)
                (curiosity (+ 0.12 (* 0.08 $exploration)))
                (novelty 0.05)
                (self_improvement 0.10)
                (ethics (- (+ 0.68 (* 0.15 $caution)) (* 0.10 $safety)))
                (sociality 0.35)
                (misinformation (+ 0.08 (* 0.30 $unsupported)))
                (unsupported_claim (+ 0.10 (* 0.35 $unsupported)))
                (privacy_violation (+ 0.05 (* 0.55 $privacy)))
                (unsafe_assistance (+ 0.05 (* 0.60 $unsafe)))
                (context_loss (+ 0.06 (* 0.18 $contextLoss)))
            )
        ))
        ($risk (+ (+ (+ 0.05 (* 0.32 $unsupported)) (* 0.35 $privacy)) (* 0.35 $unsafe)))
        ($delta (researchAssistantDeltaVector ((help 0.02) (ethics 0.01))))
    )
        (actionCandidate safe_answer (researchAssistantSchema) $corrs $delta (researchAssistantCandidateMetadata safe_answer $signals $risk))
    )
)

;; Build a guided-explore candidate.
;; Example: (researchAssistantGuidedExploreCandidate perception mood) -> actionCandidate
(= (researchAssistantGuidedExploreCandidate $perception $currentMood)
    (let* (
        ($signals (researchAssistantPerceptionSignals $perception))
        ($exploration (researchAssistantSignalExplorationNeed $signals))
        ($unsafe (researchAssistantSignalUnsafePressure $signals))
        ($privacy (researchAssistantSignalPrivacyPressure $signals))
        ($unsupported (researchAssistantSignalUnsupportedClaimPressure $signals))
        ($contextLoss (researchAssistantSignalContextLossPressure $signals))
        ($safety (maxNumber $unsafe $privacy))
        ($caution (researchAssistantMoodValue $currentMood caution))
        ($arousal (researchAssistantMoodValue $currentMood arousal))
        ($corrs (researchAssistantCorrelationVector
            (
                (help (+ (+ (+ 0.45 (* 0.25 $exploration)) (- 0.0 (* 0.20 $safety))) (researchAssistantIntentBoost $signals guided_explore)))
                (curiosity (+ (+ 0.85 (* 0.25 $exploration)) (* 0.10 $arousal)))
                (novelty (+ 0.80 (* 0.18 $exploration)))
                (self_improvement 0.25)
                (ethics (+ 0.45 (* 0.10 $caution)))
                (sociality 0.42)
                (misinformation (+ 0.12 (* 0.30 $unsupported)))
                (unsupported_claim (+ 0.15 (* 0.35 $unsupported)))
                (privacy_violation (+ 0.10 (* 0.35 $privacy)))
                (unsafe_assistance (+ 0.12 (* 0.60 $unsafe)))
                (context_loss (+ 0.10 (* 0.20 $contextLoss)))
            )
        ))
        ($risk (+ (+ (+ 0.10 (* 0.35 $unsupported)) (* 0.30 $privacy)) (* 0.50 $unsafe)))
        ($delta (researchAssistantDeltaVector ((curiosity 0.025) (novelty 0.025))))
    )
        (actionCandidate guided_explore (researchAssistantSchema) $corrs $delta (researchAssistantCandidateMetadata guided_explore $signals $risk))
    )
)

;; Build an ask-clarifying-question candidate.
;; Example: (researchAssistantClarifyCandidate perception mood) -> actionCandidate
(= (researchAssistantClarifyCandidate $perception $currentMood)
    (let* (
        ($signals (researchAssistantPerceptionSignals $perception))
        ($ambiguity (researchAssistantSignalAmbiguity $signals))
        ($privacy (researchAssistantSignalPrivacyPressure $signals))
        ($unsafe (researchAssistantSignalUnsafePressure $signals))
        ($safety (maxNumber $unsafe $privacy))
        ($corrs (researchAssistantCorrelationVector
            (
                (help (+ (+ (+ 0.20 (* 0.45 $ambiguity)) (- 0.0 (* 0.25 $safety))) (researchAssistantIntentBoost $signals ask_clarifying_question)))
                (curiosity 0.30)
                (novelty 0.10)
                (self_improvement 0.15)
                (ethics (+ 0.45 (* 0.35 $ambiguity)))
                (sociality (- (+ 0.35 (* 0.45 $ambiguity)) (* 0.25 $safety)))
                (misinformation (- -0.10 (* 0.25 $ambiguity)))
                (unsupported_claim (- -0.15 (* 0.35 $ambiguity)))
                (privacy_violation (- -0.10 (* 0.25 $ambiguity)))
                (unsafe_assistance (- -0.05 (* 0.20 $ambiguity)))
                (context_loss (- -0.15 (* 0.45 $ambiguity)))
            )
        ))
        ($risk (+ 0.03 (* 0.10 $privacy)))
        ($delta (researchAssistantDeltaVector ((help 0.01) (sociality 0.02) (context_loss -0.02))))
    )
        (actionCandidate ask_clarifying_question (researchAssistantSchema) $corrs $delta (researchAssistantCandidateMetadata ask_clarifying_question $signals $risk))
    )
)

;; Build a compare-options candidate.
;; Example: (researchAssistantCompareCandidate perception mood) -> actionCandidate
(= (researchAssistantCompareCandidate $perception $currentMood)
    (let* (
        ($signals (researchAssistantPerceptionSignals $perception))
        ($comparison (researchAssistantSignalComparisonNeed $signals))
        ($unsupported (researchAssistantSignalUnsupportedClaimPressure $signals))
        ($privacy (researchAssistantSignalPrivacyPressure $signals))
        ($unsafe (researchAssistantSignalUnsafePressure $signals))
        ($contextLoss (researchAssistantSignalContextLossPressure $signals))
        ($corrs (researchAssistantCorrelationVector
            (
                (help (+ (+ 0.70 (* 0.25 $comparison)) (researchAssistantIntentBoost $signals compare_options)))
                (curiosity (+ 0.42 (* 0.10 $comparison)))
                (novelty 0.20)
                (self_improvement 0.20)
                (ethics 0.55)
                (sociality 0.45)
                (misinformation (+ 0.10 (* 0.20 $unsupported)))
                (unsupported_claim (+ 0.12 (* 0.25 $unsupported)))
                (privacy_violation (+ 0.08 (* 0.20 $privacy)))
                (unsafe_assistance (+ 0.08 (* 0.20 $unsafe)))
                (context_loss (+ 0.08 (* 0.15 $contextLoss)))
            )
        ))
        ($risk (+ (+ (+ 0.07 (* 0.25 $unsupported)) (* 0.20 $privacy)) (* 0.20 $unsafe)))
        ($delta (researchAssistantDeltaVector ((help 0.015) (self_improvement 0.01))))
    )
        (actionCandidate compare_options (researchAssistantSchema) $corrs $delta (researchAssistantCandidateMetadata compare_options $signals $risk))
    )
)

;; Build a summarize-source candidate.
;; Example: (researchAssistantSummarizeCandidate perception mood) -> actionCandidate
(= (researchAssistantSummarizeCandidate $perception $currentMood)
    (let* (
        ($signals (researchAssistantPerceptionSignals $perception))
        ($summary (researchAssistantSignalSummaryNeed $signals))
        ($citation (researchAssistantSignalCitationNeed $signals))
        ($unsupported (researchAssistantSignalUnsupportedClaimPressure $signals))
        ($privacy (researchAssistantSignalPrivacyPressure $signals))
        ($unsafe (researchAssistantSignalUnsafePressure $signals))
        ($contextLoss (researchAssistantSignalContextLossPressure $signals))
        ($corrs (researchAssistantCorrelationVector
            (
                (help (+ (+ 0.70 (* 0.20 $summary)) (researchAssistantIntentBoost $signals summarize_source)))
                (curiosity 0.15)
                (novelty 0.10)
                (self_improvement 0.15)
                (ethics (+ 0.70 (* 0.10 $citation)))
                (sociality 0.35)
                (misinformation (+ 0.06 (* 0.20 $unsupported)))
                (unsupported_claim (+ 0.08 (* 0.25 $unsupported)))
                (privacy_violation (+ 0.08 (* 0.25 $privacy)))
                (unsafe_assistance (+ 0.05 (* 0.20 $unsafe)))
                (context_loss (+ -0.35 (* 0.15 $contextLoss)))
            )
        ))
        ($risk (+ (+ (+ 0.05 (* 0.20 $unsupported)) (* 0.20 $privacy)) (* 0.15 $unsafe)))
        ($delta (researchAssistantDeltaVector ((help 0.02) (ethics 0.015) (context_loss -0.02))))
    )
        (actionCandidate summarize_source (researchAssistantSchema) $corrs $delta (researchAssistantCandidateMetadata summarize_source $signals $risk))
    )
)

;; Build a decline-risky-request candidate.
;; Example: (researchAssistantDeclineCandidate perception mood) -> actionCandidate
(= (researchAssistantDeclineCandidate $perception $currentMood)
    (let* (
        ($signals (researchAssistantPerceptionSignals $perception))
        ($unsafe (researchAssistantSignalUnsafePressure $signals))
        ($privacy (researchAssistantSignalPrivacyPressure $signals))
        ($safety (maxNumber $unsafe $privacy))
        ($corrs (researchAssistantCorrelationVector
            (
                (help (+ (+ 0.25 (* 0.45 $safety)) (researchAssistantIntentBoost $signals decline_risky_request)))
                (curiosity -0.10)
                (novelty -0.10)
                (self_improvement 0.05)
                (ethics (+ 0.95 (* 0.20 $safety)))
                (sociality (+ 0.20 (* 0.25 $safety)))
                (misinformation -0.30)
                (unsupported_claim -0.30)
                (privacy_violation -0.80)
                (unsafe_assistance -0.95)
                (context_loss 0.05)
            )
        ))
        ($risk 0.02)
        ($delta (researchAssistantDeltaVector ((ethics 0.03) (unsafe_assistance -0.03) (privacy_violation -0.02))))
    )
        (actionCandidate decline_risky_request (researchAssistantSchema) $corrs $delta (researchAssistantCandidateMetadata decline_risky_request $signals $risk))
    )
)

;; Build all deterministic candidates in Python order.
;; Example: (researchAssistantBuildCandidates perception ((arousal 0.5) (caution 0.5))) -> candidates
(= (researchAssistantBuildCandidates $perception $currentMood)
    (
        (researchAssistantSafeAnswerCandidate $perception $currentMood)
        (researchAssistantGuidedExploreCandidate $perception $currentMood)
        (researchAssistantClarifyCandidate $perception $currentMood)
        (researchAssistantCompareCandidate $perception $currentMood)
        (researchAssistantSummarizeCandidate $perception $currentMood)
        (researchAssistantDeclineCandidate $perception $currentMood)
    )
)
