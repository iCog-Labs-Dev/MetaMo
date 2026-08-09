
;; Return every goal in canonical coordinate order.
(= (qwestorGoalNames)
    (individuation transcendence beneficial honesty safety help_short help_long
     knowledge novelty originality success_moderate success_breakthrough
     coherence social efficiency accuracy hallucinate redundant rabbit_hole
     premature)
)

;; Return independent Qwestor normative goals
(= (qwestorNormativeGoalNames)
    (beneficial honesty safety)
)

;; Return ordinary pursuit goals
(= (qwestorPursuitGoalNames)
    (help_short help_long knowledge novelty originality success_moderate
     success_breakthrough coherence social efficiency accuracy)
)

;; Return application-primary goals
(= (qwestorPrimaryGoalNames)
    (beneficial honesty safety help_short help_long knowledge novelty originality
     success_moderate success_breakthrough coherence social efficiency accuracy)
)

;; Return all four Qwestor anti-goals in canonical order
(= (qwestorAntiGoalNames)
    (hallucinate redundant rabbit_hole premature)
)

;; Return the six universal OpenPsi core modulators
(= (qwestorCoreModulatorNames)
    (valence arousal approach resolution threshold securing)
)

;; Return Qwestor application modulators
(= (qwestorApplicationModulatorNames)
    (urgency risk_aversion error_tolerance failure_wariness user_expertise
     topic_familiarity creativity)
)

;; Return every modulator in canonical coordinate order.
(= (qwestorModulatorNames)
    (valence arousal approach resolution threshold securing urgency risk_aversion
     error_tolerance failure_wariness user_expertise topic_familiarity creativity)
)

;; Build the MAGUS goal schema while retaining only MetaMo's two structural overgoals.
(= (qwestorGoalSchema)
    (magusGoalSchema
        (qwestorPrimaryGoalNames)
        (qwestorAntiGoalNames)
        (qwestorGoalNames)
        individuation
        transcendence
    )
)

;; Build the core/application modulator schema
(= (qwestorModulatorSchema)
    (modulatorSchema
        (qwestorCoreModulatorNames)
        (qwestorApplicationModulatorNames)
        (qwestorModulatorNames)
    )
)

;; Build the complete Qwestor motivation schema
(= (qwestorSchema)
    (let* (
        ($schemaConfig (qwestorSchemaConfig))
    )
        (motivationSchema
            (qwestorConfigGet $schemaConfig QWESTOR_SCHEMA_ID qwestor)
            (qwestorGoalSchema)
            (qwestorModulatorSchema)
            (qwestorConfigGet
                $schemaConfig
                QWESTOR_DECISION_PROFILE_ID
                qwestor_magus_additive
            )
            (qwestorConfigGet
                $schemaConfig
                QWESTOR_APPRAISAL_PROFILE_ID
                qwestor_openpsi
            )
        )
    )
)

;; Return whether a goal belongs to Qwestor's normative subset
(= (qwestorIsNormativeGoal $goalName)
    (listContains (qwestorNormativeGoalNames) $goalName)
)

;; Classify a goal without changing its canonical schema category
(= (qwestorGoalCategory $goalName)
    (if (or (== $goalName individuation) (== $goalName transcendence))
        structural_overgoal
        (if (qwestorIsNormativeGoal $goalName)
            normative
            (if (listContains (qwestorPursuitGoalNames) $goalName)
                pursuit
                (if (listContains (qwestorAntiGoalNames) $goalName)
                    anti_goal
                    unknown_goal
                )
            )
        )
    )
)

;; Return a goal index using the canonical schema validator
(= (qwestorGoalIndex $goalName)
    (schemaGoalIndex (qwestorSchema) $goalName)
)

;; Return a modulator index using the canonical schema validator
(= (qwestorModulatorIndex $modulatorName)
    (schemaModulatorIndex (qwestorSchema) $modulatorName)
)

