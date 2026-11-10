;; Offline real inference plus production proposal admission/conversion.
;; Explicit host sources also resolve under the workspace-local run.sh.
!(import! &self "../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../repos/OmegaClaw-Core/src/context)
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/minimal_loop))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_integration))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_outcome_assessment))
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

;; An outcome ID accessor checks the whole local layout and returns inert data.
!(test (getProposalOutcomeId ()) (ReasonerAccessorRejected InvalidProposalOutcome))

!(test (getProposalOutcomeId
    (quote (WrongOutcome (outcome-id (ReasonerOutcomeRef "s" "t")))))
    (ReasonerAccessorRejected InvalidProposalOutcome))

!(test (getProposalOutcomeId
    (quote (ReasonerProposalOutcomeEvent (outcome-id (ReasonerOutcomeRef "s" "t"))
        (proposal-event (reasonerAccessorEffect)) (execution-status Completed)
        (execution-evidence (reasonerAccessorEffect)) (frame-evidence-status Unresolved)
        (frame-state-evidence ()) (outcome Unresolved) (grade Ungraded))))
    (ReasonerOutcomeRef "s" "t"))

!(test (get-state &reasoner-accessor-effects) 0)

;; Execution status cannot supply the missing prediction observation.
!(test (map-atom (Completed Failed Blocked Unobserved) $status
    (reasonerProposalOutcomeGrade $status Unresolved))
    (Ungraded Ungraded Ungraded Ungraded))

!(test (map-atom (Completed Failed Blocked Unobserved) $status
    (reasonerProposalOutcomeClass $status Unresolved))
    (Unresolved Unresolved Unresolved Unresolved))

;; Blocking and non-execution do not establish even an asserted conclusion.
!(test (map-atom (Confirmed Refuted Unresolved) $verification
    (reasonerProposalOutcomeGrade Blocked $verification))
    (Ungraded Ungraded Ungraded))

!(test (map-atom (Confirmed Refuted Unresolved) $verification
    (reasonerProposalOutcomeGrade Unobserved $verification))
    (Ungraded Ungraded Ungraded))

!(test (map-atom (Confirmed Refuted Unresolved) $verification
    (reasonerProposalOutcomeClass Blocked $verification))
    (Unresolved Unresolved Unresolved))

!(test (map-atom (Confirmed Refuted Unresolved) $verification
    (reasonerProposalOutcomeClass Unobserved $verification))
    (Unresolved Unresolved Unresolved))

;; Invalid or missing statuses fail closed; the public writer also checks receipts.
!(test (map-atom (Rejected () Unknown) $status
    (reasonerProposalOutcomeGrade $status Confirmed))
    (Ungraded Ungraded Ungraded))

!(test (reasonerProposalOutcomeGrade Completed Unknown) Ungraded)

;; Motivational helpers never derive grades from status labels, even strong ones.
!(test (map-atom (Completed Failed Blocked Unobserved) $status
    (reasonerProposalOutcomeGrade $status Confirmed))
    (Ungraded Ungraded Ungraded Ungraded))

;; Comparison operates on retained data, including executable-looking payloads.
!(test (compareReasonerOperationResult (quote (ExpectedOperationResult (reasonerAccessorEffect)))
    (quote (reasonerAccessorEffect))) (ReasonerPredictionComparison Confirmed 1.0))

!(test (compareReasonerOperationResult (ExpectedOperationResult "expected") "other")
    (ReasonerPredictionComparison Refuted 0.0))

!(test (compareReasonerOperationResult "vague prediction" "observation")
    (ReasonerPredictionComparison Unresolved Ungraded))

!(test (get-state &reasoner-accessor-effects) 0)

;; Validate every comparator grade before changing external source weights.
!(test (map-atom (quote (
    (ReasonerPredictionComparison Confirmed "1.0")
    (ReasonerPredictionComparison Confirmed -0.1)
    (ReasonerPredictionComparison Refuted 1.1)
    (ReasonerPredictionComparison Unresolved 0.5)
    (ReasonerPredictionComparison Confirmed Ungraded)
    (ReasonerPredictionComparison Unknown 0.5)
    (WrongComparison Confirmed 1.0)
    (ReasonerPredictionComparison Confirmed 1.0 extra))) $comparison
    (reasonerComparisonValid $comparison))
    (False False False False False False False False))

