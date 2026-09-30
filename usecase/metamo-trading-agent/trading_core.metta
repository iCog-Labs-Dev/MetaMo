;; Adapters that connect the trading world to MetaMo.
;;
;; This file only translates market data into the types MetaMo already
;; understands. It does not reimplement anything. Appraisal, decision
;; scoring, consensus, the safety dynamics and the emotion layer all come
;; straight from the framework modules.
;;
;; It has three parts, built the same way as the research assistant:
;;   1. The two subsystem states     -> (motivation goals modulators)
;;   2. The market stimulus adapter  -> (openPsiStimulus n c r e)
;;   3. The trade action candidates  -> (action id corrs risk deltaG)
;;
;; Like the other framework modules, this file does not import anything
;; itself. The entry point (trading_agent.metta) does all the imports.

;; Part 1. The two subsystem states

;; The agent is made of two subsystems that want different things.
;; Prudence wants to protect the money, so its individuation goal is high.
;; Ambition wants to grow the money, so its transcendence goal is high.
;; Every step the framework's consensusTransition makes them agree on one
;; action, so the tension between them is what actually trades.
;;
;; Goal order:      (gInd gTrans gHelp gCurio gNovel gSelf gEthic gSoc)
;; Modulator order: (valence arousal approach resolution threshold securing)

;; The careful subsystem. High individuation and high caution modulators
;; (threshold and securing), low arousal and approach.
;; Example: (prudenceState)
(= (prudenceState)
    (motivation
        (0.85 0.20 0.40 0.20 0.15 0.50 0.80 0.30)
        (0.50 0.30 0.30 0.60 0.65 0.70)
    )
)

;; The eager subsystem. High transcendence, curiosity and novelty, with
;; high arousal and approach and low caution. Its gInd starts at 0.35,
;; just above the safe region floor (THETA_SAFE = 0.3), so the framework's
;; boundary caution and projection code really gets used when decisions
;; push it near the edge.
;; Example: (ambitionState)
(= (ambitionState)
    (motivation
        (0.35 0.85 0.30 0.80 0.80 0.60 0.30 0.30)
        (0.50 0.70 0.70 0.40 0.30 0.30)
    )
)

;; Both subsystems in the list shape that runMetaMoCycle expects.
;; Example: (tradingSubsystems)
(= (tradingSubsystems)
    (
        (subsystemState prudence (prudenceState))
        (subsystemState ambition (ambitionState))
    )
)

;; Part 2. Turning a market observation into an OpenPSI stimulus

;; How strongly the size of a price move counts as novelty.
(= (NOVELTY_GAIN) 8.0)

;; How strongly the direction of a price move counts as conduciveness.
(= (CONDUCIVENESS_GAIN) 6.0)

;; How strongly the size of a price move counts as risk and turbulence.
(= (RISK_GAIN) 6.0)

;; Extra risk added when the agent is holding and the price just fell.
;; Losing money on an open position hurts more than watching from cash.
(= (HOLDING_LOSS_RISK) 0.25)

;; Trading one asset takes the same small effort every step.
(= (TRADING_EFFORT) 0.10)

;; How uneasy a flat agent gets from remembered turbulence. An agent in
;; cash is not losing money, but a crashing market is still a scary place,
;; so its conduciveness goes down as turbulence goes up.
(= (FLAT_UNEASE) 1.2)

;; How fast remembered turbulence fades each step. In real markets one
;; panic day is usually followed by more rough days, so the agent should
;; not treat one quiet day inside a crash as a calm market.
(= (TURBULENCE_DECAY) 0.75)

;; Rises only count half toward remembered turbulence. Falls are what make
;; a market feel dangerous, and a strong recovery rally should invite
;; buying instead of blocking it.
(= (UPSIDE_TURBULENCE_FACTOR) 0.5)

;; The turbulence the agent remembers. It takes today's turbulence or the
;; faded memory of recent turbulence, whichever is bigger.
;; Example: (decayedTurbulence -0.05 0.0) -> 0.3
(= (decayedTurbulence $return $previousTurbulence)
    (let* (
        ($directionWeight (if (< $return 0.0) 1.0 (UPSIDE_TURBULENCE_FACTOR)))
        ($raw (npClip (* (* (absNumber $return) (RISK_GAIN)) $directionWeight) 0.0 1.0))
        ($decayed (* (TURBULENCE_DECAY) $previousTurbulence))
    )
        (if (> $raw $decayed) $raw $decayed)
    )
)

