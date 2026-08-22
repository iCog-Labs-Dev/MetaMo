; Helper functions for Qwestor anti-goal lookup and action exposure vectors.

; Map an anti-goal name to its canonical pair in the anti-goal list.
(= (matchAntiGoalValue $anti-goal-name $anti-goal-list)
    (case $anti-goal-name
          (
            (hallucinate (index-atom $anti-goal-list 0))
            (redundant   (index-atom $anti-goal-list 1))
            (rabbit_hole (index-atom $anti-goal-list 2))
            (premature   (index-atom $anti-goal-list 3))
            ($_ "value not found")
          )
      )
)

; Retrieve the numerical value of a Qwestor anti-goal from the space.
(= (getAntiGoal $space $anti-goal-name)
    (let*
      (
        ($anti-vec   (match $space ($goals $modulators $anti-goals) $anti-goals))
        ($anti-list  (cdr-atom $anti-vec))
        ($pair       (matchAntiGoalValue $anti-goal-name $anti-list))
      )
      (index-atom $pair 1)
    )
)

; Fetch an action's anti-goal exposure vector from QwestorAntiGoalExposure atoms.
(= (getQwestorAntiGoalExposureValue $action-name)
  (match &self (QwestorAntiGoalExposure $action-name $values) $values)
)
