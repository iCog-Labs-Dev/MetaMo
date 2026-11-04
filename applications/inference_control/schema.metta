(= (inferenceControlGoalNames)
    (individuation transcendence
     query_progress evidence_quality exploration resource_efficiency
     unreliable_inference low_information_gain)
)

(= (inferenceControlPrimaryGoalNames)
    (query_progress evidence_quality exploration resource_efficiency)
)

(= (inferenceControlAntiGoalNames)
    (unreliable_inference low_information_gain)
)

(= (inferenceControlModulatorNames)
    (valence arousal approach resolution threshold securing)
)

(= (inferenceControlGoalSchema)
    (magusGoalSchema
        (inferenceControlPrimaryGoalNames)
        (inferenceControlAntiGoalNames)
        (inferenceControlGoalNames)
        individuation
        transcendence
    )
)

(= (inferenceControlModulatorSchema)
    (modulatorSchema
        (inferenceControlModulatorNames)
        ()
        (inferenceControlModulatorNames)
    )
)

(= (inferenceControlSchema)
    (motivationSchema
        inference_control
        (inferenceControlGoalSchema)
        (inferenceControlModulatorSchema)
        inference_control_magus_additive
        inference_control_openpsi
    )
)
