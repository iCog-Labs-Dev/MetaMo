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
!(import! &self "../io_bridge.py")
!(import! &self "adapters/cli_bridge.py")


(= (researchAssistantCliIntentSymbol $value)
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

;; Round a number for compact CLI display.
(= (researchAssistantCliFormatFloat $value)
    (roundNum $value 2)
)

;; Deterministically adapt raw CLI text into the semantic perception record.
(= (researchAssistantCliPerceptionFromText $userText)
    (let* (
        ($intent (researchAssistantCliIntentSymbol (py-call (cli_bridge.task_intent $userText))))
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

;; Print the Python-compatible response report.
(= (researchAssistantCliPrintResponse $response)
    (let* (
        ($curiosityAction (eval (researchAssistantResponseCuriosityAction $response)))
        ($ethicsAction (eval (researchAssistantResponseEthicsAction $response)))
        ($simulatedCaution (eval (researchAssistantCliFormatFloat (researchAssistantResponseSimulatedCaution $response))))
        ($simulationError (eval (researchAssistantCliFormatFloat (researchAssistantResponseSimulationError $response))))
        ($laxError (eval (researchAssistantCliFormatFloat (researchAssistantResponseLaxError $response))))
        ($selfModelDrift (eval (researchAssistantCliFormatFloat (researchAssistantResponseSelfModelDrift $response))))
        ($individuation (eval (researchAssistantCliFormatFloat (researchAssistantResponseIndividuation $response))))
        ($transcendence (eval (researchAssistantCliFormatFloat (researchAssistantResponseTranscendence $response))))
        ($text (eval (researchAssistantResponseText $response)))
        ($_ (py-call (io_bridge.print_output "  > [Curiosity Subsystem] wants to: " $curiosityAction)))
        ($_ (py-call (io_bridge.print_output "  > [Ethics Subsystem] wants to: " $ethicsAction)))
        ($_ (py-call (io_bridge.print_output "  > [Reciprocal Simulation]: Curiosity predicts Ethics caution " $simulatedCaution " (error " $simulationError ")")))
        ($_ (py-call (io_bridge.print_output "  > [Continuity]: lax error " $laxError ", self-model drift " $selfModelDrift)))
        ($_ (py-call (io_bridge.print_output "")))
        ($_ (py-call (io_bridge.print_output "Assistant: " $text)))
        ($_ (py-call (io_bridge.print_output "")))
        ($_ (py-call (io_bridge.print_output "[Consensus State -> Individuation: " $individuation " | Transcendence: " $transcendence "]")))
    )
        True
    )
)


;; Process a user command and return the next session state or exit.
(= (researchAssistantCliProcessFromCommand $command $session $userInput)
    (if (= $command quit)
        False
        (let* (
            ($_ (py-call (io_bridge.print_output "\n[MetaMo Internal Processing...]")))
            ($perception (eval (researchAssistantCliPerceptionFromText $userInput)))
            ($draftCycle (eval (researchAssistantRunCycle
                $session
                $userInput
                $perception
                (llmProviderSuccess research_assistant_cli_draft_response)
            )))
            ($draftResponse (eval (researchAssistantCycleResponse $draftCycle)))
            ($actionId (eval (researchAssistantResponseActionId $draftResponse)))
            ($providerText (py-call (cli_bridge.final_response_text $userInput $actionId)))
            ($result (eval (researchAssistantDispatch
                $session
                (researchAssistantTextCommand
                    $userInput
                    $perception
                    (llmProviderSuccess $providerText)
                )
            )))
            ($response (eval (researchAssistantCommandOutput $result)))
            ($nextSession (eval (researchAssistantCommandNextSession $result)))
            ($_ (researchAssistantCliPrintResponse $response))
        )
            (interactiveLoop $nextSession)
        ))
    )

;; Dispatch raw CLI input by a concrete control label.
(= (processUserInput $session $userInput)
    (let* (
        ($command (py-call (cli_bridge.command_label $userInput)))
    )
        (researchAssistantCliProcessFromCommand $command $session $userInput)
    )
)

;; Read one input line and dispatch it.
(= (interactiveLoop $session)
    (let* (
        ($userInput (py-call (io_bridge.read_user_input "\nYou: ")))
    )
        (processUserInput $session $userInput)
    )
)

;; Start the runnable Research Assistant CLI.
(= (startAssistant)
    (let* (
        ($_ (py-call (io_bridge.print_output "Initializing MetaMo Multi-Subsystem Chat Interface ...")))
        ($_ (py-call (io_bridge.print_output "\nSystem Ready. Subsystems: [Curiosity] & [Ethics]. Type 'quit' to exit.")))
        ($_ (py-call (io_bridge.print_output "------------------------------------------------------------")))
    )
        (interactiveLoop (researchAssistantNewSession))
    )
)

!(startAssistant)
