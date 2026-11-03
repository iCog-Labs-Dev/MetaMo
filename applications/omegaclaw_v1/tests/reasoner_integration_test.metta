;; Offline real inference plus production proposal admission/conversion.
;; Explicit host sources also resolve under the workspace-local run.sh.
!(import! &self "../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../repos/OmegaClaw-Core/src/context)
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

;; Exercise every public proposal accessor with quoted data, including payloads
;; whose heads name executable functions. Only the accessor itself is evaluated.
;; Example: (reasonerAccessorTestFields ()) returns ten typed rejections.
(= (reasonerAccessorTestFields $proposal)
    (map-atom
        (quote (getProposalId getProposalSource getProposalKind getProposalTarget
            getProposalCandidate getProposalClaim getProposalSupport
            getProposalConfidence getProposalEvidence getProposalPrediction))
        $accessor
        (eval ($accessor (quote $proposal)))
    )
)

;; Check every accessor's rejection rather than just a representative field.
;; Example: (reasonerAccessorsReject ()) -> True.
(= (reasonerAccessorsReject $proposal)
    (== (reasonerAccessorTestFields $proposal)
        (map-atom (1 2 3 4 5 6 7 8 9 10) $index
            (ReasonerAccessorRejected InvalidProposal)
        )
    )
)

;; Distinct field values detect positional regressions across all ten getters.
;; Example: (getProposalId (reasonerAccessorTestProposal)) -> accessor-id.
(= (reasonerAccessorTestProposal)
    (quote (ReasonerMotivationalProposal accessor-id nars propose-candidate
        (FrameTarget demo-frame) respond claim support 0.9
        (EvidenceReferences (observation-1)) prediction))
)

;; Construct an inert event with the canonical ordered field layout.
;; Example: (getProposalEventProposal (reasonerAccessorTestEvent p)) rejects p.
(= (reasonerAccessorTestEvent $proposal)
    (quote (ReasonerProposalEvent (proposal $proposal)
        (decision retained-decision) (disposition Accepted)))
)

!(test (reasonerAccessorTestFields (reasonerAccessorTestProposal))
    (quote (accessor-id nars propose-candidate (FrameTarget demo-frame)
        respond claim support 0.9 (EvidenceReferences (observation-1)) prediction)))

!(test (reasonerAccessorsReject
    (quote (WrongTag id nars propose-candidate current-frame respond
        claim support 0.9 evidence prediction))) True)

!(test (reasonerAccessorsReject
    (quote (ReasonerMotivationalProposal id nars propose-candidate current-frame
        respond claim support 0.9 evidence))) True)

!(test (reasonerAccessorsReject
    (quote (ReasonerMotivationalProposal id nars propose-candidate current-frame
        respond claim support 0.9 evidence prediction extra))) True)

!(test (reasonerAccessorsReject ()) True)

!(test (reasonerAccessorsReject malformed) True)

!(test (reasonerAccessorsReject "not a record") True)

!(test (reasonerAccessorsReject 42) True)

!(test (reasonerAccessorsReject (quote $unbound-proposal)) True)

!(test (reasonerAccessorsReject
    (quote (ReasonerMotivationalProposal $unbound-id nars propose-candidate
        current-frame respond claim support 0.9 evidence prediction))) True)

!(test (getProposalEventProposal
    (reasonerAccessorTestEvent (reasonerAccessorTestProposal))) (reasonerAccessorTestProposal))

!(test (getProposalEventProposal
    (quote (WrongEvent (proposal malformed) (decision d) (disposition Accepted))))
    (ReasonerAccessorRejected InvalidProposalEvent))

!(test (getProposalEventProposal
    (quote (ReasonerProposalEvent (proposal malformed))))
    (ReasonerAccessorRejected InvalidProposalEvent))

!(test (getProposalEventProposal
    (quote (ReasonerProposalEvent (proposal malformed) (decision d)
        (disposition Accepted) extra)))
    (ReasonerAccessorRejected InvalidProposalEvent))

!(test (getProposalEventProposal
    (quote (ReasonerProposalEvent (wrong-field malformed) (decision d) (disposition Accepted))))
    (ReasonerAccessorRejected InvalidProposalEvent))

!(test (getProposalEventProposal
    (quote (ReasonerProposalEvent (proposal malformed extra) (decision d) (disposition Accepted))))
    (ReasonerAccessorRejected InvalidProposalEvent))

!(test (getProposalEventProposal
    (quote (ReasonerProposalEvent (decision d) (proposal malformed) (disposition Accepted))))
    (ReasonerAccessorRejected InvalidProposalEvent))

!(test (getProposalEventProposal (reasonerAccessorTestEvent
    (quote (WrongProposal id nars propose-candidate current-frame respond
        claim support 0.9 evidence prediction))))
    (ReasonerAccessorRejected InvalidProposalEvent))

!(test (getProposalEventProposal ()) (ReasonerAccessorRejected InvalidProposalEvent))

!(test (getProposalEventProposal malformed) (ReasonerAccessorRejected InvalidProposalEvent))

!(test (getProposalEventProposal (quote $unbound-event))
    (ReasonerAccessorRejected InvalidProposalEvent))

;; A valid embedded proposal must not hide malformed event fields or arities.
;; Example: every record returned here must reject at the event boundary.
(= (reasonerAccessorMalformedEvents)
    (let $proposal (reasonerAccessorTestProposal)
        (quote (
            (WrongEvent (proposal $proposal) (decision d) (disposition Accepted))
            (ReasonerProposalEvent (proposal $proposal) (decision d))
            (ReasonerProposalEvent (proposal $proposal) (decision d) (disposition Accepted) extra)
            (ReasonerProposalEvent (wrong-field $proposal) (decision d) (disposition Accepted))
            (ReasonerProposalEvent (proposal $proposal extra) (decision d) (disposition Accepted))
            (ReasonerProposalEvent (decision d) (proposal $proposal) (disposition Accepted))
            (ReasonerProposalEvent (proposal $proposal) (wrong-field d) (disposition Accepted))
            (ReasonerProposalEvent (proposal $proposal) (decision) (disposition Accepted))
            (ReasonerProposalEvent (proposal $proposal) (decision d extra) (disposition Accepted))
            (ReasonerProposalEvent (proposal $proposal) (decision d) (wrong-field Accepted))
            (ReasonerProposalEvent (proposal $proposal) (decision d) (disposition))
            (ReasonerProposalEvent (proposal $proposal) (decision d) (disposition Accepted extra))
        ))
    )
)

!(test (map-atom (reasonerAccessorMalformedEvents) $event
    (getProposalEventProposal $event))
    (map-atom (1 2 3 4 5 6 7 8 9 10 11 12) $index
        (ReasonerAccessorRejected InvalidProposalEvent)))

!(test (reasonerProposalShapeValid
    (getProposalEventProposal (car-atom (reasonerProposalEvents)))) True)

;; The counter proves that payload inspection/return never executes its code.
!(bind! &reasoner-accessor-effects (new-state 0))

;; Deliberately executable payload used only inside quoted records.
;; Example: an explicit (reasonerAccessorEffect) increments the counter once.
(= (reasonerAccessorEffect)
    (change-state! &reasoner-accessor-effects
        (+ (get-state &reasoner-accessor-effects) 1)
    )
)

;; All fields are expressions to exercise every accessor's data-return path.
;; Example: (getProposalClaim (reasonerAccessorInertProposal)) returns the expression unchanged.
(= (reasonerAccessorInertProposal)
    (quote (ReasonerMotivationalProposal
        (reasonerAccessorEffect) (reasonerAccessorEffect) (reasonerAccessorEffect)
        (reasonerAccessorEffect) (reasonerAccessorEffect) (reasonerAccessorEffect)
        (reasonerAccessorEffect) (reasonerAccessorEffect) (reasonerAccessorEffect)
        (reasonerAccessorEffect)))
)

!(test (reasonerAccessorTestFields (reasonerAccessorInertProposal))
    (quote ((reasonerAccessorEffect) (reasonerAccessorEffect) (reasonerAccessorEffect)
        (reasonerAccessorEffect) (reasonerAccessorEffect) (reasonerAccessorEffect)
        (reasonerAccessorEffect) (reasonerAccessorEffect) (reasonerAccessorEffect)
        (reasonerAccessorEffect))))

!(test (getProposalEventProposal (reasonerAccessorTestEvent (reasonerAccessorInertProposal)))
    (reasonerAccessorInertProposal))

!(test (getProposalEventProposal
    (let $proposal (reasonerAccessorInertProposal)
        (quote (ReasonerProposalEvent (proposal $proposal)
            (decision (reasonerAccessorEffect)) (disposition (reasonerAccessorEffect))))))
    (reasonerAccessorInertProposal))

!(test (getProposalEventProposal
    (quote (ReasonerProposalEvent (proposal (reasonerAccessorEffect))
        (decision (reasonerAccessorEffect)) (disposition (reasonerAccessorEffect)))))
    (ReasonerAccessorRejected InvalidProposalEvent))

!(test (getProposalId (quote (reasonerAccessorEffect)))
    (ReasonerAccessorRejected InvalidProposal))

!(test (getProposalEventProposal (quote (reasonerAccessorEffect)))
    (ReasonerAccessorRejected InvalidProposalEvent))

!(test (get-state &reasoner-accessor-effects) 0)
