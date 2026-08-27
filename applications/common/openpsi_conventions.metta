;; Compute OpenPsi core modulator deltas from novelty/conduciveness/risk/effort.
;; Example: (commonOpenPsiCoreDeltas state (stimulusFeatures ((novelty 0.3) (conduciveness 0.8) (risk 0.1) (effort 0.2)))) -> deltas
(= (commonOpenPsiCoreDeltas $state $features)
    (let* (
        ($novelty (featureMapNumericUnit $features novelty 0.0))
        ($conduciveness (featureMapNumericUnit $features conduciveness 0.0))
        ($risk (featureMapNumericUnit $features risk 0.0))
        ($effort (featureMapNumericUnit $features effort 0.0))
        ($schema (stateSchema $state))
        ($goalSchema (motivationSchemaGoals $schema))
        ($gInd (stateGoal $state (magusGoalSchemaIndividuationName $goalSchema)))
        ($gTrans (stateGoal $state (magusGoalSchemaTranscendenceName $goalSchema)))
        ($arousalFeedback (sigmoidNum (* (- (stateModulator $state arousal) 0.5) 5.0)))
        ($transScale (expNum (- $gTrans 0.5)))
        ($indScale (expNum (- $gInd 0.5)))
        ($benignNovelty (* $novelty (- 1.0 $risk)))
        ($demandingContext (/ (+ $effort $risk) 2.0))
        ($deltaValence (- (+ (* 0.75 $conduciveness) (* 0.25 $benignNovelty)) (+ (* 0.55 $risk) (* 0.15 $effort))))
        ($deltaArousal (- (+ (* $novelty (+ 1.0 (* 0.5 $arousalFeedback))) (* 0.15 $risk)) (* 0.35 $effort)))
        ($deltaApproach (- (+ (* 0.65 $benignNovelty) (* 0.35 $conduciveness)) (* 0.75 $risk)))
        ($deltaResolution (+ (+ (* 0.55 $conduciveness) (* 0.35 $effort)) (* 0.20 $risk)))
        ($deltaThreshold (- (+ (* 0.70 $risk) (* 0.25 $demandingContext)) (* 0.15 $conduciveness)))
        ($deltaSecuring (- (+ (* 0.80 $risk) (* 0.20 $effort)) (+ (* 0.30 $benignNovelty) (* 0.10 $conduciveness))))
    )
        (
            (arousal (* $deltaArousal $transScale))
            (approach (* $deltaApproach $transScale))
            (threshold (* $deltaThreshold $indScale))
            (securing (* $deltaSecuring $indScale))
            (valence $deltaValence)
            (resolution $deltaResolution)
        )
    )
)

;; Compute common MAGUS goal-change feedback from OpenPsi feature convention.
;; Example: (commonOpenPsiGoalFeedback state stimulus (stimulusFeatures ((novelty 0.3) (conduciveness 0.8) (risk 0.1) (effort 0.2)))) -> feedback
(= (commonOpenPsiGoalFeedback $state $stimulus $features)
    (let* (
        ($novelty (featureMapNumericUnit $features novelty 0.0))
        ($conduciveness (featureMapNumericUnit $features conduciveness 0.0))
        ($risk (featureMapNumericUnit $features risk 0.0))
        ($effort (featureMapNumericUnit $features effort 0.0))
        ($opportunity (/ (+ $novelty $conduciveness) 2.0))
    )
        (goalChangeFeedback
            (
                (safety_pressure (maxNumber $risk (* $effort 0.5)))
                (useful_novelty (* $novelty (- 1.0 $risk)))
                (progress $conduciveness)
                (individuation_target (clipUnit (+ (+ 0.45 (* 0.45 $risk)) (* 0.10 $effort))))
                (transcendence_target (clipUnit (- (+ 0.45 (* 0.45 $opportunity)) (* 0.30 $risk))))
            )
        )
    )
)

