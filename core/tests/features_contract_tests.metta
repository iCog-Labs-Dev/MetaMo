!(import! &self ../validation)
!(import! &self ../features)

!(test
    (featureMapGet
        (stimulusFeatures ((novelty 0.3) (risk 0.8)))
        novelty
        0.0
    )
    0.3
)

!(test
    (featureMapNumericUnit
        (stimulusFeatures ((risk 1.2)))
        risk
        0.0
    )
    1.0
)

!(test
    (featureMapHas
        (goalChangeFeedback ((progress 0.8)))
        progress
    )
    True
)

