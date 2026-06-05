;; Decision layer for MAGUS - MeTTa implementation
;; Mirrors magus/decision.py from MetaMo-Python

;; ─── Pure numeric helpers ───────────────────────────────────────────────────

(= (sigmoid $x)
    (/ 1.0 (+ 1.0 (py-call (helpers.exp (- 0.0 $x)))))
)

(= (positivePart $value)
    (if (> $value 0.0) $value 0.0)
)

;; ─── Modulator routing ──────────────────────────────────────────────────────

;; relevantModulator : MotivationalState -> Number -> Number
;; Maps each primary goal index to its most relevant modulator value.

(= (relevantModulator $state $goalIdx)
    (let* (($mods (motivationModulators $state)))
        (if (== $goalIdx (eval (G_HELP)))
            (py-call (helpers.index $mods (eval (M_RESOLUTION))))
        (if (== $goalIdx (eval (G_CURIO)))
            (py-call (helpers.index $mods (eval (M_AROUSAL))))
        (if (== $goalIdx (eval (G_NOVEL)))
            (py-call (helpers.index $mods (eval (M_APPROACH))))
        (if (== $goalIdx (eval (G_SELF)))
            (/ (+ (py-call (helpers.index $mods (eval (M_APPROACH))))
                  (py-call (helpers.index $mods (eval (M_RESOLUTION)))))
               2.0)
        (if (== $goalIdx (eval (G_ETHIC)))
            (/ (+ (py-call (helpers.index $mods (eval (M_THRESHOLD))))
                  (py-call (helpers.index $mods (eval (M_SECURING)))))
               2.0)
        (if (== $goalIdx (eval (G_SOC)))
            (/ (+ (py-call (helpers.index $mods (eval (M_VALENCE))))
                  (py-call (helpers.index $mods (eval (M_APPROACH)))))
               2.0)
        0.0))))))
    )
)

;; ─── Overgoal support ───────────────────────────────────────────────────────

;; overgoalSupport : Number -> Number -> Number -> Number
;; Encodes narrative coupling between primary goals and the dual overgoals.

(= (overgoalSupport $goalIdx $gInd $gTrans)
    (let* (
        ($indSupport   (sigmoid (* (- $gInd 0.5) 6.0)))
        ($transSupport (sigmoid (* (- $gTrans 0.5) 6.0)))
    )
        (if (or (== $goalIdx (eval (G_HELP))) (== $goalIdx (eval (G_ETHIC))))
            (+ 0.5 (* 0.5 $indSupport))
        (if (or (== $goalIdx (eval (G_CURIO))) (== $goalIdx (eval (G_NOVEL))))
            (+ 0.5 (* 0.5 $transSupport))
        (if (or (== $goalIdx (eval (G_SELF))) (== $goalIdx (eval (G_SOC))))
            (+ 0.5 (* 0.25 (+ $indSupport $transSupport)))
        1.0)))
    )
)

;; ─── Growth signal ──────────────────────────────────────────────────────────

;; normalizedGrowthSignal : ActionType -> Number
;; Measures whether a candidate supports exploratory growth.

(= (normalizedGrowthSignal $candidate)
    (let* (
        ($corrs (actionGoalCorrelations $candidate))
        ($dg    (actionDeltaG $candidate))
        ($exploratory
            (mean
                (list
                    (positivePart (py-call (helpers.index $corrs (eval (G_CURIO)))))
                    (positivePart (py-call (helpers.index $corrs (eval (G_NOVEL)))))
                    (positivePart (py-call (helpers.index $corrs (eval (G_SELF)))))
                )
            )
        )
        ($growthShift
            (mean
                (list
                    (py-call (helpers.clip (/ (py-call (helpers.index $dg (eval (G_CURIO)))) 0.1) 0.0 1.0))
                    (py-call (helpers.clip (/ (py-call (helpers.index $dg (eval (G_NOVEL)))) 0.1) 0.0 1.0))
                    (py-call (helpers.clip (/ (py-call (helpers.index $dg (eval (G_SELF))))  0.1) 0.0 1.0))
                )
            )
        )
    )
        (+ (* 0.7 $exploratory) (* 0.3 $growthShift))
    )
)

;; ─── Candidate scoring ──────────────────────────────────────────────────────

;; scoreCandidate : MotivationalState -> ActionType -> Number
;; Scores a single candidate action under the current motivational state.

