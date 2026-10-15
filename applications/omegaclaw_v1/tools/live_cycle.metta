;; Loaded after production startup imports. One bounded, serialized host driver.
;; All provider calls, frame ingestion, bridge scoring and Core handlers are real.
!(test (py-call (live_cycle_probe.prepare)) 1)
!(initLoop)
!(initMemory)
!(initChannels)
!(initContextFrame)
!(initOperationSession)
!(initOmegaClawMotivation)
!(bind! &live-message (new-state (string-safe (repr (receive)))))
!(change-state! &prevmsg (get-state &live-message))
!(ctx-ingest-user-message (get-state &live-message))
!(cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
!(bind! &live-frame (new-state (cfv2-root-current-frame-id)))
!(change-state! &core-loop-new-message True)
!(test (coreLoopPrepare) 1)
!(test (!= (get-state &live-frame) ()) True)

(= (liveCycle $label)
   (progn
      (coreLoopPrepare)
      (let $outputs (collapse (motivationContextBlock))
         (progn
            (println! (LivePolicy $label $outputs))
            (py-call (live_cycle_probe.capture $label "selection"))
            (size-atom $outputs))))
)

(= (liveDispatch $label)
   (let $result (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
      (progn
         (println! (LiveExecution $label $result))
         (py-call (live_cycle_probe.capture $label "outcome"))
         $result)))

;; The same admitted frame and session persist across every cycle. Fresh explicit
;; execution confirmations authorize selection intent, never policy or dispatch.
!(test (liveCycle "success") 1)
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) execute-skill)
!(test (liveDispatch "success") (DispatchResult Executed Feasible "live cycle approved content"))

!(test (liveCycle "io-failure") 1)
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback Success 0))
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) execute-skill)
;; Remove only the generated test file after selection, exercising the real
;; read handler's missing-file path. Core now reports a definite failure.
!(test (py-call (live_cycle_probe.change_file 0)) 1)
!(test (liveDispatch "io-failure") (DispatchResult Executed Feasible (Error read-file FileUnavailable)))

;; Consume the definite failure before the next fresh execution confirmation.
!(change-state! &core-loop-new-message False)
!(test (liveCycle "consume-failure") 1)
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback Failure 1))
!(change-state! &core-loop-new-message True)
;; Explicit operator repair of a read-only dependency; no fabricated callback.
!(test (py-call (live_cycle_probe.change_file 1)) 1)
!(test (liveCycle "recovery") 1)
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback NoOutcome 1))
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) execute-skill)
!(test (liveDispatch "recovery") (DispatchResult Executed Feasible "live cycle approved content"))

!(test (liveCycle "revoked-after-selection") 1)
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback Success 0))
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) execute-skill)
!(test (py-call (live_cycle_probe.policy 0)) 1)
!(test (liveDispatch "revoked-after-selection") (DispatchResult Blocked StaleSnapshot none))

!(test (liveCycle "denied-before-selection") 1)
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback Blocked 0))
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) none)
!(test (tpContains (candidateRejections) (CandidateRejection execute-skill PermissionDenied)) True)
!(test (selectedHostCommand) ())
!(test (liveDispatch "denied-before-selection") (DispatchResult Blocked MissingDecision none))

!(test (py-call (live_cycle_probe.policy 1)) 1)
!(test (liveCycle "permission-restored") 1)
!(test (liveDispatch "permission-restored") (DispatchResult Executed Feasible "live cycle approved content"))
!(change-state! &core-loop-new-message False)
!(test (liveCycle "observe-recovery") 1)
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback Success 0))
!(test (cfv2-root-current-frame-id) (get-state &live-frame))
!(test (size-atom (cfv2-frame-refs-by-status Active)) 1)
!(test (frameRuntimeTaskOpen (activeFrameBundle)) True)
