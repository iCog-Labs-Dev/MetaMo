;; Build a canonical bimonad from the provided application bundle only.
;; Example: (buildMetaMoFromBundle bundle) -> metaMoPseudoBimonad
(= (buildMetaMoFromBundle $bundle)
    (bundleBimonad $bundle)
)

;; Validate and build a canonical bimonad from a bundle.
;; Example: (buildValidatedMetaMoFromBundle bundle) -> metaMoPseudoBimonad
(= (buildValidatedMetaMoFromBundle $bundle)
    (let* (
        ($validation (validateApplicationBundle $bundle))
    )
        (if (validationIsOk $validation)
            (buildMetaMoFromBundle $bundle)
            $validation
        )
    )
)

;; Run one bundle-scoped step through the registry facade.
;; Example: (runRegisteredBundleStep bundle state stimulus) -> transitionResult
(= (runRegisteredBundleStep $bundle $state $rawStimulus)
    (runBundleStep $bundle $state $rawStimulus)
)

;; Run one diagnosed bundle-scoped step through the registry facade.
;; Example: (runRegisteredBundleStepWithDiagnostics bundle state stimulus True) -> diagnosed-transition
(= (runRegisteredBundleStepWithDiagnostics $bundle $state $rawStimulus $embody)
    (runBundleStepWithDiagnostics $bundle $state $rawStimulus $embody)
)
