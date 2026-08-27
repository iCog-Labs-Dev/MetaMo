(: TradingObservation Type)
(: tradingObservation (-> Number Bool Number Number Number Number Number Number Number Number Number TradingObservation))


(= (tradingObservationMapper $observation $type)
    (let (tradingObservation $return $holding 
            $turbulence $exposure $unrealizedPnl 
            $drawdown $momentum $liquidityPressure
            $signalConfidence $regimeUncertainty $transactionCost) $observation
        (case $type (
            (return $return)
            (holding $holding)
            (turbulence $turbulence)
            (exposure $exposure)
            (unrealizedPnl $unrealizedPnl)
            (drawdown $drawdown)
            (momentum $momentum)
            (liquidityPressure $liquidityPressure)
            (signalConfidence $signalConfidence)
            (regimeUncertainty $regimeUncertainty)
            (transactionCost $transactionCost)
            ($_ (empty))
        ))
    )
)


(= (makeTradingObservation $return $holding $turbulence $exposure $unrealizedPnl $drawdown $momentum $liquidityPressure $signalConfidence $regimeUncertainty $transactionCost)
    (tradingObservation
        (clipRange $return -1.0 1.0)
        $holding
        (clipUnit $turbulence)
        (clipUnit $exposure)
        (clipRange $unrealizedPnl -1.0 1.0)
        (clipUnit $drawdown)
        (clipRange $momentum -1.0 1.0)
        (clipUnit $liquidityPressure)
        (clipUnit $signalConfidence)
        (clipUnit $regimeUncertainty)
        (clipUnit $transactionCost)
    )
)

(= (tradingOpportunity $observation)
    (clipUnit
        (+ (+ (* 0.55 (positivePart (tradingObservationMapper $observation momentum)))
              (* 0.35 (tradingObservationMapper $observation signalConfidence)))
           (* 0.10 (positivePart (tradingObservationMapper $observation return))))
    )
)

(= (tradingNovelty $observation)
    (clipUnit
        (+ (* 8.0 (absNumber (tradingObservationMapper $observation return)))
           (* 0.25 (tradingObservationMapper $observation regimeUncertainty)))
    )
)

(= (tradingConduciveness $observation)
    (if (tradingObservationMapper $observation holding)
        (clipUnit
            (+ (+ 0.50 (* 5.0 (tradingObservationMapper $observation return)))
               (* 0.20 (tradingObservationMapper $observation unrealizedPnl)))
        )
        (clipUnit
            (- (+ 0.50 (* 0.40 (positivePart (tradingObservationMapper $observation momentum))))
               (+ (* 0.35 (tradingObservationMapper $observation turbulence))
                  (* 0.20 (tradingObservationMapper $observation regimeUncertainty))))
        )
    )
)

(= (tradingRisk $observation)
    (clipUnit
        (+ (max-atom
            (
                (tradingObservationMapper $observation turbulence)
                (tradingObservationMapper $observation drawdown)
                (tradingObservationMapper $observation liquidityPressure)
                (tradingObservationMapper $observation regimeUncertainty)
            ))
           (if (and (tradingObservationMapper $observation holding) (< (tradingObservationMapper $observation return) 0.0))
               0.20
               0.0
           ))
    )
)

(= (tradingEffort $observation)
    (clipUnit
        (+ (+ 0.10 (tradingObservationMapper $observation transactionCost))
           (* 0.25 (tradingObservationMapper $observation regimeUncertainty)))
    )
)

(= (tradingStimulusFeatures $observation)
    (let* (
        ($risk (tradingRisk $observation))
        ($opportunity (tradingOpportunity $observation))
    )
        (stimulusFeatures
            (
                (novelty (tradingNovelty $observation))
                (conduciveness (tradingConduciveness $observation))
                (risk $risk)
                (effort (tradingEffort $observation))
                (return (tradingObservationMapper $observation return))
                (pnl (tradingObservationMapper $observation unrealizedPnl))
                (momentum (tradingObservationMapper $observation momentum))
                (opportunity $opportunity)
                (volatility (tradingObservationMapper $observation turbulence))
                (stress (tradingObservationMapper $observation drawdown))
                (exposure (tradingObservationMapper $observation exposure))
                (confidence (tradingObservationMapper $observation signalConfidence))
                (uncertainty (tradingObservationMapper $observation regimeUncertainty))
                (friction (tradingObservationMapper $observation liquidityPressure))
                (cost (tradingObservationMapper $observation transactionCost))
                (hazard (* $risk (tradingObservationMapper $observation exposure)))
            )
        )
    )
)

(= (tradingObservationFromMarket $scenario $step $portfolio $previousTurbulence)
    (let* (
        ($price (tradingScenarioPriceAt $scenario $step))
        ($return (tradingScenarioReturn $scenario $step))
        ($turbulence (tradingDecayedTurbulence $return $previousTurbulence))
        ($holding (tradingIsHolding $portfolio))
        ($exposure (tradingExposure $portfolio $price))
        ($pnl (tradingUnrealizedPnl $portfolio $price))
        ($drawdown (tradingDrawdown $portfolio $price))
        ($momentum (tradingSignal $scenario $step))
        ($liquidity (clipUnit (+ (* 0.20 $turbulence) (* 0.05 (absNumber $return)))))
        ($confidence (tradingSignalConfidence $scenario $step))
        ($uncertainty (clipUnit (+ (* 0.50 $turbulence) (* 0.50 (- 1.0 $confidence)))))
        ($cost (clipUnit (* 100.0 (tradingEstimatedCostRate $turbulence))))
    )
        (makeTradingObservation $return $holding $turbulence $exposure $pnl $drawdown $momentum $liquidity $confidence $uncertainty $cost)
    )
)
