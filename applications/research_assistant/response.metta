(: AssistantResponse Type)
(: assistantResponse (-> Expression Symbol Number Number Symbol Symbol Number Number Number Number Expression Expression Expression AssistantResponse))

;; Return response text.
;; Example: (researchAssistantResponseText (assistantResponse text safe_answer 0.5 0.5 a b 0.0 0.0 0.0 0.0 () raw cal)) -> text
(= (researchAssistantResponseText
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $text
)

;; Return response action id.
;; Example: (researchAssistantResponseActionId response) -> safe_answer
(= (researchAssistantResponseActionId
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $actionId
)

;; Return response individuation score.
;; Example: (researchAssistantResponseIndividuation response) -> 0.9
(= (researchAssistantResponseIndividuation
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $individuation
)

;; Return response transcendence score.
;; Example: (researchAssistantResponseTranscendence response) -> 0.5
(= (researchAssistantResponseTranscendence
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $transcendence
)

;; Return the local curiosity action id captured in the response.
;; Example: (researchAssistantResponseCuriosityAction response) -> guided_explore
(= (researchAssistantResponseCuriosityAction
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $curiosityAction
)

;; Return the local ethics action id captured in the response.
;; Example: (researchAssistantResponseEthicsAction response) -> safe_answer
(= (researchAssistantResponseEthicsAction
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $ethicsAction
)

;; Return simulated peer caution.
;; Example: (researchAssistantResponseSimulatedCaution response) -> 0.5
(= (researchAssistantResponseSimulatedCaution
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $simulatedCaution
)

;; Return reciprocal simulation error.
;; Example: (researchAssistantResponseSimulationError response) -> 0.0
(= (researchAssistantResponseSimulationError
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $simulationError
)

;; Return maximum local lax error.
;; Example: (researchAssistantResponseLaxError response) -> 0.0
(= (researchAssistantResponseLaxError
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $laxError
)

;; Return maximum local self-model drift.
;; Example: (researchAssistantResponseSelfModelDrift response) -> 0.0
(= (researchAssistantResponseSelfModelDrift
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $selfModelDrift
)

;; Return calibration markers captured in the response.
;; Example: (researchAssistantResponseCalibrationAdjustments response) -> ()
(= (researchAssistantResponseCalibrationAdjustments
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $calibrationAdjustments
)

;; Return the raw perception snapshot captured in the response.
;; Example: (researchAssistantResponseRawPerception response) -> snapshot
(= (researchAssistantResponseRawPerception
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $rawPerception
)

;; Return the calibrated perception snapshot captured in the response.
;; Example: (researchAssistantResponseCalibratedPerception response) -> snapshot
(= (researchAssistantResponseCalibratedPerception
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityAction
            $ethicsAction
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawPerception
            $calibratedPerception
        )
    )
    $calibratedPerception
)

;; Snapshot a perception for logging without recomputing features.
;; Example: (researchAssistantPerceptionSnapshot perception) -> snapshot
(= (researchAssistantPerceptionSnapshot $perception)
    (let* (
        ($stimulus (researchAssistantPerceptionStimulus $perception))
        ($signals (researchAssistantPerceptionSignals $perception))
    )
        (
            (stimulus_novelty (researchAssistantStimulusNovelty $stimulus))
            (stimulus_conduciveness (researchAssistantStimulusConduciveness $stimulus))
            (stimulus_risk (researchAssistantStimulusRisk $stimulus))
            (stimulus_effort (researchAssistantStimulusEffort $stimulus))
            (task_intent (researchAssistantSignalTaskIntent $signals))
            (ambiguity (researchAssistantSignalAmbiguity $signals))
            (citation_need (researchAssistantSignalCitationNeed $signals))
            (comparison_need (researchAssistantSignalComparisonNeed $signals))
            (summary_need (researchAssistantSignalSummaryNeed $signals))
            (exploration_need (researchAssistantSignalExplorationNeed $signals))
            (unsafe_pressure (researchAssistantSignalUnsafePressure $signals))
            (privacy_pressure (researchAssistantSignalPrivacyPressure $signals))
            (unsupported_claim_pressure (researchAssistantSignalUnsupportedClaimPressure $signals))
            (context_loss_pressure (researchAssistantSignalContextLossPressure $signals))
        )
    )
)

;; Build the response prompt payload sent to an LLM adapter.
;; Example: (researchAssistantResponsePrompt user no_context action state) -> prompt
(= (researchAssistantResponsePrompt $userText $paperContext $chosenAction $state)
    (let* (
        ($actionId (eval (candidateId $chosenAction)))
    )
        (researchAssistantResponsePromptRecord
            $userText
            $paperContext
            $actionId
            (eval (researchAssistantExecutionInstruction $actionId))
            (eval (stateGoal $state individuation))
            (eval (stateGoal $state transcendence))
            (researchAssistantSystemInstruction)
        )
    )
)

;; Build a provider request for the final natural-language response.
;; Example: (researchAssistantResponseProviderRequest user no_context action state) -> request
(= (researchAssistantResponseProviderRequest $userText $paperContext $chosenAction $state)
    (llmProviderRequest
        research_assistant
        (researchAssistantResponsePrompt $userText $paperContext $chosenAction $state)
        final_response_text
        0.2
        False
    )
)

;; Build controlled fallback text when a provider cannot supply a final answer.
;; Example: (researchAssistantFallbackResponseText safe_answer unavailable) -> fallback record
(= (researchAssistantFallbackResponseText $actionId $reason)
    (researchAssistantFallbackText
        $actionId
        $reason
        (researchAssistantExecutionInstruction $actionId)
    )
)

;; Normalize a provider result to response text or a controlled fallback record.
;; Example: (researchAssistantProviderResponseText (llmProviderSuccess text) safe_answer) -> text
(= (researchAssistantProviderResponseText $providerResult $actionId)
    (case $providerResult (
        ((llmProviderSuccess $text) $text)
        ((llmProviderError $code $details $retryable)
            (researchAssistantFallbackResponseText $actionId $code)
        )
        ($_ (researchAssistantFallbackResponseText $actionId malformed-provider-result))
    ))
)

;; Build the canonical AssistantResponse record.
;; Example: (researchAssistantBuildResponse user context action state c e 0.5 0.0 0.0 0.0 cal raw calibrated provider) -> response
(= (researchAssistantBuildResponse
        $userText
        $paperContext
        $chosenAction
        $mergedTarget
        $curiosityActionId
        $ethicsActionId
        $simulatedCaution
        $simulationError
        $laxError
        $selfModelDrift
        $calibration
        $rawPerception
        $calibratedPerception
        $providerResult
    )
    (let* (
        ($actionId (eval (candidateId $chosenAction)))
        ($text (eval (researchAssistantProviderResponseText $providerResult $actionId)))
        ($individuation (eval (stateGoal $mergedTarget individuation)))
        ($transcendence (eval (stateGoal $mergedTarget transcendence)))
        ($calibrationAdjustments (eval (researchAssistantCalibrationAdjustments $calibration)))
        ($rawSnapshot (eval (researchAssistantPerceptionSnapshot $rawPerception)))
        ($calibratedSnapshot (eval (researchAssistantPerceptionSnapshot $calibratedPerception)))
    )
        (assistantResponse
            $text
            $actionId
            $individuation
            $transcendence
            $curiosityActionId
            $ethicsActionId
            $simulatedCaution
            $simulationError
            $laxError
            $selfModelDrift
            $calibrationAdjustments
            $rawSnapshot
            $calibratedSnapshot
        )
    )
)
