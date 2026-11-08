;; Default state for the inference control system

(= (INFERENCE_CONTROL_DEFAULT_GOALS)
    (0.70 0.50 0.85 0.80 0.45 0.70 0.40 0.35)
)

(= (INFERENCE_CONTROL_DEFAULT_MODULATORS)
    (0.50 0.45 0.45 0.60 0.55 0.55)
)

(= (inferenceControlDefaultState)
    (motivationState
        (inferenceControlSchema)
        (INFERENCE_CONTROL_DEFAULT_GOALS)
        (INFERENCE_CONTROL_DEFAULT_MODULATORS)
    )
)