;; Return an application-owned description for a goal
(= (qwestorGoalDescription $goalName)
    (featurePairsGet
        (
            (individuation coherent_bounded_identity)
            (transcendence beneficial_research_growth)
            (beneficial improve_user_and_societal_outcomes)
            (honesty truthful_grounded_research_assistance)
            (safety avoid_harmful_research_assistance)
            (help_short satisfy_the_immediate_request)
            (help_long advance_the_deeper_research_agenda)
            (knowledge acquire_and_integrate_reliable_information)
            (novelty explore_usefully_different_directions)
            (originality synthesize_non_derivative_insights)
            (success_moderate make_steady_verifiable_progress)
            (success_breakthrough seek_high_value_discoveries)
            (coherence maintain_consistent_reasoning_and_context)
            (social collaborate_effectively_with_the_user)
            (efficiency use_time_and_resources_well)
            (accuracy prefer_correct_precise_claims)
            (hallucinate avoid_fabricated_or_unsupported_content)
            (redundant avoid_unnecessary_repetition)
            (rabbit_hole avoid_unbounded_low_value_exploration)
            (premature avoid_answering_before_required_reasoning_or_evidence)
        )
        $goalName
        unknown_goal
    )
)

;; Build a twenty-coordinate goal vector from name/value pairs
(= (qwestorGoalVectorFromPairs $pairs)
    (
        (featurePairsGet $pairs individuation 0.0)
        (featurePairsGet $pairs transcendence 0.0)
        (featurePairsGet $pairs beneficial 0.0)
        (featurePairsGet $pairs honesty 0.0)
        (featurePairsGet $pairs safety 0.0)
        (featurePairsGet $pairs help_short 0.0)
        (featurePairsGet $pairs help_long 0.0)
        (featurePairsGet $pairs knowledge 0.0)
        (featurePairsGet $pairs novelty 0.0)
        (featurePairsGet $pairs originality 0.0)
        (featurePairsGet $pairs success_moderate 0.0)
        (featurePairsGet $pairs success_breakthrough 0.0)
        (featurePairsGet $pairs coherence 0.0)
        (featurePairsGet $pairs social 0.0)
        (featurePairsGet $pairs efficiency 0.0)
        (featurePairsGet $pairs accuracy 0.0)
        (featurePairsGet $pairs hallucinate 0.0)
        (featurePairsGet $pairs redundant 0.0)
        (featurePairsGet $pairs rabbit_hole 0.0)
        (featurePairsGet $pairs premature 0.0)
    )
)

;; Build a thirteen-coordinate modulator vector from name/value pairs
(= (qwestorModulatorVectorFromPairs $pairs)
    (
        (featurePairsGet $pairs valence 0.0)
        (featurePairsGet $pairs arousal 0.0)
        (featurePairsGet $pairs approach 0.0)
        (featurePairsGet $pairs resolution 0.0)
        (featurePairsGet $pairs threshold 0.0)
        (featurePairsGet $pairs securing 0.0)
        (featurePairsGet $pairs urgency 0.0)
        (featurePairsGet $pairs risk_aversion 0.0)
        (featurePairsGet $pairs error_tolerance 0.0)
        (featurePairsGet $pairs failure_wariness 0.0)
        (featurePairsGet $pairs user_expertise 0.0)
        (featurePairsGet $pairs topic_familiarity 0.0)
        (featurePairsGet $pairs creativity 0.0)
    )
)

;; Return default goals in exact canonical order
(= (qwestorDefaultGoals)
    (qwestorGoalVectorFromPairs (qwestorDefaultGoalPairs))
)

;; Return default modulators in exact canonical order
(= (qwestorDefaultModulators)
    (qwestorModulatorVectorFromPairs (qwestorDefaultModulatorPairs))
)

;; Build a bounded candidate-correlation vector from named pairs
(= (qwestorCorrelationVector $pairs)
    (clipVector (qwestorGoalVectorFromPairs $pairs) -1.0 1.0)
)

;; Build a bounded goal-change hint vector from named pairs
(= (qwestorDeltaVector $pairs)
    (clipVector (qwestorGoalVectorFromPairs $pairs) -0.1 0.1)
)

;; Convert signed raw valence into the canonical unit interval
(= (qwestorSignedValenceToUnit $signedValence)
    (clipUnit (/ (+ $signedValence 1.0) 2.0))
)
