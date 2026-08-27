(= (tradingStimulusFeatureFn $state $observation)
    (tradingStimulusFeatures $observation)
)

(= (tradingCoreDeltas $state $features)
    (commonOpenPsiCoreDeltas $state $features)
)

(= (tradingApplicationDeltaToward $state $features $name $featureName $default)
    (* 0.55 (- (featureMapNumericUnit $features $featureName $default) (stateModulator $state $name)))
)

(= (tradingApplicationDeltas $state $features)
    (
        (volatility (tradingApplicationDeltaToward $state $features volatility volatility 0.0))
        (stress (tradingApplicationDeltaToward $state $features stress stress 0.0))
        (exposure (tradingApplicationDeltaToward $state $features exposure exposure 0.0))
        (confidence (tradingApplicationDeltaToward $state $features confidence confidence 0.5))
        (uncertainty (tradingApplicationDeltaToward $state $features uncertainty uncertainty 0.0))
        (friction (tradingApplicationDeltaToward $state $features friction friction 0.0))
    )
)

(= (tradingGoalFeedback $state $observation $features)
    (let* (
        ($common (commonOpenPsiGoalFeedback $state $observation $features))
        ($risk (featureMapNumericUnit $features risk 0.0))
        ($opportunity (featureMapNumericUnit $features opportunity 0.0))
        ($drawdown (featureMapNumericUnit $features stress 0.0))
        ($exposure (featureMapNumericUnit $features exposure 0.0))
        ($confidence (featureMapNumericUnit $features confidence 0.5))
        ($regime (featureMapNumericUnit $features uncertainty 0.0))
        ($liquidity (featureMapNumericUnit $features friction 0.0))
        ($cost (featureMapNumericUnit $features cost 0.0))
        ($negativeReturn (positivePart (- 0.0 (featureMapNumeric $features return 0.0))))
    )
        (goalChangeFeedback
            (listAppend
                (featureMapPairs $common)
                (
                    (safeguard (clipUnit (+ (+ 0.40 (* 0.40 $risk)) (+ (* 0.25 $drawdown) (* 0.15 $exposure)))))
                    (growth (clipUnit (- (+ 0.40 (* 0.45 $opportunity)) (+ (* 0.25 $risk) (* 0.15 $liquidity)))))
                    (drawdown $drawdown)
                    (overtrading (clipUnit (+ (* 0.60 $cost) (* 0.25 $regime))))
                    (recklessness (max-atom ((eval (* $risk $exposure)) $drawdown $regime)))
                    (illiquidity $liquidity)
                    (chasing (max-atom ($drawdown $negativeReturn (eval (* 0.50 $risk)))))
                    (staleness (clipUnit (+ (* 0.65 (- 1.0 $confidence)) (* 0.35 $regime))))
                )
            )
        )
    )
)

(= (tradingAppraisalProfile)
    (appraisalProfile
        trading_openpsi
        (valence arousal approach resolution threshold securing volatility stress exposure confidence uncertainty friction)
        tradingStimulusFeatureFn
        tradingCoreDeltas
        tradingApplicationDeltas
        tradingGoalFeedback
        1.0
        (
            (volatility 0.0 1.0)
            (stress 0.0 1.0)
            (exposure 0.0 1.0)
            (confidence 0.0 1.0)
            (uncertainty 0.0 1.0)
            (friction 0.0 1.0)
        )
    )
)
