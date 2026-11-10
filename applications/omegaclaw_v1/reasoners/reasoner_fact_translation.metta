;; Pure optional adapter translation. The caller supplies an already admitted view;
;; no frame getters, observation resolution, providers or mutable stores are used.
;; Requires host_reasoner_contracts, or its definitions with prerequisites already
;; loaded by the inference extension. Leaves do not reimport shared dependencies.

(: ReasonerAdmittedViewType Type)
(: ReasonerAdmittedView (-> Expression Expression Expression ReasonerAdmittedViewType))
(: ReasonerNativeFactType Type)
(: ReasonerNativeFact (-> Symbol Expression ReasonerNativeFactType))
(: ReasonerTranslatedFactsType Type)
(: ReasonerTranslatedFacts (-> Expression Expression Expression ReasonerTranslatedFactsType))
(: ReasonerTranslationResultType Type)
(: ReasonerTranslationRejected (-> Symbol ReasonerTranslationResultType))
(: ReasonerSignalTermType Type)
(: SignalHolds (-> Expression Symbol ReasonerSignalTermType))
(: SignalValue (-> Expression Symbol Expression ReasonerSignalTermType))
(: ReasonerSentenceType Type)
(: Sentence (-> Expression Expression ReasonerSentenceType))
(: ReasonerTruthType Type)
(: stv (-> Number Number ReasonerTruthType))

;; A supplied fact may cite only references included in this admitted invocation.
;; Example: an absent reference rejects rather than being resolved from host state.
(= (reasonerAdmittedReferences $invocation $references)
    (and (mrcItems reference $references 128 True ())
        (and (!= $references ())
            (== (filter-atom $references $ref
                (not (tpContains (mrcValue $invocation 13) $ref))) ())))
)

;; Native truth components, terms and stamps are validated but never rewritten.
;; Example: (ReasonerNativeFact pln (Sentence (claim (stv 0 0.7)) refs)) retains negative support.
(= (reasonerNativeFactValid $engine $invocation $record)
    (case $record (
        ((ReasonerNativeFact $source (Sentence ($term (stv $value $confidence)) $references))
            (tpAllTrue (
                (== $source $engine)
                (reasonerProposalPayloadValid $term)
                (fsNumberIn $value 0 1)
                (fsNumberIn $confidence 0 1)
                (reasonerAdmittedReferences $invocation $references)
            )))
        ($_ False)
    ))
)

;; Validate each typed observation against the existing registry and supplied references.
;; Example: explicit BooleanFact False is valid; NoObservation is not an asserted fact.
(= (reasonerAdmittedSignalValid $invocation $record)
    (case (validateFactualSignal $record) (
        ((FactualSignalValid $_ $_ $_)
            (reasonerAdmittedReferences $invocation (factualSignalField provenance $record)))
        ($_ False)
    ))
)

;; Reject duplicate kinds instead of selecting or silently revising one observation.
;; Example: two failure records, even identical, require host adjudication first.
(= (reasonerAdmittedSignalsUnique $signals)
    (== (filter-atom $signals $record
        (!= (size-atom (filter-atom $signals $other
            (== (factualSignalField kind $record) (factualSignalField kind $other)))) 1)) ())
)

;; Check payload bounds before mapping, using the invocation's configured ceilings.
;; Example: zero max-facts accepts an empty view and rejects one supplied premise.
(= (reasonerAdmittedPayloadBounded $invocation $signals $native)
    (if (and (== (get-metatype $signals) Expression) (== (get-metatype $native) Expression))
        (let $limits (mrcValue $invocation 12)
            (and (<= (+ (size-atom $signals) (size-atom $native)) (mrcValue $limits 1))
                (>= (reasonerProposalDataRemaining (quote ($signals $native)) 16
                    (mrcValue $limits 2)) 0)))
        False
    )
)

;; Boolean polarity is explicit; numerical observations retain their typed value/unit.
;; Confidence is an explicit adapter encoding parameter, never a classifier score.
;; Example: BooleanFact False -> (Sentence ((SignalHolds frame failure) (stv 0 confidence)) refs).
(= (reasonerSignalSentence $frame $confidence $record)
    (let (FactualSignal (kind $kind) (value $value) (provenance $references)) $record
        (case $value (
            ((BooleanFact $boolean)
                (let $frequency (if (== $boolean True) 1 0)
                    (quote (Sentence ((SignalHolds $frame $kind) (stv $frequency $confidence)) $references))))
            ($_ (quote (Sentence ((SignalValue $frame $kind $value) (stv 1 $confidence)) $references)))
        ))
    )
)

;; Translation inspects only validated supplied data; native facts stay engine-specific.
;; Example: missing failure emits no SignalHolds premise, while False emits frequency zero.
(= (reasonerTranslateValidatedView $engine $invocation $signals $native $confidence)
    (if (reasonerAdmittedPayloadBounded $invocation $signals $native)
        (if (tpAllTrue (
                (== (filter-atom $signals $record
                    (not (reasonerAdmittedSignalValid $invocation $record))) ())
                (== (filter-atom $native $record
                    (not (reasonerNativeFactValid $engine $invocation $record))) ())
            ))
            (if (reasonerAdmittedSignalsUnique $signals)
                (let* (
                    ($frame (mrcValue $invocation 7))
                    ($observations (map-atom $signals $record
                        (reasonerSignalSentence $frame $confidence $record)))
                    ($sentences (map-atom $native $record (index-atom $record 2)))
                    ($facts (append $observations $sentences))
                )
                    (quote (ReasonerTranslatedFacts (invocation $invocation) (engine $engine) (facts $facts))))
                (ReasonerTranslationRejected DuplicateSignalKind))
            (ReasonerTranslationRejected InvalidFact))
        (ReasonerTranslationRejected PayloadLimit)
    )
)

;; Representation validation is not evidence authentication or runtime intake permission.
;; Example: (translateReasonerAdmittedView nars () 0.9) -> InvalidView rejection.
(= (translateReasonerAdmittedView $engine $view $confidence)
    (if (and (fsContains (nars pln) $engine) (fsNumberIn $confidence 0 1))
        (if (is-ground $view)
            (case $view (
                ((ReasonerAdmittedView (invocation $invocation) (signals $signals) (native-facts $native))
                    (case (validateReasonerInvocation $invocation) (
                        ((ReasonerContractValid ReasonerInvocation 1)
                            (reasonerTranslateValidatedView $engine $invocation $signals $native $confidence))
                        ($_ (ReasonerTranslationRejected InvalidInvocation))
                    )))
                ($_ (ReasonerTranslationRejected InvalidView))
            ))
            (ReasonerTranslationRejected InvalidView))
        (ReasonerTranslationRejected InvalidAdapter)
    )
)
