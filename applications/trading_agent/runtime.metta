(= (tradingRawStimulusAdapterFn $rawObservation)
    $rawObservation
)

(= (tradingCandidateBuilderFn $state $observation)
    (tradingBuildCandidates $state $observation)
)

(= (tradingFrameAdapters)
    ()
)

(= (tradingBundle)
    (let* (
        ($schema (tradingSchema))
        ($appraisal (tradingAppraisalProfile))
        ($decision (tradingDecisionProfile))
        ($stability (makeDefaultStabilityPolicy))
        ($coherence (makeDefaultCoherencePolicy))
        ($merge (makeDefaultParallelMergePolicy))
    )
        (applicationBundle
            trading_agent
            $schema
            $appraisal
            $decision
            defaultGoalChangeDeltaG
            $stability
            $coherence
            $merge
            tradingRawStimulusAdapterFn
            tradingCandidateBuilderFn
            (tradingFrameAdapters)
        )
    )
)

(= (tradingValidatedBundle)
    (validateApplicationBundle (tradingBundle))
)

(= (tradingBimonad)
    (bundleBimonad (tradingBundle))
)

(= (tradingBundleStepWithDiagnostics $state $rawObservation $embody)
    (let* (
        ($bundle (tradingBundle))
        ($stimulus (eval (bundleAdaptStimulus $bundle $rawObservation)))
        ($candidates (eval (bundleBuildCandidates $bundle $state $stimulus)))
        ($bimonad (eval (bundleBimonad $bundle)))
    )
        (eval (stepWithDiagnostics $bimonad $state $stimulus $candidates $embody))
    )
)

(= (tradingBundleStep $state $rawObservation)
    (let* (
        ($diagnosed (eval (tradingBundleStepWithDiagnostics $state $rawObservation True)))
    )
        (transitionResult (diagnosedAction $diagnosed) (diagnosedState $diagnosed))
    )
)

(: TradingEngineState Type)
(: tradingEngineState (-> MotivationState MotivationState TradingPortfolio Number Expression Expression TradingEngineState))

(: TradingPreparedCycle Type)
(: tradingPreparedCycle (-> TradingObservation MotivationState Expression TradingPreparedCycle))

(: TradingCycleResult Type)
(: tradingCycleResult (-> TradingEngineState ActionCandidate TradingObservation TradingCycleResult))

(: TradingDiagnosticsPair Type)
(: tradingDiagnosticsPair (-> Expression Expression TradingDiagnosticsPair))

(= (tradingEngineMapper $engineState $type)
    (let (tradingEngineState $prudence $ambition $portfolio $turbulence $history $diagnostics) $engineState
        (case $type (
            (prudence $prudence)
            (ambition $ambition)
            (portfolio $portfolio)
            (turbulence $turbulence)
            (history $history)
            (diagnostics $diagnostics)
            ($_ (empty))
        ))
    )
)

(= (tradingInitialEngineState)
    (tradingEngineState
        (tradingPrudenceState)
        (tradingAmbitionState)
        (tradingInitialPortfolio)
        0.0
        ()
        ()
    )
)

(= (tradingMergePerspectiveStates $prudenceState $ambitionState)
    (let* (
        ($bimonad (eval (tradingBimonad)))
    )
        (eval
            (parallelMerge
                (bimonadMerge $bimonad)
                (bimonadDecision $bimonad)
                $prudenceState
                $ambitionState
            )
        )
    )
)

(= (tradingPreparedMapper $preparedCycle $type)
    (let (tradingPreparedCycle $observation $merged $candidates) $preparedCycle
        (case $type (
            (observation $observation)
            (merged $merged)
            (candidates $candidates)
            ($_ (empty))
        ))
    )
)

(= (tradingPrepareCycle $engineState $scenario $step)
    (let* (
        ($observation (eval (tradingObservationFromMarket
            $scenario
            $step
            (tradingEngineMapper $engineState portfolio)
            (tradingEngineMapper $engineState turbulence)
        )))
        ($merged (eval (tradingMergePerspectiveStates
            (tradingEngineMapper $engineState prudence)
            (tradingEngineMapper $engineState ambition)
        )))
        ($candidates (eval (tradingBuildCandidates $merged $observation)))
    )
        (tradingPreparedCycle $observation $merged $candidates)
    )
)

(= (tradingDiagnosedStep $state $observation $candidates)
    (let* (
        ($bimonad (eval (tradingBimonad)))
    )
        (eval (stepWithDiagnostics $bimonad $state $observation $candidates True))
    )
)

(= (tradingConsensusScore $decision $contextA $contextB $candidate)
    (let* (
        ($scoreA (eval (magusScore $decision $contextA $candidate)))
        ($scoreB (eval (magusScore $decision $contextB $candidate)))
        ($mean (eval (/ (+ $scoreA $scoreB) 2.0)))
        ($disagreement (eval (absNumber (- $scoreA $scoreB))))
    )
        (eval (- $mean (* 0.20 $disagreement)))
    )
)

