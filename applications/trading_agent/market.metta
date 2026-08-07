(= (tradingScenarioPrices vshape)
    (100.0 101.38 102.24 101.6 103.57 104.79 106.1 107.19 110.2 112.39 112.14 109.74 107.16 103.86 101.69 96.37 96.66 95.12 93.54 92.92 93.62 95.06 97.17 96.42 99.74 101.14 103.18 103.08 103.52 107.04 107.62 108.37)
)

(= (tradingScenarioPrices choppy)
    (100.0 103.91 101.45 101.9 101.23 99.5 98.52 97.75 97.8 98.7 100.63 100.93 102.81 103.3 103.09 102.3 100.2 97.25 97.3 97.19 97.94 98.63 96.45 95.48 93.93 96.12 96.21 96.69 95.35 93.55 93.11 93.52)
)

(= (tradingScenarioPrices downtrend)
    (100.0 97.97 96.81 96.66 94.96 92.98 92.16 88.42 89.4 89.76 89.87 89.33 89.76 90.17 85.21 84.52 82.88 81.46 80.66 78.79 78.72 79.12 76.84 77.27 75.99 75.11 74.1 72.73 71.43 70.81 68.77 69.12)
)

(= (tradingScenarioPrices realistic)
    (100.0 99.15 100.06 101.66 101.59 100.61 101.04 102.08 103.82 102.95 102.01 103.31 104.36 106.65 108.33 108.75 108.97 112.59 112.8 108.72 104.1 101.99 92.3 89.7 87.63 77.11 76.38 76.2 74.81 70.76 72.34 71.04 71.45 70.09 70.72 70.31 71.23 76.34 76.95 78.88 77.61 77.88 79.56 80.14 81.42 82.31 81.48 83.09 82.55 86.23)
)

(= (tradingScenarioPriceCount $scenario)
    (size-atom (tradingScenarioPrices $scenario))
)

(= (tradingScenarioPriceAt $scenario $step)
    (index-atom (tradingScenarioPrices $scenario) $step)
)

(= (tradingScenarioReturn $scenario $step)
    (let* (
        ($current (tradingScenarioPriceAt $scenario $step))
        ($previous (tradingScenarioPriceAt $scenario (- $step 1)))
    )
        (/ (- $current $previous) $previous)
    )
)

(= (TRADING_RISK_GAIN) 6.0)
(= (TRADING_TURBULENCE_DECAY) 0.75)
(= (TRADING_UPSIDE_TURBULENCE_FACTOR) 0.5)
(= (TRADING_SIGNAL_GAIN) 12.0)

(= (tradingDecayedTurbulence $return $previousTurbulence)
    (let* (
        ($directionWeight (if (< $return 0.0) 1.0 (TRADING_UPSIDE_TURBULENCE_FACTOR)))
        ($raw (clipUnit (* (* (absNumber $return) (TRADING_RISK_GAIN)) $directionWeight)))
        ($decayed (* (TRADING_TURBULENCE_DECAY) $previousTurbulence))
    )
        (max-atom ($raw $decayed))
    )
)

(= (tradingMomentum $scenario $step)
    (if (< $step 3)
        (tradingScenarioReturn $scenario $step)
        (if (< $step 5)
            (/ (+ (+ (tradingScenarioReturn $scenario $step) (tradingScenarioReturn $scenario (- $step 1))) (tradingScenarioReturn $scenario (- $step 2))) 3.0)
            (/ (+
                    (+ (tradingScenarioReturn $scenario $step) (tradingScenarioReturn $scenario (- $step 1)))
                    (+ (+ (tradingScenarioReturn $scenario (- $step 2)) (tradingScenarioReturn $scenario (- $step 3)))
                       (tradingScenarioReturn $scenario (- $step 4))))
               5.0)
        )
    )
)

(= (tradingSignal $scenario $step)
    (clipRange (* (TRADING_SIGNAL_GAIN) (tradingMomentum $scenario $step)) -1.0 1.0)
)

(= (tradingSignalConfidence $scenario $step)
    (let* (
        ($signal (tradingSignal $scenario $step))
        ($return (tradingScenarioReturn $scenario $step))
        ($agreement (if (or (and (> $signal 0.0) (> $return 0.0))
                            (and (< $signal 0.0) (< $return 0.0)))
                        1.0
                        0.0
                    ))
    )
        (clipUnit (+ 0.20 (+ (* 0.55 (absNumber $signal)) (* 0.25 $agreement))))
    )
)
