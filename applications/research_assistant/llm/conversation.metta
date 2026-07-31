;; Return system instruction symbol for provider requests.
;; Example: (researchAssistantSystemInstruction) -> metamo_research_assistant_system_instruction
(= (researchAssistantSystemInstruction)
    metamo_research_assistant_system_instruction
)

;; Build a final-response request from selected action and state.
;; Example: (researchAssistantFinalResponseRequest "hello" action state) -> request
(= (researchAssistantFinalResponseRequest $userText $chosenAction $state)
    (researchAssistantFinalResponseRequestRecord
        $userText
        (candidateId $chosenAction)
        (stateGoal $state individuation)
        (stateGoal $state transcendence)
        (researchAssistantExecutionInstruction (candidateId $chosenAction))
        (researchAssistantSystemInstruction)
    )
)

;; Append a conversation turn to history.
;; Example: (researchAssistantAppendTurn () user assistant) -> turns
(= (researchAssistantAppendTurn $history $userText $assistantText)
    (listAppend $history ((researchAssistantConversationTurn $userText $assistantText)))
)

