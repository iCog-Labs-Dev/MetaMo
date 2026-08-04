;; Isolated diagnostic for OmegaClaw's MetaMo appraisal and decision layers.
;; This file does not import bridge.metta or OmegaClaw-Core, so task routing,
;; the LLM, and command policy cannot influence the results.

!(import! &self (library lib_import))

!(import! &self (library MetaMo core/config))
!(import! &self (library MetaMo applications/omegaclaw/openpsi_config))
!(import! &self (library MetaMo core/state))
!(import! &self (library MetaMo core/state_accessors))
!(import! &self (library MetaMo core/helper))
!(import! &self (library MetaMo core/helpers.py))
!(import! &self (library MetaMo category/functors))

!(import! &self (library MetaMo applications/omegaclaw/registry))
!(import! &self (library MetaMo applications/omegaclaw/adapter))
!(import! &self (library MetaMo applications/omegaclaw/omegaclaw_appraisal))
!(import! &self (library MetaMo applications/omegaclaw/omegaclaw_decision))


(= (clamp $value)
   (if (< $value 0.0) 0.0 (if (> $value 1.0) 1.0 $value)))


;; Every scenario uses this exact candidate set. No availability gate runs.
(= (diagnosticActions)
   (collapse
      (let $name (superpose (respond retrieve-memory learn ask-clarification))
         (candidateToAction $name))))

(= (diagnosticScores $state)
   (let* (
      ($respondScore
         (omegaclawScore $state (candidateToAction respond)))
      ($retrieveScore
         (omegaclawScore $state (candidateToAction retrieve-memory)))
      ($learnScore
         (omegaclawScore $state (candidateToAction learn)))
      ($clarificationScore
         (omegaclawScore $state (candidateToAction ask-clarification)))
   )
      ((respond $respondScore)
       (retrieve-memory $retrieveScore)
       (learn $learnScore)
       (ask-clarification $clarificationScore))))

;; Use the same pure best-action traversal as omegaclawDecide without updating
;; its anti-saturation counter. This keeps repeated diagnostic runs identical.
(= (diagnosticWinner $state)
   (let* (
      ($actions (diagnosticActions))
      (($head $tail) (decons-atom $actions))
      ($firstScore (omegaclawScore $state $head))
      ($bestAction (findBestAction $state $tail $head $firstScore))
   )
      (actionId $bestAction)))

(= (printScenario $label $state)
   (let* (
      ($scores (diagnosticScores $state))
      ($winner (diagnosticWinner $state))
   )
      (println! (MetaMo-Scoring-Test $label
                    (modulators (motivationModulators $state))
                    (scores $scores)
                    (winner $winner)))))


;; Low, equal goals keep the diagnostic away from the score clamp. The four
;; states differ only in their modulator vectors.
(= (executionTestState)
   (motivation
      (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
      (1.0 0.0 1.0 0.0 0.0 0.5 0.0 0.5 0.0 0.0 0.5)))

(= (knowledgeTestState)
   (motivation
      (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
      (0.0 1.0 0.5 0.0 1.0 0.5 0.0 0.5 0.2 0.2 0.5)))

(= (growthTestState)
   (motivation
      (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
      (0.0 0.0 0.0 1.0 0.0 0.5 1.0 0.5 0.1 0.1 0.5)))

(= (safetyTestState)
   (motivation
      (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
      (0.0 1.0 0.0 0.0 0.0 0.5 0.0 0.5 1.0 1.0 0.5)))


;; The appraisal experiment starts from one neutral state. Only the stimulus
;; changes, so winner changes demonstrate stimulus -> appraisal -> decision.
(= (neutralAppraisalState)
   (motivation
      (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
      (0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5)))

(= (executionStimulus)
   (stimulus (0.0 0.0 1.0 0.0 0.0 1.0)))

(= (growthStimulus)
   (stimulus (1.0 0.0 0.0 0.0 1.0 0.0)))

(= (safetyStimulus)
   (stimulus (0.0 1.0 0.0 1.0 0.0 0.0)))

(= (appraisedExecutionState)
   (omegaclawAppraise (neutralAppraisalState) (executionStimulus)))

(= (appraisedGrowthState)
   (omegaclawAppraise (neutralAppraisalState) (growthStimulus)))

(= (appraisedSafetyState)
   (omegaclawAppraise (neutralAppraisalState) (safetyStimulus)))


!(println! "Direct motivational-state scoring")
!(printScenario execution-state (executionTestState))
!(printScenario knowledge-state (knowledgeTestState))
!(printScenario growth-state (growthTestState))
!(printScenario safety-state (safetyTestState))

!(println! "Appraisal-driven scoring from one neutral state")
!(printScenario execution-stimulus (appraisedExecutionState))
!(printScenario growth-stimulus (appraisedGrowthState))
!(printScenario safety-stimulus (appraisedSafetyState))


!(println! "Production baseline calibration report")
!(printScenario production-initial-state (createInitialState))


!(test (diagnosticWinner (executionTestState)) respond)
!(test (diagnosticWinner (knowledgeTestState)) retrieve-memory)
!(test (diagnosticWinner (growthTestState)) learn)
!(test (diagnosticWinner (safetyTestState)) ask-clarification)

!(test (diagnosticWinner (appraisedExecutionState)) respond)
!(test (diagnosticWinner (appraisedGrowthState)) learn)
!(test (diagnosticWinner (appraisedSafetyState)) ask-clarification)

