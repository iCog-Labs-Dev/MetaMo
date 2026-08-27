!(import! &self ../../../core/validation)
!(import! &self ../../../core/schema)
!(import! &self ../../../core/features)
!(import! &self ../../../core/state)
!(import! &self ../../../core/helper)
!(import! &self "../../../core/helpers.py")
!(import! &self ../../../core/runtime)
!(import! &self ../../../openpsi/profile)
!(import! &self ../../../openpsi/appraisal)
!(import! &self ../../../magus/profile)
!(import! &self ../../../magus/goal_change)
!(import! &self ../../../magus/decision)
!(import! &self ../../../dynamics/stability)
!(import! &self ../../../dynamics/coherence)
!(import! &self ../../../category/diagnostics)
!(import! &self ../../../category/bimonad)
!(import! &self ../../../category/merge)
!(import! &self ../../../category/functors)
!(import! &self ../../../category/laws)
!(import! &self ../../../applications/common/openpsi_conventions)
!(import! &self ../schema)
!(import! &self ../state)
!(import! &self ../stimulus)
!(import! &self ../actions)
!(import! &self ../calibration)
!(import! &self ../appraisal_profile)
!(import! &self ../decision_profile)
!(import! &self ../translations)
!(import! &self ../planning)
!(import! &self ../prompts)
!(import! &self ../llm/providers)
!(import! &self ../llm/conversation)
!(import! &self ../papers/services/ingestion)
!(import! &self ../bundle)
!(import! &self ../response)
!(import! &self ../engine)
!(import! &self ../main)

!(test
    (bundleId (researchAssistantBundle))
    research_assistant
)

!(test
    (stateGoal
        (researchAssistantEngineCuriosityState (researchAssistantInitialEngineState))
        transcendence
    )
    0.9
)

!(test
    (stateGoal
        (researchAssistantEngineEthicsState (researchAssistantInitialEngineState))
        individuation
    )
    0.9
)

!(test
    (researchAssistantResponseActionId
        (assistantResponse text safe_answer 0.9 0.5 safe_answer safe_answer 0.5 0.0 0.0 0.0 () raw calibrated)
    )
    safe_answer
)

(= (engineBundlePerception $intent $ambiguity $citation $comparison $summary $explore $unsafe $privacy $unsupported $context)
    (researchAssistantPerception
        (makeResearchAssistantStimulus 0.2 0.8 0.1 0.2)
        (makeResearchAssistantSignals $intent $ambiguity $citation $comparison $summary $explore $unsafe $privacy $unsupported $context)
    )
)

(= (engineBundleAnswerPerception)
    (engineBundlePerception answer 0.1 0.6 0.0 0.0 0.2 0.0 0.0 0.0 0.0)
)

(= (engineBundleClarifyPerception)
    (engineBundlePerception clarify 0.9 0.1 0.0 0.0 0.1 0.0 0.0 0.0 0.0)
)

(= (engineBundleComparePerception)
    (engineBundlePerception compare 0.1 0.4 0.9 0.0 0.2 0.0 0.0 0.0 0.0)
)

(= (engineBundleSummarizePerception)
    (engineBundlePerception summarize 0.1 0.7 0.0 0.9 0.1 0.0 0.0 0.0 0.0)
)

(= (engineBundleExplorePerception)
    (engineBundlePerception explore 0.1 0.1 0.0 0.0 0.9 0.0 0.0 0.0 0.0)
)

(= (engineBundleUnsafePerception)
    (engineBundlePerception decline 0.1 0.0 0.0 0.0 0.1 0.9 0.2 0.2 0.0)
)

(= (engineBundlePrepared $perception)
    (eval (researchAssistantPrepareCycle
        (researchAssistantInitialEngineState)
        $perception
    ))
)

(= (engineBundleLocalCuriosityAction $perception)
    (let* (
        ($prepared (engineBundlePrepared $perception))
        ($step (eval (researchAssistantDiagnosedStep
            (researchAssistantEngineCuriosityState (researchAssistantInitialEngineState))
            (researchAssistantPreparedPerception $prepared)
            (researchAssistantPreparedCandidates $prepared)
        )))
    )
        (eval (candidateId (diagnosedAction $step)))
    )
)

(= (engineBundleCycle $perception)
    (eval (researchAssistantRunCycle
        (researchAssistantInitialEngineState)
        sample_user_text
        $perception
        (llmProviderSuccess deterministic_final_text)
    ))
)

(= (engineBundleCycleResponse $perception)
    (eval (researchAssistantCycleResponse (engineBundleCycle $perception)))
)

(= (engineBundleCycleAction $perception)
    (eval (researchAssistantResponseActionId (engineBundleCycleResponse $perception)))
)

!(test
    (validationIsOk (eval (validateApplicationBundle (researchAssistantBundle))))
    True
)

!(test
    (case (engineBundlePrepared (engineBundleAnswerPerception)) (
        ((researchAssistantPreparedCycle $raw $calibration $perception $merged $mood $candidates) True)
        ($_ False)
    ))
    True
)

!(test
    (engineBundleLocalCuriosityAction (engineBundleAnswerPerception))
    guided_explore
)

!(test
    (engineBundleCycleAction (engineBundleAnswerPerception))
    safe_answer
)

!(test
    (engineBundleCycleAction (engineBundleClarifyPerception))
    ask_clarifying_question
)

!(test
    (engineBundleCycleAction (engineBundleComparePerception))
    compare_options
)

!(test
    (engineBundleCycleAction (engineBundleSummarizePerception))
    summarize_source
)

!(test
    (engineBundleCycleAction (engineBundleExplorePerception))
    guided_explore
)

!(test
    (engineBundleCycleAction (engineBundleUnsafePerception))
    decline_risky_request
)

!(test
    (researchAssistantResponseText (engineBundleCycleResponse (engineBundleAnswerPerception)))
    deterministic_final_text
)

!(test
    (researchAssistantResponseCalibrationAdjustments (engineBundleCycleResponse (engineBundleAnswerPerception)))
    (calibration_context_loss_floor_checked calibration_citation_floor_checked calibration_exploration_cap_checked calibration_risk_floor_checked calibration_effort_floor_checked)
)

!(test
    (researchAssistantEngineHistory
        (researchAssistantCycleNextEngine (engineBundleCycle (engineBundleAnswerPerception)))
    )
    ((researchAssistantConversationTurn sample_user_text deterministic_final_text))
)

!(test
    (case (eval (researchAssistantDispatch
        (researchAssistantInitialEngineState)
        (researchAssistantTextCommand
            sample_user_text
            (engineBundleAnswerPerception)
            (llmProviderSuccess deterministic_final_text)
        )
    )) (
        ((researchAssistantCommandResult $session $output) (researchAssistantResponseActionId $output))
        ($_ no_command)
    ))
    safe_answer
)
