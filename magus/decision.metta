;; Canonical profile-aware MAGUS decision wrapper.

(: MagusDecision Type)
(: magusDecision (-> DecisionProfile Symbol Number Number MagusDecision))

;; Return the profile from a canonical MAGUS decision wrapper.
;; Example: (magusDecisionProfile (magusDecision profile defaultGoalChangeDeltaG 0.5 0.5)) -> profile
(= (magusDecisionProfile (magusDecision $profile $goalChangeFn $lambdaInd $lambdaTrans))
    $profile
)

;; Return the goal-change function from a canonical MAGUS decision wrapper.
;; Example: (magusDecisionGoalChangeFn (magusDecision profile defaultGoalChangeDeltaG 0.5 0.5)) -> defaultGoalChangeDeltaG
(= (magusDecisionGoalChangeFn (magusDecision $profile $goalChangeFn $lambdaInd $lambdaTrans))
    $goalChangeFn
)

;; Return the individuation lambda.
;; Example: (magusDecisionLambdaInd (magusDecision profile fn 0.5 0.5)) -> 0.5
(= (magusDecisionLambdaInd (magusDecision $profile $goalChangeFn $lambdaInd $lambdaTrans))
    $lambdaInd
)

;; Return the transcendence lambda.
;; Example: (magusDecisionLambdaTrans (magusDecision profile fn 0.5 0.5)) -> 0.5
(= (magusDecisionLambdaTrans (magusDecision $profile $goalChangeFn $lambdaInd $lambdaTrans))
    $lambdaTrans
)

;; Construct the default canonical MAGUS decision wrapper.
;; Example: (makeMagusDecision profile) -> (magusDecision profile defaultGoalChangeDeltaG 0.5 0.5)
(= (makeMagusDecision $profile)
    (magusDecision $profile defaultGoalChangeDeltaG 0.5 0.5)
)

;; Canonical monadic unit.
;; Example: (profiledMagusUnit state) -> state
(= (profiledMagusUnit $state)
    $state
)

;; Score a candidate with explicit profile and lambdas.
;; Example: (profiledMagusScore profile state candidate 0.5 0.5) -> score
(= (profiledMagusScore $profile $state $candidate $lambdaInd $lambdaTrans)
    (decisionProfileScoreCandidate $profile $state $candidate $lambdaInd $lambdaTrans)
)

;; Propose Delta G through an explicit goal-change function.
;; Example: (profiledMagusProposeDeltaG defaultGoalChangeDeltaG profile state candidate feedback 0.5 0.5) -> delta-vector
(= (profiledMagusProposeDeltaG $goalChangeFn $profile $state $candidate $feedback $lambdaInd $lambdaTrans)
    (eval ($goalChangeFn $profile $state $candidate $feedback $lambdaInd $lambdaTrans))
)

;; Find the best candidate, preserving first candidate on score ties.
;; Example: (profiledMagusBestLoop profile state best 1.0 rest feedback 0.5 0.5) -> best
(= (profiledMagusBestLoop $profile $state $currentBest $currentScore $remaining $feedback $lambdaInd $lambdaTrans)
    (if (== $remaining ())
        $currentBest
        (let* (
            (($head $rest) (decons $remaining))
            ($headScore (profiledMagusScore $profile $state $head $lambdaInd $lambdaTrans))
        )
            (if (> $headScore $currentScore)
                (profiledMagusBestLoop $profile $state $head $headScore $rest $feedback $lambdaInd $lambdaTrans)
                (profiledMagusBestLoop $profile $state $currentBest $currentScore $rest $feedback $lambdaInd $lambdaTrans)
            )
        )
    )
)

;; Decide with an explicit profile and goal-change callback.
;; Example: (profiledMagusDecide profile defaultGoalChangeDeltaG state candidates feedback 0.5 0.5) -> decisionResult
(= (profiledMagusDecide $profile $goalChangeFn $state $candidates $feedback $lambdaInd $lambdaTrans)
    (if (== $candidates ())
        (validationError empty-candidates $profile)
        (let* (
            (($first $rest) (decons $candidates))
            ($firstScore (profiledMagusScore $profile $state $first $lambdaInd $lambdaTrans))
            ($best (profiledMagusBestLoop $profile $state $first $firstScore $rest $feedback $lambdaInd $lambdaTrans))
            ($delta (profiledMagusProposeDeltaG $goalChangeFn $profile $state $best $feedback $lambdaInd $lambdaTrans))
        )
            (decisionResult $best $delta)
        )
    )
)

;; Decide through a canonical MAGUS decision wrapper.
;; Example: (magusDecide decision state candidates feedback) -> decisionResult
(= (magusDecide (magusDecision $profile $goalChangeFn $lambdaInd $lambdaTrans) $state $candidates $feedback)
    (profiledMagusDecide $profile $goalChangeFn $state $candidates $feedback $lambdaInd $lambdaTrans)
)

;; Score through a canonical MAGUS decision wrapper.
;; Example: (magusScore decision state candidate) -> score
(= (magusScore (magusDecision $profile $goalChangeFn $lambdaInd $lambdaTrans) $state $candidate)
    (profiledMagusScore $profile $state $candidate $lambdaInd $lambdaTrans)
)
