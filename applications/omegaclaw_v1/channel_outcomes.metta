;; Channel-specific send evidence. Adding a channel extends this module rather
;; than operation selection or callback ingestion. Unknown channels fail closed.
;; Resolve the channel from recorded destination data, never the current socket.
!(import! &self (library MetaMo applications/omegaclaw_v1/host_operations.py))

(= (sendOutcomeStatus $command $result)
   (case $result (
      ((DispatchResult Executed Feasible (SendObservation $destination $observation))
       (channelOutcomeStatus (py-call (host_operations.send_observation_channel $destination))
          $command $destination $observation))
      ($_ Unobserved))))

;; Shared entry point: each channel owns its documented observation contract.
;; Channel names alone confer no success; handlers validate their destination
;; and evidence. Future channels must add an explicit case and their own checks.
(= (channelOutcomeStatus $channel $command $destination $observation)
   (case $channel (
      (local (localSendOutcomeStatus $destination $observation))
      (irc (ircSendOutcomeStatus $command $destination $observation))
      ($_ Unobserved))))

(= (localSendOutcomeStatus $destination $observation)
   (if (tpAllTrue ((== $destination "local:stdout") (== $observation Accepted)))
       Success Unobserved))

;; Selection correlation is shared by transports that report a destination.
(= (selectedSendMatches $command $destination)
   (case (get-state &selected-host-operation) (
      ((HostOperation $candidate $selected
          (PolicyOperation (candidate $candidate) $_ (skill "send") $_
             (egress ($expected)) $_) $_ $_ $ticket)
       (tpAllTrue (
          (== $command $selected)
          (tpContains (respond ask-clarification) $candidate)
          (== $destination $expected)
          (== (get-state &selected-operation-decision)
              (OperationDecision (get-state &operation-context)
                 $candidate $command $ticket)))))
      ($_ False))))

(= (completeSubmissionCounts $completed $total)
   (if (tpQuantity $total)
       (tpAllTrue ((> $total 0)
          (== (floor-math $total) $total)
          (== $completed $total))) False))

(= (ircSendOutcomeStatus $command $destination $observation)
   ;; A later disconnect cannot erase submission evidence from this selection.
   ;; Socket submission is operation success, never recipient acknowledgement.
   (case $observation (
      ((TransportSubmission Submitted Complete $completed $total)
       (if (selectedSendMatches $command $destination)
           (if (completeSubmissionCounts $completed $total)
               (if (== (py-call (host_operations.supported_irc_destination $destination)) 1)
                   Success Unobserved) Unobserved) Unobserved))
      ($_ Unobserved))))
