;; Execute benchmark episodes through existing fixture and native runtime APIs.
!(import! &self reasoner_benchmark_matrix.py)

(: BenchmarkHostType Type)
(: BenchmarkHost (-> Atom Atom Atom Atom Atom BenchmarkHostType))
(: BenchmarkScenarioType Type)
(: BenchmarkScenario (-> Atom String String Atom Number String Expression Number BenchmarkHostType BenchmarkScenarioType))

(: BenchmarkObservationType Type)
(: BenchmarkObservation (-> Expression Expression Expression Expression Expression BenchmarkObservationType))
(: BenchmarkUsageType Type)
(: BenchmarkUsage (-> Number Number Number BenchmarkUsageType))

;; Example: native Boolean results become explicit numeric setup checks.
(= (benchmarkRequire $value)
    (if (== $value True) 1 (progn (println! (repr $value)) 0)))

;; Example: configured inference limits remain data checked by the registered adapter.
(= (benchmarkIntakeLimits)
    (sread (py-call (reasoner_benchmark_matrix.intake_limits))))

;; Example: an absent seed leaves the process RNG unchanged.
(= (benchmarkInitializeSeed $seed)
    (if (== $seed ()) 1 (benchmarkRequire (benchmarkSeed $seed))))

;; Example: absent host fields retain the fresh fixture's defaults.
(= (benchmarkInitializeHost (BenchmarkHost $root $frame $status $priority $posture))
    (progn
        (if (!= $root ()) (change-state! &cfv2-root-mode $root) 1)
        (if (!= $frame ()) (change-state! &cfv2-current-frame-mode $frame) 1)
        (if (!= $status ()) (change-state! &cfv2-current-status $status) 1)
        (if (!= $priority ()) (change-state! &cfv2-current-priority $priority) 1)
        (if (!= $posture ()) (setConstitutionalMode $posture) 1)))

;; Example: observe initialized state before the first cycle mutates it.
(= (benchmarkRecordInitial)
    (let* (
        ($m (motivosToMetamoState))
        ($s (getSelfModel))
        ($h (benchmarkInitialHost)))
        (py-call (reasoner_benchmark_matrix.record_initial (quote $m) (quote $s)
            (get-state &active-task) (frameBundleCurrentMode (frameStateForMetaMo)) (quote $h)
            (get-state &cfv2-current-status) (get-state &cfv2-current-priority) (constitutionalMode)
            (frameBundleRootMode (frameStateForMetaMo))))))

;; Example: built-ins use scenario limits; custom registrations keep their declared limits.
(= (benchmarkRegisterAdapter $id)
    (if (tpContains ("nars" "pln") $id)
        (let* (
            ((ReasonerAdapterRegistration $adapter $version $config $source $caps $oldLimits)
                (builtinHostReasoner (sread $id)))
            ($limits (benchmarkIntakeLimits)))
            (benchmarkRequire (registerHostReasoner
                (quote (ReasonerAdapterRegistration $adapter $version $config $source $caps (limits $limits)))
                (quote loadHostReasonerInference))))
        1))

;; Example: disabled comparisons never select or configure a reasoner.
(= (benchmarkPrepareAdapter $id)
    (if (== $id "disabled") 1
        (let* (
            (1 (benchmarkRegisterAdapter $id))
            (1 (benchmarkRequire (selectHostReasoner $id)))
            (1 (benchmarkRequire (benchmarkConfigureAdapter $id)))
            (1 (benchmarkRequire (== (mrcValue (index-atom (registeredHostReasoner $id) 1) 6)
                (benchmarkIntakeLimits)))))
            1)))

;; Example: retain a configuration audit before a later invalid influence request fails.
(= (benchmarkReport $id)
    (let* (
        ($r (if (== $id "disabled") () (index-atom (registeredHostReasoner $id) 1)))
        ($rt (if (== $id "disabled") () (hostReasonerRuntimeBinding $id)))
        ($c (if (== $id "disabled") () (hostReasonerControlsFor $id)))
        ($i (if (== $id "disabled") () (hostReasonerInfluenceSettingFor $id))))
        (py-call (reasoner_benchmark_matrix.record_configuration $id (quote $r) (quote $rt) (quote $c) (quote $i)))))

;; Example: influence configuration still requires native predictive evidence checks.
(= (benchmarkApplyControls $id $controls $cap)
    (if (== $id "disabled") 1
        (let* (
            (1 (if (== (index-atom (index-atom $controls 2) 1) True)
                (benchmarkRequire (configureHostReasonerInfluence $id $cap ())) 1))
            (1 (benchmarkRequire (configureHostReasonerControls $id $controls))))
            1)))


