
; Qwestor Main Loop
;
; Full pipeline:
;   1. Parse the user query into a structured context (Python wrap_parser)
;   2. Project the Qwestor space into a MetaMo motivation state (state_bridge)
;   3. Convert context list into a MetaMo stimulus (stimulus_adapter)
;   4. Run the MetaMo cycle to select the optimal action
;   5. Re-score all candidate actions against merged target
;   6. Return a comprehensive result including selected action, scores,
;      next motivation state, and stimulus values
;
; Entry point:
;   (runQwestor &space query)
;
; Returns:
;   (qwestor-result
;     (selected  <action-atom>)
;     (scores    (<ranked score+action pairs>))
;     (next-motivation <motivation-atom>)
;     (stimulus  <stimulus-values>)
;   )


!(import! &self anti_goal_helpers)
!(import! &self utils)
!(import! &self config)
!(import! &self "context_parser.py")
!(import! &self adapters/state_bridge)
!(import! &self adapters/stimulus_adapter)
!(import! &self adapters/qwestor_actions)

!(import! &self "../core/helpers.py")
!(import! &self ../core/helper)
!(import! &self ../core/state)
!(import! &self ../core/state_accessors)
!(import! &self ../core/config)
!(import! &self ../openpsi/config)
!(import! &self ../openpsi/appraisal_helpers)
!(import! &self ../openpsi/appraisal)
!(import! &self ../category/functors)
!(import! &self ../category/bimonad)
!(import! &self ../magus/decision)
!(import! &self ../dynamics/stability)
!(import! &self ../dynamics/coherence)
!(import! &self ../main/main)

!(import! &self "tests/session_short.py")
!(import! &self "../llm/metta_bridge.py")
!(import! &self ../llm/llm)
!(import! &self "session_store.py")
!(import! &self "metrics/qwestor_eval.py")
!(import! &self "../applications/io_bridge.py")
!(import! &self session_helpers)

!(bind! &session-control (new-space))
!(add-atom &session-control (active-session "session_a"))
!(bind! &space (new-space))
!(initializeSessionSpace &space)


; runQwestor
; Main function: full pipeline from user query to ranked actions and
; next motivation state.

(= (runQwestor $space $query)
  (let*
    (
      ; Step 1 ─ Parse the user query using Python context_parser
      ; Converts free-text query into structured list of context features

      ($context-list (py-call (context_parser.wrap_parser $query)))
      ($_ (println! ("[STEP 1] context-list: " $context-list)))

      ; Step 2 ─ Project Qwestor space into MetaMo motivation state
      ; This initializes the agent's internal motivational state

      ($current-motiv (eval (projectToMotivation $space)))
      
      ($_ (println! ("[STEP 2] current motivation: " $current-motiv)))

      ; Step 3 ─ Convert context list into MetaMo stimulus
      ; Maps contextual information to stimulus values usable by the cycle

      ($stimulus-vals (eval (projectStimulus $context-list)))
      ($stimulus-atom (stimulus $stimulus-vals))
      ($stimulus-final (eval (getStimulusValues $stimulus-atom)))
      ($_ (println! ("[STEP 3] stimulus: " $stimulus-final)))

      ; Step 4 ─ Wrap motivation state in subsystemStates for cycle
      ; Prepares input for MetaMo bimonad cycle

      ; this can be extended to multiple subsystems with different motivations if needed 
      ($states ((subsystemState qwestor $current-motiv) (subsystemState ethics $current-motiv)))
      ($_ (println! ("[STEP 4] state: " $states)))

      ; Step 5 ─ Retrieve candidate actions for Qwestor

      ($candidates (qwestorCandidatesForContextAndSpace $space $context-list))
      ($_ (println! ("[STEP 5] candidates: " $candidates)))

      ; Step 6 ─ Execute full MetaMo cycle

      ($bimonad (eval (defaultMetaMoBimonad)))
      ($_ (println! ("bimonad: " $bimonad)))

      ($stimulus-cycle (eval (integrationStimulus $stimulus-final)))
      ($_ (println! (" stimulus-cycle: " $stimulus-cycle)))

      ($cycle-result
        (runMetaMoCycleDefault
          (eval (defaultMetaMoBimonad))
          ; Single subsystem (Qwestor) for now, but can be extended to multiple
          ((subsystemState qwestor $current-motiv))
          (eval (integrationStimulus $stimulus-final))
          $candidates
          ()  
          ())
      )

      ($_ (println! ("[STEP 6] cycle-result: " $cycle-result)))

      ; Step 7 ─ Extract winning action and action identifier

      ($selected-action (cycleFinalAction $cycle-result))
      ($_ (println! ("[STEP 7] selected-action: " $selected-action)))
      ($action-name (actionId $selected-action))
      ($_ (println! ("[STEP 7] action-name: " $action-name)))
      
      ; Step 8 ─ Extract next motivation states from cycle result

      ($next-states (cycleNextStates $cycle-result))
      ($_ (println! ("[STEP 8] next-states: " $next-states)))

      ; Step 9 ─ Extract the next motivation for the Qwestor subsystem

      ($next-motiv (subsystemMotivation (car-atom $next-states)))
      ($_ (println! ("[STEP 9] next-motiv: " $next-motiv)))

      ($_ (injectMotivation $space $next-motiv))

      ($next-goals (motivationGoals $next-motiv))
      ($_ (println! ("next-goals: " $next-goals)))
      ($gInd   (index-atom $next-goals 0))
      ($_ (println! ("gInd: " $gInd)))

      ($gTrans (index-atom $next-goals 1))
      ($_ (println! ("gTrans " $gTrans)))

      ($answer (llmGenerateFinalResponse $query $action-name $gInd $gTrans))
      ($_ (println! ("\nAssistant: " $answer)))

      ; Step 10 ─ Compute merged target and decision-context candidate scores
      ; Scores explain the action choice and feed the JSON evaluation metrics.

      ($merged-target (cycleMergedTarget $cycle-result))
      ($_ (println! ("[STEP 10] merged-target: " $merged-target)))
      ($candidate-scores (qwestorCandidateScores $bimonad $current-motiv $stimulus-cycle $candidates))
      ($_ (println! ("[STEP 10] candidate-scores: " $candidate-scores)))
      ($_ (py-call (qwestor_eval.record_turn (sessionId) $query $action-name $answer $candidate-scores $context-list $stimulus-final)))

      ; Step 11 ─ Construct final Qwestor result object

      ($result (qwestor-result
          (selected         $action-name)
          (candidates       $candidates)
          (next-motivation  $next-motiv)
          (stimulus         $stimulus-vals)
      ))

    )
    
    ; Print the full Qwestor decision report
    (let $_ (printQwestorResult $result)
        ($action-name $answer)
    )
  )
)

