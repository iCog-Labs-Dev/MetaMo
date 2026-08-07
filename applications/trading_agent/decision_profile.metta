(= (tradingDecisionProfile)
    (let* (
        ($schema (tradingSchema))
    )
        (decisionProfile
            trading_magus_additive
            $schema
            (
                (capital (securing threshold stress))
                (profit (approach confidence))
                (safety (threshold securing volatility stress))
                (opportunity (arousal approach confidence))
                (liquidity (friction threshold))
                (discipline (resolution exposure))
            )
            (capital safety liquidity discipline)
            (profit opportunity)
            ()
            (
                (drawdown 1.5)
                (overtrading 1.0)
                (recklessness 1.6)
                (illiquidity 1.2)
                (chasing 1.3)
                (staleness 1.1)
            )
            (
                (individuation safeguard)
                (transcendence growth)
            )
            (
                (drawdown drawdown)
                (overtrading overtrading)
                (recklessness recklessness)
                (illiquidity illiquidity)
                (chasing chasing)
                (staleness staleness)
            )
            none
            0.012
            0.020
            0.045
            0.25
            0.08
        )
    )
)

(= (tradingGrowthGoals)
    (profit opportunity)
)

(= (tradingSafetyGoals)
    (capital safety liquidity discipline)
)
