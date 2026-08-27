!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../diagnostics)
!(import! &self ../laws)

!(test
    (reciprocalSimulationHolds
        (reciprocalSimulationResult source target left right 0.0 0.05 True)
    )
    True
)

!(test
    (reciprocalSimulationError
        (reciprocalSimulationResult source target left right 0.2 0.05 False)
    )
    0.2
)

