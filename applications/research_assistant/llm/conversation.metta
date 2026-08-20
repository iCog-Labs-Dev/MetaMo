;; Build a final-response request from selected action and state.
;; Example: (researchAssistantFinalResponseRequest "hello" action state) -> request
(= (researchAssistantFinalResponseRequest $userText $chosenAction $state)
    (researchAssistantFinalResponseRequestRecord
        $userText
        (candidateId $chosenAction)
        (stateGoal $state individuation)
        (stateGoal $state transcendence)
        (researchAssistantExecutionInstruction (candidateId $chosenAction))
    )
)

;; Append a conversation turn to history.
;; Example: (researchAssistantAppendTurn () user assistant) -> turns
(= (researchAssistantAppendTurn $history $userText $assistantText)
    (listAppend $history ((researchAssistantConversationTurn $userText $assistantText)))
)

