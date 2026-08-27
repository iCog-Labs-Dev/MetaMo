
;; Build the default Research Assistant motivational state.
;; Example: (researchAssistantDefaultState) -> motivationState
(= (researchAssistantDefaultState)
    (motivationState
        (researchAssistantSchema)
        (researchAssistantDefaultGoals)
        (researchAssistantDefaultModulators)
    )
)

;; Set one default Research Assistant goal by name.
;; Example: (researchAssistantStateWithGoal transcendence 0.9) -> updated-state
(= (researchAssistantStateWithGoal $goalName $value)
    (stateSetGoal (researchAssistantDefaultState) $goalName $value)
)

;; Build the curiosity perspective state used by the engine.
;; Example: (researchAssistantCuriosityState) -> state with transcendence 0.9
(= (researchAssistantCuriosityState)
    (researchAssistantStateWithGoal transcendence 0.9)
)

;; Build the ethics perspective state used by the engine.
;; Example: (researchAssistantEthicsState) -> state with individuation 0.9
(= (researchAssistantEthicsState)
    (researchAssistantStateWithGoal individuation 0.9)
)

;; Serialize an application state as schema id plus coordinates.
;; Example: (researchAssistantStateSnapshot (researchAssistantDefaultState)) -> snapshot
(= (researchAssistantStateSnapshot $state)
    (researchAssistantStateSnapshotRecord (motivationSchemaId (stateSchema $state)) (stateGoals $state) (stateModulators $state))
)

;; Restore an application state snapshot.
;; Example: (researchAssistantStateFromSnapshot (researchAssistantStateSnapshot state)) -> state
(= (researchAssistantStateFromSnapshot (researchAssistantStateSnapshotRecord $schemaId $goals $modulators))
    (if (== $schemaId research_assistant)
        (motivationState (researchAssistantSchema) $goals $modulators)
        (validationError wrong-research-assistant-schema $schemaId)
    )
)

