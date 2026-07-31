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
!(import! &self ../../../magus/correlation)
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
!(import! &self ../eval_bench)

(= (evalBenchAnswerPerception)
    (researchAssistantPerception
        (makeResearchAssistantStimulus 0.2 0.8 0.1 0.2)
        (makeResearchAssistantSignals answer 0.1 0.6 0.0 0.0 0.2 0.0 0.0 0.0 0.0)
    )
)

(= (evalBenchResponse)
    (eval (researchAssistantEvalPreparedResponse
        (researchAssistantInitialEngineState)
        eval_bench_user_text
        (evalBenchAnswerPerception)
        deterministic_eval_response
    ))
)

(= (evalBenchNextSession)
    (eval (researchAssistantEvalPreparedNextSession
        (researchAssistantInitialEngineState)
        eval_bench_user_text
        (evalBenchAnswerPerception)
        deterministic_eval_response
    ))
)

(= (evalBenchDirectCycle)
    (eval (researchAssistantRunCycle
        (researchAssistantInitialEngineState)
        eval_bench_user_text
        (evalBenchAnswerPerception)
        (llmProviderSuccess deterministic_eval_response)
    ))
)

(= (evalBenchDirectAction)
    (eval (researchAssistantResponseActionId
        (eval (researchAssistantCycleResponse (evalBenchDirectCycle)))
    ))
)

!(test
    (researchAssistantEvalIntentSymbol compare)
    compare
)

!(test
    (researchAssistantEvalIntentSymbol summarize)
    summarize
)

!(test
    (researchAssistantEvalIntentSymbol clarify)
    clarify
)

!(test
    (evalBenchDirectAction)
    safe_answer
)

!(test
    (eval (researchAssistantResponseText
        (evalBenchResponse)
    ))
    deterministic_eval_response
)

!(test
    (eval (researchAssistantResponseActionId
        (researchAssistantCommandOutput
            (researchAssistantDispatch
                (evalBenchNextSession)
                (researchAssistantTextCommand
                    eval_bench_second_turn
                    (evalBenchAnswerPerception)
                    deterministic_eval_response_2
                )
            )
        )
    ))
    safe_answer
)

!(test
    (eval (diagnosticsCount
        (researchAssistantEngineDiagnosticsHistory
            (evalBenchNextSession)
        )
    ))
    2
)