!(test (reasonerComparisonValid
    (ReasonerPredictionComparison Confirmed (reasonerValidationNumber "1.0Inf"))) False)

!(test (reasonerComparisonValid
    (ReasonerPredictionComparison Refuted (reasonerValidationNumber "1.5NaN"))) False)

!(test (map-atom (quote ((ReasonerPredictionComparison Confirmed 0.9)
    (ReasonerPredictionComparison Refuted 0.1)
    (ReasonerPredictionComparison Unresolved Ungraded))) $comparison
    (reasonerComparisonValid $comparison)) (True True True))

!(test (map-atom (quote (Ungraded "0.5" -1 2)) $grade
    (updateReasonerSourceReliability nars $grade))
    ((ReasonerAssessmentRejected InvalidGrade) (ReasonerAssessmentRejected InvalidGrade)
        (ReasonerAssessmentRejected InvalidGrade) (ReasonerAssessmentRejected InvalidGrade)))

!(test (reasonerSourceReliability nars) (get-state &reasoner-validation-reliability))

!(test (assessReasonerProposalOutcome (car-atom (reasonerProposalEvents)) ())
    (ReasonerAssessmentRejected MissingHostEvidence))

!(test (reasonerProposalAssessments) ())

;; A code-shaped grade stays data and is rejected before numerical arithmetic.
!(test (reasonerComparisonValid
    (quote (ReasonerPredictionComparison Confirmed (reasonerAccessorEffect)))) False)

!(test (get-state &reasoner-accessor-effects) 0)

!(test (compareReasonerOperationResult (quote (ExpectedOperationResult "x" extra)) "x")
    (ReasonerPredictionComparison Unresolved Ungraded))

;; Real negative evidence must survive querying without becoming a recommendation.
!(test (map-atom (nars pln) $engine
    (reasonerQuery $engine
        ((Sentence ((Recommend demo-frame repair-failure) (stv 0.0 0.99)) (negative-observation)))
        (Recommend demo-frame repair-failure) (reasonerInferenceLimits)))
    (((stv 0.0 0.99) (negative-observation)) ((stv 0.0 0.99) (negative-observation))))

!(test (map-atom (nars pln) $engine
    (reasonerInferProposal $engine negative-native demo-frame
        ((Sentence ((Recommend demo-frame repair-failure) (stv 0.0 0.99)) (negative-observation)))
        repair-failure (Expected recovered) (reasonerInferenceLimits))) (() ()))

;; PLN also needs its premise; an implication alone is not an inferred result.
!(test (reasonerInferProposal pln missing-pln demo-frame
    ((Sentence ((Implication (Failed demo-frame) (Recommend demo-frame repair-failure))
        (stv 1.0 0.9)) (rule-1)))
    repair-failure (Expected recovered) (reasonerInferenceLimits)) ())

;; Both real engine results still face the same constitutional rejection.
!(change-state! &constitutional-mode Sleep)
!(test (map-atom ((narsRepairProposal) (plnRepairProposal)) $proposal
    (getStatus (reasonerProposalAdmission (minimalDemoBundle) $proposal))) (Rejected Rejected))
!(change-state! &constitutional-mode Engaged)
!(test (reasonerSourceReliability nars) (get-state &reasoner-validation-reliability))

;; Isolate outcome layout errors using a valid event and inert payloads.
;; Example: (reasonerOutcomeAccessorFixture) has exactly eight ordered tagged fields.
(= (reasonerOutcomeAccessorFixture)
    (let $event (reasonerAccessorTestEvent (reasonerAccessorTestProposal))
        (quote (ReasonerProposalOutcomeEvent (outcome-id (ReasonerOutcomeRef "s" "t"))
            (proposal-event $event) (execution-status Completed)
            (execution-evidence (reasonerAccessorEffect)) (frame-evidence-status Unresolved)
            (frame-state-evidence ()) (outcome Unresolved) (grade Ungraded)))
    )
)

