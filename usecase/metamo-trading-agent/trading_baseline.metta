;; Simple momentum baseline used for the comparison.
;;
;; This agent trades in the exact same market world as the MetaMo agent
;; (trading_market.metta) but uses none of the MetaMo thinking. It just
;; buys after any rise above a fixed threshold and sells after any fall
;; below it. It only borrows the math helpers for rounding the log values.
;; So any difference between the two agents comes from the MetaMo
;; motivational system and nothing else.
;;
;; Run:
;;   sh /path/to/PeTTa/run.sh usecase/metamo-trading-agent/trading_baseline.metta

!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self trading_market)

;; The return size that triggers the momentum rule.
(= (BASELINE_THRESHOLD) 0.01)

;; Runs the baseline over one scenario's whole price series and prints one
;; parseable atom per step, in the same shape as the MetaMo agent's log.
;; Example: (baselineLoop vshape (initialPortfolio) 1)
(= (baselineLoop $scenario $portfolio $step)
    (if (>= $step (scenarioPriceCount $scenario))
        (let* (
            ($lastPrice  (scenarioPriceAt $scenario (- (scenarioPriceCount $scenario) 1)))
            ($finalValue (roundNum (portfolioValue $portfolio $lastPrice) 2))
        )
            (println! (BASELINE FINAL scenario $scenario value $finalValue))
        )
        (let* (
            ($price         (scenarioPriceAt $scenario $step))
            ($return        (scenarioReturn $scenario $step))
            ($holding       (isHolding $portfolio))
            ($baselineAction (|-> ($return $holding)
                (if $holding
                    (if (< $return (* -1.0 (BASELINE_THRESHOLD))) sell hold)
                    (if (> $return (BASELINE_THRESHOLD)) buy hold)
                )
            ))
            ($actionId      ($baselineAction $return $holding))
            ($nextPortfolio (executeTrade $portfolio $actionId $price))
            ($value         (roundNum (portfolioValue $nextPortfolio $price) 2))
            ($_ (println! (BASELINE scenario $scenario step $step price $price action $actionId value $value)))
        )
            (baselineLoop $scenario $nextPortfolio (+ $step 1))
        )
    )
)

!(println! (Momentum Baseline starting))
!(baselineLoop vshape (initialPortfolio) 1)
!(baselineLoop choppy (initialPortfolio) 1)
!(baselineLoop downtrend (initialPortfolio) 1)
!(baselineLoop realistic (initialPortfolio) 1)