(= (saveCurrentSession $space)
    (let*
        (
            ($state (match $space ($g $m $a) ($g $m $a)))
            ($goals (cdr-atom (index-atom $state 0)))
            ($mods  (cdr-atom (index-atom $state 1)))
            ($anti  (cdr-atom (index-atom $state 2)))
        )
        (py-call (session_store.save_session (sessionId) $goals $mods $anti))
    )
)

(= (qwestorLoop $space $query)
    (if (or (== $query quit) (== $query exit))
        (saveCurrentSession $space)
        (let* (
                ($turn-result (runQwestor $space $query))
                ($turn-action (index-atom $turn-result 0))
                ($turn-answer (index-atom $turn-result 1))
                ($_ (py-call (session_store.log_turn (sessionId) $query $turn-action $turn-answer)))
            )
            (qwestorLoop $space (py-call (io_bridge.read_user_input "\nYou: ")))
        )
    )
)

(= (qwestorLoopFromList $space $queries)
    (if (== $queries ())
        (saveCurrentSession $space)
        (let* (
            ($_ (println! ("All Queries in the given session: " $queries)))
            (($query $rest) (decons $queries))
            ($_ (println! ("Processing query: " $query)))
            ($turn-result (runQwestor $space $query))
            ($turn-action (index-atom $turn-result 0))
            ($turn-answer (index-atom $turn-result 1))
            ($_ (py-call (session_store.log_turn (sessionId) $query $turn-action $turn-answer)))
            ($_ (println! ("Turn result: " $turn-result)))
        )
            (qwestorLoopFromList $space $rest)
        )
    )
)

; Runs every session. The shared space is
; reset from that session's saved/default state before qwestorLoopFromList
; prints every step, answer, and turn result directly to the terminal.

(= (qwestorLoopFromAllSessions $space $session-ids)
    (if (== $session-ids ())
        (println! "All configured sessions completed.")
        (let* (
            (($session-id $rest) (decons $session-ids))
            ($_ (setSessionId $session-id))
            ($_ (println! ("\n========== Starting session: " $session-id " ==========")))
            ($old-state (match $space ($g $m $a) ($g $m $a)))
            ($_ (remove-atom $space $old-state))
            ($_ (initializeSessionSpace $space))
            ($_ (saveCurrentSession $space))
            ($_ (qwestorLoopFromList $space (sessionQueries)))
            ($_ (println! ("========== Finished session: " $session-id " ==========\n")))
        )
        (qwestorLoopFromAllSessions $space $rest))
    )
)