!(test (getProposalOutcomeId (reasonerOutcomeAccessorFixture)) (ReasonerOutcomeRef "s" "t"))

!(test (getProposalOutcomeId (map-atom (0 1 2 3 4 5 6 7) $index
    (index-atom (reasonerOutcomeAccessorFixture) $index)))
    (ReasonerAccessorRejected InvalidProposalOutcome))

!(test (getProposalOutcomeId (concat (reasonerOutcomeAccessorFixture) (extra)))
    (ReasonerAccessorRejected InvalidProposalOutcome))

;; Alter every field tag while retaining the rest of the exact record.
!(test (map-atom (1 2 3 4 5 6 7 8) $changed
    (getProposalOutcomeId (map-atom (0 1 2 3 4 5 6 7 8) $index
        (if (== $index $changed)
            (cons-atom WrongField (cdr-atom (index-atom (reasonerOutcomeAccessorFixture) $index)))
            (index-atom (reasonerOutcomeAccessorFixture) $index)))))
    (map-atom (1 2 3 4 5 6 7 8) $changed (ReasonerAccessorRejected InvalidProposalOutcome)))

!(test (get-state &reasoner-accessor-effects) 0)
!(test (reasonerProposalOutcomes) (get-state &reasoner-validation-outcomes))
!(test (reasonerProposalAssessments) ())
!(test (reasonerSourceReliability nars) (get-state &reasoner-validation-reliability))

;; Translation fixtures supply an admitted publication explicitly; no host getters.
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_contracts))

;; Stable references cover both observation and engine rule evidence.
;; Example: (translationInvocation) -> the unchanged fixture invocation with two refs.
(= (translationInvocation)
    (reasonerContractSet (quote (evidence))
        (quote ((SessionObservationRef "session-1" 0) (SessionObservationRef "session-1" 1)))
        (reasonerContractFixture invocation))
)

;; Assemble a supplied view without consulting global signal or frame state.
;; Example: (translationView () ()) represents no supplied observations or rules.
(= (translationView $signals $native)
    (let $invocation (translationInvocation)
        (quote (ReasonerAdmittedView (invocation $invocation) (signals $signals) (native-facts $native))))
)

;; Preserve explicit boolean polarity and its original observation reference.
;; Example: (translationFailure False) supplies negative failure evidence.
(= (translationFailure $value)
    (quote (FactualSignal (kind failure) (value (BooleanFact $value))
        (provenance ((SessionObservationRef "session-1" 0)))))
)

;; The engine owns implication syntax; translation preserves its truth and stamps.
;; Example: (translationRule nars) uses ==>; PLN uses Implication.
(= (translationRule $engine)
    (let $implication (if (== $engine nars) ==> Implication)
        (quote (ReasonerNativeFact $engine
            (Sentence (($implication (SignalHolds Frame-A failure) (Recommend Frame-A repair-failure))
                (stv 1.0 0.83)) ((SessionObservationRef "session-1" 1))))))
)

;; Extract successful translated facts only for the following offline engine probes.
;; Example: (translationFacts nars False) retains a frequency-zero failure premise.
(= (translationFacts $engine $value)
    (let $result (translateReasonerAdmittedView $engine
        (translationView ((translationFailure $value)) ((translationRule $engine))) 0.72)
        (index-atom (index-atom $result 3) 1))
)

!(test (map-atom (nars pln) $engine
    (translateReasonerAdmittedView $engine (translationView () ()) 0.72))
    ((ReasonerTranslatedFacts (invocation (translationInvocation)) (engine nars) (facts ()))
     (ReasonerTranslatedFacts (invocation (translationInvocation)) (engine pln) (facts ()))))

!(test (car-atom (translationFacts nars False))
    (quote (Sentence ((SignalHolds Frame-A failure) (stv 0 0.72))
        ((SessionObservationRef "session-1" 0)))))

!(test (car-atom (translationFacts pln True))
    (quote (Sentence ((SignalHolds Frame-A failure) (stv 1 0.72))
        ((SessionObservationRef "session-1" 0)))))

!(test (map-atom (nars pln) $engine
    (index-atom (translationFacts $engine True) 1))
    ((index-atom (translationRule nars) 2) (index-atom (translationRule pln) 2)))

