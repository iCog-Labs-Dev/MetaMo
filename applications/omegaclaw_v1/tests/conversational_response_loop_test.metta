;; Example: exercise answer through real Core polling and dispatch.
(= (conversationScenario) "answer")
!(import! &self fixtures/conversational_response_loop.metta)

;; Standalone Core can still generate commands through the original provider path.
!(configureCoreLoopCommandSource coreLoopModelCommandSource)
!(py-call (conversational_response.install_legacy_provider))

!(test (let (CoreLoopResponse $_ $commands)
   (coreLoopResponseForPlan (coreLoopCommandPlan) "legacy context" "legacy input")
   $commands) (quote ((send "legacy model reply"))))
