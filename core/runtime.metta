(: ApplicationBundle Type)
(: applicationBundle (-> Symbol MotivationSchema AppraisalProfile DecisionProfile Symbol StabilityPolicy CoherencePolicy ParallelMergePolicy Symbol Symbol Expression ApplicationBundle))

(: RuntimeCycleResult Type)
(: runtimeCycleResult (-> Expression MotivationState MotivationState Expression Expression RuntimeCycleResult))

;; Return the bundle id.
;; Example: (bundleId (applicationBundle app schema appraisal decision goalFn stability coherence merge adapt build ())) -> app
(= (bundleId (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $id
)

;; Return the bundle schema.
;; Example: (bundleSchema bundle) -> schema
(= (bundleSchema (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $schema
)

;; Return the bundle appraisal profile.
;; Example: (bundleAppraisalProfile bundle) -> appraisal-profile
(= (bundleAppraisalProfile (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $appraisalProfile
)

;; Return the bundle decision profile.
;; Example: (bundleDecisionProfile bundle) -> decision-profile
(= (bundleDecisionProfile (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $decisionProfile
)

;; Return the bundle goal-change function symbol.
;; Example: (bundleGoalChangeFn bundle) -> defaultGoalChangeDeltaG
(= (bundleGoalChangeFn (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $goalChangeFn
)

;; Return the bundle stability policy.
;; Example: (bundleStabilityPolicy bundle) -> policy
(= (bundleStabilityPolicy (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $stabilityPolicy
)

;; Return the bundle coherence policy.
;; Example: (bundleCoherencePolicy bundle) -> policy
(= (bundleCoherencePolicy (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $coherencePolicy
)

;; Return the bundle merge policy.
;; Example: (bundleMergePolicy bundle) -> policy
(= (bundleMergePolicy (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $mergePolicy
)

;; Return raw stimulus adapter symbol.
;; Example: (bundleRawStimulusAdapterFn bundle) -> adaptStimulus
(= (bundleRawStimulusAdapterFn (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $rawStimulusAdapterFn
)

;; Return candidate builder symbol.
;; Example: (bundleCandidateBuilderFn bundle) -> buildCandidates
(= (bundleCandidateBuilderFn (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $candidateBuilderFn
)

;; Return frame adapters.
;; Example: (bundleFrameAdapters bundle) -> ()
(= (bundleFrameAdapters (applicationBundle $id $schema $appraisalProfile $decisionProfile $goalChangeFn $stabilityPolicy $coherencePolicy $mergePolicy $rawStimulusAdapterFn $candidateBuilderFn $frameAdapters))
    $frameAdapters
)

;; Validate a bundle after schema/appraisal validation records are known.
;; Example: (validateApplicationBundleFromChecks bundle schema (validationOk schema) (validationOk app)) -> validation
(= (validateApplicationBundleFromChecks $bundle $schema (validationOk $validatedSchema) (validationOk $validatedAppraisal))
    (let* (
        ($decisionSchema (eval (decisionProfileSchema (bundleDecisionProfile $bundle))))
    )
        (if (== $decisionSchema $schema)
            (validationOk $bundle)
            (validationError bundle-decision-schema-mismatch (bundleDecisionProfile $bundle))
        )
    )
)

(= (validateApplicationBundleFromChecks $bundle $schema (validationOk $validatedSchema) (validationError $code $details))
    (validationError $code $details)
)

(= (validateApplicationBundleFromChecks $bundle $schema (validationError $code $details) $appraisalValidation)
    (validationError $code $details)
)

;; Validate an application bundle without consulting global constructor atoms.
;; Example: (validationIsOk (validateApplicationBundle bundle)) -> True
(= (validateApplicationBundle $bundle)
    (let* (
        ($schema (eval (bundleSchema $bundle)))
        ($schemaValidation (eval (validateMotivationSchema $schema)))
        ($appraisalValidation (eval (appraisalProfileValidate (bundleAppraisalProfile $bundle) $schema)))
    )
        (validateApplicationBundleFromChecks $bundle $schema $schemaValidation $appraisalValidation)
    )
)

;; Build a bimonad from a validated application bundle.
;; Example: (bundleBimonadFromValidatedBundle bundle) -> metaMoPseudoBimonad
(= (bundleBimonadFromValidatedBundle $bundle)
    (metaMoPseudoBimonad
        (openPsiAppraisal (bundleAppraisalProfile $bundle))
        (magusDecision (bundleDecisionProfile $bundle) (bundleGoalChangeFn $bundle) 0.5 0.5)
        (bundleStabilityPolicy $bundle)
        (bundleCoherencePolicy $bundle)
        (bundleMergePolicy $bundle)
        ()
    )
)

;; Build a bimonad from a validation result.
;; Example: (bundleBimonadFromValidation (validationOk bundle)) -> bimonad
(= (bundleBimonadFromValidation (validationOk $bundle))
    (bundleBimonadFromValidatedBundle $bundle)
)

(= (bundleBimonadFromValidation (validationError $code $details))
    (validationError $code $details)
)

;; Build a bimonad from this bundle only.
;; Example: (bundleBimonad bundle) -> metaMoPseudoBimonad
(= (bundleBimonad $bundle)
    (let* (
        ($validation (validateApplicationBundle $bundle))
    )
        (bundleBimonadFromValidation $validation)
    )
)

;; Adapt a raw stimulus through the bundle adapter.
;; Example: (bundleAdaptStimulus bundle raw) -> stimulus
(= (bundleAdaptStimulus $bundle $rawStimulus)
    (eval ((bundleRawStimulusAdapterFn $bundle) $rawStimulus))
)

;; Build candidates through the bundle candidate builder.
;; Example: (bundleBuildCandidates bundle state stimulus) -> (candidate ...)
(= (bundleBuildCandidates $bundle $state $stimulus)
    (eval ((bundleCandidateBuilderFn $bundle) $state $stimulus))
)

;; Run one diagnosed single-subsystem bundle step.
;; Example: (runBundleStepWithDiagnostics bundle state rawStimulus True) -> diagnosed-transition
(= (runBundleStepWithDiagnostics $bundle $state $rawStimulus $embody)
    (let* (
        ($stimulus (bundleAdaptStimulus $bundle $rawStimulus))
        ($candidates (bundleBuildCandidates $bundle $state $stimulus))
    )
        (stepWithDiagnostics (bundleBimonad $bundle) $state $stimulus $candidates $embody)
    )
)

;; Run one bundle step and return only action/state.
;; Example: (runBundleStep bundle state rawStimulus) -> transitionResult
(= (runBundleStep $bundle $state $rawStimulus)
    (let* (
        ($diagnosed (runBundleStepWithDiagnostics $bundle $state $rawStimulus True))
    )
        (transitionResult (diagnosedAction $diagnosed) (diagnosedState $diagnosed))
    )
)

;; Return the action from a runtime cycle result.
;; Example: (runtimeCycleAction (runtimeCycleResult action current target next diag)) -> action
(= (runtimeCycleAction (runtimeCycleResult $action $mergedCurrent $mergedTarget $nextStates $diagnostics))
    $action
)

;; Return diagnostics from a runtime cycle result.
;; Example: (runtimeCycleDiagnostics result) -> diagnostics
(= (runtimeCycleDiagnostics (runtimeCycleResult $action $mergedCurrent $mergedTarget $nextStates $diagnostics))
    $diagnostics
)