;; Actual engines derive recommendations with evidence from the translated view.
!(test (map-atom (nars pln) $engine
    (getProposalEvidence (reasonerInferProposal $engine translated Frame-A
        (translationFacts $engine True) repair-failure prediction (reasonerInferenceLimits))))
    (quote ((EvidenceReferences ((SessionObservationRef "session-1" 0) (SessionObservationRef "session-1" 1)))
            (EvidenceReferences ((SessionObservationRef "session-1" 0) (SessionObservationRef "session-1" 1))))))

;; Negative evidence remains visible in actual queries without becoming positive advice.
!(test (map-atom (nars pln) $engine
    (reasonerQuery $engine (translationFacts $engine False)
        (SignalHolds Frame-A failure) (reasonerInferenceLimits)))
    (quote (((stv 0 0.72) ((SessionObservationRef "session-1" 0)))
            ((stv 0 0.72) ((SessionObservationRef "session-1" 0))))))

!(test (map-atom (nars pln) $engine
    (reasonerInferProposal $engine negative-translated Frame-A
        (translationFacts $engine False) repair-failure prediction (reasonerInferenceLimits))) (() ()))

!(test (map-atom (nars pln) $engine
    (reasonerInferProposal $engine absent-translated Frame-A
        ((index-atom (translationRule $engine) 2)) repair-failure prediction (reasonerInferenceLimits))) (() ()))

;; Native truth values and negative evidence are retained exactly, including both components.
!(test (map-atom (nars pln) $engine
    (let $native (quote (ReasonerNativeFact $engine
        (Sentence (negative-claim (stv 0.12 0.67)) ((SessionObservationRef "session-1" 1)))))
        (let $result (translateReasonerAdmittedView $engine (translationView () ($native)) 0.72)
            (index-atom (index-atom $result 3) 1))))
    (quote (((Sentence (negative-claim (stv 0.12 0.67)) ((SessionObservationRef "session-1" 1))))
            ((Sentence (negative-claim (stv 0.12 0.67)) ((SessionObservationRef "session-1" 1)))))))

;; A classifier score is a reported value, not the probability that its proposition holds.
!(test (let $result (translateReasonerAdmittedView nars
    (translationView (quote ((FactualSignal (kind danger) (value (RatioFact 0.23 classifier-score))
        (provenance ((SessionObservationRef "session-1" 0)))))) ()) 0.72)
    (index-atom (index-atom $result 3) 1))
    (quote ((Sentence ((SignalValue Frame-A danger (RatioFact 0.23 classifier-score)) (stv 1 0.72))
        ((SessionObservationRef "session-1" 0))))))

!(test (let $result (translateReasonerAdmittedView pln
    (translationView (quote ((FactualSignal (kind failure-streak) (value (QuantityFact 2 count))
        (provenance ((SessionObservationRef "session-1" 0)))))) ()) 0.72)
    (index-atom (index-atom $result 3) 1))
    (quote ((Sentence ((SignalValue Frame-A failure-streak (QuantityFact 2 count)) (stv 1 0.72))
        ((SessionObservationRef "session-1" 0))))))

!(test (translateReasonerAdmittedView llm (translationView () ()) 0.72)
    (ReasonerTranslationRejected InvalidAdapter))

!(test (translateReasonerAdmittedView nars (translationView () ()) "0.72")
    (ReasonerTranslationRejected InvalidAdapter))

!(test (translateReasonerAdmittedView nars (quote $unbound) 0.72)
    (ReasonerTranslationRejected InvalidView))

!(test (translateReasonerAdmittedView nars
    (quote (ReasonerAdmittedView (invocation ()) (signals ()) (native-facts ()))) 0.72)
    (ReasonerTranslationRejected InvalidInvocation))

!(test (translateReasonerAdmittedView nars
    (quote (ReasonerAdmittedView (invocation ()) (signals ()) (native-facts ()) (extra value))) 0.72)
    (ReasonerTranslationRejected InvalidView))

