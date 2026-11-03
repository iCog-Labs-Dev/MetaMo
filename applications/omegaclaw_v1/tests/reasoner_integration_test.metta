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

;; Replace one field as data so each invalid value crosses the complete validator.
;; Example: (reasonerProposalValid (reasonerValidationWith 8 "0.9")) -> False.
(= (reasonerValidationWith $index $value)
    (let $proposal (reasonerAccessorTestProposal)
        (map-atom (0 1 2 3 4 5 6 7 8 9 10) $position
            (if (== $position $index) $value (index-atom $proposal $position))
        )
    )
)

;; Build a deterministic list of the requested size for boundary cases.
;; Example: (reasonerValidationIndices 3) -> (2 1 0).
(= (reasonerValidationIndices $count)
    (if (== $count 0) ()
        (cons-atom (- $count 1) (reasonerValidationIndices (- $count 1)))
    )
)

;; Build exact boundary text without Python or a provider dependency.
;; Example: (reasonerValidationText 3) -> "xxx".
(= (reasonerValidationText $count)
    (let* (
        ($codes (map-atom (reasonerValidationIndices $count) $index 120))
        ($_ (translatePredicate (string_codes $text $codes)))
    )
        $text
    )
)

;; Nest one opaque scalar without running it, to test the depth bound.
;; Example: (reasonerValidationNested 1) -> (leaf).
(= (reasonerValidationNested $depth)
    (if (== $depth 0)
        leaf
        (cons-atom (reasonerValidationNested (- $depth 1)) ())
    )
)

;; Supply actual host nonfinite values through the existing Prolog interface.
;; Example: (reasonerValidationNumber "1.0Inf") returns positive infinity.
(= (reasonerValidationNumber $text)
    (let $_ (translatePredicate (atom_number $text $number)) $number)
)

!(bind! &reasoner-validation-audit (new-state (reasonerProposalEvents)))
!(bind! &reasoner-validation-outcomes (new-state (reasonerProposalOutcomes)))
!(bind! &reasoner-validation-reliability (new-state (reasonerSourceReliability nars)))

!(test (reasonerProposalValid (reasonerAccessorTestProposal)) True)

!(test (reasonerProposalValid (reasonerValidationWith 1 "proposal-1")) True)

!(test (reasonerProposalValid (reasonerValidationWith 1 (reasonerValidationText 256))) True)

!(test (reasonerProposalValid (reasonerValidationWith 1 (reasonerValidationText 257))) False)

!(test (map-atom (quote ("" "   " "\t" "id\nnext" 42 True False None none () (reasonerAccessorEffect))) $id
    (reasonerProposalValid (reasonerValidationWith 1 $id)))
    (False False False False False False False False False False False))

!(test (reasonerProposalValid (reasonerValidationWith 1 (quote $missing-id))) False)

!(test (reasonerProposalValid (reasonerValidationWith 4 current-frame)) True)

!(test (reasonerProposalValid (reasonerValidationWith 4 (quote (FrameTarget "frame-1")))) True)

!(test (map-atom (quote (frame-1 "frame-1" () 42 True (FrameTarget "")
    (FrameTarget 42) (FrameTarget (reasonerAccessorEffect)) (FrameTarget f extra)
    (ModeTarget Slow) (reasonerAccessorEffect))) $target
    (reasonerProposalValid (reasonerValidationWith 4 $target)))
    (False False False False False False False False False False False))

!(test (reasonerProposalTargetValid request-attention current-frame) True)

!(test (reasonerProposalTargetValid request-attention (quote (FrameTarget Frame-native))) True)

!(test (reasonerProposalTargetValid request-frame-switch current-frame) False)

!(test (reasonerProposalTargetValid request-frame-switch (quote (FrameTarget Frame-native))) True)

!(test (reasonerProposalTargetValid request-mode-change (quote (ModeTarget Fast))) True)

!(test (reasonerProposalTargetValid request-mode-change (quote (ModeTarget Slow))) True)

!(test (reasonerProposalTargetValid request-mode-change (quote (ModeTarget Other))) False)

!(test (reasonerProposalTargetValid request-mode-change (quote (ModeTarget Slow extra))) False)

