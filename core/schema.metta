;; Schema records for the canonical MetaMo port.

(: MagusGoalSchema Type)
(: magusGoalSchema (-> Expression Expression Expression Symbol Symbol MagusGoalSchema))

(: ModulatorSchema Type)
(: modulatorSchema (-> Expression Expression Expression ModulatorSchema))

(: MotivationSchema Type)
(: motivationSchema (-> Symbol MagusGoalSchema ModulatorSchema Symbol Symbol MotivationSchema))

;; Return primary goal names.
;; Example: (magusGoalSchemaPrimary (magusGoalSchema (help) (risk) (individuation transcendence help risk) individuation transcendence)) -> (help)
(= (magusGoalSchemaPrimary (magusGoalSchema $primary $anti $all $individuation $transcendence))
    $primary
)

;; Return anti-goal names.
;; Example: (magusGoalSchemaAnti (magusGoalSchema (help) (risk) (individuation transcendence help risk) individuation transcendence)) -> (risk)
(= (magusGoalSchemaAnti (magusGoalSchema $primary $anti $all $individuation $transcendence))
    $anti
)

;; Return every goal name in coordinate order.
;; Example: (magusGoalSchemaNames (magusGoalSchema (help) (risk) (individuation transcendence help risk) individuation transcendence)) -> (individuation transcendence help risk)
(= (magusGoalSchemaNames (magusGoalSchema $primary $anti $all $individuation $transcendence))
    $all
)

;; Return the individuation overgoal name.
;; Example: (magusGoalSchemaIndividuationName (magusGoalSchema () () (individuation transcendence) individuation transcendence)) -> individuation
(= (magusGoalSchemaIndividuationName (magusGoalSchema $primary $anti $all $individuation $transcendence))
    $individuation
)

;; Return the transcendence overgoal name.
;; Example: (magusGoalSchemaTranscendenceName (magusGoalSchema () () (individuation transcendence) individuation transcendence)) -> transcendence
(= (magusGoalSchemaTranscendenceName (magusGoalSchema $primary $anti $all $individuation $transcendence))
    $transcendence
)

;; Count goal coordinates.
;; Example: (magusGoalSchemaCount (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)) -> 3
(= (magusGoalSchemaCount $goalSchema)
    (size-atom (magusGoalSchemaNames $goalSchema))
)

;; Validate the goal schema invariants used by Python MagusGoalSchema.
;; Example: (validationIsOk (validateMagusGoalSchema (magusGoalSchema (help) (risk) (individuation transcendence help risk) individuation transcendence))) -> True
(= (validateMagusGoalSchema $goalSchema)
    (let* (
        ($primary (magusGoalSchemaPrimary $goalSchema))
        ($anti (magusGoalSchemaAnti $goalSchema))
        ($all (magusGoalSchemaNames $goalSchema))
        ($individuation (magusGoalSchemaIndividuationName $goalSchema))
        ($transcendence (magusGoalSchemaTranscendenceName $goalSchema))
    )
        (if (listUnique $all)
            (if (listUnique $primary)
                (if (listUnique $anti)
                    (if (listsDisjoint $primary $anti)
                        (if (listContains $all $individuation)
                            (if (listContains $all $transcendence)
                                (if (listContains $primary $individuation)
                                    (validationError overgoal-in-primary $individuation)
                                    (if (listContains $anti $transcendence)
                                        (validationError overgoal-in-anti $transcendence)
                                        (validationOk $goalSchema)
                                    )
                                )
                                (validationError missing-transcendence $transcendence)
                            )
                            (validationError missing-individuation $individuation)
                        )
                        (validationError primary-anti-overlap ($primary $anti))
                    )
                    (validationError duplicate-anti-goals $anti)
                )
                (validationError duplicate-primary-goals $primary)
            )
            (validationError duplicate-goal-names $all)
        )
    )
)

;; Return core modulator names.
;; Example: (modulatorSchemaCore (modulatorSchema (valence) () (valence))) -> (valence)
(= (modulatorSchemaCore (modulatorSchema $core $application $all))
    $core
)

;; Return application modulator names.
;; Example: (modulatorSchemaApplication (modulatorSchema (valence) (focus) (valence focus))) -> (focus)
(= (modulatorSchemaApplication (modulatorSchema $core $application $all))
    $application
)

;; Return every modulator name in coordinate order.
;; Example: (modulatorSchemaNames (modulatorSchema (valence) (focus) (valence focus))) -> (valence focus)
(= (modulatorSchemaNames (modulatorSchema $core $application $all))
    $all
)

