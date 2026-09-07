
(= (omegaClawGoalNames)
    (gInd_over gTrans_over help_user learn cooperate responsiveness clarity
     coherence reliability progress adaptivity risk contradiction unsafe))

(= (omegaClawPrimaryGoalNames)
    (help_user learn cooperate responsiveness clarity coherence reliability
     progress adaptivity))

(= (omegaClawAntiGoalNames)
    (risk contradiction unsafe))

(= (omegaClawCoreModulatorNames)
    (valence arousal approach resolution threshold securing))

(= (omegaClawApplicationModulatorNames)
    (urgency persistence context_depth human_deference focus))

(= (omegaClawModulatorNames)
    (valence arousal approach resolution threshold securing urgency
     persistence context_depth human_deference focus))

(= (omegaClawGoalSchema)
    (magusGoalSchema
        (omegaClawPrimaryGoalNames)
        (omegaClawAntiGoalNames)
        (omegaClawGoalNames)
        gInd_over
        gTrans_over))

(= (omegaClawModulatorSchema)
    (modulatorSchema
        (omegaClawCoreModulatorNames)
        (omegaClawApplicationModulatorNames)
        (omegaClawModulatorNames)))

(= (omegaClawSchema)
    (motivationSchema
        omegaclaw
        (omegaClawGoalSchema)
        (omegaClawModulatorSchema)
        omegaclaw_magus_additive
        omegaclaw_openpsi))

;; Build named vectors in canonical schema order.
(= (omegaClawNamedVectorFromPairs () $pairs $default)
    ())

(= (omegaClawNamedVectorFromPairs $names $pairs $default)
    (let* (
        (($head $tail) (decons $names))
    )
        (cons-atom
            (featurePairsGet $pairs $head $default)
            (omegaClawNamedVectorFromPairs $tail $pairs $default))))

(= (omegaClawGoalVectorFromPairs $pairs)
    (omegaClawNamedVectorFromPairs
        (omegaClawGoalNames) $pairs 0.0))

(= (omegaClawCorrelationVector $pairs)
    (clipVector (omegaClawGoalVectorFromPairs $pairs) -1.0 1.0))

(= (omegaClawZeroGoalVector)
    (omegaClawGoalVectorFromPairs ()))
