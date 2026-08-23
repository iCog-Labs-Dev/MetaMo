; Map a modulator name to its canonical value in the modulator list.
; Each modulator corresponds to a fixed index in the mod-list.
; Returns the pair (modulator-name, value) or "value not found".

(= (matchValue $modulator-name $mod-list)
    (case $modulator-name
          (
            (m_urgency           (index-atom $mod-list 0))
            (m_resolution        (index-atom $mod-list 1))
            (m_user_expertise    (index-atom $mod-list 2))
            (m_threshold         (index-atom $mod-list 3))
            (m_topic_familiarity (index-atom $mod-list 4))
            (m_failure_wariness  (index-atom $mod-list 5))
            (m_securing          (index-atom $mod-list 6))
            (m_approach          (index-atom $mod-list 7))
            (m_arousal           (index-atom $mod-list 8))
            (m_risk_aversion     (index-atom $mod-list 9))
            (m_error_tolerance   (index-atom $mod-list 10))
            (m_creativity        (index-atom $mod-list 11))
            (m_valence           (index-atom $mod-list 12))
            ($_ "value not found")
          )
      )
)

; Retrieve the numerical value of a given modulator from the space.
; Uses matchValue to locate the value within the modulator vector.

(= (getMod $space $modulator-name)
    (let*
      (
        ($mod-vec   (match $space ($goals $modulators $anti-goals) $modulators))
        ($mod-list  (cdr-atom $mod-vec))
        ($pair      (matchValue $modulator-name $mod-list))
      )
      (index-atom $pair 1)
    )
)
; Clamp a numeric value to [0,1].
; Equivalent to Python's clamp_to_unit_interval function.

(= (clampToUnitInterval $x)
  (if (and (< $x 1) (> $x 0))
     $x
     (if (>= $x 1)
      1
      0
      )
   )
)

; Look up a value by key in a list of key-value pairs.
; Returns the value using superpose if found, otherwise continues search.

(= (findByKey $key $dic_list)
(if (== $dic_list ())
     ()
        (let* (
                (($pair $next) (decons $dic_list))
                ($k (car-atom $pair))
                ($v (cdr-atom $pair))
            )
            (if (== $k $key)
                (superpose $v)
                (findByKey $key $next)
            )
        )

)
)

; Retrieve a goal value from the space given a goal name.
; Maps the goal to its fixed index in the goal list.

(= (getSingleGoal $space $goal-name)
 (let*
  (
    ($goal-vec  (match $space ($goals $modulators $anti-goals) $goals))
    ($goal-list (cdr-atom $goal-vec))
    ($pair
      (case $goal-name
        (
          (efficiency           (index-atom $goal-list 0))
          (accuracy             (index-atom $goal-list 1))
          (success_moderate     (index-atom $goal-list 2))
          (knowledge            (index-atom $goal-list 3))
          (novelty              (index-atom $goal-list 4))
          (success_breakthrough (index-atom $goal-list 5))
          (coherence            (index-atom $goal-list 6))
          (originality          (index-atom $goal-list 7))
          (social               (index-atom $goal-list 8))
          (help_short           (index-atom $goal-list 9))
          (help_long            (index-atom $goal-list 10))
          (over_beneficial      (index-atom $goal-list 11))
          (over_safety          (index-atom $goal-list 12))
          (over_honesty         (index-atom $goal-list 13))
        )
      )
    )
  )
  (index-atom $pair 1)
 )
)

(= (getGoalQwestor $space $goal-name)
   (getSingleGoal $space $goal-name)
)

; Add multiple items to a space recursively.

(= (addItems $baseCase $space $items)
   (if (== $items ())
        $baseCase
        (let* (
               ($h (car-atom $items))
               ($t (cdr-atom $items))
               ($_ (add-atom $space $h))
               )
          (addItems $baseCase $space $t)
          )
     )
)

; Accessor functions for goals and state management.

(= (getGoals $space) (match $space ($goals $modulators $anti-goals) $goals))
(= (addState $space $state)
    (add-atom $space $state)
)
(= (addAlpha $space $list) (addItems () $space $list))

; Utilities for integration and cycle operations.

(= (integrationState $state)
    $state
)

(= (integrationStates $name1 $name2 $intState)
    (
        (subsystemState $name1 $intState)
        (subsystemState $name2 $intState)
    )
)
(= (integrationStimulus $stimulus)
   $stimulus
)

; Print the Qwestor decision result.
; Displays the selected action, all candidates, stimulus values, and next motivation.

(= (printQwestorResult
      (qwestor-result
        (selected         $action-name)
        (candidates       $candidate)
        (next-motivation  $next-motiv)
        (stimulus         $stim-vals)))
  (let*
    (
      ($_ (println! ""))

      ($_ (println! "--------------------- Qwestor Decision Report  ---------------------"))
      ($_ (println! (stimulus $stim-vals)))

      ($_ (println! "--------------------- Selected Action ------------------------------"))
      ($_ (println! (selected_Action $action-name)))

      ($_ (println! "--------------------- Candidate Actions ----------------------------"))
      ($_ (println! (candidates $candidate)))

      ($_ (println! "--------------------- Next Motivation State ------------------------"))
      ($_ (println! (eval (motivationSummary $next-motiv))))
    )
    done
  )
)