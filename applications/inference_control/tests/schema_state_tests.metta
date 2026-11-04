!(import! &self ../../../core/validation)
!(import! &self ../../../core/schema)
!(import! &self ../../../core/state)
!(import! &self ../../../core/helper)
!(import! &self "../../../core/helpers.py")
!(import! &self ../../../dynamics/stability)
!(import! &self ../schema)
!(import! &self ../state)

!(test (inferenceControlGoalNames)
    (individuation transcendence
     query_progress evidence_quality exploration resource_efficiency
     unreliable_inference low_information_gain))

!(test (inferenceControlPrimaryGoalNames)
    (query_progress evidence_quality exploration resource_efficiency))

!(test (inferenceControlAntiGoalNames)
    (unreliable_inference low_information_gain))

!(test (inferenceControlModulatorNames)
    (valence arousal approach resolution threshold securing))

!(test (validationIsOk (validateMotivationSchema (inferenceControlSchema))) True)
!(test (validationIsOk (validateMotivationState (inferenceControlDefaultState))) True)

!(test (schemaGoalIndex (inferenceControlSchema) evidence_quality) (validationOk 3))
!(test (schemaGoalIndex (inferenceControlSchema) low_information_gain) (validationOk 7))
!(test (schemaGoalCount (inferenceControlSchema)) 8)
!(test (schemaModulatorIndex (inferenceControlSchema) threshold) (validationOk 4))

!(test (schemaIsAntiGoal (inferenceControlSchema) unreliable_inference) True)
!(test (schemaIsAntiGoal (inferenceControlSchema) low_information_gain) True)
!(test (schemaIsAntiGoal (inferenceControlSchema) query_progress) False)

!(test (stateGoal (inferenceControlDefaultState) individuation) 0.70)
!(test (stateGoal (inferenceControlDefaultState) query_progress) 0.85)
!(test (stateGoal (inferenceControlDefaultState) unreliable_inference) 0.40)
!(test (stateGoal (inferenceControlDefaultState) low_information_gain) 0.35)
!(test (stateModulator (inferenceControlDefaultState) resolution) 0.60)
!(test (stateModulator (inferenceControlDefaultState) securing) 0.55)

!(test (isInSafeRegion (makeDefaultStabilityPolicy)
                       (inferenceControlDefaultState)) True)
