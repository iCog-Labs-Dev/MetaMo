;; Offline inputs/provider memory are doubled; host selection, engines and dispatch are real.
!(import! &self ../boundary_loop)
!(import! &self (library MetaMo applications/omegaclaw_v1/host_ingress))
!(import! &self benchmark_world.py)
!(import_prolog_functions_from_file
   (library MetaMo applications/omegaclaw_v1/tests/fixtures/reasoner_benchmark/controls.pl)
   (benchmarkSeed benchmarkInitialHost))
(: BenchmarkInitialHostType Type)
(: BenchmarkInitialHost (-> Expression Expression Expression Expression BenchmarkInitialHostType))

;; Initialize the same single admitted task and policy for every adapter/configuration.
;; Example: (benchmarkSetup "Explain the project documentation" "allowed") -> 1.
(= (benchmarkSetup $input $policy)
   (progn
      (commitmentFixtureReset)
      (initContextFrame)
      (fullLoopStartSession)
      (change-state! &last-host-input (sread (py-call (host_ingress.ingest $input))))
      (cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
      (change-state! &prevmsg $input)
      (change-state! &new-msg-flag True)
      (commitmentFixtureOpen "benchmark-task" (get-state &cfv2-current-frame-id) $input)
      (py-call (host_mode_fixture.setup))))

;; Initialization uses native restore validation and registry field names before any writes.
;; Example: an unknown goal or forbidden self-model metric rejects the entire override.
(= (benchmarkMotivationKnown $row)
   (case $row (
      ((goal $name $_) (== (size-atom (collapse (match &self (GoalSpec $name $v) $v))) 1))
      ((anti-goal $name $_) (== (size-atom (collapse (match &self (AntiGoalSpec $name $v) $v))) 1))
      ((modulator $name $_) (== (size-atom (collapse (match &self (ModulatorSpec $name $v) $v))) 1))
      ((self-metric $_ $_) (selfModelMetricValid $row))
      ($_ False))))

;; Example: registry defaults plus validated partial overrides initialize a fresh volatile state.
(= (benchmarkInitializeMotivation)
   (let $rows (sread (py-call (benchmark_world.motivation)))
      (if (== (filter-atom $rows $row (not (benchmarkMotivationKnown $row))) ())
         (if (== (restoreParsedMotivationalState (quote $rows)) MotivationalStateRestored)
            (progn (change-state! &motivation-restored True) 1) 0)
         0)))

;; Example: ordinary held input stays held; explicit follow-ups use the existing host router.
(= (benchmarkInput $message)
   (let $admission (sread (py-call (host_ingress.ingest $message)))
      (progn
         (change-state! &last-host-input $admission)
         (change-state! &prevmsg $message)
         (change-state! &new-msg-flag
            (case $admission (
               ((HostInput NewTask) True)
               ((HostInput FollowUp $_ $_ $_) True)
               ((HostInput Replaced $_ $_ $_ $_) True)
               ($_ False))))
         (case $admission (
            ((HostInput NewTask)
             (progn (cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
                (py-call (host_dispatch_config.admit_startup_commitment))
                (py-call (benchmark_world.provision (get-state &cfv2-current-frame-id)))))
            ((HostInput Replaced $_ $_ $_ $_)
             (py-call (benchmark_world.provision (get-state &cfv2-current-frame-id))))
            ($_ 1)))
         1)))

;; Apply only declared world inputs before normal sensing, selection and invocation.
;; Example: idle cycles do not fabricate a message merely to force a candidate.
(= (benchmarkBeforeCycle $cycle)
   (let $input (sread (py-call (benchmark_world.input_at $cycle)))
      (progn
         (py-call (benchmark_world.before_cycle $cycle (frameStateRuntimeSummary $input 1200)))
         (if (> $cycle 1)
            (progn (change-state! &new-msg-flag False)
               (if (== $input ()) 1 (benchmarkInput $input)))
            1))))

;; The test scenario supplies equivalent native implications, not conclusions or engine results.
;; Example: both local engines must derive Recommend from the admitted user-waiting signal.
(= (benchmarkConfigureAdapter $id)
   (if (tpContains ("nars" "pln") $id)
      (let* (
         ($frame (get-state &cfv2-current-frame-id))
         ($source (if (== $id "nars") nars pln))
         ($implication (if (== $id "nars") ==> Implication))
      )
         (eval (configureHostReasonerRuntime $id
            (quote (HostReasonerRuntime "local-libraries" collectBuiltinHostReasoner noHostReasonerFeedback
               ((ReasonerNativeFact $source (Sentence
                  (($implication (SignalHolds $frame user-waiting) (Recommend $frame respond)) (stv 1 0.9))
                  ((ObservationRef "benchmark-rule-v1" "respond"))))) 0.8)))))
      True))
