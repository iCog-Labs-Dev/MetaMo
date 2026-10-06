;; Canonical MetaMo top-level facade.

;; The top level is intentionally bundle-scoped.  Applications provide an
;; ApplicationBundle with their schema, profiles, policies, stimulus adapter, and
;; candidate builder; core runtime/registry code does the generic execution.

;; Build a bimonad from an application bundle through the registry facade.
;; Example: (mainBuildMetaMo bundle) -> metaMoPseudoBimonad
(= (mainBuildMetaMo $bundle)
    (buildValidatedMetaMoFromBundle $bundle)
)

;; Run one canonical application bundle step.
;; Example: (runMetaMoBundleStep bundle state rawStimulus) -> transitionResult
(= (runMetaMoBundleStep $bundle $state $rawStimulus)
    (runRegisteredBundleStep $bundle $state $rawStimulus)
)

;; Run one canonical application bundle step with diagnostics.
;; Example: (runMetaMoBundleStepWithDiagnostics bundle state rawStimulus True) -> diagnosed-transition
(= (runMetaMoBundleStepWithDiagnostics $bundle $state $rawStimulus $embody)
    (runRegisteredBundleStepWithDiagnostics $bundle $state $rawStimulus $embody)
)

;; Return only the selected action from a canonical bundle step.
;; Example: (runMetaMoBundleAction bundle state rawStimulus) -> action
(= (runMetaMoBundleAction $bundle $state $rawStimulus)
    (transitionAction (runMetaMoBundleStep $bundle $state $rawStimulus))
)

;; Return only the next state from a canonical bundle step.
;; Example: (runMetaMoBundleState bundle state rawStimulus) -> MotivationState
(= (runMetaMoBundleState $bundle $state $rawStimulus)
    (transitionState (runMetaMoBundleStep $bundle $state $rawStimulus))
)

;; Legacy, non-bundle convenience default - kept for backward compatibility
;; with existing callers (usecase/main-loop.metta, trading_agent.metta) that
;; predate the ApplicationBundle pattern described above. Restored after being
;; dropped during the bundle-API refactor without updating its callers, which
;; left those callers referencing an undefined function with no test coverage
;; to catch it. New application code should prefer the bundle-based functions
;; above (mainBuildMetaMo, runMetaMoBundleStep, etc.) over this one.
(= (defaultMetaMoBimonad)
    (metaMoPseudoBimonad
        (openPsiAppraisal (makeDefaultAppraisalProfile))
        (magusDecision (makeDefaultDecisionProfile) defaultGoalChangeFn 0.5 0.5)
        (makeDefaultStabilityPolicy)
        (makeDefaultCoherencePolicy)
        (makeDefaultParallelMergePolicy)
        ()
    )
)
