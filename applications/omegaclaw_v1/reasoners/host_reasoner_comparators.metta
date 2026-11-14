;; Trusted comparator routes use retained adapter/configuration/schema identities.
(: HostReasonerComparatorType Type)
(: HostReasonerComparator
    (-> Expression Expression Expression Expression Expression HostReasonerComparatorType))
!(bind! &host-reasoner-comparators (new-state ()))

;; Lookup never consults a process-wide active comparator or prediction-supplied function.
;; Example: routes for two configuration versions cannot adopt each other's evaluator.
(= (hostReasonerComparatorFor $adapter $configuration $schema)
    (let $rows (filter-atom (get-state &host-reasoner-comparators) $row
        (and (== (mrcValue $row 1) $adapter)
            (and (== (mrcValue $row 2) $configuration) (== (mrcValue $row 3) $schema))))
        (if (== (size-atom $rows) 1) (car-atom $rows) ()))
)

;; Register only trusted symbols for a schema declared by the registered adapter.
;; Example: (configureHostReasonerComparator "adapter" "ExpectedResult" "v1" compareResult).
(= (configureHostReasonerComparator $adapter $schema $version $function)
    (case (registeredHostReasoner $adapter) (
        ((HostReasonerAdapter $registration $_)
            (if (tpAllTrue ((mrcText $schema) (mrcText $version)
                    (!= (collapse (translatePredicate (atom $function))) ())
                    (tpContains (mrcValue (mrcValue $registration 5) 3) $schema)))
                (let* (
                    ($configuration (mrcValue $registration 3))
                    ($route (quote (HostReasonerComparator (adapter $adapter)
                        (configuration-version $configuration) (schema $schema)
                        (version $version) (function $function))))
                ) (retainHostReasonerComparator $route))
                (ReasonerAssessmentRejected InvalidComparator)))
        ($_ (ReasonerAssessmentRejected InvalidComparator))))
)

;; Retained intake freezes routing, including an implicit built-in or unsupported route.
;; Example: late registration cannot retroactively choose a more favorable evaluator.
(= (retainHostReasonerComparator $route)
    (let* (
        ($adapter (mrcValue $route 1))
        ($configuration (mrcValue $route 2))
        ($prior (hostReasonerComparatorFor $adapter $configuration (mrcValue $route 3)))
        ($invoked (filter-atom (hostReasonerCycles) $row
            (and (== (mrcValue (index-atom $row 2) 2) $adapter)
                (== (mrcValue (index-atom $row 2) 4) $configuration))))
    )
        (case (== $prior $route) (
            (True True)
            (False (if (!= $invoked ()) (ReasonerAssessmentRejected ComparatorAlreadyInvoked)
                (progn (change-state! &host-reasoner-comparators
                    (cons-atom $route (filter-atom (get-state &host-reasoner-comparators) $old
                        (!= $old $prior)))) True))))))
)

;; Resolve from the original invocation, with one versioned built-in exact-result route.
;; Example: an undeclared prediction constructor remains unsupported even if a route exists.
(= (hostReasonerPredictionComparator $envelope)
    (let* (
        ($invocation (mrcValue $envelope 2))
        ($prediction (getProposalPrediction (mrcValue $envelope 4)))
        ($adapter (mrcValue $invocation 2))
        ($configuration (mrcValue $invocation 4))
        ($schema (if (and (== (get-metatype $prediction) Expression) (!= $prediction ()))
            (repr (car-atom $prediction)) ""))
        ($declared (tpContains (mrcValue (mrcValue $invocation 11) 3) $schema))
    )
        (if $declared
            (case (hostReasonerComparatorFor $adapter $configuration $schema) (
                (() (if (== $schema "ExpectedOperationResult")
                    (HostReasonerComparator (adapter $adapter) (configuration-version $configuration)
                        (schema $schema) (version "exact-operation-result-1") (function compareReasonerOperationResult)) ()))
                ($route $route))) ()))
)
