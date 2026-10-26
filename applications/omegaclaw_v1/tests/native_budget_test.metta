;; Production order: ContextFrames compiles before the loop's config getters.
;; Serialize before comparison so the test cannot repair stored expressions by
;; evaluating them as part of equality. No provider or memory service is started.
!(import! &self (library OmegaClaw-Core src/utils))
!(import! &self (library OmegaClaw-Core src/helper.py))
!(import! &self (library OmegaClaw-Core src/context))
!(import! &self (library OmegaClaw-Core src/loop))
!(initLoop)
!(test (repr (cfv2-default-budget))
   "(ResourceBudget (max-output-tokens 6000) (max-command-lines 5) (wake-interval 600) (status Open))")
!(initContextFrame)
!(test (repr (get-state &cfv2-global-budget))
   "(ResourceBudget (max-output-tokens 6000) (max-command-lines 5) (wake-interval 600) (status Open))")
!(test (repr (get-state &cfv2-current-budget))
   "(ResourceBudget (max-output-tokens 6000) (max-command-lines 5) (wake-interval 600) (status Open))")

;; Example: rejected autonomous creation cannot allocate any frame/goal/relation state.
(= (nativeCreationState)
    ((get-state &cfv2-current-frame-id) (get-state &cfv2-last-admitted-frame-id)
     (get-state &cfv2-active-framespace) (get-state &cfv2-frame-indexspace)
     (get-state &cfv2-goalspace) (get-state &cfv2-subframespace)
     (get-state &cfv2-relational-space))
)

!(bind! &before-native-creation (new-state (nativeCreationState)))
!(change-state! &cfv2-root-mode Fast)
!(test (new-autonomous-frame "unsupported autonomous task") (FrameCreationRejected SlowModeRequired))
!(test (cfv2-create-autonomous-frame "unsupported" 0.5 Slow) (FrameCreationRejected SlowModeRequired))
!(test (cfv2-create-frame AgentDirective "unsupported" 0.5 Slow) (FrameCreationRejected SlowModeRequired))
!(test (nativeCreationState) (get-state &before-native-creation))
!(change-state! &cfv2-root-mode Slow)
!(test (new-autonomous-frame "unsupported autonomous task")
    (FrameCreationRejected MissingAutonomousCreationPolicy))
!(test (cfv2-create-autonomous-frame "unsupported" 0.5 Fast) (FrameCreationRejected SlowModeRequired))
!(test (cfv2-create-frame AgentDirective "unsupported" 0.5 Slow)
    (FrameCreationRejected MissingAutonomousCreationPolicy))
!(test (nativeCreationState) (get-state &before-native-creation))

;; The production command loop uses this exact filter before any dispatch.
!(test (coreLoopCommands (quote ((send "1") (send "2")))) (quote ((send "1") (send "2"))))
!(test (coreLoopCommands (quote ((send "1") (send "2") (send "3") (send "4") (send "5") (send "6")))) ())
!(test (get-state &error) (DispatchBlocked CommandLimitExceeded))
!(test (coreLoopCommands "not a batch") ())
!(test (get-state &error) (DispatchBlocked InvalidCommandBatch))
!(change-state! &cfv2-global-budget
    (ResourceBudget (max-output-tokens 6000) (max-command-lines 1) (wake-interval 600) (status Open)))
!(test (coreLoopCommands (quote ((send "1") (send "2")))) ())
!(change-state! &cfv2-current-budget
    (ResourceBudget (max-output-tokens 6000) (max-command-lines 0) (wake-interval 600) (status Open)))
!(test (coreLoopCommands (quote ((send "1")))) ())
!(test (coreCommandLimitIn
    (ResourceBudget (max-output-tokens 6000) (max-command-lines "invalid") (wake-interval 600) (status Open))) 0)