;; Conduciveness between 0 and 1, seen from the agent's position. While
;; holding, a rise is good and a fall is bad. While flat, the price does
;; not touch the wallet, but a turbulent market still feels unsafe, so
;; conduciveness sinks with remembered turbulence.
;; Example: (marketConduciveness 0.05 True 0.3) -> 0.8
(= (marketConduciveness $return $holding $turbulence)
    (if $holding
        (npClip (+ 0.5 (* $return (CONDUCIVENESS_GAIN))) 0.0 1.0)
        (npClip (- 0.5 (* (FLAT_UNEASE) $turbulence)) 0.0 1.0)
    )
)

;; Risk between 0 and 1. It is the remembered turbulence, plus the extra
;; holding-loss part when a held position just lost value. Because it uses
;; the remembered turbulence, the framework's appraisal stays careful
;; through a whole crash instead of relaxing on every quiet day inside it.
;; Example: (marketRisk -0.115 True 0.69) -> 0.94
(= (marketRisk $return $holding $turbulence)
    (let $lossBonus (if (and $holding (< $return 0.0)) (HOLDING_LOSS_RISK) 0.0)
        (npClip (+ $turbulence $lossBonus) 0.0 1.0)
    )
)

;; Puts the four parts together into the OpenPSI stimulus. This plays the
;; same role as the text perception in the research assistant.
;; Example: (marketStimulus 0.05 True 0.3)
(= (marketStimulus $return $holding $turbulence)
    (let $marketNovelty 
        (|-> ($return) 
            (npClip (* (absNumber $return) (NOVELTY_GAIN)) 0.0 1.0)
        )
        (openPsiStimulus
            ($marketNovelty $return)
            (marketConduciveness $return $holding $turbulence)
            (marketRisk $return $holding $turbulence)
            (TRADING_EFFORT)
        )
    )
)

;; Part 3. The trade actions offered to the framework

;; The goal correlations use the framework's 8-goal layout. In the MAGUS
;; scorer, gCurio is weighted by arousal, gNovel by approach and gEthic by
;; the average of threshold and securing. So buying naturally wins when the
;; excited modulators are high, and selling wins when the caution
;; modulators are high. gInd and gTrans work through the overgoal support
;; and through each action's deltaG instead of direct correlations.

;; The papers give the scoring equation but leave the correlations open as
;; a modeling choice. Here they depend on the market: in a dangerous market
;; selling counts strongly as the safety goal and buying counts weakly as
;; exploring, and in a calm market it is the other way around. The research
;; assistant builds its candidates from the current context in the same
;; way.

;; Buying goes for gains. Its curiosity and novelty correlations are
;; strongest in calm markets and shrink with turbulence, while its risk
;; grows with turbulence. Its deltaG pushes the goals a bit toward
;; transcendence.
;; Example: (buyCandidate 0.3)
(= (buyCandidate $turbulence)
    (let $exploreCorr (* 0.65 (- 1.0 (* 0.5 $turbulence)))
        (action buy
            (-0.40 0.70 0.00 $exploreCorr $exploreCorr 0.30 -0.10 0.00)
            (npClip (+ 0.30 (* 0.60 $turbulence)) 0.0 1.0)
            (-0.02 0.03 0.0 0.01 0.01 0.0 0.0 0.0)
        )
    )
)

;; Selling protects the money. Its safety correlation (gEthic) grows with
;; turbulence, from 0.2 in a calm market up to 0.8 in a violent one, and
;; its risk stays low. Its deltaG pushes the goals a bit toward
;; individuation.
;; Example: (sellCandidate 0.3)
(= (sellCandidate $turbulence)
    (let $safetyCorr (+ 0.2 (* 0.6 $turbulence))
        (action sell
            (0.70 -0.40 0.00 -0.15 -0.15 0.25 $safetyCorr 0.00)
            (npClip (+ 0.10 (* 0.15 $turbulence)) 0.0 1.0)
            (0.03 -0.02 0.0 -0.01 -0.01 0.0 0.01 0.0)
        )
    )
)

;; Holding is the safe default. It leans a little toward individuation and
;; drifts the goals slightly toward safety.
;; Example: (holdCandidate)
(= (holdCandidate)
    (action hold
        (0.25 0.05 0.00 0.00 -0.10 0.10 0.20 0.00)
        0.08
        (0.005 -0.005 0.0 0.0 0.0 0.0 0.0 0.0)
    )
)

;; The actions offered to the MetaMo cycle. Only actions that make sense
;; for the current position are offered: buy or hold when flat, sell or
;; hold when holding. Takes the remembered turbulence from
;; decayedTurbulence.
;; Example: (tradingCandidates 0.3 False)
(= (tradingCandidates $turbulence $holding)
    (if $holding
        ((sellCandidate $turbulence) (holdCandidate))
        ((buyCandidate $turbulence) (holdCandidate))
    )
)
