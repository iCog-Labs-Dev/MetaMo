;; Offline inputs/provider memory are doubled; host selection, engines and dispatch are real.
!(import! &self ../boundary_loop)

;; Initialize the same single admitted task and policy for every adapter/configuration.
;; Example: (benchmarkSetup "Explain the project documentation" "allowed") -> 1.
(= (benchmarkSetup $input $policy)
   (progn
      (commitmentFixtureReset)
      (initContextFrame)
      (fullLoopStartSession)
      (fullLoopIngest $input)
      (commitmentFixtureOpen "benchmark-task" (get-state &cfv2-current-frame-id) $input)
      (py-call (host_mode_fixture.setup))
      (boundaryProvision $policy)))

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
