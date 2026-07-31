!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/features)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../../core/runtime)
!(import! &self ../../core/registry)
!(import! &self ../../openpsi/profile)
!(import! &self ../../openpsi/appraisal)
!(import! &self ../../magus/profile)
!(import! &self ../../magus/correlation)
!(import! &self ../../magus/goal_change)
!(import! &self ../../magus/decision)
!(import! &self ../../dynamics/stability)
!(import! &self ../../dynamics/coherence)
!(import! &self ../../category/diagnostics)
!(import! &self ../../category/bimonad)
!(import! &self ../../category/merge)
!(import! &self ../../category/functors)
!(import! &self ../../category/laws)
!(import! &self ../common/openpsi_conventions)
!(import! &self schema)
!(import! &self state)
!(import! &self stimulus)
!(import! &self actions)
!(import! &self calibration)
!(import! &self appraisal_profile)
!(import! &self decision_profile)
!(import! &self translations)
!(import! &self planning)
!(import! &self prompts)
!(import! &self llm/providers)
!(import! &self llm/conversation)
!(import! &self papers/config)
!(import! &self papers/entities)
!(import! &self papers/services/ingestion)
!(import! &self bundle)
!(import! &self response)
!(import! &self engine)
!(import! &self main)
!(import! &self "adapters/cli_bridge.py")
!(import! &self "adapters/eval_bridge.py")

(: ResearchAssistantEvalCaseResult Type)
(: researchAssistantEvalCaseResult (-> ResearchAssistantEngineState AssistantResponse ResearchAssistantEvalCaseResult))

;; Convert live provider task-intent text into the canonical MeTTa symbol.
(= (researchAssistantEvalIntentSymbol $value)
    (case $value (
        (answer answer)
        (summarize summarize)
        (compare compare)
        (clarify clarify)
        (explore explore)
        (decline decline)
        ($_ answer)
    ))
)

;; Adapt raw text into a live semantic perception through the configured LLM.
(= (researchAssistantEvalPerceptionFromText $userText)
    (let* (
        ($intent (researchAssistantEvalIntentSymbol (py-call (cli_bridge.task_intent $userText))))
    )
        (researchAssistantPerception
            (makeResearchAssistantStimulus
                (py-call (cli_bridge.stimulus_novelty $userText))
                (py-call (cli_bridge.stimulus_conduciveness $userText))
                (py-call (cli_bridge.stimulus_risk $userText))
                (py-call (cli_bridge.stimulus_effort $userText))
            )
            (makeResearchAssistantSignals
                $intent
                (py-call (cli_bridge.ambiguity $userText))
                (py-call (cli_bridge.citation_need $userText))
                (py-call (cli_bridge.comparison_need $userText))
                (py-call (cli_bridge.summary_need $userText))
                (py-call (cli_bridge.exploration_need $userText))
                (py-call (cli_bridge.unsafe_pressure $userText))
                (py-call (cli_bridge.privacy_pressure $userText))
                (py-call (cli_bridge.unsupported_claim_pressure $userText))
                (py-call (cli_bridge.context_loss_pressure $userText))
            )
        )
    )
)

;; Run one case with an already prepared perception and final provider text.
(= (researchAssistantEvalPreparedCycle $session $userText $rawPerception $providerText)
    (eval (researchAssistantRunCycle
        $session
        $userText
        $rawPerception
        (llmProviderSuccess $providerText)
    ))
)

;; Return the response from a prepared eval cycle.
(= (researchAssistantEvalPreparedResponse $session $userText $rawPerception $providerText)
    (case (eval (researchAssistantRunCycle
            $session
            $userText
            $rawPerception
            (llmProviderSuccess $providerText)
        )) (
        ((researchAssistantCycleResult $nextEngine $response $diagnostics $prepared) $response)
        ($_ no_eval_response)
    ))
)

;; Return the next session from a prepared eval cycle.
(= (researchAssistantEvalPreparedNextSession $session $userText $rawPerception $providerText)
    (case (eval (researchAssistantRunCycle
            $session
            $userText
            $rawPerception
            (llmProviderSuccess $providerText)
        )) (
        ((researchAssistantCycleResult $nextEngine $response $diagnostics $prepared) $nextEngine)
        ($_ $session)
    ))
)

;; Return the selected action id from a prepared eval cycle.
(= (researchAssistantEvalPreparedActionId $session $userText $rawPerception $providerText)
    (case (eval (researchAssistantEvalPreparedResponse $session $userText $rawPerception $providerText)) (
        ((assistantResponse
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
            $raw
            $calibrated
        ) $actionId)
        ($_ no_eval_action)
    ))
)

;; Run one case with an already prepared perception and final provider text.
(= (researchAssistantEvalRunPreparedCase $session $userText $rawPerception $providerText)
    (researchAssistantEvalCaseResult
        (researchAssistantEvalPreparedNextSession $session $userText $rawPerception $providerText)
        (researchAssistantEvalPreparedResponse $session $userText $rawPerception $providerText)
    )
)

;; Run one live case by calling the configured LLM for perception and response.
(= (researchAssistantEvalRunLiveCase $session $userText)
    (let* (
        ($rawPerception (eval (researchAssistantEvalPerceptionFromText $userText)))
        ($actionId (eval (researchAssistantEvalPreparedActionId
            $session
            $userText
            $rawPerception
            research_assistant_eval_draft_response
        )))
        ($providerText (py-call (cli_bridge.final_response_text $userText $actionId)))
    )
        (researchAssistantEvalRunPreparedCase
            $session
            $userText
            $rawPerception
            $providerText
        )
    )
)