(= (tradingConsensusBestLoop $decision $contextA $contextB $currentBest $currentScore $remaining)
    (if (== $remaining ())
        $currentBest
        (let* (
            (($head $rest) (decons $remaining))
            ($headScore (eval (tradingConsensusScore $decision $contextA $contextB $head)))
        )
            (if (eval (> $headScore $currentScore))
                (tradingConsensusBestLoop $decision $contextA $contextB $head $headScore $rest)
                (tradingConsensusBestLoop $decision $contextA $contextB $currentBest $currentScore $rest)
            )
        )
    )
)

(= (tradingConsensusAction $decision $contextA $contextB $candidates)
    (let* (
        (($first $rest) (decons $candidates))
        ($firstScore (eval (tradingConsensusScore $decision $contextA $contextB $first)))
    )
        (tradingConsensusBestLoop $decision $contextA $contextB $first $firstScore $rest)
    )
)

(= (tradingDecisionDeltaForAction (magusDecision $profile $goalChangeFn $lambdaInd $lambdaTrans) $state $action $feedback)
    (profiledMagusProposeDeltaG $goalChangeFn $profile $state $action $feedback $lambdaInd $lambdaTrans)
)

(= (tradingConsensusTransition $prudenceState $ambitionState $observation $candidates)
    (let* (
        ($bimonad (eval (tradingBimonad)))
        ($decision (eval (bimonadDecision $bimonad)))
        ($contextP (eval (decisionContext $bimonad $prudenceState $observation)))
        ($contextA (eval (decisionContext $bimonad $ambitionState $observation)))
        ($action (eval (tradingConsensusAction $decision $contextP $contextA $candidates)))
        ($feedbackP (eval (bimonadFeedback $bimonad $prudenceState $observation)))
        ($feedbackA (eval (bimonadFeedback $bimonad $ambitionState $observation)))
        ($deltaP (eval (tradingDecisionDeltaForAction $decision $contextP $action $feedbackP)))
        ($deltaA (eval (tradingDecisionDeltaForAction $decision $contextA $action $feedbackA)))
        ($targetPComputation (eval (stateFromDeltaComputation $bimonad $contextP $deltaP $feedbackP)))
        ($targetAComputation (eval (stateFromDeltaComputation $bimonad $contextA $deltaA $feedbackA)))
        ($targetP (eval (transitionComputationState $targetPComputation)))
        ($targetA (eval (transitionComputationState $targetAComputation)))
        ($mergedTarget (eval (parallelMerge
            (bimonadMerge $bimonad)
            $decision
            $targetP
            $targetA
        )))
    )
        (transitionResult $action $mergedTarget)
    )
)

(= (tradingBlendTowardTarget $state $target)
    (let* (
        ($bimonad (eval (tradingBimonad)))
        ($blend (eval (measureBlend (bimonadCoherence $bimonad) $state $target)))
    )
        (eval (blendResultState $blend))
    )
)

(= (tradingCycleMapper $cycleResult $type)
    (let (tradingCycleResult $engine $action $observation) $cycleResult
        (case $type (
            (engine $engine)
            (action $action)
            (observation $observation)
            ($_ (empty))
        ))
    )
)

(= (tradingRunCycle $engineState $scenario $step)
    (let* (
        ($signalStep (- $step 1))
        ($prepared (eval (tradingPrepareCycle $engineState $scenario $signalStep)))
        ($observation (eval (tradingPreparedMapper $prepared observation)))
        ($candidates (eval (tradingPreparedMapper $prepared candidates)))
        ($transition (eval (tradingConsensusTransition
            (tradingEngineMapper $engineState prudence)
            (tradingEngineMapper $engineState ambition)
            $observation
            $candidates
        )))
        ($action (eval (transitionAction $transition)))
        ($target (eval (transitionState $transition)))
        ($nextPrudence (eval (tradingBlendTowardTarget (tradingEngineMapper $engineState prudence) $target)))
        ($nextAmbition (eval (tradingBlendTowardTarget (tradingEngineMapper $engineState ambition) $target)))
        ($price (tradingScenarioPriceAt $scenario $step))
        ($afterTrade (eval (tradingExecuteTrade (tradingEngineMapper $engineState portfolio) (candidateId $action) $price)))
        ($nextPortfolio (eval (tradingUpdatePortfolioPeak $afterTrade $price)))
        ($nextTurbulence (tradingObservationMapper $observation turbulence))
        ($value (eval (tradingPortfolioValue $nextPortfolio $price)))
        ($historyEntry (tradingTurn $scenario $step (candidateId $action) $value))
        ($diagnosedP (eval (tradingDiagnosedStep (tradingEngineMapper $engineState prudence) $observation $candidates)))
        ($diagnosedA (eval (tradingDiagnosedStep (tradingEngineMapper $engineState ambition) $observation $candidates)))
        ($nextEngine (tradingEngineState
            $nextPrudence
            $nextAmbition
            $nextPortfolio
            $nextTurbulence
            (listAppend (tradingEngineMapper $engineState history) ($historyEntry))
            (listAppend (tradingEngineMapper $engineState diagnostics) ((tradingDiagnosticsPair $diagnosedP $diagnosedA)))
        ))
    )
        (tradingCycleResult $nextEngine $action $observation)
    )
)

