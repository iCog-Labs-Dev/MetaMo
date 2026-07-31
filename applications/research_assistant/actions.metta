
;; Return actions in deterministic Python order.
;; Example: (researchAssistantActionOrder) -> (safe_answer guided_explore ...)
(= (researchAssistantActionOrder)
    (safe_answer guided_explore ask_clarifying_question compare_options summarize_source decline_risky_request)
)

;; Return planning instruction for an action.
;; Example: (researchAssistantPlanningInstruction safe_answer) -> careful_grounded_answer
(= (researchAssistantPlanningInstruction $actionId)
    (symbolMapGet
        (
            (safe_answer careful_grounded_answer_using_supported_claims)
            (guided_explore creative_bounded_exploration_with_uncertainty)
            (ask_clarifying_question one_focused_clarification)
            (compare_options compare_alternatives_and_tradeoffs)
            (summarize_source faithful_concise_source_summary)
            (decline_risky_request refuse_risky_request_and_redirect)
        )
        $actionId
        unknown_action
    )
)

;; Return execution instruction for an action.
;; Example: (researchAssistantExecutionInstruction safe_answer) -> answer_cautiously
(= (researchAssistantExecutionInstruction $actionId)
    (symbolMapGet
        (
            (safe_answer answer_cautiously_with_supported_facts)
            (guided_explore explore_constructively_with_clear_uncertainty)
            (ask_clarifying_question ask_one_short_clarifying_question)
            (compare_options present_concise_tradeoff_comparison)
            (summarize_source summarize_faithfully_without_unsupported_claims)
            (decline_risky_request briefly_refuse_and_offer_safe_alternative)
        )
        (researchAssistantNormalizeActionId $actionId)
        unknown_action
    )
)

;; Normalize action aliases into canonical ids.
;; Example: (researchAssistantNormalizeActionId risky_explore) -> guided_explore
(= (researchAssistantNormalizeActionId $actionId)
    (if (listContains (researchAssistantActionOrder) $actionId)
        $actionId
        (symbolMapGet
            (
                (risky_exploration guided_explore)
                (risky_explore guided_explore)
                (explore guided_explore)
                (clarify ask_clarifying_question)
                (clarifying_question ask_clarifying_question)
                (compare compare_options)
                (summary summarize_source)
                (summarize summarize_source)
                (decline decline_risky_request)
                (refuse decline_risky_request)
            )
            $actionId
            (validationError unknown-research-assistant-action-id $actionId)
        )
    )
)

;; Return a compact action spec record.
;; Example: (researchAssistantActionSpec safe_answer) -> (researchAssistantActionSpecRecord ...)
(= (researchAssistantActionSpec $actionId)
    (let* (
        ($canonical (researchAssistantNormalizeActionId $actionId))
    )
        (researchAssistantActionSpecRecord
            $canonical
            (researchAssistantPlanningInstruction $canonical)
            (researchAssistantExecutionInstruction $canonical)
        )
    )
)

