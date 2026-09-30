;; Creates an OpenPSI appraisal comonad using a custom appraisal function.
;; Example: (openPsiAppraisalWith customAppraiseFn)
(= (openPsiAppraisalWith $appraiseFn)
    (let $openPsiExtract (|-> ($state) $state)
        (appraisalComonad $openPsiExtract $appraiseFn)
    )
)

;; Creates a default OpenPSI appraisal comonad using the standard openPsiAppraise function.
;; Example: (openPsiAppraisal)
(= (openPsiAppraisal)
    (openPsiAppraisalWith openPsiAppraise)
)
;; Performs the core OpenPSI appraisal by updating the motivation state based on a stimulus.
;; Example:
;;   (openPsiAppraise
;;     (motivation (0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5) (0.5 0.5 0.5 0.5 0.5 0.5))
;;     (stimulus (0.2 0.8 0.1 0.2))
;;   )
(= (openPsiAppraise $state $stimulus)
    (let* (
        ;; Extract goal values by name
        ($gInd   (getGoal $state gInd))
        ($gTrans (getGoal $state gTrans))

        ;; Extract modulator values by name
        ($valence    (getModulator $state valence))
        ($arousal    (getModulator $state arousal))
        ($approach   (getModulator $state approach))
        ($resolution (getModulator $state resolution))
        ($threshold  (getModulator $state threshold))
        ($securing   (getModulator $state securing))

        ;; Extract stimulus values by name
        ($novelty       (getStimulus $stimulus novelty))
        ($conduciveness (getStimulus $stimulus conduciveness))
        ($risk          (getStimulus $stimulus risk))
        ($effort        (getStimulus $stimulus effort))

        ;; Intermediate values
        ($arousalFeedback  (eval (openPsiArousalFeedback $arousal)))
        ($transScale       (eval (openPsiTransScale $gTrans)))
        ($indScale         (eval (openPsiIndScale $gInd)))
        ($benignNovelty    (eval (openPsiBenignNovelty $novelty $risk)))
        ($demandingContext (eval (openPsiDemandingContext $effort $risk)))
        
        ;; Delta calculations
        ($deltaValence    (eval (openPsiDeltaValence $conduciveness $benignNovelty $risk $effort)))
        ($deltaArousal    (eval (openPsiDeltaArousal $novelty $arousalFeedback $risk $effort)))
        ($deltaApproach   (eval (openPsiDeltaApproach $benignNovelty $conduciveness $risk)))
        ($deltaResolution (eval (openPsiDeltaResolution $conduciveness $effort $risk)))
        ($deltaThreshold  (eval (openPsiDeltaThreshold $risk $demandingContext $conduciveness)))
        ($deltaSecuring   (eval (openPsiDeltaSecuring $risk $effort $benignNovelty $conduciveness)))

        ;; Next modulator values
        ($nextValence    (eval (openPsiNextValence $valence $deltaValence)))
        ($nextArousal    (eval (openPsiNextArousal $arousal $deltaArousal $transScale)))
        ($nextApproach   (eval (openPsiNextApproach $approach $deltaApproach $transScale)))
        ($nextResolution (eval (openPsiNextResolution $resolution $deltaResolution)))
        ($nextThreshold  (eval (openPsiNextThreshold $threshold $deltaThreshold $indScale)))
        ($nextSecuring   (eval (openPsiNextSecuring $securing $deltaSecuring $indScale)))
    )
        (motivation
            (motivationGoals $state)
            ($nextValence $nextArousal $nextApproach $nextResolution $nextThreshold $nextSecuring)
        )
    )
)