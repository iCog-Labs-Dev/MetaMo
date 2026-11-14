;; Trusted stage controls are optional host configuration, not proposal data.
(: HostReasonerControlsType Type)
(: HostReasonerControls (-> Expression Expression Expression Expression HostReasonerControlsType))
(: HostReasonerControlBindingType Type)
(: HostReasonerControlBinding (-> String Expression HostReasonerControlBindingType))
!(bind! &host-reasoner-controls (new-state ()))

;; Selection/loading alone grants no permission to collect, assess, influence or learn.
;; Example: (hostReasonerControlsFor "unconfigured") returns four disabled stages.
(= (hostReasonerControlsFor $id)
    (let $rows (filter-atom (get-state &host-reasoner-controls) $row (== (index-atom $row 1) $id))
        (case $rows (
            (((HostReasonerControlBinding $_ $controls)) $controls)
            ($_ (HostReasonerControls (collection False) (influence False) (assessment False) (learning False)))
        )))
)

;; Read one named Boolean without introducing dependencies between stages.
;; Example: learning can be enabled while assessment remains disabled.
(= (hostReasonerStageEnabledFor $id $stage)
    (let $controls (hostReasonerControlsFor $id)
        (tpContains (cdr-atom $controls) ($stage True)))
)

;; Freeze configuration once an invocation exists, preserving historical interpretation.
;; Example: enabling influence currently rejects until bounded weighting is implemented.
(= (configureHostReasonerControls $id $controls)
    (case $controls (
        ((HostReasonerControls (collection $c) (influence $i) (assessment $a) (learning $l))
            (if (and (!= (registeredHostReasoner $id) ())
                    (tpAllTrue ((tpContains (True False) $c) (tpContains (True False) $i)
                        (tpContains (True False) $a) (tpContains (True False) $l))))
                (if $i (ReasonerRuntimeError UnsupportedInfluence)
                    (retainHostReasonerControls $id $controls))
                (ReasonerRuntimeError InvalidControls)))
        ($_ (ReasonerRuntimeError InvalidControls))))
)

;; Repeated identical configuration is harmless; active configuration cannot be rewritten.
;; Example: invalid/late configuration preserves the previous four controls.
(= (retainHostReasonerControls $id $controls)
    (if (== (hostReasonerControlsFor $id) $controls) True
        (if (!= (filter-atom (hostReasonerCycles) $row
                (== (mrcValue (index-atom $row 2) 2) $id)) ())
            (ReasonerRuntimeError AlreadyInvoked)
            (progn (change-state! &host-reasoner-controls
                (cons-atom (quote (HostReasonerControlBinding $id $controls))
                    (filter-atom (get-state &host-reasoner-controls) $row (!= (index-atom $row 1) $id)))) True)))
)

;; Optional startup flags use the same stage controls as programmatic configuration.
;; Example: reasoner-collection=True enables collection without assessment or learning.
(= (hostReasonerStartupFlag $key $fallback)
    (case (collapse (argk $key)) (
        (() $fallback)
        (($value) (case (repr $value) (
            ("True" True) ("False" False) ("true" True) ("false" False) ($_ InvalidFlag))))
        ($_ InvalidFlag))))

;; Missing flags preserve trusted configuration, whose unconfigured stages are disabled.
;; Example: reasoner=nars alone selects an adapter without invoking it.
(= (configureHostReasonerStartupControls)
    (let* (
        ($id (hostReasonerSelection))
        ($current (hostReasonerControlsFor $id))
        ($c (hostReasonerStartupFlag "reasoner-collection" (mrcValue $current 1)))
        ($i (hostReasonerStartupFlag "reasoner-influence" (mrcValue $current 2)))
        ($a (hostReasonerStartupFlag "reasoner-assessment" (mrcValue $current 3)))
        ($l (hostReasonerStartupFlag "reasoner-learning" (mrcValue $current 4)))
    )
        (configureHostReasonerControls $id
            (HostReasonerControls (collection $c) (influence $i) (assessment $a) (learning $l))))
)
