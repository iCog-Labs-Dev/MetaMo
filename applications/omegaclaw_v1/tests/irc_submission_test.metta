;; Provision the real session adapter and invoke existing local Core handlers.
;; Only the real local stdout channel is loaded; no external messages/services.
!(import! &self (library OmegaClaw-Core src/helper.py))
!(import! &self (library OmegaClaw-Core src/utils))
!(import! &self (library OmegaClaw-Core src/context))
!(import! &self (library OmegaClaw-Core src/skills))
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
!(import! &self (library MetaMo applications/omegaclaw_v1/dispatch))
!(import! &self (library MetaMo applications/omegaclaw_v1/host_dispatch_config.py))
!(import! &self fixtures/host_config_fixture.py)
(= (maxOutputToken) 256)
(= (wakeupInterval) 1)
(= (getFrameSkillsCompact) (quote (read-file show-current-frame)))
!(bind! &prevmsg (new-state ""))
!(bind! &lastresults (new-state ""))
!(bind! &error (new-state ""))
!(bind! &loops (new-state 1))
!(bind! &nextWakeAt (new-state 0))
!(bind! &send-test-channel (new-state local))
(= (commchannel) (get-state &send-test-channel))
!(import! &self (library OmegaClaw-Core channels/local_channel.py))
!(import! &self (library OmegaClaw-Core src/channels))
!(initContextFrame)
;; Supply a typed host frame identity for the concrete-operation contract.
;; Native Core ID migration is a separate production projection task.
!(change-state! &cfv2-current-frame-id "configured-frame")
!(change-state! &cfv2-current-status Active)
!(change-state! &cfv2-root-mode Fast)
!(change-state! &cfv2-current-frame-mode Fast)
!(setConstitutionalMode Engaged)
!(initMetaMoDispatch)
!(bind! &host-config-path (new-state (py-call (host_config_fixture.setup))))
!(bind! &host-read-command (new-state (sread (py-call (host_config_fixture.command)))))
(= (hostReadIntent) (AdmissionRequest propose-candidate current-frame execute-skill))
(= (hostFrameIntent) (AdmissionRequest propose-candidate current-frame search-knowledge))
(= (hostReadTicket) (coreDispatchCapture (hostReadIntent)))

(= (hostSendIntent) (AdmissionRequest propose-candidate current-frame respond))
(= (hostSendTicket) (coreDispatchCapture (hostSendIntent)))
(= (hostSendCommand) (quote (send "observed reply")))

!(import! &self (library OmegaClaw-Core channels/irc.py))
!(import! &self fixtures/irc_routing_fixture.py)
!(import! &self fixtures/irc_submission_fixture.py)
!(change-state! &send-test-channel irc)
!(py-call (irc_routing_fixture.connect "same"))
!(py-call (host_dispatch_config.provision (py-call (irc_submission_fixture.configure "allowed"))))
;; A legacy marker from another channel/failed attempt cannot suppress IRC.
!(change-state! &lastsend "observed reply")
!(bind! &submission-ticket (new-state (hostSendTicket)))
!(test (coreDispatchCommand (get-state &submission-ticket) (hostSendCommand))
   (DispatchResult Executed Feasible
      (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission Submitted Complete 1 1))))
!(test (py-call (irc_routing_fixture.writes)) 1)
;; Fresh invocation of confirmed duplicate text reports suppression, not delivery.
!(test (coreDispatchCommand (hostSendTicket) (hostSendCommand))
   (DispatchResult Executed Feasible
      (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission NotSubmitted SuppressedDuplicate 0 1))))
!(test (py-call (irc_routing_fixture.writes)) 1)
;; Clear transport dedup to prove the ticket ledger alone prevents another write.
!(py-call (irc_submission_fixture.clear_marker))
!(test (coreDispatchCommand (get-state &submission-ticket) (hostSendCommand))
   (DispatchResult Executed Feasible
      (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission Submitted Complete 1 1))))
