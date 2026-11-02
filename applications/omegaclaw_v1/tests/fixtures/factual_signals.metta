;; Shape-valid typed fixtures for pure consumer tests. These references do not
;; claim host authentication. Managed integration tests use real publication.
;; Load after composition, which owns production state and validators.

;; Example: (fixtureSignalFact failure (quote (BooleanFact True))).
(= (fixtureSignalFact $kind $value)
    (makeFactualSignal $kind $value ((SessionObservationRef "typed-signal-fixture" 0))))

;; Example: replacing True with False changes a fact, never its motivational weight.
;; Fixture-only insertion deliberately bypasses the host publication boundary.
(= (fixturePutSignal $kind $value)
    (let $fact (fixtureSignalFact $kind $value)
        (case (validateFactualSignal $fact) (
            ((FactualSignalValid $_ $_ $_)
                (progn
                    (collapse (let $old (match &signal-space
                        (FactualSignal (kind $kind) (value $v) (provenance $p))
                        (FactualSignal (kind $kind) (value $v) (provenance $p)))
                        (remove-atom &signal-space $old)))
                    (add-atom &signal-space $fact)))
            ($rejection $rejection)))))
