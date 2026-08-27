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

(: ResearchAssistantCommandResult Type)
(: researchAssistantCommandResult (-> ResearchAssistantEngineState Expression ResearchAssistantCommandResult))

;; Create a new Research Assistant session.
(= (researchAssistantNewSession)
    (researchAssistantInitialEngineState)
)

;; Create a session with a supplied paper context.
(= (researchAssistantNewSessionWithPaperContext $paperContext)
    (researchAssistantSetPaperContext
        (researchAssistantInitialEngineState)
        $paperContext
    )
)

;; Build a text-cycle command record.
(= (researchAssistantTextCommand $userText $rawPerception $providerResult)
    (researchAssistantCommand text_cycle $userText $rawPerception $providerResult)
)

;; Build a paper-context command record.
(= (researchAssistantSetPaperContextCommand $paperContext)
    (researchAssistantCommand set_paper_context $paperContext none none)
)

;; Build an ingestion effect command record.
(= (researchAssistantIngestPaperCommand $path)
    (researchAssistantCommand ingest_paper $path none none)
)

;; Dispatch a text cycle command.
(= (researchAssistantDispatch $session (researchAssistantCommand text_cycle $userText $rawPerception $providerResult))
    (let* (
        ($cycle (eval (researchAssistantRunCycle $session $userText $rawPerception $providerResult)))
    )
        (researchAssistantCommandResult
            (eval (researchAssistantCycleNextEngine $cycle))
            (eval (researchAssistantCycleResponse $cycle))
        )
    )
)

;; Dispatch a paper-context update command without changing motivational states.
(= (researchAssistantDispatch $session (researchAssistantCommand set_paper_context $paperContext $unusedA $unusedB))
    (let* (
        ($next (researchAssistantSetPaperContext $session $paperContext))
    )
        (researchAssistantCommandResult $next paper_context_updated)
    )
)

;; Dispatch a paper ingestion command as an effect request; adapters execute it.
(= (researchAssistantDispatch $session (researchAssistantCommand ingest_paper $path $unusedA $unusedB))
    (researchAssistantCommandResult
        $session
        (researchAssistantPaperIngestionRequest $path)
    )
)

;; Return the next session state from a command result.
(= (researchAssistantCommandNextSession (researchAssistantCommandResult $session $output))
    $session
)

;; Return command output.
(= (researchAssistantCommandOutput (researchAssistantCommandResult $session $output))
    $output
)