(= (TRADING_BASELINE_THRESHOLD) 0.12)

(= (tradingBaselineAction $signal $holding $exposure)
    (if $holding
        (if (< $signal (* -1.0 (TRADING_BASELINE_THRESHOLD))) sell
            (if (and (> $signal (TRADING_BASELINE_THRESHOLD)) (< $exposure 0.80)) buy hold))
        (if (> $signal (TRADING_BASELINE_THRESHOLD)) buy hold)
    )
)

(= (tradingBaselineStep $portfolio $scenario $step)
    (let* (
        ($price (tradingScenarioPriceAt $scenario $step))
        ($signal (tradingSignal $scenario (- $step 1)))
        ($action (tradingBaselineAction $signal (tradingIsHolding $portfolio) (tradingExposure $portfolio $price)))
    )
        (tradingUpdatePortfolioPeak (tradingExecuteTrade $portfolio $action $price) $price)
    )
)

(= (tradingEmotionIntensity $state happy)
    (clipUnit (/ (+ (+ (stateModulator $state valence) (stateModulator $state approach)) (stateModulator $state resolution)) 3.0))
)

(= (tradingEmotionIntensity $state sad)
    (clipUnit (/ (+ (+ (- 1.0 (stateModulator $state valence)) (stateModulator $state stress)) (stateModulator $state uncertainty)) 3.0))
)

(= (tradingEmotionIntensity $state angry)
    (clipUnit (/ (+ (+ (+ (stateModulator $state arousal) (stateModulator $state exposure)) (stateModulator $state stress)) (- 1.0 (stateModulator $state valence))) 4.0))
)

(= (tradingEmotionIntensity $state fear)
    (clipUnit (/ (+ (+ (+ (stateModulator $state securing) (stateModulator $state threshold)) (stateModulator $state volatility)) (stateModulator $state stress)) 4.0))
)

(= (tradingDominantEmotionFold $best $pairs)
    (if (== $pairs ())
        $best
        (let* (
            ($pair (car-atom $pairs))
            ($rest (cdr-atom $pairs))
        )
            (let ($name $val) $pair
                (let ($bestName $bestVal) $best
                    (if (> $val $bestVal)
                        (tradingDominantEmotionFold $pair $rest)
                        (tradingDominantEmotionFold $best $rest)
                    )
                )
            )
        )
    )
)

(= (tradingDominantEmotion $state)
    (let* (
        ($h (tradingEmotionIntensity $state happy))
        ($s (tradingEmotionIntensity $state sad))
        ($a (tradingEmotionIntensity $state angry))
        ($f (tradingEmotionIntensity $state fear))
        ($winner (tradingDominantEmotionFold (happy $h) ((sad $s) (angry $a) (fear $f))))
    )
        (let ($wName $wVal) $winner
            (if (> $wVal 0.6)
                ($wName $wVal)
                (neutral $wVal)
            )
        )
    )
)

(= (tradingLogRecord $scenario $step $price $actionId $state $portfolio)
    (let* (
        ($value (roundNum (eval (tradingPortfolioValue $portfolio $price)) 2))
        ($emotion (eval (tradingDominantEmotion $state)))
        ($fHappy (roundNum (eval (tradingEmotionIntensity $state happy)) 3))
        ($fSad (roundNum (eval (tradingEmotionIntensity $state sad)) 3))
        ($fAngry (roundNum (eval (tradingEmotionIntensity $state angry)) 3))
        ($fFear (roundNum (eval (tradingEmotionIntensity $state fear)) 3))
        ($valence (roundNum (eval (stateModulator $state valence)) 3))
        ($securing (roundNum (eval (stateModulator $state securing)) 3))
        ($gInd (roundNum (eval (stateGoal $state individuation)) 3))
        ($gTrans (roundNum (eval (stateGoal $state transcendence)) 3))
    )
        (TRADER scenario $scenario step $step price $price action $actionId emotion $emotion feelings ($fHappy $fSad $fAngry $fFear) valence $valence securing $securing gInd $gInd gTrans $gTrans value $value)
    )
)