;; Example: capture independent world/policy inputs before selection reserves any budget.
(= (benchmarkBeginCycle)
    (let $host (benchmarkInitialHost)
        (py-call (reasoner_benchmark_matrix.begin_cycle (quote $host)))))

;; Example: structured callback evidence is retained alongside readable trace text.
(= (benchmarkObserve $decision $result $outcome)
    (let* (($host (benchmarkInitialHost)) ($usage (benchmarkUsage)))
        (quote (BenchmarkObservation $decision $result $outcome $host $usage))))


;; Example: execute the declared cycle bound without grading inside the native loop.
(= (benchmarkSteps $step $maximum $id)
    (if (> $step $maximum) 1
        (let* (
            (1 (benchmarkBeforeCycle $step))
            (1 (benchmarkBeginCycle))
            (1 (boundaryCycle benchmark))
            (1 (benchmarkDispatch $step))
            (1 (benchmarkRetainEvidence $id)))
            (benchmarkSteps (+ $step 1) $maximum $id))))

;; Example: keep the exact selected operation and callback before the next cycle replaces them.
(= (benchmarkDispatch $step)
    (let* (
        ($chosen (get-state &selected-operation-decision))
        ($result (fullLoopDispatch benchmark (coreLoopDispatchBegin) (selectedHostCommand)))
        ($outcome (benchmarkOwnOutcome $chosen))
        ($observed (benchmarkObserve $chosen $result $outcome)))
        (benchmarkRecordCycle $step $chosen $result $outcome $observed)))

;; Example: a stale callback cannot become the current decision's evidence.
(= (benchmarkOwnOutcome $chosen)
    (case (get-state &last-operation-outcome) (
        ((OperationOutcome $origin $_ $_ $_)
            (if (== $origin $chosen) (get-state &last-operation-outcome) ()))
        ($_ ()))))

;; Example: readable trace text and structured evidence share the retained cycle identity.
(= (benchmarkRecordCycle $step $chosen $result $outcome $observed)
    (let* (
        ($signals (repr (lastFactualSignals)))
        ($trace (repr (lastCycleTrace)))
        ($ref (repr (index-atom (lastCycleTrace) 2)))
        ($motivation (motivosToMetamoState)))
        (py-call (reasoner_benchmark_matrix.record_cycle $step (repr $chosen) (repr $result)
            (repr $outcome) (repr (get-state &operation-feedback)) $signals $trace $ref
            (quote $motivation) (repr (get-state &last-host-input)) (quote $observed)))))

;; Example: partial runs preserve their bounded proposal and receipt audit after every callback.
(= (benchmarkRetainEvidence $id)
    (let* (
        ($cycles (if (== $id "disabled") () (hostReasonerCycles)))
        ($admissions (if (== $id "disabled") () (hostReasonerAdmissions)))
        ($receipts (if (== $id "disabled") () (hostReasonerReceipts)))
        ($selections (if (== $id "disabled") () (hostReasonerSelections)))
        ($routes (benchmarkComparatorRoutes)))
        (py-call (reasoner_benchmark_matrix.write_evidence
            (quote $cycles) (quote $admissions) (quote $receipts) (quote $selections) (quote $routes)))))

;; Example: completion requires the declared episode, not merely a clean interpreter exit.
(= (benchmarkFinish $id)
    (let* (
        ($cycles (if (== $id "disabled") () (hostReasonerCycles)))
        ($admissions (if (== $id "disabled") () (hostReasonerAdmissions)))
        ($influence (if (== $id "disabled") () (hostReasonerInfluenceSettingFor $id))))
        (progn
            (py-call (reasoner_benchmark_matrix.finish (quote $cycles) (quote $admissions) (quote $influence)))
            (py-call (host_config_fixture.cleanup)))))

;; Example: one entry invocation consumes data from the subprocess's private scenario copy.
(= (benchmarkExecute (BenchmarkScenario $reset $input $policy $seed $maximum $id $controls $cap $host))
    (let* (
        (1 (benchmarkInitializeSeed $seed))
        (1 (eval ($reset $input $policy)))
        (1 (py-call (benchmark_world.initialize (get-state &cfv2-current-frame-id))))
        (1 (benchmarkInitializeMotivation))
        ($_ (benchmarkInitializeHost $host))
        (1 (benchmarkRecordInitial))
        (1 (benchmarkPrepareAdapter $id))
        (1 (benchmarkReport $id))
        (1 (benchmarkApplyControls $id $controls $cap))
        (1 (benchmarkReport $id))
        (1 (benchmarkSteps 1 $maximum $id)))
        (benchmarkFinish $id)))

;; Example: load this process's scenario as data before entering the native driver.
(= (benchmarkRun)
    (benchmarkExecute (sread (py-call (reasoner_benchmark_matrix.run_configuration)))))