;; Return the next session from an eval case result.
(= (researchAssistantEvalCaseNextSession (researchAssistantEvalCaseResult $session $response))
    (eval $session)
)

;; Return the assistant response from an eval case result.
(= (researchAssistantEvalCaseResponse (researchAssistantEvalCaseResult $session $response))
    (eval $response)
)

;; Retrieve a named value from a response perception snapshot.
(= (researchAssistantEvalSnapshotValue $snapshot $name)
    (featurePairsGet $snapshot $name "")
)

;; Emit a Python-eval-compatible case row through the eval bridge.
(= (researchAssistantEvalEmitCaseResult
        $caseId
        $taskType
        $riskLabel
        $paperPath
        $query
        $expectedAction
        $acceptableActions
        $response
    )
    (case (eval $response) (
        ((assistantResponse
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
            $raw
            $calibrated
        )
            (py-call (eval_bridge.emit_case_result
                $caseId
                $taskType
                $riskLabel
                $paperPath
                $query
                $expectedAction
                $acceptableActions
                $actionId
                $curiosityAction
                $ethicsAction
                $individuation
                $transcendence
                $simulationError
                $laxError
                $selfModelDrift
                $calibrationAdjustments
                $text
                (eval (researchAssistantEvalSnapshotValue $raw stimulus_novelty))
                (eval (researchAssistantEvalSnapshotValue $raw stimulus_conduciveness))
                (eval (researchAssistantEvalSnapshotValue $raw stimulus_risk))
                (eval (researchAssistantEvalSnapshotValue $raw stimulus_effort))
                (eval (researchAssistantEvalSnapshotValue $raw task_intent))
                (eval (researchAssistantEvalSnapshotValue $raw ambiguity))
                (eval (researchAssistantEvalSnapshotValue $raw citation_need))
                (eval (researchAssistantEvalSnapshotValue $raw comparison_need))
                (eval (researchAssistantEvalSnapshotValue $raw summary_need))
                (eval (researchAssistantEvalSnapshotValue $raw exploration_need))
                (eval (researchAssistantEvalSnapshotValue $raw unsafe_pressure))
                (eval (researchAssistantEvalSnapshotValue $raw privacy_pressure))
                (eval (researchAssistantEvalSnapshotValue $raw unsupported_claim_pressure))
                (eval (researchAssistantEvalSnapshotValue $raw context_loss_pressure))
                (eval (researchAssistantEvalSnapshotValue $calibrated stimulus_novelty))
                (eval (researchAssistantEvalSnapshotValue $calibrated stimulus_conduciveness))
                (eval (researchAssistantEvalSnapshotValue $calibrated stimulus_risk))
                (eval (researchAssistantEvalSnapshotValue $calibrated stimulus_effort))
                (eval (researchAssistantEvalSnapshotValue $calibrated task_intent))
                (eval (researchAssistantEvalSnapshotValue $calibrated ambiguity))
                (eval (researchAssistantEvalSnapshotValue $calibrated citation_need))
                (eval (researchAssistantEvalSnapshotValue $calibrated comparison_need))
                (eval (researchAssistantEvalSnapshotValue $calibrated summary_need))
                (eval (researchAssistantEvalSnapshotValue $calibrated exploration_need))
                (eval (researchAssistantEvalSnapshotValue $calibrated unsafe_pressure))
                (eval (researchAssistantEvalSnapshotValue $calibrated privacy_pressure))
                (eval (researchAssistantEvalSnapshotValue $calibrated unsupported_claim_pressure))
                (eval (researchAssistantEvalSnapshotValue $calibrated context_loss_pressure))
            ))
        )
        ($_ False)
    ))
)

;; Emit one diagnostics record through the eval bridge.
(= (researchAssistantEvalEmitDiagnosticsRecord
        (metaMoDiagnostics
            $actionId
            $laxError
            $laxTolerance
            $laxHolds
            $contractiveHolds
            $targetSafe
            $finalSafe
            $pressureBefore
            $pressureTarget
            $pressureFinal
            $projectionDelta
            $targetDistance
            $stateDrift
            $selfDrift
            $combinedDrift
            $selfDriftHolds
            $blendAlpha
            $baseBlendAlpha
        )
    )
    (py-call (eval_bridge.emit_diagnostics_record
        $actionId
        $laxError
        $laxTolerance
        $laxHolds
        $contractiveHolds
        $targetSafe
        $finalSafe
        $pressureBefore
        $pressureTarget
        $pressureFinal
        $projectionDelta
        $targetDistance
        $stateDrift
        $selfDrift
        $combinedDrift
        $selfDriftHolds
        $blendAlpha
        $baseBlendAlpha
    ))
)

;; Emit the full accumulated diagnostics history once at the end of a run.
(= (researchAssistantEvalEmitDiagnosticsHistory $items)
    (if (== $items ())
        True
        (let* (
            (($head $tail) (decons $items))
            ($_ (researchAssistantEvalEmitDiagnosticsRecord $head))
        )
            (researchAssistantEvalEmitDiagnosticsHistory $tail)
        )
    )
)
