;; Offline real inference plus production proposal admission/conversion.
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/minimal_loop))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_integration))
!(initMinimalLoopFixture)

(= (narsRepairFacts)
   ((Sentence ((Failed demo-frame) (stv 1.0 0.9)) (observation-1))
    (Sentence ((==> (Failed demo-frame) (Recommend demo-frame repair-failure))
       (stv 1.0 0.9)) (rule-1))))
(= (plnRepairFacts)
   ((Sentence ((Failed demo-frame) (stv 1.0 0.9)) (observation-1))
    (Sentence ((Implication (Failed demo-frame) (Recommend demo-frame repair-failure))
       (stv 1.0 0.9)) (rule-1))))
(= (narsRepairProposal)
   (reasonerInferProposal nars nars-1 demo-frame (narsRepairFacts)
      repair-failure (Expected recovered) (reasonerInferenceLimits)))
(= (plnRepairProposal)
   (reasonerInferProposal pln pln-1 demo-frame (plnRepairFacts)
      repair-failure (Expected recovered) (reasonerInferenceLimits)))

!(test (getProposalSource (narsRepairProposal)) nars)
!(test (getProposalSource (plnRepairProposal)) pln)
!(test (reasonerProposalValid (narsRepairProposal)) True)
!(test (reasonerProposalValid (plnRepairProposal)) True)
!(test (getProposalEvidence (narsRepairProposal))
   (EvidenceReferences (observation-1 rule-1)))
!(test (getProposalTarget (plnRepairProposal)) (FrameTarget demo-frame))
!(test (getCandidate (reasonerProposalToAction (minimalDemoBundle) (narsRepairProposal))) repair-failure)
!(test (getStatus (reasonerProposalToAction (minimalDemoBundle) (plnRepairProposal))) Accepted)

;; Identical query with missing premise cannot manufacture a recommendation.
!(test (reasonerInferProposal nars missing demo-frame
   ((Sentence ((==> (Failed demo-frame) (Recommend demo-frame repair-failure))
      (stv 1.0 0.9)) (rule-1)))
   repair-failure (Expected recovered) (reasonerInferenceLimits)) ())
;; Neither engine may accidentally use the other engine's implication rules.
!(test (reasonerQuery nars (plnRepairFacts) (Recommend demo-frame repair-failure)
   (reasonerInferenceLimits)) ())
!(test (reasonerQuery pln (narsRepairFacts) (Recommend demo-frame repair-failure)
   (reasonerInferenceLimits)) ())
!(test (reasonerInferenceResultToProposal nars negative demo-frame ()
   (Recommend demo-frame repair-failure) repair-failure (Expected recovered)
   ((stv 0.0 0.99) (negative-evidence))) ())

;; Constitutional admission still applies to inferred recommendations.
!(change-state! &constitutional-mode Sleep)
!(test (getStatus (reasonerProposalToAction (minimalDemoBundle) (narsRepairProposal))) Rejected)
!(test (getStatus (reasonerProposalDecision (minimalDemoBundle) () (narsRepairProposal))) Rejected)
!(test (getStatus (reasonerProposalAdmission (minimalDemoBundle)
   (ReasonerMotivationalProposal broken))) Malformed)
!(test (reasonerInferDirective nars missing (minimalDemoBundle) () ()
   repair-failure (Expected recovered) (reasonerInferenceLimits)) ())
!(change-state! &constitutional-mode Engaged)
;; Repeated grades build on the previous value, rather than restarting at prior.
!(updateReasonerSourceReliability nars 1.0)
!(updateReasonerSourceReliability nars 1.0)
!(test (> (reasonerSourceReliability nars) 0.86) True)

;; Accepted proposals also traverse the real scorer and audit function.
!(test (getStatus (reasonerProposalDecision (minimalDemoBundle)
   (motivation (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
               (0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5))
   (plnRepairProposal))) Accepted)
