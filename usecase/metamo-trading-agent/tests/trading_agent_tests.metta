;; Tests for the trading application.
;;
;; They cover the market world (trading_market.metta), the MetaMo adapters
;; (trading_core.metta) and one full framework cycle over the trading
;; candidates.
;;
;; Run:
;;   sh /path/to/PeTTa/run.sh usecase/metamo-trading-agent/tests/trading_agent_tests.metta

!(import! &self ../../../core/helper)
!(import! &self "../../../core/helpers.py")
!(import! &self ../../../core/state)
!(import! &self ../../../core/state_accessors)
!(import! &self ../../../core/config)
!(import! &self ../../../openpsi/config)
!(import! &self ../../../category/functors)
!(import! &self ../../../category/bimonad)
!(import! &self ../../../openpsi/appraisal)
!(import! &self ../../../openpsi/appraisal_helpers)
!(import! &self ../../../openpsi/feeling)
!(import! &self ../../../magus/decision)
!(import! &self ../../../dynamics/stability)
!(import! &self ../../../dynamics/coherence)
!(import! &self ../../../main/main)
!(import! &self ../trading_market)
!(import! &self ../trading_core)

;; Market world

;; The default scenario has 20 prices starting at 10.0, and the older
;; zero-argument accessors point to it.
!(test (priceCount) 20)
!(test (priceAt 0) 10.0)
!(test (priceAt 5) (scenarioPriceAt (DEFAULT_SCENARIO) 5))

;; Named scenarios can be used directly.
!(test (scenarioPriceCount choppy) 20)
!(test (scenarioPriceAt choppy 0) 10.0)
!(test (scenarioPriceAt choppy 19) 10.5)

;; The default scenario opens with +2%, choppy with +4% and the downtrend
;; with -3%.
!(test (eval (roundNum (marketReturn 1) 2)) 0.02)
!(test (eval (roundNum (scenarioReturn choppy 1) 2)) 0.04)
!(test (scenarioPriceCount downtrend) 20)
!(test (eval (roundNum (scenarioReturn downtrend 1) 2)) -0.03)

;; The realistic scenario has 50 prices and starts at 100.
!(test (scenarioPriceCount realistic) 50)
!(test (scenarioPriceAt realistic 0) 100.0)

;; Portfolio math: start flat with 100, buy turns all cash into units, the
;; position changes value with the price, and sell turns it back to cash.
!(test (portfolioValue (initialPortfolio) 10.0) 100.0)
!(test (executeTrade (portfolio 100.0 0.0) buy 10.0) (portfolio 0.0 10.0))
!(test (portfolioValue (portfolio 0.0 10.0) 12.0) 120.0)
!(test (executeTrade (portfolio 0.0 10.0) sell 12.0) (portfolio 120.0 0.0))

;; Moves that make no sense do nothing: buying while already holding,
;; selling while flat, and holding.
!(test (executeTrade (portfolio 0.0 10.0) buy 12.0) (portfolio 0.0 10.0))
!(test (executeTrade (portfolio 100.0 0.0) sell 12.0) (portfolio 100.0 0.0))
!(test (executeTrade (portfolio 0.0 10.0) hold 12.0) (portfolio 0.0 10.0))

;; Stimulus adapter

;; All four stimulus values stay between 0 and 1 even for extreme inputs.
!(test (getStimulus (marketStimulus 0.5 True 1.0) risk) 1.0)
!(test (getStimulus (marketStimulus 0.5 True 1.0) novelty) 1.0)
!(test (getStimulus (marketStimulus -0.2 True 1.0) conduciveness) 0.0)

;; A crash while holding is high risk (turbulence plus HOLDING_LOSS_RISK).
!(test (eval (roundNum (getStimulus (marketStimulus -0.115 True 0.69) risk) 2)) 0.94)

;; The same turbulence while flat has no holding loss part.
!(test (eval (roundNum (getStimulus (marketStimulus -0.115 False 0.69) risk) 2)) 0.69)

;; A rally while holding is conducive, and effort is always the constant.
!(test (eval (roundNum (getStimulus (marketStimulus 0.05 True 0.3) conduciveness) 2)) 0.8)
!(test (getStimulus (marketStimulus 0.05 True 0.3) effort) 0.1)

;; Candidate adapter

;; All candidates match the framework's 8-goal action shape.
!(test (validateActionShape (buyCandidate 0.3)) True)
!(test (validateActionShape (sellCandidate 0.3)) True)
!(test (validateActionShape (holdCandidate)) True)

;; The correlations scale with turbulence: sell's safety correlation
;; (gEthic, index 6) grows from 0.2 in a calm market to 0.8 in a violent
;; one, and buy's curiosity correlation (index 3) shrinks with turbulence.
!(test (index-atom (actionGoalCorrelations (sellCandidate 0.0)) 6) 0.2)
!(test (eval (roundNum (index-atom (actionGoalCorrelations (sellCandidate 1.0)) 6) 2)) 0.8)
!(test (index-atom (actionGoalCorrelations (buyCandidate 0.0)) 3) 0.65)
!(test (eval (roundNum (index-atom (actionGoalCorrelations (buyCandidate 1.0)) 3) 3)) 0.325)

;; The offered actions depend on the position: buy is only offered while
;; flat and sell only while holding.
!(test (actionId (car-atom (tradingCandidates 0.12 False))) buy)
!(test (actionId (car-atom (tradingCandidates 0.12 True))) sell)

;; Turbulence memory: a quiet day right after a panic day still feels
;; turbulent because the memory wins, after a calm day the fresh value
;; wins, and falls count fully while rises only count half.
!(test (eval (roundNum (decayedTurbulence 0.02 0.72) 2)) 0.54)
!(test (eval (roundNum (decayedTurbulence -0.05 0.0) 2)) 0.3)
!(test (eval (roundNum (decayedTurbulence 0.05 0.0) 2)) 0.15)

;; An agent in cash does not care about the price itself but gets uneasy
;; when remembered turbulence is high.
!(test (marketConduciveness -0.2 False 0.0) 0.5)
!(test (marketConduciveness -0.2 False 1.0) 0.0)
!(test (eval (roundNum (marketConduciveness -0.2 False 0.3) 2)) 0.14)

;; Both subsystem states have the shape the framework expects.
!(test (validateMotivationalStateShape (prudenceState)) True)
!(test (validateMotivationalStateShape (ambitionState)) True)

;; Full cycle smoke test

;; Runs one complete MetaMo cycle on a crash while holding (remembered
;; turbulence 0.69, which is a fresh -11.5% day). The consensus action must
;; be one of the offered candidates and the merged state must still be a
;; valid motivational state.
(= (crashCycleResult)
    (runMetaMoCycleDefault
        (defaultMetaMoBimonad)
        (tradingSubsystems)
        (marketStimulus -0.115 True 0.69)
        (tradingCandidates 0.69 True)
        ()
        ())
)

!(test (let $isOfferedWhileHolding (|-> ($actionId) (or (== $actionId sell) (== $actionId hold)))
            ($isOfferedWhileHolding (actionId (cycleFinalAction (crashCycleResult)))))
       True)
!(test (validateMotivationalStateShape (cycleMergedTarget (crashCycleResult))) True)
