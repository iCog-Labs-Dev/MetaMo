
(: ResearchAssistantCalibrationResult Type)
(: researchAssistantCalibrationResult (-> ResearchAssistantPerception Expression ResearchAssistantCalibrationResult))

;; Return calibrated perception.
(= (researchAssistantCalibrationPerception (researchAssistantCalibrationResult $perception $adjustments))
    $perception
)

;; Return calibration adjustments.
(= (researchAssistantCalibrationAdjustments (researchAssistantCalibrationResult $perception $adjustments))
    $adjustments
)

;; Return max over four values.
(= (researchAssistantMax4 $a $b $c $d)
    (maxNumber (maxNumber $a $b) (maxNumber $c $d))
)

;; Apply a unit-clamped floor.
(= (researchAssistantFloor $value $floor)
    (maxNumber $value (clipUnit $floor))
)

;; Apply a unit-clamped ceiling.
(= (researchAssistantCeiling $value $ceiling)
    (minNumber $value (clipUnit $ceiling))
)

;; Build symbolic adjustment markers in Python operation order.
(= (researchAssistantCalibrationAdjustmentMarkers $raw $calibrated)
    (
        calibration_context_loss_floor_checked
        calibration_citation_floor_checked
        calibration_exploration_cap_checked
        calibration_risk_floor_checked
        calibration_effort_floor_checked
    )
)

;; Calibrate a perception with the exact Python rule order.
(= (calibrateResearchAssistantPerception $perception)
    (let* (
        ($stimulus (researchAssistantPerceptionStimulus $perception))
        ($signals (researchAssistantPerceptionSignals $perception))
        ($taskIntent (researchAssistantSignalTaskIntent $signals))
        ($ambiguity (researchAssistantSignalAmbiguity $signals))
        ($citation (researchAssistantSignalCitationNeed $signals))
        ($comparison (researchAssistantSignalComparisonNeed $signals))
        ($summary (researchAssistantSignalSummaryNeed $signals))
        ($exploration (researchAssistantSignalExplorationNeed $signals))
        ($unsafe (researchAssistantSignalUnsafePressure $signals))
        ($privacy (researchAssistantSignalPrivacyPressure $signals))
        ($unsupported (researchAssistantSignalUnsupportedClaimPressure $signals))
        ($contextLoss (researchAssistantSignalContextLossPressure $signals))
        ($risk (researchAssistantStimulusRisk $stimulus))
        ($effort (researchAssistantStimulusEffort $stimulus))
        ($calibratedContextLoss (researchAssistantFloor $contextLoss (* 0.70 $ambiguity)))
        ($calibratedCitation (researchAssistantFloor $citation (* 0.85 $unsupported)))
        ($safetyPressure (maxNumber $unsafe $privacy))
        ($calibratedExploration
            (if (> $safetyPressure 0.55)
                (researchAssistantCeiling $exploration (- 1.0 (* 0.70 $safetyPressure)))
                $exploration
            )
        )
        ($riskFloor (researchAssistantMax4 (* 0.90 $unsafe) (* 0.85 $privacy) (* 0.60 $unsupported) (* 0.40 $calibratedContextLoss)))
        ($calibratedRisk (researchAssistantFloor $risk $riskFloor))
        ($effortFloor (researchAssistantMax4 (* 0.65 $ambiguity) (* 0.55 $calibratedContextLoss) (* 0.25 $calibratedCitation) 0.0))
        ($calibratedEffort (researchAssistantFloor $effort $effortFloor))
        ($calibrated
            (researchAssistantPerception
                (researchAssistantStimulus
                    (researchAssistantStimulusNovelty $stimulus)
                    (researchAssistantStimulusConduciveness $stimulus)
                    $calibratedRisk
                    $calibratedEffort
                )
                (researchAssistantSignals
                    $taskIntent
                    $ambiguity
                    $calibratedCitation
                    $comparison
                    $summary
                    $calibratedExploration
                    $unsafe
                    $privacy
                    $unsupported
                    $calibratedContextLoss
                )
            )
        )
    )
        (researchAssistantCalibrationResult
            $calibrated
            (researchAssistantCalibrationAdjustmentMarkers $perception $calibrated)
        )
    )
)

