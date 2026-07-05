!(bind! &consecutive-safety-wins (new-state 0))


;; Check if a candidate is registered as a safety-type action.
(= (isSafetyCandidate $name)
    (let $res (collapse (match &self (CandidateSpec $name safety) True))
        (if (== $res ()) False True))
)

;; Read anti-saturation constants from registry (with defaults).
(= (antiSatThreshold)
    (let $res (collapse (match &self (AntiSaturation threshold $v) $v))
        (if (== $res ()) 2 (car-atom $res)))
)
(= (antiSatStep)
    (let $res (collapse (match &self (AntiSaturation step $v) $v))
        (if (== $res ()) 0.10 (car-atom $res)))
)
(= (antiSatMax)
    (let $res (collapse (match &self (AntiSaturation max $v) $v))
        (if (== $res ()) 0.50 (car-atom $res)))
)

(= (omegaclawUnit $state) $state)

;; omegaclawScore: score a single MetaMo Action against the current state.
(= (omegaclawScore $state $action)
    (let* (
        ($candName  (actionId $action))
        ; ($_ (println! ("Scoring candidate: " $candName)))
        ($gInd      (getGoal $state gInd_over))
        ($gTrans    (getGoal $state gTrans_over))
        ($corrs     (actionGoalCorrelations $action))
        ($goals     (motivationGoals $state))
        ; ($_ (println! ("all: " $goals $corrs $gInd $gTrans)))

        ;; 1. Goal alignment — dot product of goal values × correlations.
        ($products (collapse
            (let $idx (superpose (0 1 2 3 4 5 6 7 8 9 10))
                (* (index-atom $goals $idx) (index-atom $corrs $idx))
            )
        ))
        ($goalAlignment (sum $products))
        ; ($_ (println! ("all2: => " $goalAlignment $products)))

        ;; 2. Transcendence bonus for growth candidates
        ($isGrowth (let $r (collapse (match &self (CandidateSpec $candName growth) True))
            (if (== $r ()) False True)))
        ($transBonus (if $isGrowth (* $gTrans 0.30) 0.0))
        ; ($_ (println! ("isGrowth: " $isGrowth " transBonus: " $transBonus)))

        ;; 3. Stability and risk penalties
        ($riskFactor      (actionRiskEstimate $action))
        ($securing        (getModulator $state securing))
        ($threshold       (getModulator $state threshold))
        ($stabilityPenalty (* $riskFactor (* $gInd $securing)))
        ($riskPenalty      (* $riskFactor $threshold))
        ; ($_ (println! ("riskFactor: " $riskFactor " stabilityPenalty: " $stabilityPenalty
                    ; " riskPenalty: " $riskPenalty)))

        ;; 4. Anti-saturation penalty — discourages continuous safety selections
        ($consecutiveWins (get-state &consecutive-safety-wins))
        ($isSafety        (isSafetyCandidate $candName))
        ($antiSatPenalty
            (if (and $isSafety (> $consecutiveWins (antiSatThreshold)))
                (let $raw (* (- $consecutiveWins (antiSatThreshold)) (antiSatStep))
                    (if (> $raw (antiSatMax)) (antiSatMax) $raw))
                0.0
            ))
        ; ($_ (println! ("antiSatPenalty: " $antiSatPenalty " consecutiveWins: " $consecutiveWins
        ;             " isSafety: " $isSafety)))

        ;; 5. Composite score, clamped to [0, 1]
        ($x (* $goalAlignment (+ 1.0 $transBonus)))
        ($y (+ $stabilityPenalty (+ $riskPenalty $antiSatPenalty)))
        ($rawScore (eval (clamp (- $x $y))))
        ; ($_ (println! ("rawScore: " $rawScore " x: " $x " y: " $y)))

    )
        $rawScore
    )
)


(= (findBestAction $state () $bestAction $bestScore) $bestAction)
(= (findBestAction $state $remaining $bestAction $bestScore)
    (let* (
        (($head $tail) (decons-atom $remaining))
        ($score (omegaclawScore $state $head))
    )
        (if (> $score $bestScore)
            (findBestAction $state $tail $head $score)
            (findBestAction $state $tail $bestAction $bestScore)
        )
    )
)


;; omegaclawDecide: select the best action and update the anti-saturation counter.
(= (omegaclawDecide $state $candidates)
    (if (== $candidates ())
        ;; Empty candidate list — return a no-op result
        (decisionResult (action none () 0.0 ()) ())
        (let* (
            (($head $tail) (decons-atom $candidates))
            ($firstScore  (omegaclawScore $state $head))
            ($bestAction  (findBestAction $state $tail $head $firstScore))
            ($candName    (actionId $bestAction))

            ;; Update anti-saturation streak counter
            ($isSafety (isSafetyCandidate $candName))
            ($_ (if $isSafety
                    (change-state! &consecutive-safety-wins
                        (+ (get-state &consecutive-safety-wins) 1))
                    (change-state! &consecutive-safety-wins 0)))
        )
            (decisionResult $bestAction (actionDeltaG $bestAction))
        )
    )
)

(= (omegaclawDecision)
    (decisionMonad omegaclawUnit omegaclawDecide omegaclawScore)
)
