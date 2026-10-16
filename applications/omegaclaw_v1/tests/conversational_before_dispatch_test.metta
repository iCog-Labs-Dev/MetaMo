;; Example: newer admitted input invalidates the captured greeting ticket.
(= (conversationScenario) "before_dispatch")
!(import! &self fixtures/conversational_response_loop.metta)