!(test (reasonerProposalTargetValid request-mode-change (quote (FrameTarget frame))) False)

!(test (map-atom (0 1 0.9) $confidence
    (reasonerProposalValid (reasonerValidationWith 8 $confidence))) (True True True))

!(test (map-atom (quote (-0.1 1.1 "0.9" True () (reasonerAccessorEffect))) $confidence
    (reasonerProposalValid (reasonerValidationWith 8 $confidence)))
    (False False False False False False))

!(test (map-atom ("1.0Inf" "-1.0Inf" "1.5NaN") $value
    (reasonerProposalValid (reasonerValidationWith 8 (reasonerValidationNumber $value))))
    (False False False))

;; Claim/support/prediction share the same nonempty, bounded inert-data contract.
!(test (map-atom (6 7 10) $index
    (map-atom (quote (() None "" "   ")) $value
        (reasonerProposalValid (reasonerValidationWith $index $value))))
    ((False False False False) (False False False False) (False False False False)))

!(test (map-atom (6 7 10) $index
    (reasonerProposalValid (reasonerValidationWith $index (reasonerValidationText 1200))))
    (True True True))

!(test (map-atom (6 7 10) $index
    (reasonerProposalValid (reasonerValidationWith $index (reasonerValidationText 1201))))
    (False False False))

!(test (reasonerProposalValid (reasonerValidationWith 10 (reasonerValidationNested 15))) True)

!(test (reasonerProposalValid (reasonerValidationWith 10 (reasonerValidationNested 16))) False)

!(test (reasonerProposalValid (reasonerValidationWith 7 (map-atom (reasonerValidationIndices 256) $index support))) True)

!(test (reasonerProposalValid (reasonerValidationWith 7 (map-atom (reasonerValidationIndices 257) $index support))) False)

;; Four lists with 255 leaves give 1025 nodes; removing one leaf gives 1024.
!(test (reasonerProposalValid (reasonerValidationWith 7
    (map-atom (0 1 2 3) $group
        (map-atom (reasonerValidationIndices (if (== $group 0) 254 255)) $index support)))) True)

!(test (reasonerProposalValid (reasonerValidationWith 7
    (map-atom (0 1 2 3) $group (map-atom (reasonerValidationIndices 255) $index support)))) False)

!(test (map-atom (6 7 10) $index
    (reasonerProposalValid (reasonerValidationWith $index
        (quote (Claim (reasonerAccessorEffect)))))) (True True True))

!(test (reasonerProposalValid (reasonerValidationWith 10
    (quote (Claim $unbound-prediction)))) False)

!(test (reasonerProposalValid (reasonerValidationWith 7
    (reasonerValidationNumber "1.0Inf"))) False)

!(test (reasonerProposalValid (reasonerValidationWith 9
    (quote (EvidenceReferences (e1 "e2" (ObservationRef "host" "obs")
        (SessionObservationRef "session" 1)))))) True)

!(test (reasonerProposalValid (reasonerValidationWith 9
    (quote (EvidenceReferences (not-yet-resolved))))) True)

!(test (map-atom (quote (() (e1) (EvidenceReferences ()) (EvidenceReferences e1)
    (EvidenceReferences (e1 e1)) (EvidenceReferences ("")) (EvidenceReferences (42))
    (EvidenceReferences ((reasonerAccessorEffect)))
    (EvidenceReferences ((ObservationRef host "id")))
    (EvidenceReferences ((ObservationRef "host" "")))
    (EvidenceReferences ((ObservationRef "host" "id" extra)))
    (EvidenceReferences ((SessionObservationRef "s" -1)))
    (EvidenceReferences ((SessionObservationRef "s" 1.5)))
    (EvidenceReferences (e1) extra))) $evidence
    (reasonerProposalValid (reasonerValidationWith 9 $evidence)))
    (False False False False False False False False False False False False False False))

!(test (reasonerProposalValid (reasonerValidationWith 9
    (EvidenceReferences (map-atom (reasonerValidationIndices 32) $index (SessionObservationRef "s" $index))))) True)

