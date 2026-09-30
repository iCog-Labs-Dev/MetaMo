(: boundOpenPsiModulator (-> Number Number))

;; Bounds a modulator value using a sigmoid function to keep it between 0 and 1.
;; Example: (boundOpenPsiModulator 0.7)
(= (boundOpenPsiModulator $value)
    (eval (sigmoidNum (* 4.0 (- $value 0.5))))
)

;; Calculates arousal feedback to modulate the effect of novelty on arousal.
;; Example: (openPsiArousalFeedback 0.6)
(= (openPsiArousalFeedback $arousal)
    (eval (sigmoidNum (* (- $arousal 0.5) 5.0)))
)

;; Calculates the transformation scale based on the transformation goal ($gTrans).
;; Example: (openPsiTransScale 0.75)
(= (openPsiTransScale $gTrans)
    (eval (expNum (- $gTrans 0.5)))
)

;; Calculates the individual scale based on the individual goal ($gInd).
;; Example: (openPsiIndScale 0.25)
(= (openPsiIndScale $gInd)
    (eval (expNum (- $gInd 0.5)))
)
;; Calculates novelty adjusted for risk, representing "benign" novelty.
;; Example: (openPsiBenignNovelty 0.8 0.1)
(= (openPsiBenignNovelty $novelty $risk)
    (* $novelty (- 1.0 $risk))
)

;; Calculates the demand of the current context based on effort and risk.
;; Example: (openPsiDemandingContext 0.5 0.3)
(= (openPsiDemandingContext $effort $risk)
    (/ (+ $effort $risk) 2.0)
)
;; Calculates the change in valence based on conduciveness, benign novelty, risk, and effort.
;; Example: (openPsiDeltaValence 0.8 0.1 0.1 0.2)
(= (openPsiDeltaValence $conduciveness $benignNovelty $risk $effort)
    (+ (+ (* 0.75 $conduciveness) (* 0.25 $benignNovelty))
       (* -1 (+ (* 0.55 $risk) (* 0.15 $effort))))
)

;; Calculates the change in arousal based on novelty, arousal feedback, risk, and effort.
;; Example: (openPsiDeltaArousal 0.2 0.5 0.1 0.2)
(= (openPsiDeltaArousal $novelty $arousalFeedback $risk $effort)
    (+ (+ (* $novelty (+ 1.0 (* 0.5 $arousalFeedback))) (* 0.15 $risk))
       (* -1 (* 0.35 $effort)))
)

;; Calculates the change in approach (intention strength) based on benign novelty, conduciveness, and risk.
;; Example: (openPsiDeltaApproach 0.1 0.8 0.1)
(= (openPsiDeltaApproach $benignNovelty $conduciveness $risk)
    (+ (+ (* 0.65 $benignNovelty) (* 0.35 $conduciveness))
       (* -1 (* 0.75 $risk)))
)

;; Calculates the change in resolution based on conduciveness, effort, and risk.
;; Example: (openPsiDeltaResolution 0.8 0.2 0.1)
(= (openPsiDeltaResolution $conduciveness $effort $risk)
    (+ (+ (* 0.55 $conduciveness) (* 0.35 $effort))
       (* 0.20 $risk))
)

;; Calculates the change in threshold based on risk, demanding context, and conduciveness.
;; Example: (openPsiDeltaThreshold 0.1 0.4 0.8)
(= (openPsiDeltaThreshold $risk $demandingContext $conduciveness)
    (+ (+ (* 0.70 $risk) (* 0.25 $demandingContext))
       (* -1 (* 0.15 $conduciveness)))
)

;; Calculates the change in securing based on risk, effort, benign novelty, and conduciveness.
;; Example: (openPsiDeltaSecuring 0.1 0.2 0.1 0.8)
(= (openPsiDeltaSecuring $risk $effort $benignNovelty $conduciveness)
    (+ (+ (* 0.80 $risk) (* 0.20 $effort))
       (* -1 (+ (* 0.30 $benignNovelty) (* 0.10 $conduciveness))))
)

;; Calculates the next valence value by applying the delta and bounding the result.
;; Example: (openPsiNextValence 0.5 0.1)
(= (openPsiNextValence $valence $deltaValence)
    (boundOpenPsiModulator (+ $valence $deltaValence))
)

;; Calculates the next arousal value by applying the scaled delta and bounding the result.
;; Example: (openPsiNextArousal 0.5 0.1 1.2)
(= (openPsiNextArousal $arousal $deltaArousal $transScale)
    (boundOpenPsiModulator (+ $arousal (* $deltaArousal $transScale)))
)

;; Calculates the next approach value by applying the scaled delta and bounding the result.
;; Example: (openPsiNextApproach 0.5 0.1 1.2)
(= (openPsiNextApproach $approach $deltaApproach $transScale)
    (boundOpenPsiModulator (+ $approach (* $deltaApproach $transScale)))
)

;; Calculates the next resolution value by applying the delta and bounding the result.
;; Example: (openPsiNextResolution 0.5 0.1)
(= (openPsiNextResolution $resolution $deltaResolution)
    (boundOpenPsiModulator (+ $resolution $deltaResolution))
)

;; Calculates the next threshold value by applying the scaled delta and bounding the result.
;; Example: (openPsiNextThreshold 0.5 0.1 0.8)
(= (openPsiNextThreshold $threshold $deltaThreshold $indScale)
    (boundOpenPsiModulator (+ $threshold (* $deltaThreshold $indScale)))
)

;; Calculates the next securing value by applying the scaled delta and bounding the result.
;; Example: (openPsiNextSecuring 0.5 0.1 0.8)
(= (openPsiNextSecuring $securing $deltaSecuring $indScale)
    (boundOpenPsiModulator (+ $securing (* $deltaSecuring $indScale)))
)
