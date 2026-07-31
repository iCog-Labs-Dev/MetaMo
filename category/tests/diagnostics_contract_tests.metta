!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../diagnostics)

!(test
    (lawCheckHolds (lawCheckResult lax left right 0.01 0.1 True))
    True
)

!(test
    (diagnosticsProjectionDelta
        (metaMoDiagnostics answer 0.0 0.01 True True True True 0.0 0.0 0.0 0.2 0.0 0.0 0.0 0.0 True 1.0 1.0)
    )
    0.2
)

!(test
    (diagnosedState
        (diagnosedTransition action state diagnostics)
    )
    state
)

