!(bind! &consecutive-safety-wins (new-state 0))
!(bind! &active-frame-bundle (new-state ()))

(= (setActiveFrameBundle $bundle)
   (change-state! &active-frame-bundle $bundle))

(= (activeFrameBundle)
   (get-state &active-frame-bundle))


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

(= (candidateType $candName)
    (let $res (collapse (match &self (CandidateSpec $candName $type) $type))
        (if (== $res ()) unknown (car-atom $res)))
)

(= (candidateModulatorBias $state $type)
    (let $rows (collapse (match &self (CandidateTypeModulator $type $mod $sign)
                            (CandidateTypeModulator $type $mod $sign)))
        (if (== $rows ())
            0.0
            (let $parts (collapse
                    (let $row (superpose $rows)
                        (let (CandidateTypeModulator $_type $mod $sign) $row
                            (* $sign (- (getModulator $state $mod) 0.5)))))
                (* 0.20 (sum $parts)))))
)

;; omegaclawScore: score a single MetaMo Action against the current state.
(= (omegaclawScore $state $action)
    (if (== (actionId $action) none)
        0.0
        (let* (
        ($candName  (actionId $action))
        ; ($_ (println! ("Scoring candidate: " $candName)))
        ($gInd      (getGoal $state gInd_over))
        ($gTrans    (getGoal $state gTrans_over))
        ($type      (candidateType $candName))
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
        ($modulatorBias (candidateModulatorBias $state $type))
        ($x (+ (* $goalAlignment (+ 1.0 $transBonus)) $modulatorBias))
        ($y (+ $stabilityPenalty (+ $riskPenalty $antiSatPenalty)))
        ($rawScore (eval (clampValue (- $x $y))))
        ; ($_ (println! ("rawScore: " $rawScore " x: " $x " y: " $y)))

        )
            $rawScore
        )
    )
)

;; Bundle-aware decision facades. The bimonad retains its historical
;; two-argument function contract, while the runtime boundary is explicit at
;; the v1 entry point and callers can only score a bundle-scoped candidate.
(= (omegaclawScoreForBundle $bundle $state $action)
   (if (== (frameBundleCurrentId $bundle) ())
       0.0
       (omegaclawScore $state $action)))


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

(= (omegaclawDecideForBundle $bundle $state $candidates)
   (if (== (frameBundleCurrentId $bundle) ())
       (decisionResult (action none () 0.0 ()) ())
       (omegaclawDecide $state $candidates)))

(= (omegaclawScoreBound $state $action)
   (let $bundle (activeFrameBundle)
      (if (== $bundle ())
          (omegaclawScore $state $action)
          (omegaclawScoreForBundle $bundle $state $action))))

(= (omegaclawDecideBound $state $candidates)
   (let $bundle (activeFrameBundle)
      (if (== $bundle ())
          (omegaclawDecide $state $candidates)
          (omegaclawDecideForBundle $bundle $state $candidates))))

(= (omegaclawDecision)
    (decisionMonad omegaclawUnit omegaclawDecideBound omegaclawScoreBound)
)
