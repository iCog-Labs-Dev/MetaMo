(= (TRADING_INITIAL_CASH) 100.0)
(= (TRADING_MIN_EXPOSURE) 0.20)
(= (TRADING_ALLOCATION_STEP) 0.25)
(= (TRADING_FEE_RATE) 0.002)
(= (TRADING_SLIPPAGE_RATE) 0.001)

(= (tradingEstimatedCostRate $turbulence)
    (+ (+ (TRADING_FEE_RATE) (TRADING_SLIPPAGE_RATE)) (* 0.002 $turbulence))
)

(: TradingPortfolio Type)
(: tradingPortfolio (-> Number Number Number Number Number TradingPortfolio))

(= (tradingPortfolioMapper $portfolio $type)
    (let (tradingPortfolio $cash $units $entry $peak $value) $portfolio
        (case $type (
            (cash $cash)
            (units $units)
            (entry $entry)
            (peak $peak)
            (value $value)
            ($_ (empty))
        ))
    )
)

(= (tradingInitialPortfolio)
    (tradingPortfolio (TRADING_INITIAL_CASH) 0.0 0.0 (TRADING_INITIAL_CASH) (TRADING_INITIAL_CASH))
)

(= (tradingPortfolioValue (tradingPortfolio $cash $units $entryPrice $peakValue $lastValue) $price)
    (+ $cash (* $units $price))
)

(= (tradingIsHolding $portfolio)
    (> (tradingPortfolioMapper $portfolio units) 0.0)
)

(= (tradingExposure $portfolio $price)
    (let* (
        ($value (tradingPortfolioValue $portfolio $price))
    )
        (if (<= $value 0.0)
            0.0
            (clipUnit (/ (* (tradingPortfolioMapper $portfolio units) $price) $value))
        )
    )
)

(= (tradingUnrealizedPnl $portfolio $price)
    (if (tradingIsHolding $portfolio)
        (let* (
            ($entry (tradingPortfolioMapper $portfolio entry))
        )
            (if (<= $entry 0.0)
                0.0
                (clipRange (/ (- $price $entry) $entry) -1.0 1.0)
            )
        )
        0.0
    )
)

(= (tradingDrawdown $portfolio $price)
    (let* (
        ($value (tradingPortfolioValue $portfolio $price))
        ($peak (max-atom ((tradingPortfolioMapper $portfolio peak) $value)))
    )
        (if (<= $peak 0.0)
            0.0
            (clipUnit (/ (- $peak $value) $peak))
        )
    )
)

(= (tradingUpdatePortfolioPeak $portfolio $price)
    (let* (
        ($value (tradingPortfolioValue $portfolio $price))
        ($peak (max-atom ((tradingPortfolioMapper $portfolio peak) $value)))
    )
        (tradingPortfolio
            (tradingPortfolioMapper $portfolio cash)
            (tradingPortfolioMapper $portfolio units)
            (tradingPortfolioMapper $portfolio entry)
            $peak
            $value
        )
    )
)

(= (tradingExecuteTrade $portfolio buy $price)
    (if (> (tradingPortfolioMapper $portfolio cash) 0.0)
        (let* (
            ($cash (tradingPortfolioMapper $portfolio cash))
            ($oldUnits (tradingPortfolioMapper $portfolio units))
            ($oldEntry (tradingPortfolioMapper $portfolio entry))
            ($value (tradingPortfolioValue $portfolio $price))
            ($targetAllocation (* (TRADING_ALLOCATION_STEP) $value))
            ($allocation (if (< $cash $targetAllocation) $cash $targetAllocation))
            ($fee (* $allocation (TRADING_FEE_RATE)))
            ($executionPrice (* $price (+ 1.0 (TRADING_SLIPPAGE_RATE))))
            ($addedUnits (/ (- $allocation $fee) $executionPrice))
            ($newUnits (+ $oldUnits $addedUnits))
            ($newCash (- $cash $allocation))
            ($newEntry (if (> $oldUnits 0.0)
                (/ (+ (* $oldUnits $oldEntry) $allocation) $newUnits)
                (/ $allocation $addedUnits)
            ))
            ($newValue (+ $newCash (* $newUnits $price)))
        )
            (tradingPortfolio
                $newCash
                $newUnits
                $newEntry
                (max-atom ((tradingPortfolioMapper $portfolio peak) $newValue))
                $newValue
            )
        )
        $portfolio
    )
)

(= (tradingExecuteTrade $portfolio sell $price)
    (if (> (tradingPortfolioMapper $portfolio units) 0.0)
        (let* (
            ($executionPrice (* $price (- 1.0 (TRADING_SLIPPAGE_RATE))))
            ($gross (* (tradingPortfolioMapper $portfolio units) $executionPrice))
            ($fee (* $gross (TRADING_FEE_RATE)))
            ($cash (+ (tradingPortfolioMapper $portfolio cash) (- $gross $fee)))
            ($peak (max-atom ((tradingPortfolioMapper $portfolio peak) $cash)))
        )
            (tradingPortfolio $cash 0.0 0.0 $peak $cash)
        )
        $portfolio
    )
)

(= (tradingExecuteTrade $portfolio hold $price)
    (tradingUpdatePortfolioPeak $portfolio $price)
)

(= (tradingExecuteTrade $portfolio reduce $price)
    (if (> (tradingPortfolioMapper $portfolio units) 0.0)
        (let* (
            ($sellUnits (* 0.5 (tradingPortfolioMapper $portfolio units)))
            ($remainingUnits (- (tradingPortfolioMapper $portfolio units) $sellUnits))
            ($executionPrice (* $price (- 1.0 (TRADING_SLIPPAGE_RATE))))
            ($gross (* $sellUnits $executionPrice))
            ($fee (* $gross (TRADING_FEE_RATE)))
            ($cash (+ (tradingPortfolioMapper $portfolio cash) (- $gross $fee)))
            ($value (+ $cash (* $remainingUnits $price)))
            ($peak (max-atom ((tradingPortfolioMapper $portfolio peak) $value)))
            ($remainingExposure (if (<= $value 0.0) 0.0 (clipUnit (/ (* $remainingUnits $price) $value))))
        )
            (if (< $remainingExposure (TRADING_MIN_EXPOSURE))
                (tradingExecuteTrade $portfolio sell $price)
                (tradingPortfolio $cash $remainingUnits (tradingPortfolioMapper $portfolio entry) $peak $value)
            )
        )
        $portfolio
    )
)