!(test (translateReasonerAdmittedView nars
    (translationView ((translationFailure True) (translationFailure False)) ()) 0.72)
    (ReasonerTranslationRejected DuplicateSignalKind))

!(test (translateReasonerAdmittedView nars
    (translationView (quote (NoObservation)) ()) 0.72)
    (ReasonerTranslationRejected InvalidFact))

!(test (translateReasonerAdmittedView nars
    (translationView (quote ((FactualSignal (kind failure) (value (BooleanFact False))
        (provenance ((SessionObservationRef "session-1" 99)))))) ()) 0.72)
    (ReasonerTranslationRejected InvalidFact))

!(test (translateReasonerAdmittedView nars
    (translationView () ((translationRule pln))) 0.72)
    (ReasonerTranslationRejected InvalidFact))

;; Bad native structures, truth values and evidence reject the entire view atomically.
!(test (map-atom (quote (
    (ReasonerNativeFact nars (Sentence (claim (stv 0.2 "0.9")) ((SessionObservationRef "session-1" 1))))
    (ReasonerNativeFact nars (Sentence (claim (stv 1.1 0.9)) ((SessionObservationRef "session-1" 1))))
    (ReasonerNativeFact nars (Sentence (claim (stv 1 0.9)) ()))
    (ReasonerNativeFact nars (Sentence (claim (stv 1 0.9)) ((SessionObservationRef "other" 1))))
    (ReasonerNativeFact nars (Sentence (claim (stv 1 0.9)) ((SessionObservationRef "session-1" 1) (SessionObservationRef "session-1" 1))))
    (ReasonerNativeFact nars (Sentence (claim (stv 1 0.9)) ((SessionObservationRef "session-1" 1))) extra)
    )) $native
    (translateReasonerAdmittedView nars (translationView ((translationFailure True)) ($native)) 0.72))
    ((ReasonerTranslationRejected InvalidFact) (ReasonerTranslationRejected InvalidFact)
     (ReasonerTranslationRejected InvalidFact) (ReasonerTranslationRejected InvalidFact)
     (ReasonerTranslationRejected InvalidFact) (ReasonerTranslationRejected InvalidFact)))

;; Actual invocation ceilings apply before any engine is called.
!(test (translateReasonerAdmittedView nars
    (reasonerContractSet (quote (invocation limits max-facts)) 1
        (translationView ((translationFailure True)) ((translationRule nars)))) 0.72)
    (ReasonerTranslationRejected PayloadLimit))

!(test (translateReasonerAdmittedView nars
    (reasonerContractSet (quote (invocation limits max-payload-nodes)) 1
        (translationView ((translationFailure True)) ())) 0.72)
    (ReasonerTranslationRejected PayloadLimit))

!(test (translateReasonerAdmittedView nars (translationView malformed ()) 0.72)
    (ReasonerTranslationRejected PayloadLimit))

;; Snapshot translation is unchanged when mutable host/signal state changes afterwards.
!(bind! &translation-retained-view (new-state
    (translationView ((translationFailure False)) ((translationRule nars)))))
!(bind! &translation-retained-result (new-state
    (translateReasonerAdmittedView nars (get-state &translation-retained-view) 0.72)))
!(bind! &translation-original-bundle (new-state (activeFrameBundle)))
!(setActiveFrameBundle (quote (not-the-published-view)))
!(clearSignals)
!(test (translateReasonerAdmittedView nars (get-state &translation-retained-view) 0.72)
    (get-state &translation-retained-result))
!(setActiveFrameBundle (get-state &translation-original-bundle))

;; Even executable-looking native terms are inert while translating.
!(bind! &translation-sentinel (new-state preserved))
!(test (let $native (quote (ReasonerNativeFact nars
    (Sentence ((change-state! &translation-sentinel changed) (stv 0.2 0.6))
        ((SessionObservationRef "session-1" 1)))))
    (let $result (translateReasonerAdmittedView nars (translationView () ($native)) 0.72)
        (index-atom (index-atom $result 3) 1)))
    (quote ((Sentence ((change-state! &translation-sentinel changed) (stv 0.2 0.6))
        ((SessionObservationRef "session-1" 1))))))

!(test (get-state &translation-sentinel) preserved)
