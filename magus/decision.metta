;; MAGUS Hierarchical Decision Layer

;; Goal-to-Modulator Relevance Mapping
;; Maps each goal to its most relevant modulator(s) for scoring.
(goalModulatorRelevance gHelp (resolution))
(goalModulatorRelevance gCurio (arousal))
(goalModulatorRelevance gNovel (approach))
(goalModulatorRelevance gEthic (threshold securing))
(goalModulatorRelevance gSoc (valence approach))
(goalModulatorRelevance gSelf (approach resolution))

;; Goal Category Atoms for Overgoal Support
(goalMetaDrive gHelp individuation)
(goalMetaDrive gEthic individuation)
(goalMetaDrive gCurio transcendence)
(goalMetaDrive gNovel transcendence)
(goalMetaDrive gSelf dual)
(goalMetaDrive gSoc dual)

;; Exploratory Growth Goal Set
(growthGoal gCurio)
(growthGoal gNovel)
(growthGoal gSelf)

;; Calculates the average modulator value for a list of modulators relevant to a goal.
(= (sumModulators $mods $state)
    (if (== $mods ())
        0.0
        (let* (
            (($head $tail) (decons $mods))
            ($val (eval (getModulator $state $head)))
        )
            (+ $val (sumModulators $tail $state))
        )
    )
)

;; Retrieve the relevant modulator weight for a goal (average of relevant modulators).
;; Example: (magusRelevantModulator $state gEthic) → average of threshold and securing
(= (magusRelevantModulator $state $goalName)
    (let $result (match &self (goalModulatorRelevance $goalName $mods) $mods)
        (if (== $result ())
            0.0
            (/ (sumModulators $result $state) (size-atom $result))
        )
    )
)

;; Compute overgoal support for a goal based on individuation and transcendence meta-drives.
(= (magusOvergoalSupport $goalName $indSignal $transSignal)
    (let $drive (match &self (goalMetaDrive $goalName $d) $d)
        (case $drive (
            (individuation (+ 0.5 (* 0.5 $indSignal)))
            (transcendence (+ 0.5 (* 0.5 $transSignal)))
            (dual (+ 0.5 (* 0.25 (+ $indSignal $transSignal))))
            ($_ 1.0)
        ))
    )
)

;; Compute the normalized growth signal for a candidate action.
(= (magusNormalizedGrowthSignal $candidate)
    (let* (
        ($getGrowthIndices(collapse (match &self (growthGoal $name) (match &self (GoalIndex $name $idx) $idx))))
        ($growthIndices ($getGrowthIndices))
        ($corrs (actionGoalCorrelations $candidate))
        ($deltaG (actionDeltaG $candidate))
        ($exploratoryAlignment (meanAtIndices $corrs $growthIndices))
        ;; Measure shift normalized by typical step size
        ($growthShift (meanAtIndices (clipVector (scaleArray $deltaG 10.0) 0.0 1.0) $growthIndices))
    )
        (+ (* 0.7 (positivePart $exploratoryAlignment))
           (* 0.3 $growthShift))
    )
)

;; Compute the weighted contribution of a specific goal to the total score.
(= (goalScoreContribution $state $candidate $goalName $indSignal $transSignal)
    (let* (
        ($weight (eval (getGoal $state $goalName)))
        ($modWeight (magusRelevantModulator $state $goalName))
        ($metaSupport (magusOvergoalSupport $goalName $indSignal $transSignal))
        ($idx (match &self (GoalIndex $goalName $i) $i))
        ($corr (index-atom (eval (actionGoalCorrelations $candidate)) $idx))
    )
        (* (* (* $weight $modWeight) $metaSupport) $corr)
    )
)

;; Recursively sum contributions for a list of goal names.
(= (sumGoalContributions $goals $state $candidate $indSignal $transSignal)
    (if (== $goals ())
        0.0
        (let* (
                (($head $tail) (decons $goals))
                ($headScore (goalScoreContribution $state $candidate $head $indSignal $transSignal))
                ($tailScore (sumGoalContributions $tail $state $candidate $indSignal $transSignal))
            )
            (+ $headScore $tailScore)
        )
    )
)

;; MAGUS Score Candidate
(= (magusScore $state $candidate)
    (let* (
        ($gInd (eval (getGoal $state gInd)))
        ($gTrans (eval (getGoal $state gTrans)))
        ($indSignal (eval (sigmoidNum (* (- $gInd 0.5) 6.0))))
        ($transSignal (eval (sigmoidNum (* (- $gTrans 0.5) 6.0))))
        ($cautionSignal (/ (+ (eval (getModulator $state threshold)) (eval (getModulator $state securing))) 2.0))
        ($growthSignal (/ (+ (eval (getModulator $state arousal)) (eval (getModulator $state approach))) 2.0))

        ;; Dynamic list of primary goals to score (those with modulator mappings)
        ($primaryGoals (collapse (match &self (goalModulatorRelevance $g $m) $g)))
        ($baseScore (sumGoalContributions $primaryGoals $state $candidate $indSignal $transSignal))

        ;; Conflict penalty: curiosity-ethics conflict
        ;; Conflict penalty: curiosity-ethics conflict
        ($getGoalIndex (|-> ($goalName) (match &self (GoalIndex $goalName $idx) $idx)))
        ($ethicIdx ($getGoalIndex gEthic))
        ($curioIdx ($getGoalIndex gCurio))
        ($corrs (eval (actionGoalCorrelations $candidate)))
        ($curioEthicConflict (* (index-atom $corrs $curioIdx) (index-atom $corrs $ethicIdx)))
        ($conflictPenalty (if (< $curioEthicConflict -0.2)
                            (eval (expNum (* (absNumber $curioEthicConflict) 3.0)))
                            0.0))
        ($riskPenalty (* (* (* (eval (LAMBDA_IND)) $gInd) $cautionSignal) (eval (actionRiskEstimate $candidate))))
        ($growthReward (* (* (* (eval (LAMBDA_TRANS)) $gTrans) $growthSignal)
                        (magusNormalizedGrowthSignal $candidate)))
    )
        (+ (- $baseScore (+ $riskPenalty $conflictPenalty)) $growthReward)
    )
)

;; Recursive Best Candidate Search
(= (magusBestLoop $state $currentBest $currentScore $remaining)
    (if (== $remaining ())
        $currentBest
        (let* (
            (($head $rest) (decons $remaining))
            ($headScore (magusScore $state $head))
        )
            (if (> $headScore $currentScore)
                (magusBestLoop $state $head $headScore $rest)
                (magusBestLoop $state $currentBest $currentScore $rest)
            )
        )
    )
)

;; MAGUS Decision Functions (DecisionMonad interface)

(= (magusUnit $state) $state)

(= (magusDecide $state $candidates)
    (let* (
        (($first $rest) (decons $candidates))
        ($firstScore (magusScore $state $first))
        ($best (magusBestLoop $state $first $firstScore $rest))
    )
        (decisionResult $best (actionDeltaG $best))
    )
)

(= (magusDecision)
    (decisionMonad magusUnit magusDecide magusScore)
)