;; Count modulator coordinates.
;; Example: (modulatorSchemaCount (modulatorSchema (valence) (focus) (valence focus))) -> 2
(= (modulatorSchemaCount $modulatorSchema)
    (size-atom (modulatorSchemaNames $modulatorSchema))
)

;; Validate modulator uniqueness and core/application separation.
;; Example: (validationIsOk (validateModulatorSchema (modulatorSchema (valence) (focus) (valence focus)))) -> True
(= (validateModulatorSchema $modulatorSchema)
    (let* (
        ($core (modulatorSchemaCore $modulatorSchema))
        ($application (modulatorSchemaApplication $modulatorSchema))
        ($all (modulatorSchemaNames $modulatorSchema))
    )
        (if (listUnique $all)
            (if (listUnique $core)
                (if (listUnique $application)
                    (if (listsDisjoint $core $application)
                        (validationOk $modulatorSchema)
                        (validationError core-application-overlap ($core $application))
                    )
                    (validationError duplicate-application-modulators $application)
                )
                (validationError duplicate-core-modulators $core)
            )
            (validationError duplicate-modulator-names $all)
        )
    )
)

;; Return the schema profile id.
;; Example: (motivationSchemaId (motivationSchema research schema mods decision appraisal)) -> research
(= (motivationSchemaId (motivationSchema $id $goals $modulators $decisionProfile $appraisalProfile))
    $id
)

;; Return the goal schema.
;; Example: (motivationSchemaGoals (motivationSchema id goals mods decision appraisal)) -> goals
(= (motivationSchemaGoals (motivationSchema $id $goals $modulators $decisionProfile $appraisalProfile))
    $goals
)

;; Return the modulator schema.
;; Example: (motivationSchemaModulators (motivationSchema id goals mods decision appraisal)) -> mods
(= (motivationSchemaModulators (motivationSchema $id $goals $modulators $decisionProfile $appraisalProfile))
    $modulators
)

;; Return the decision profile name.
;; Example: (motivationSchemaDecisionProfile (motivationSchema id goals mods decision appraisal)) -> decision
(= (motivationSchemaDecisionProfile (motivationSchema $id $goals $modulators $decisionProfile $appraisalProfile))
    $decisionProfile
)

;; Return the appraisal profile name.
;; Example: (motivationSchemaAppraisalProfile (motivationSchema id goals mods decision appraisal)) -> appraisal
(= (motivationSchemaAppraisalProfile (motivationSchema $id $goals $modulators $decisionProfile $appraisalProfile))
    $appraisalProfile
)

;; Count goal coordinates for a motivation schema.
;; Example: (schemaGoalCount (motivationSchema id goals mods decision appraisal)) -> (magusGoalSchemaCount goals)
(= (schemaGoalCount $schema)
    (magusGoalSchemaCount (motivationSchemaGoals $schema))
)

;; Count modulator coordinates for a motivation schema.
;; Example: (schemaModulatorCount (motivationSchema id goals mods decision appraisal)) -> (modulatorSchemaCount mods)
(= (schemaModulatorCount $schema)
    (modulatorSchemaCount (motivationSchemaModulators $schema))
)

;; Return a validation result containing the goal index for a name.
;; Example: (schemaGoalIndex schema help) -> (validationOk 2)
(= (schemaGoalIndex $schema $goalName)
    (listIndexResult
        (magusGoalSchemaNames (motivationSchemaGoals $schema))
        $goalName
        0
    )
)

;; Return a validation result containing the modulator index for a name.
;; Example: (schemaModulatorIndex schema valence) -> (validationOk 0)
(= (schemaModulatorIndex $schema $modulatorName)
    (listIndexResult
        (modulatorSchemaNames (motivationSchemaModulators $schema))
        $modulatorName
        0
    )
)

;; Test whether a goal name belongs to the anti-goal set.
;; Example: (schemaIsAntiGoal schema misinformation) -> True
(= (schemaIsAntiGoal $schema $goalName)
    (listContains
        (magusGoalSchemaAnti (motivationSchemaGoals $schema))
        $goalName
    )
)

;; Validate the full motivation schema.
;; Example: (validationIsOk (validateMotivationSchema schema)) -> True
(= (validateMotivationSchema $schema)
    (let* (
        ($goalResult (validateMagusGoalSchema (motivationSchemaGoals $schema)))
        ($modulatorResult (validateModulatorSchema (motivationSchemaModulators $schema)))
    )
        (if (validationIsOk $goalResult)
            (if (validationIsOk $modulatorResult)
                (validationOk $schema)
                $modulatorResult
            )
            $goalResult
        )
    )
)

