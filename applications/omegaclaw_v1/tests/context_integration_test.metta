;; ContextFrames/MetaMo v1 integration smoke test.
;; This intentionally imports the same local OmegaClaw-Core composition used
;; by MetaMo/applications/omegaclaw_v1/run.metta.

!(import! &self (library lib_import))
!(import! &self "../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../repos/OmegaClaw-Core/src/skills)
!(import! &self ../../../../repos/OmegaClaw-Core/src/context)
!(import! &self (library MetaMo core/config))
!(import! &self (library MetaMo core/state))
!(import! &self (library MetaMo core/state_accessors))
!(import! &self (library MetaMo core/helper))
!(import! &self (library MetaMo core/helpers.py))
!(import! &self (library MetaMo applications/omegaclaw_v1/utils))
!(import! &self (library MetaMo applications/omegaclaw_v1/registry))
!(import! &self (library MetaMo applications/omegaclaw_v1/adapter))
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/signals)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/context_integration)

;; Minimal runtime state normally initialized by the full OmegaClaw loop.
!(bind! &prevmsg (new-state ""))
!(bind! &lastresults (new-state ""))
!(bind! &error (new-state ""))
!(bind! &loops (new-state 0))
!(bind! &nextWakeAt (new-state 0))

!(initContextFrame)

;; Required ContextFrames symbols must resolve and produce values after init.
!(test (== (cfv2-has-current-frame) False) True)
!(test (!= (contextFrameForPrompt) ()) True)
!(test (!= (frameStateBundle) ()) True)

;; Frame creation is exercised by the full runtime test suite. It requires the
;; optional ChromaDB relation-composer dependency, so this import smoke test
;; deliberately stays independent of that external service.
!(test (!= (ctx-record-command-batch () ()) ()) True)
!(test (!= (switch-mode) ()) True)

;; With no current frame, execution is rejected before scoring. This proves
;; hard pruning is not merely a score penalty.
!(test (== (eval (contextPolicyGate execute-skill))
           (GateDecision Rejected NoActiveFrame)) True)
!(test (== (eval (candidateAdmitted execute-skill)) False) True)

;; Verify that a typed rejected directive is emitted with separate target,
;; slice, admission, priority, task, and source fields.
!(test (eval (makeAttentionDirective execute-skill 0.80))
      (AttentionDirective
         (target ())
         (slice CurrentFrameTask)
         (task execute-skill)
         (admission Rejected)
         (reason NoActiveFrame)
         (priority 0)
         (source MetaMo)))

;; Required public aliases remain resolvable.
;; These no-current-frame calls intentionally return no operational result;
;; loading and executing them is the resolution check for the public aliases.
!(switch-frame ())
!(complete-goals-stm "smoke completion")
