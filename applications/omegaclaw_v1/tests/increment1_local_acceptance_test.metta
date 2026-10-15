
(= (acceptanceChannel) local)
(= (acceptanceSuccess) (DispatchResult Executed Feasible (SendObservation "local:stdout" Accepted)))
(= (acceptanceUncertain) (DispatchResult Unobserved ExecutionUncertain none))
!(import! &self fixtures/increment1_acceptance)
