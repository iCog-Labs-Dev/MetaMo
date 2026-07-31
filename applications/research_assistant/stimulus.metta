(: ResearchAssistantStimulus Type)
(: researchAssistantStimulus (-> Number Number Number Number ResearchAssistantStimulus))

(: ResearchAssistantSignals Type)
(: researchAssistantSignals (-> Symbol Number Number Number Number Number Number Number Number Number ResearchAssistantSignals))

(: ResearchAssistantPerception Type)
(: researchAssistantPerception (-> ResearchAssistantStimulus ResearchAssistantSignals ResearchAssistantPerception))

;; Return recognized task intents.
;; Example: (researchAssistantTaskIntents) -> (answer summarize compare clarify explore decline)
(= (researchAssistantTaskIntents)
    (answer summarize compare clarify explore decline)
)

;; Validate a task intent symbol.
;; Example: (researchAssistantValidTaskIntent answer) -> True
(= (researchAssistantValidTaskIntent $taskIntent)
    (listContains (researchAssistantTaskIntents) $taskIntent)
)

;; Return novelty from a stimulus.
;; Example: (researchAssistantStimulusNovelty (researchAssistantStimulus 0.1 0.2 0.3 0.4)) -> 0.1
(= (researchAssistantStimulusNovelty (researchAssistantStimulus $novelty $conduciveness $risk $effort))
    $novelty
)

;; Return conduciveness from a stimulus.
;; Example: (researchAssistantStimulusConduciveness stimulus) -> value
(= (researchAssistantStimulusConduciveness (researchAssistantStimulus $novelty $conduciveness $risk $effort))
    $conduciveness
)

;; Return risk from a stimulus.
;; Example: (researchAssistantStimulusRisk stimulus) -> value
(= (researchAssistantStimulusRisk (researchAssistantStimulus $novelty $conduciveness $risk $effort))
    $risk
)

;; Return effort from a stimulus.
;; Example: (researchAssistantStimulusEffort stimulus) -> value
(= (researchAssistantStimulusEffort (researchAssistantStimulus $novelty $conduciveness $risk $effort))
    $effort
)

;; Construct a unit-clamped stimulus.
;; Example: (makeResearchAssistantStimulus 2.0 0.5 -1.0 0.1) -> clamped stimulus
(= (makeResearchAssistantStimulus $novelty $conduciveness $risk $effort)
    (researchAssistantStimulus
        (clipUnit $novelty)
        (clipUnit $conduciveness)
        (clipUnit $risk)
        (clipUnit $effort)
    )
)

;; Return task intent from signals.
;; Example: (researchAssistantSignalTaskIntent signals) -> answer
(= (researchAssistantSignalTaskIntent (researchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss))
    $taskIntent
)

;; Return ambiguity signal.
;; Example: (researchAssistantSignalAmbiguity signals) -> value
(= (researchAssistantSignalAmbiguity (researchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss))
    $ambiguity
)

;; Return citation need signal.
;; Example: (researchAssistantSignalCitationNeed signals) -> value
(= (researchAssistantSignalCitationNeed (researchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss))
    $citation
)

;; Return comparison need signal.
;; Example: (researchAssistantSignalComparisonNeed signals) -> value
(= (researchAssistantSignalComparisonNeed (researchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss))
    $comparison
)

;; Return summary need signal.
;; Example: (researchAssistantSignalSummaryNeed signals) -> value
(= (researchAssistantSignalSummaryNeed (researchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss))
    $summary
)

;; Return exploration need signal.
;; Example: (researchAssistantSignalExplorationNeed signals) -> value
(= (researchAssistantSignalExplorationNeed (researchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss))
    $exploration
)

;; Return unsafe pressure signal.
;; Example: (researchAssistantSignalUnsafePressure signals) -> value
(= (researchAssistantSignalUnsafePressure (researchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss))
    $unsafe
)

;; Return privacy pressure signal.
;; Example: (researchAssistantSignalPrivacyPressure signals) -> value
(= (researchAssistantSignalPrivacyPressure (researchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss))
    $privacy
)

;; Return unsupported-claim pressure signal.
;; Example: (researchAssistantSignalUnsupportedClaimPressure signals) -> value
(= (researchAssistantSignalUnsupportedClaimPressure (researchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss))
    $unsupported
)

;; Return context-loss pressure signal.
;; Example: (researchAssistantSignalContextLossPressure signals) -> value
(= (researchAssistantSignalContextLossPressure (researchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss))
    $contextLoss
)

;; Construct unit-clamped signals.
;; Example: (makeResearchAssistantSignals answer 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9) -> signals
(= (makeResearchAssistantSignals $taskIntent $ambiguity $citation $comparison $summary $exploration $unsafe $privacy $unsupported $contextLoss)
    (if (researchAssistantValidTaskIntent $taskIntent)
        (researchAssistantSignals
            $taskIntent
            (clipUnit $ambiguity)
            (clipUnit $citation)
            (clipUnit $comparison)
            (clipUnit $summary)
            (clipUnit $exploration)
            (clipUnit $unsafe)
            (clipUnit $privacy)
            (clipUnit $unsupported)
            (clipUnit $contextLoss)
        )
        (validationError unknown-research-assistant-task-intent $taskIntent)
    )
)

;; Return stimulus from perception.
;; Example: (researchAssistantPerceptionStimulus (researchAssistantPerception stimulus signals)) -> stimulus
(= (researchAssistantPerceptionStimulus (researchAssistantPerception $stimulus $signals))
    $stimulus
)

;; Return signals from perception.
;; Example: (researchAssistantPerceptionSignals (researchAssistantPerception stimulus signals)) -> signals
(= (researchAssistantPerceptionSignals (researchAssistantPerception $stimulus $signals))
    $signals
)

;; Construct a perception.
;; Example: (makeResearchAssistantPerception stimulus signals) -> perception
(= (makeResearchAssistantPerception $stimulus $signals)
    (researchAssistantPerception $stimulus $signals)
)

;; Convert application stimulus to generic feature map.
;; Example: (researchAssistantStimulusFeatures stimulus) -> stimulusFeatures
(= (researchAssistantStimulusFeatures $stimulus)
    (stimulusFeatures
        (
            (novelty (researchAssistantStimulusNovelty $stimulus))
            (conduciveness (researchAssistantStimulusConduciveness $stimulus))
            (risk (researchAssistantStimulusRisk $stimulus))
            (effort (researchAssistantStimulusEffort $stimulus))
        )
    )
)