!(test (py-call (irc_routing_fixture.writes)) 1)
;; A first sendall exception can still follow partial bytes. No success or retry.
!(py-call (irc_routing_fixture.connect "same"))
!(py-call (irc_submission_fixture.fail_after 0))
!(bind! &failed-ticket (new-state (hostSendTicket)))
!(bind! &failed-result (new-state (coreDispatchCommand (get-state &failed-ticket) (hostSendCommand))))
!(test (get-state &failed-result)
   (DispatchResult Executed Feasible
      (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission Uncertain WriteUncertain 0 1))))
!(test (operationOutcomeStatus (hostSendCommand) (get-state &failed-result)) Unobserved)
!(test (py-call (irc_routing_fixture.writes)) 2)
!(test (py-call (irc_submission_fixture.marker_empty)) 1)
!(test (coreDispatchCommand (get-state &failed-ticket) (hostSendCommand)) (get-state &failed-result))
!(test (py-call (irc_routing_fixture.writes)) 2)
!(test (py-call (irc_routing_fixture.route_lock_available)) 1)
;; Three UTF-8 chunks; the second write fails, so the third is never attempted.
!(py-call (irc_routing_fixture.connect "same"))
!(py-call (host_dispatch_config.provision (py-call (irc_submission_fixture.configure "long"))))
!(bind! &long-command (new-state (sread (py-call (irc_submission_fixture.long_command)))))
!(py-call (irc_submission_fixture.fail_after 1))
!(bind! &partial-ticket (new-state (hostSendTicket)))
!(bind! &partial-result (new-state (coreDispatchCommand (get-state &partial-ticket) (get-state &long-command))))
!(test (get-state &partial-result)
   (DispatchResult Executed Feasible
      (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission Uncertain WriteUncertain 1 3))))
!(test (py-call (irc_routing_fixture.writes)) 4)
!(test (py-call (irc_submission_fixture.marker_empty)) 1)
!(test (coreDispatchCommand (get-state &partial-ticket) (get-state &long-command)) (get-state &partial-result))
!(test (py-call (irc_routing_fixture.writes)) 4)
!(test (operationOutcomeStatus (get-state &long-command) (get-state &partial-result)) Unobserved)
;; The dispatch guard releases the route lock after an uncertain attempt.
!(test (py-call (irc_routing_fixture.route_lock_available)) 1)
;; Legacy direct handler behavior on a missing socket is also explicit. The
;; v1 dispatcher normally rejects this route before invoking the handler.
!(py-call (irc_routing_fixture.disconnect))
!(test (send "observed reply")
   (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission NotSubmitted Disconnected 0 1)))
!(test (py-call (irc_submission_fixture.marker_empty)) 1)
!(test (py-call (irc_routing_fixture.writes)) 4)
;; After definite non-submission, an explicit new attempt is not marked duplicate.
!(py-call (irc_routing_fixture.connect "same"))
!(py-call (host_dispatch_config.provision (py-call (irc_submission_fixture.configure "allowed"))))
!(test (coreDispatchCommand (hostSendTicket) (hostSendCommand))
   (DispatchResult Executed Feasible
      (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission Submitted Complete 1 1))))
!(test (py-call (irc_routing_fixture.writes)) 5)
;; The clarification candidate returns the same transport observation contract.
!(test (coreDispatchCommand
   (coreDispatchCapture (AdmissionRequest propose-candidate current-frame ask-clarification))
   (quote (send "Which file?")))
   (DispatchResult Executed Feasible
      (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission Submitted Complete 1 1))))
!(test (py-call (irc_routing_fixture.writes)) 6)
;; Raw observations without a retained selected operation cannot claim success.
!(test (operationOutcomeStatus (hostSendCommand)
   (DispatchResult Executed Feasible
      (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission Submitted Complete 1 1)))) Unobserved)
!(test (py-call (host_config_fixture.cleanup)) 1)
