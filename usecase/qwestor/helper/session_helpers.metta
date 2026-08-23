
; Session persistence helpers for Qwestor's space.

; updateState: replaces the current (goals modulators anti-goals) triple
; in the space with a new one.
; Example: (updateState &space newGoals newMods newAntiGoals)

(= (updateState $space $newGoals $newMods $newAntiGoals)
    (let*
        (
            ($oldState (match $space ($g $m $a) ($g $m $a)))
            ($_ (remove-atom $space $oldState)) 
            ($_(add-atom $space ($newGoals $newMods $newAntiGoals)))
        )
        "Space updated sucessfully"
    )
)

; injectMotivation: writes a MetaMo motivation state back into Qwestor's
; space. Reverse of projectToMotivation.
; Example: (injectMotivation &space nextMotivState)

(= (injectMotivation $space (motivation $g $m))
  (let*
    (
      ; unpack the OpenPSI goal vector  
      ($gInd   (index-atom $g 0))
      ($gTrans (index-atom $g 1))
      ($gHelp  (index-atom $g 2))
      ($gCurio (index-atom $g 3))
      ($gNovel (index-atom $g 4))
      ($gSelf  (index-atom $g 5))
      ($gEthic (index-atom $g 6))
      ($gSoc   (index-atom $g 7))

      ; unpack the OpenPSI modulator vector  
      ($val_openpsi (index-atom $m 0))
      ($m_ar   (index-atom $m 1))
      ($m_app  (index-atom $m 2))
      ($m_res  (index-atom $m 3))
      ($m_thr  (index-atom $m 4))
      ($m_sec  (index-atom $m 5))

      ; goals OpenPSI doesn't carry, kept from the space  
      ($efficiency           (getGoalQwestor $space efficiency))
      ($accuracy             (getGoalQwestor $space accuracy))
      ($coherence             (getGoalQwestor $space coherence))
      ($originality           (getGoalQwestor $space originality))
      ($over_beneficial       (getGoalQwestor $space over_beneficial))

      ; modulators OpenPSI doesn't carry, kept from the space  
      ($m_urgency           (getMod $space m_urgency))
      ($m_user_expertise    (getMod $space m_user_expertise))
      ($m_topic_familiarity (getMod $space m_topic_familiarity))
      ($m_failure_wariness  (getMod $space m_failure_wariness))
      ($m_risk_aversion     (getMod $space m_risk_aversion))
      ($m_error_tolerance   (getMod $space m_error_tolerance))
      ($m_creativity        (getMod $space m_creativity))

      ($anti_goals (match $space ($gg $mm $aa) $aa))

      ; valence: map OpenPSI's [0,1] back to Qwestor's [-1,1]
      ($m_val (eval (- (* $val_openpsi 2.0) 1.0)))

      ; rebuild Qwestor's goal vector  
      ($newGoals (goal-vector
        (efficiency           $efficiency)
        (accuracy             $accuracy)
        (success_moderate     $gSelf)
        (knowledge            $gCurio)
        (novelty              $gNovel)
        (success_breakthrough $gTrans)
        (coherence            $coherence)
        (originality          $originality)
        (social               $gSoc)
        (help_short           $gHelp)
        (help_long            $gHelp)
        (over_beneficial      $over_beneficial)
        (over_safety          $gInd)
        (over_honesty         $gEthic)
      ))

      ; rebuild Qwestor's modulator vector  
      ($newMods (modulator-vector
        (m_urgency           $m_urgency)
        (m_resolution        $m_res)
        (m_user_expertise    $m_user_expertise)
        (m_threshold         $m_thr)
        (m_topic_familiarity $m_topic_familiarity)
        (m_failure_wariness  $m_failure_wariness)
        (m_securing          $m_sec)
        (m_approach          $m_app)
        (m_arousal           $m_ar)
        (m_risk_aversion     $m_risk_aversion)
        (m_error_tolerance   $m_error_tolerance)
        (m_creativity        $m_creativity)
        (m_valence           $m_val)
      ))
    )
    (updateState $space $newGoals $newMods $anti_goals)
  )
)

; sessionRetrival
;
; Retrieves the previously stored user queries for a specific
; session from the session memory backend.

(= (sessionRetrival (sessionId))
   (let* (
      ($rw_res (py-call (session_short.get_session_queries (sessionId))))
      ($final_res (parse $rw_res))
   )
   $final_res)
)
; sessionQueries
;
; Convenience wrapper around sessionRetrival.
; Automatically retrieves the query history for the
; currently active session using the sessionId atom.

(= (sessionQueries) (sessionRetrival (sessionId)))

;sessionIds
;Returns all configured session IDs, newly appended sessions are included automatically.
(= (sessionIds)
   (let* (
      ($raw-ids (py-call (session_short.get_session_ids)))
      ($ids (parse $raw-ids))
   )
   $ids)
)

; Returns the identifier of the currently active session.
(= (sessionId)
    (match &session-control (active-session $session-id) $session-id)
)

; Switches the active session identifier.
;
; This only changes which session subsequent save/load operations target.
; It does NOT modify or erase any persisted session data. Each session's
; motivation state is stored independently by session_store using the
; session ID as the persistence key.

(= (setSessionId $session-id)
    (let* (
        ($old-session (match &session-control (active-session $old-id) (active-session $old-id)))
        ($_ (remove-atom &session-control $old-session))
        ($_ (add-atom &session-control (active-session $session-id)))
    )
    $session-id)
)

; initializeSessionSpace
;
; Initializes the shared AtomSpace for the currently active session.
;
; If a persisted session exists, its saved goals, modulators, and
; anti-goals are restored so execution continues from the previous
; motivational state. Otherwise, a new session is initialized with
; the default motivation state.

(= (initializeSessionSpace $space)
  (if (py-call (session_store.has_session (sessionId)))
    (addState $space (
        (goal-vector (py-call (session_store.load_goals (sessionId))))
        (modulator-vector (py-call (session_store.load_mods (sessionId))))
        (anti-goals (py-call (session_store.load_anti_goals (sessionId))))))
    (addState $space ((default-goals) (default-mods) (default-anti-goals)))
  )
)

; qwestorCandidateScoresForState
; Score each candidate in the same decision context that drives action choice.
(= (qwestorCandidateScoresForState $bimonad $decision-state $candidates)
  (if (== $candidates ())
      ()
      (let*
        (
          (($candidate $rest) (decons $candidates))
          ($score (eval (scoreCandidate (bimonadDecision $bimonad) $decision-state $candidate)))
          ($entry (action-score (actionId $candidate) $score))
        )
        (cons-atom $entry (qwestorCandidateScoresForState $bimonad $decision-state $rest))
      )
  )
)

; qwestorCandidateScores
;
; Builds the decision context from the current motivation state and
; stimulus, then evaluates every candidate action within that context.
; Returns a ranked list of (action-score) atoms used for reporting
; and evaluation metrics.

(= (qwestorCandidateScores $bimonad $state $stimulus $candidates)
  (let $decision-state (decisionContext $bimonad $state $stimulus)
    (qwestorCandidateScoresForState $bimonad $decision-state $candidates)
  )
)
