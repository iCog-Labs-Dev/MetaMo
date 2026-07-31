;; OpenPSI feeling (emotion) layer.
;; Derives emotions from modulator values per Cai et al. (2013), §4.3,
;; eqs. 14-17 and Table 2. Reads the emotion table + constants from config.metta.

;; P(m, indicator): eq. (15)
;; Maps a modulator level $m to a membership in [0,1] given a fuzzy indicator.
(= (indicatorMembership $m EL) (eval (fuzzyLow  $m (eval (FUZZY_T_EL)) (eval (FUZZY_ALPHA)))))
(= (indicatorMembership $m L)  (eval (fuzzyLow  $m (eval (FUZZY_T_L))  (eval (FUZZY_ALPHA)))))
(= (indicatorMembership $m M)  (eval (fuzzyEqual $m (eval (FUZZY_T_M)) (eval (FUZZY_ALPHA)))))
(= (indicatorMembership $m H)  (eval (fuzzyHigh $m (eval (FUZZY_T_H))  (eval (FUZZY_ALPHA)))))
(= (indicatorMembership $m EH) (eval (fuzzyHigh $m (eval (FUZZY_T_EH)) (eval (FUZZY_ALPHA)))))
(= (indicatorMembership $m U)  0.0)

;; indicator lookup
;; Returns the indicator symbol for an (emotion, modulator) pair from the table.
;; Example: (emotionIndicator happy arousal) → H
(= (emotionIndicator $emotion $modulator)
    (match &self (EmotionModulator $emotion $modulator $ind) $ind)
)

;; Weighted contribution of one dimension.
;; W_m * P(modulatorLevel, indicator) for one emotion dimension.
(= (emotionDimContribution $state $emotion $modulator)
    (let* (
        ($level     (stateModulator $state $modulator))
        ($indicator (emotionIndicator $emotion $modulator))
        ($p         (indicatorMembership $level $indicator))
    )
        (* (eval (EMOTION_WEIGHT)) $p)
    )
)

;; fold over the 5 emotion dimensions: I(E) eq. (14)
(= (emotionIntensitySum $state $emotion $mods)
    (if (== $mods ())
        0.0
        (+ (emotionDimContribution $state $emotion (car-atom $mods))
           (emotionIntensitySum $state $emotion (cdr-atom $mods)))
    )
)

;; Intensity I(E) of one named emotion given a motivation state.
;; Example: (emotionIntensity myState happy)
(= (emotionIntensity $state $emotion)
    (emotionIntensitySum $state $emotion (eval (EMOTION_DIM_MODULATORS)))
)

;; all four emotion intensities as a vector (happy sad angry fear)
(= (feelingVector $state)
    (
        (emotionIntensity $state happy)
        (emotionIntensity $state sad)
        (emotionIntensity $state angry)
        (emotionIntensity $state fear)
    )
)

;; Dominant Emotion Selection
(= (dominantEmotionFold $best $pairs)
    (if (== $pairs ())
        $best
        (let* (
            ($pair (car-atom $pairs))
            ($rest (cdr-atom $pairs))
        )
            (let ($name $val) $pair
                (let ($bestName $bestVal) $best
                    (if (> $val $bestVal)
                        (dominantEmotionFold $pair $rest)
                        (dominantEmotionFold $best $rest)
                    )
                )
            )
        )
    )
)

(= (dominantEmotion $state)
    (let* (
        ($h (emotionIntensity $state happy))
        ($s (emotionIntensity $state sad))
        ($a (emotionIntensity $state angry))
        ($f (emotionIntensity $state fear))
        ($winner (dominantEmotionFold (happy $h) ((sad $s) (angry $a) (fear $f))))
    )
        (let ($wName $wVal) $winner
            (if (> $wVal (eval (EMOTION_GAMMA)))
                ($wName $wVal)
                (neutral $wVal)
            )
        )
    )
)
