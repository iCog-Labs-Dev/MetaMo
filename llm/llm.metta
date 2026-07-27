;; getStimulusFromText
;; Calls the LLM pipeline to appraise text and returns a Stimulus state.
;; Example: (getStimulusFromText "I want to explore the woods")
;; Returns: (stimulus (novelty conduciveness risk effort))
(= (getStimulusFromText $text)
    (let $values (py-call (metta_bridge.get_stimulus_as_list $text))
        (stimulus $values)
    )
)

;; Helper to unpack a single Python action list into a MeTTa action expression
(= (unpackAction $actionList)
    (let* (
        ($id (index-atom $actionList 0))
        ($corrs (index-atom $actionList 1))
        ($risk (index-atom $actionList 2))
        ($deltas (index-atom $actionList 3))
    )
        (action $id $corrs $risk $deltas)
    )
)

;; Helper to unpack a list of Python actions into a tuple of MeTTa actions
(= (unpackActionsTuple $actionsList $idx $length)
    (if (>= $idx $length)
        ()
        (let* (
            ($action (index-atom $actionsList $idx))
            ($unpacked (unpackAction $action))
            ($rest (unpackActionsTuple $actionsList (+ $idx 1) $length))
        )
            (cons-atom $unpacked $rest)
        )
    )
)

;; getCandidatesFromText
;; Calls the LLM pipeline to generate candidate actions based on text and current mood.
;; Example: (getCandidatesFromText "text" 0.5 0.5)
;; Returns: ((action ...) (action ...))
(= (getCandidatesFromText $text $arousal $caution)
    (let* (
        ($pyList (py-call (metta_bridge.get_candidates_as_list $text $arousal $caution)))
        ($length (size-atom $pyList))
    )
        (unpackActionsTuple $pyList 0 $length)
    )
)

;; analyzeTurnFromText
;; Makes one semantic-analysis request and returns both the stimulus and locally
;; selected candidate actions.
;; Returns: ((stimulus (...)) ((action ...) ...))
(= (analyzeTurnFromText $text $arousal $caution)
    (let* (
        ($analysis (py-call (metta_bridge.analyze_turn_as_lists $text $arousal $caution)))
        ($stimulusValues (index-atom $analysis 0))
        ($actionsList (index-atom $analysis 1))
        ($length (size-atom $actionsList))
        ($candidates (unpackActionsTuple $actionsList 0 $length))
    )
        ((stimulus $stimulusValues) $candidates)
    )
)

;; llmGenerateFinalResponse
;; Calls the LLM conversation module to produce the final chat response.
;; Example: (llmGenerateFinalResponse "hello" "safe_answer" 0.5 0.5)
;; Returns: "String response"
(= (llmGenerateFinalResponse $userText $actionId $indLevel $transLevel)
    (py-call (metta_bridge.generate_final_response $userText $actionId $indLevel $transLevel))
)
