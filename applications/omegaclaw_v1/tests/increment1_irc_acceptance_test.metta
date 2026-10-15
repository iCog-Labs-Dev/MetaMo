
(= (acceptanceChannel) irc)
(= (acceptanceSuccess) (DispatchResult Executed Feasible (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission Submitted Complete 1 1))))
(= (acceptanceUncertain) (DispatchResult Executed Feasible (SendObservation "irc:irc.example.org:6667:#room" (TransportSubmission Uncertain WriteUncertain 0 1))))
!(import! &self fixtures/increment1_acceptance)
