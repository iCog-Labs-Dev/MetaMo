;; Adapt an ordered goal-score vector to MetaMo's motivation state.

;; MetaMo's OpenPSI state defines six ordered modulators:
;; valence, arousal, approach, resolution, threshold, and securing.
(= (defaultModulatorValue)
   0.5)

(= (defaultModulators)
   ((defaultModulatorValue)
      (defaultModulatorValue)
      (defaultModulatorValue)
      (defaultModulatorValue)
      (defaultModulatorValue)
      (defaultModulatorValue)))

;; MetaMo represents a motivational state as two ordered value vectors.
(= (createMotivationState $goalScores)
   (motivation $goalScores (defaultModulators)))

(= (motivationStateGoals (motivation $goals $modulators))
   $goals)

(= (motivationStateModulators (motivation $goals $modulators))
   $modulators)

;; Pass (goalAdapter $frameAtomspace) here to preserve frameID index order.
(= (motivationStateFactory $goalScores)
   (createMotivationState $goalScores))

(= (motivationAdapter $goalScores)
   (motivationStateFactory $goalScores))

;; Self-checks for petta.

