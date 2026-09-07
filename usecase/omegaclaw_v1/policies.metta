
(= (omegaClawStabilityPolicy)
    (defaultStabilityPolicy
        0.55
        2.10
        0.10
        0.90
        0.05
        (threshold securing)))

(= (omegaClawCoherencePolicy)
    (defaultCoherencePolicy
        0.10
        0.15
        0.000001
        1.0
        0.10
        0.125
        0.50
        0.50
        (threshold securing)
        (arousal approach)
        resolution
        valence))

(= (omegaClawMergePolicy)
    (defaultParallelMergePolicy
        (threshold securing)
        (arousal approach)
        (valence resolution)
        0.05))