(= (scoreCandidate $state $candidate)
    (let* (
        ($goals  (motivationGoals $state))
        ($mods   (motivationModulators $state))
        ($corrs  (actionGoalCorrelations $candidate))

        ($gInd   (py-call (helpers.index $goals (eval (G_IND)))))
        ($gTrans (py-call (helpers.index $goals (eval (G_TRANS)))))

        ($cautionSignal
            (/ (+ (py-call (helpers.index $mods (eval (M_THRESHOLD))))
                  (py-call (helpers.index $mods (eval (M_SECURING)))))
               2.0))
        ($growthSignal
            (/ (+ (py-call (helpers.index $mods (eval (M_AROUSAL))))
                  (py-call (helpers.index $mods (eval (M_APPROACH)))))
               2.0))

        ;; Base score: sum over primary goals (indices 2..NUM_GOALS-1)
        ($baseScore
            (eval (scorePrimaryGoals $state $candidate 2 0.0)))

        ;; Curiosity-ethics conflict penalty
        ($curioCorrVal  (py-call (helpers.index $corrs (eval (G_CURIO)))))
        ($ethicCorrVal  (py-call (helpers.index $corrs (eval (G_ETHIC)))))
        ($curiEthicConf (* $curioCorrVal $ethicCorrVal))
        ($conflictPenalty
            (if (< $curiEthicConf -0.2)
                (py-call (helpers.exp (* (py-call (helpers.abs $curiEthicConf)) 3.0)))
                0.0))

        ($riskPenalty
            (* (eval (LAMBDA_IND)) (* $gInd (* $cautionSignal (actionRiskEstimate $candidate)))))
        ($growthReward
            (* (eval (LAMBDA_TRANS)) (* $gTrans (* $growthSignal (normalizedGrowthSignal $candidate)))))
    )
        (- (+ $baseScore $growthReward) (+ $riskPenalty $conflictPenalty))
    )
)

;; scorePrimaryGoals : MotivationalState -> ActionType -> Number -> Number -> Number
;; Tail-recursive accumulator over goal indices 2..(NUM_GOALS-1).

(= (scorePrimaryGoals $state $candidate $i $acc)
    (if (>= $i (eval (NUM_GOALS)))
        $acc
        (let* (
            ($goals       (motivationGoals $state))
            ($corrs       (actionGoalCorrelations $candidate))
            ($goals2      (motivationGoals $state))
            ($gInd        (py-call (helpers.index $goals2 (eval (G_IND)))))
            ($gTrans      (py-call (helpers.index $goals2 (eval (G_TRANS)))))
            ($goalWeight  (py-call (helpers.index $goals $i)))
            ($modWeight   (relevantModulator $state $i))
            ($metaSupport (overgoalSupport $i $gInd $gTrans))
            ($corrVal     (py-call (helpers.index $corrs $i)))
            ($contrib     (* $goalWeight (* $modWeight (* $metaSupport $corrVal))))
        )
            (scorePrimaryGoals $state $candidate (+ $i 1) (+ $acc $contrib))
        )
    )
)

;; ─── Decision monad ─────────────────────────────────────────────────────────

;; magusUnit : MotivationalState -> MotivationalState
;; Monadic unit (eta): injects state into the monadic context unchanged.

(= (magusUnit $state) $state)

;; decideBest : MotivationalState -> Expression -> ActionType -> Number -> ActionType
;; Iterates over candidates and returns the highest-scoring action.

(= (decideBest $state $candidates $bestAction $bestScore)
    (if (== $candidates ())
        $bestAction
        (let* (
            ($head      (car-atom $candidates))
            ($tail      (cdr-atom $candidates))
            ($score     (scoreCandidate $state $head))
        )
            (if (> $score $bestScore)
                (decideBest $state $tail $head $score)
                (decideBest $state $tail $bestAction $bestScore)
            )
        )
    )
)

;; magusDecide : MotivationalState -> Expression -> (ActionType, Expression)
;; Entry point: scores all candidates, returns the best action and its deltaG.

(= (magusDecide $state $candidates)
    (let* (
        ($first     (car-atom $candidates))
        ($firstScore (scoreCandidate $state $first))
        ($best      (decideBest $state (cdr-atom $candidates) $first $firstScore))
    )
        (pair $best (actionDeltaG $best))
    )
)