(= (printTradingLogRecord $scenario $step $price $actionId $state $portfolio)
    (println! (tradingLogRecord $scenario $step $price $actionId $state $portfolio))
)

(= (tradingFinalRecord $scenario $portfolio $lastPrice)
    (TRADER FINAL scenario $scenario value (roundNum (eval (tradingPortfolioValue $portfolio $lastPrice)) 2))
)

(= (printTradingFinalRecord $scenario $portfolio $lastPrice)
    (println! (tradingFinalRecord $scenario $portfolio $lastPrice))
)

(= (tradingLoopScenario $scenario $engineState $step)
    (if (>= $step (tradingScenarioPriceCount $scenario))
        (printTradingFinalRecord
            $scenario
            (tradingEngineMapper $engineState portfolio)
            (tradingScenarioPriceAt $scenario (- (tradingScenarioPriceCount $scenario) 1))
        )
        (let* (
            ($cycle (eval (tradingRunCycle $engineState $scenario $step)))
            ($nextEngine (eval (tradingCycleMapper $cycle engine)))
            ($action (eval (tradingCycleMapper $cycle action)))
            ($price (tradingScenarioPriceAt $scenario $step))
            ($mergedState (eval (tradingMergePerspectiveStates
                (tradingEngineMapper $nextEngine prudence)
                (tradingEngineMapper $nextEngine ambition)
            )))
            ($_ (printTradingLogRecord
                $scenario
                $step
                $price
                (candidateId $action)
                $mergedState
                (tradingEngineMapper $nextEngine portfolio)
            ))
        )
            (tradingLoopScenario $scenario $nextEngine (+ $step 1))
        )
    )
)

(= (startTradingScenario $scenario)
    (let* (
        ($_ (println! (MetaMo Trading Agent starting scenario $scenario)))
    )
        (tradingLoopScenario $scenario (tradingInitialEngineState) 2)
    )
)

(= (startTradingAgentScenarios)
    (let* (
        ($_ (startTradingScenario vshape))
        ($_ (startTradingScenario choppy))
        ($_ (startTradingScenario downtrend))
    )
        (startTradingScenario realistic)
    )
)

(= (tradingBaselineLogRecord $scenario $step $price $actionId $portfolio)
    (BASELINE scenario $scenario step $step price $price action $actionId value (roundNum (eval (tradingPortfolioValue $portfolio $price)) 2))
)

(= (printTradingBaselineLogRecord $scenario $step $price $actionId $portfolio)
    (println! (tradingBaselineLogRecord $scenario $step $price $actionId $portfolio))
)

(= (tradingBaselineFinalRecord $scenario $portfolio $lastPrice)
    (BASELINE FINAL scenario $scenario value (roundNum (eval (tradingPortfolioValue $portfolio $lastPrice)) 2))
)

(= (printTradingBaselineFinalRecord $scenario $portfolio $lastPrice)
    (println! (tradingBaselineFinalRecord $scenario $portfolio $lastPrice))
)

(= (tradingBaselineLoopScenario $scenario $portfolio $step)
    (if (>= $step (tradingScenarioPriceCount $scenario))
        (printTradingBaselineFinalRecord
            $scenario
            $portfolio
            (tradingScenarioPriceAt $scenario (- (tradingScenarioPriceCount $scenario) 1))
        )
        (let* (
            ($price (tradingScenarioPriceAt $scenario $step))
            ($signal (tradingSignal $scenario (- $step 1)))
            ($actionId (tradingBaselineAction $signal (tradingIsHolding $portfolio) (tradingExposure $portfolio $price)))
            ($nextPortfolio (eval (tradingUpdatePortfolioPeak (tradingExecuteTrade $portfolio $actionId $price) $price)))
            ($_ (printTradingBaselineLogRecord $scenario $step $price $actionId $nextPortfolio))
        )
            (tradingBaselineLoopScenario $scenario $nextPortfolio (+ $step 1))
        )
    )
)

(= (startTradingBaselineScenario $scenario)
    (tradingBaselineLoopScenario $scenario (tradingInitialPortfolio) 2)
)

(= (startTradingBaselineScenarios)
    (let* (
        ($_ (println! (Signal Baseline starting)))
        ($_ (startTradingBaselineScenario vshape))
        ($_ (startTradingBaselineScenario choppy))
        ($_ (startTradingBaselineScenario downtrend))
    )
        (startTradingBaselineScenario realistic)
    )
)

(= (tradingNewSession)
    (tradingInitialEngineState)
)

(= (tradingStepCommand $scenario $step)
    (tradingCommand step $scenario $step)
)

(= (tradingDispatch $session (tradingCommand step $scenario $step))
    (tradingRunCycle $session $scenario $step)
)