!(test (reasonerProposalValid (reasonerValidationWith 9
    (EvidenceReferences (map-atom (reasonerValidationIndices 33) $index (SessionObservationRef "s" $index))))) False)

!(test (reasonerProposalEvidenceValid pln (quote (EvidenceReferences ()))) False)

!(test (reasonerProposalEvidenceValid llm (quote (EvidenceReferences ()))) True)

!(test (reasonerProposalValid (llmReasoningToProposal "llm-1" claim 0.8 () respond prediction)) True)

!(test (reasonerProposalValid (requestFrameSwitchProposal p Frame-native 0.8
    (quote (e1)) prediction)) True)

!(test (reasonerProposalValid (requestSlowModeProposal p 0.8
    (quote (EvidenceReferences (e1))) prediction)) True)

;; Neither malformed value admission path may proceed into scoring or dispatch.
!(test (getStatus (reasonerProposalAdmission (minimalDemoBundle)
    (reasonerValidationWith 9 (quote (EvidenceReferences ()))))) Malformed)

!(test (reasonerProposalScore (minimalDemoBundle) invalid-scoring-state
    (reasonerValidationWith 7 ())) 0.0)

!(test (reasonerInferProposal nars "" demo-frame (narsRepairFacts)
    repair-failure prediction (reasonerInferenceLimits)) ())

!(test (reasonerInferProposal nars p demo-frame (narsRepairFacts)
    repair-failure () (reasonerInferenceLimits)) ())

!(test (reasonerInferenceResultToProposal nars p demo-frame () query respond prediction
    (quote ((stv 1.0 0.9) ()))) ())

!(test (reasonerInferenceResultToProposal nars p demo-frame () query respond prediction
    (quote ((stv 1.0 "0.9") (e1)))) ())

!(test (get-state &reasoner-accessor-effects) 0)

;; Value validation preserves multiline data and never interprets embedded code.
!(test (map-atom (6 7 10) $index
    (reasonerProposalValid (reasonerValidationWith $index "first\nsecond")))
    (True True True))

!(test (reasonerProposalValid (reasonerValidationWith 1 (quote getProposalSource))) True)

!(test
    (reasonerProposalValid
        (reasonerValidationWith 9
            (EvidenceReferences (cons-atom (reasonerValidationText 257) ()))
        )
    )
    False
)

!(test (map-atom (quote (
    (EvidenceReferences ((ObservationRef "h" "o") (ObservationRef "h" "o")))
    (EvidenceReferences ((SessionObservationRef "s" 1) (SessionObservationRef "s" 1)))
    (EvidenceReferences ((SessionObservationRef "s" 9007199254740992)))
    (EvidenceReferences ((UnknownRef "h" "o")))
    (EvidenceReferences ("   ")))) $evidence
    (reasonerProposalValid (reasonerValidationWith 9 $evidence)))
    (False False False False False))

!(test (reasonerProposalValid (reasonerValidationWith 9
    (quote (EvidenceReferences ((SessionObservationRef "s" 9007199254740991)))))) True)

!(test (map-atom (6 7 10) $index
    (reasonerProposalValid (reasonerValidationWith $index
        (cons-atom Claim (cons-atom (reasonerValidationNumber "1.5NaN") ())))))
    (False False False))

!(test (get-state &reasoner-accessor-effects) 0)

!(test (reasonerProposalEffectiveScore (minimalDemoBundle) invalid-scoring-state
    (reasonerValidationWith 8 "0.9")) 0.0)

!(test (reasonerProposalEvents) (get-state &reasoner-validation-audit))

!(test (reasonerProposalOutcomes) (get-state &reasoner-validation-outcomes))

!(test (reasonerSourceReliability nars) (get-state &reasoner-validation-reliability))

;; No host adapter means status labels cannot mint execution-backed grades.
!(test (recordReasonerProposalOutcome (car-atom (reasonerProposalEvents))
    Completed () Confirmed ()) (ReasonerOutcomeRejected MissingHostEvidence))

!(test (reasonerProposalOutcomes) (get-state &reasoner-validation-outcomes))

!(test (reasonerSourceReliability nars) (get-state &reasoner-validation-reliability))
