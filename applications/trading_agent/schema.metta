(= (tradingGoalNames)
    (individuation transcendence capital profit safety opportunity liquidity discipline drawdown overtrading recklessness illiquidity chasing staleness)
)

(= (tradingPrimaryGoalNames)
    (capital profit safety opportunity liquidity discipline)
)

(= (tradingAntiGoalNames)
    (drawdown overtrading recklessness illiquidity chasing staleness)
)

(= (tradingCoreModulatorNames)
    (valence arousal approach resolution threshold securing)
)

(= (tradingApplicationModulatorNames)
    (volatility stress exposure confidence uncertainty friction)
)

(= (tradingModulatorNames)
    (valence arousal approach resolution threshold securing volatility stress exposure confidence uncertainty friction)
)

(= (tradingGoalSchema)
    (magusGoalSchema
        (tradingPrimaryGoalNames)
        (tradingAntiGoalNames)
        (tradingGoalNames)
        individuation
        transcendence
    )
)

(= (tradingModulatorSchema)
    (modulatorSchema
        (tradingCoreModulatorNames)
        (tradingApplicationModulatorNames)
        (tradingModulatorNames)
    )
)

(= (tradingSchema)
    (motivationSchema
        trading_agent
        (tradingGoalSchema)
        (tradingModulatorSchema)
        trading_magus_additive
        trading_openpsi
    )
)

(= (tradingGoalIndex $goalName)
    (schemaGoalIndex (tradingSchema) $goalName)
)

(= (tradingModulatorIndex $modulatorName)
    (schemaModulatorIndex (tradingSchema) $modulatorName)
)

(= (tradingDefaultGoals)
    (0.60 0.55 0.78 0.70 0.75 0.60 0.60 0.65 0.30 0.25 0.25 0.20 0.20 0.20)
)

(= (tradingDefaultModulators)
    (0.50 0.50 0.50 0.55 0.50 0.50 0.20 0.10 0.00 0.60 0.20 0.10)
)

(= (tradingGoalDescription $goalName)
    (symbolMapGet
        (
            (individuation stability)
            (transcendence adaptation)
            (capital preservation)
            (profit return)
            (safety caution)
            (opportunity timing)
            (liquidity liquidity)
            (discipline discipline)
            (drawdown drawdown)
            (overtrading overtrading)
            (recklessness recklessness)
            (illiquidity illiquidity)
            (chasing chasing)
            (staleness staleness)
        )
        $goalName
        unknown
    )
)

(= (tradingGoalVectorFromPairs $pairs)
    (
        (featurePairsGet $pairs individuation 0.0)
        (featurePairsGet $pairs transcendence 0.0)
        (featurePairsGet $pairs capital 0.0)
        (featurePairsGet $pairs profit 0.0)
        (featurePairsGet $pairs safety 0.0)
        (featurePairsGet $pairs opportunity 0.0)
        (featurePairsGet $pairs liquidity 0.0)
        (featurePairsGet $pairs discipline 0.0)
        (featurePairsGet $pairs drawdown 0.0)
        (featurePairsGet $pairs overtrading 0.0)
        (featurePairsGet $pairs recklessness 0.0)
        (featurePairsGet $pairs illiquidity 0.0)
        (featurePairsGet $pairs chasing 0.0)
        (featurePairsGet $pairs staleness 0.0)
    )
)

(= (tradingModulatorVectorFromPairs $pairs)
    (
        (featurePairsGet $pairs valence 0.0)
        (featurePairsGet $pairs arousal 0.0)
        (featurePairsGet $pairs approach 0.0)
        (featurePairsGet $pairs resolution 0.0)
        (featurePairsGet $pairs threshold 0.0)
        (featurePairsGet $pairs securing 0.0)
        (featurePairsGet $pairs volatility 0.0)
        (featurePairsGet $pairs stress 0.0)
        (featurePairsGet $pairs exposure 0.0)
        (featurePairsGet $pairs confidence 0.0)
        (featurePairsGet $pairs uncertainty 0.0)
        (featurePairsGet $pairs friction 0.0)
    )
)

(= (tradingCorrelationVector $pairs)
    (clipVector (tradingGoalVectorFromPairs $pairs) -1.0 1.0)
)

(= (tradingDeltaVector $pairs)
    (clipVector (tradingGoalVectorFromPairs $pairs) -0.1 0.1)
)
