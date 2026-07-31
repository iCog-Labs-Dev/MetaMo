!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../config)
!(import! &self ../feeling)

(= (feelingTestSchema)
    (motivationSchema
        feeling_test
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence arousal approach resolution threshold securing) () (valence arousal approach resolution threshold securing))
        decision
        appraisal
    )
)

;; Paper Table 3 modulator levels, mapped to this repo's canonical modulator slots:
;; valence, arousal, approach, resolution, threshold, securing.
(= (paperFeelingState)
    (motivationState
        (feelingTestSchema)
        (0.25 0.75 0.5)
        (0.7245 0.4247 0.5 0.3466 0.7752 0.8436)
    )
)

(= (flatFeelingState)
    (motivationState
        (feelingTestSchema)
        (0.25 0.75 0.5)
        (0.5 0.5 0.5 0.5 0.5 0.5)
    )
)

!(test (fuzzyEqual 0.5 0.5 50.0) 1.0)
!(test (fuzzyHigh 0.8 0.70 50.0) 1.0)
!(test (fuzzyLow 0.2 0.30 50.0) 1.0)

!(test (indicatorMembership 0.8 H) 1.0)
!(test (indicatorMembership 0.2 L) 1.0)
!(test (indicatorMembership 0.1 EL) 1.0)
!(test (indicatorMembership 0.9 EH) 1.0)
!(test (eval (roundNum (indicatorMembership 0.5 M) 6)) 1.0)

!(test (emotionIndicator happy arousal) H)
!(test (emotionIndicator sad resolution) H)
!(test (emotionIndicator angry threshold) L)
!(test (emotionIndicator fear resolution) EH)

!(test (eval (roundNum (emotionIntensity (paperFeelingState) happy) 6)) 0.622169)
!(test (eval (roundNum (emotionIntensity (paperFeelingState) sad) 6)) 0.161286)
!(test (eval (roundNum (emotionIntensity (paperFeelingState) angry) 6)) 0.249869)
!(test (eval (roundNum (emotionIntensity (paperFeelingState) fear) 6)) 0.080637)

!(test (let ($n $v) (dominantEmotion (paperFeelingState)) ($n (eval (roundNum $v 6)))) (happy 0.622169))
!(test (let ($n $v) (dominantEmotion (flatFeelingState)) $n) neutral)
