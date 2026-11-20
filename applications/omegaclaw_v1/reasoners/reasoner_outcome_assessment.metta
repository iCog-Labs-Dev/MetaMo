;; Optional host assessment/learning service. Load reasoner_proposals once first.
;; Motivational admission and execution-receipt recording never invoke this module.
;; Coordinator assessments are explicit comparisons without source/native learning.
;; Example: (assessReasonerProposalOutcome EVENT EXECUTION-EVIDENCE).
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_comparators))
!(import! &self (library MetaMo applications/omegaclaw_v1/trace))
(: ExpectedOperationResultType Type)
(: ExpectedOperationResult (-> Expression ExpectedOperationResultType))
(: ReasonerPredictionObservationType Type)
(: ReasonerPredictionObservation
    (-> Expression Expression Expression Expression Expression ReasonerPredictionObservationType))
(: ReasonerPredictionComparisonType Type)
(: ReasonerPredictionComparison (-> Symbol Expression ReasonerPredictionComparisonType))
(: ReasonerProposalAssessmentType Type)
(: ReasonerProposalAssessment
    (-> Expression Expression Expression Expression Expression Expression Expression
        ReasonerProposalAssessmentType))
(: ReasonerAssessmentResultType Type)
(: ReasonerAssessmentRejected (-> Symbol ReasonerAssessmentResultType))
(: ReasonerAssessmentDeferred (-> Symbol ReasonerAssessmentResultType))

!(bind! &reasoner-proposal-assessments (new-space))
;; Trusted host configuration may install another comparator for its own syntax.
!(bind! &reasoner-prediction-comparator (new-state compareReasonerOperationResult))

;; Compare exact declared operation payloads as data, without interpreting text.
;; Example: (compareReasonerOperationResult (ExpectedOperationResult "x") "x") -> confirmed.
(= (compareReasonerOperationResult $prediction $observation)
    (case $prediction
        (
            ((ExpectedOperationResult $expected)
                (if (== $expected $observation)
                    (ReasonerPredictionComparison Confirmed 1.0)
                    (ReasonerPredictionComparison Refuted 0.0)
                )
            )
            ($_ (ReasonerPredictionComparison Unresolved Ungraded))
        )
    )
)

;; Require an exact ground comparison and a finite numerical grade in [0,1].
;; Example: (reasonerComparisonValid (ReasonerPredictionComparison Confirmed "1")) -> False.
(= (reasonerComparisonValid $comparison)
    (if (is-ground $comparison)
        (case $comparison
            (
                ((ReasonerPredictionComparison Unresolved Ungraded) True)
                ((ReasonerPredictionComparison $conclusion $grade)
                    (and (or (== $conclusion Confirmed) (== $conclusion Refuted))
                        (reasonerProposalConfidenceValid $grade)))
                ($_ False)
            )
        )
        False
    )
)

;; External source weighting policy, distinct from native reasoner truth revision.
;; Example: (reasonerSourceReliabilityAfterGrade nars 1.0) uses a 20% update step.
(= (reasonerSourceReliabilityAfterGrade $source $grade)
    (+ (* 0.80 (reasonerSourceReliability $source)) (* 0.20 $grade))
)

;; Only a finite grade and a valid existing reliability permit an update.
;; This is an internal learner; the assessment boundary supplies validated grades.
;; Example: (updateReasonerSourceReliability nars Ungraded) -> InvalidGrade rejection.
(= (updateReasonerSourceReliability $source $grade)
    (if (and (reasonerProposalSourceValid $source) (reasonerProposalConfidenceValid $grade))
        (if (reasonerProposalConfidenceValid (reasonerSourceReliability $source))
            (writeReasonerSourceReliability $source $grade)
            (ReasonerAssessmentRejected InvalidReliability)
        )
        (ReasonerAssessmentRejected InvalidGrade)
    )
)

;; Replace the source row only after the external learner validates both numbers.
;; Example: writeReasonerSourceReliability is used inside the assessment transaction.
(= (writeReasonerSourceReliability $source $grade)
    (let*
        (
            ($rows (collapse (match &reasoner-source-reliability
                (ReasonerSourceReliability $source $old) (ReasonerSourceReliability $source $old))))
            ($new (reasonerSourceReliabilityAfterGrade $source $grade))
            ($_ (map-atom $rows $row (remove-atom &reasoner-source-reliability $row)))
            ($_ (add-atom &reasoner-source-reliability (ReasonerSourceReliability $source $new)))
        )
        $new
    )
)

;; Query retained assessments without recomputing comparisons or applying learning.
;; Example: (reasonerProposalAssessments) returns () before the first assessment.
(= (reasonerProposalAssessments)
    (collapse (match &reasoner-proposal-assessments
        (ReasonerProposalAssessment $id $event $prediction $observation $execution $comparator $comparison)
        (ReasonerProposalAssessment $id $event $prediction $observation $execution $comparator $comparison)))
)

;; Resolve trusted observations first; supplied proposal/execution records stay data.
;; Example: absent host wiring returns MissingHostEvidence without calling a comparator.
(= (reasonerAssessmentObservation $event $execution)
    (case (get-state &reasoner-prediction-observer)
        (
            (() (ReasonerOutcomeRejected MissingHostEvidence))
            ($reader (eval ($reader (quote $event) (quote $execution))))
        )
    )
)

;; One assessment per stable outcome; a changed comparator cannot regrade replay.
;; Example: an identical delivery returns the retained assessment and skips learning.
(= (reasonerAssessObservation $observation)
    (let (ReasonerPredictionObservation $id $event $prediction $actual $execution) $observation
        (case (collapse (match &reasoner-proposal-assessments
            (ReasonerProposalAssessment (outcome-id $id) $e $p $a $x $c $r)
            (ReasonerProposalAssessment (outcome-id $id) $e $p $a $x $c $r)))
            (
                (() (reasonerCompareObservation $observation))
                (($retained) (reasonerAssessmentReplay $observation $retained))
                ($_ (ReasonerAssessmentRejected ConflictingAssessment))
            )
        )
    )
)

;; Require the original event, prediction and observation on assessment redelivery.
;; Example: another event with a reused identity returns ConflictingAssessment.
(= (reasonerAssessmentReplay $observation $retained)
    (case $retained
        (
            ((ReasonerProposalAssessment (outcome-id $id) (proposal-event $event)
                (prediction $prediction) (observation $actual) (execution-evidence $execution)
                (comparator $comparator) (comparison $comparison))
                (if (== $observation
                        (quote (ReasonerPredictionObservation $id $event $prediction $actual $execution)))
                    $retained
                    (ReasonerAssessmentRejected ConflictingAssessment)
                )
            )
            ($_ (ReasonerAssessmentRejected ConflictingAssessment))
        )
    )
)

;; Invoke the configured comparator on quoted retained data, then validate its result.
;; Example: unsupported prediction syntax stays deferred and can be assessed later.
(= (reasonerCompareObservation $observation)
    (let*
        (
            ((ReasonerPredictionObservation $id $event $prediction $actual $execution) $observation)
            ($comparator (get-state &reasoner-prediction-comparator))
            ($comparison (catch (eval ($comparator (quote $prediction) (quote $actual)))))
        )
        (if (reasonerComparisonValid $comparison)
            (case $comparison
                (
                    ((ReasonerPredictionComparison Unresolved Ungraded)
                        (ReasonerAssessmentDeferred InsufficientEvidence))
                    ($_ (commitReasonerAssessment $observation $comparator $comparison))
                )
            )
            (ReasonerAssessmentRejected InvalidComparison)
        )
    )
)

;; Validate the learner before appending; the surrounding transaction rolls back errors.
;; Example: invalid source reliability rejects without storing an assessment marker.
(= (writeReasonerAssessment $observation $comparator $comparison)
    (let*
        (
            ((ReasonerPredictionObservation $id $event $prediction $actual $execution) $observation)
            ((ReasonerPredictionComparison $conclusion $grade) $comparison)
            ($source (getProposalSource (getProposalEventProposal $event)))
            ($learned (updateReasonerSourceReliability $source $grade))
        )
        (case $learned
            (
                ((ReasonerAssessmentRejected $reason) (ReasonerAssessmentRejected $reason))
                ($_ (let $record (ReasonerProposalAssessment (outcome-id $id)
                        (proposal-event $event) (prediction $prediction) (observation $actual)
                        (execution-evidence $execution) (comparator $comparator) (comparison $comparison))
                    (progn (add-atom &reasoner-proposal-assessments $record) $record)))
            )
        )
    )
)

;; Audit insertion and learning are atomic and share the execution ledger's mutex.
;; Example: a write exception yields AssessmentCommitFailed and leaves both spaces intact.
(= (commitReasonerAssessment $observation $comparator $comparison)
    (case (catch (transaction (writeReasonerAssessment $observation $comparator $comparison)))
        (
            ((Error $reason $context) (ReasonerAssessmentRejected AssessmentCommitFailed))
            ((Error $reason) (ReasonerAssessmentRejected AssessmentCommitFailed))
            ($result $result)
        )
    )
)

;; Host-only entry: retained prediction + host receipt -> comparison -> validated learning.
;; Example: (assessReasonerProposalOutcome EVENT (ReasonerExecutionEvidence TICKET)).
(= (assessReasonerProposalOutcome $event $execution)
    (if (is-ground ($event $execution))
        (with_mutex omegaclaw_dispatch
            (case (reasonerAssessmentObservation $event $execution)
                (
                    ((ReasonerPredictionObservation $id $retained $prediction $actual $evidence)
                        (if (and (== ($retained $evidence) (quote ($event $execution)))
                                (== $prediction (getProposalPrediction (getProposalEventProposal $event))))
                            (reasonerAssessObservation
                                (ReasonerPredictionObservation $id $retained $prediction $actual $evidence))
                            (ReasonerAssessmentRejected InvalidHostEvidence)
                        )
                    )
                    ((ReasonerOutcomeRejected $reason) (ReasonerAssessmentRejected $reason))
                    ($_ (ReasonerAssessmentRejected InvalidHostEvidence))
                )
            )
        )
        (ReasonerAssessmentRejected MalformedEvidence)
    )
)

(: HostReasonerAssessmentType Type)
(: HostReasonerAssessment (-> Expression Expression Expression Expression HostReasonerAssessmentType))
!(bind! &host-reasoner-assessments (new-state ()))

;; Query explicit coordinator assessments; receipt capture never calls a comparator.
;; Example: (hostReasonerAssessments) is () after dispatch until assessment is requested.
(= (hostReasonerAssessments) (get-state &host-reasoner-assessments))

;; Assess only the exact pre-dispatch primary against its captured execution receipt.
;; Example: rejected/unselected alternatives remain ungraded without independent evidence.
(= (assessHostReasonerProposalOutcome $envelope $id)
    (let $result (assessHostReasonerProposalOutcomeRetained $envelope $id)
        (progn (flushMetaMoTrace) $result)))

;; Finish emission only after retained assessment has released its dispatch lock.
;; Example: disabled assessment returns its original deferred result without comparison.
(= (assessHostReasonerProposalOutcomeRetained $envelope $id)
    (case (catch (hostReasonerStageEnabledFor (mrcValue (mrcValue $envelope 2) 2) assessment)) (
        (True (assessEnabledHostReasonerProposalOutcome $envelope $id))
        ($_ (ReasonerAssessmentDeferred AssessmentDisabled))))
)

;; Receipt comparison is independent of learning even when both switches are enabled.
;; Example: a shadow assessment never calls updateReasonerSourceReliability.
(= (assessEnabledHostReasonerProposalOutcome $envelope $id)
    (case (catch (hostReasonerReceiptFor $id)) (
        ((HostReasonerReceipt $id
            (HostReasonerSelection $_ $_ $decision (HostReasonerPrimary $primary $_ $_))
            (OperationOutcome $decision $_ $status (DispatchResult Executed Feasible $actual)))
            (if (!= $envelope $primary) (ReasonerAssessmentDeferred NoObservedAlternative)
                (if (or (== $status Success) (== $status Failure))
                    (assessHostReasonerObservation $id $envelope $actual)
                    (ReasonerAssessmentDeferred InsufficientEvidence))))
        ((HostReasonerReceipt $_ $_ $_) (ReasonerAssessmentDeferred InsufficientEvidence))
        ($_ (ReasonerAssessmentRejected MissingReceipt))))
)

;; Compare outside the callback and mutex; replay uses the original retained comparison.
;; Example: unsupported schemas stay deferred, with no reliability or engine update.
(= (assessHostReasonerObservation $id $envelope $actual)
    (let $prior (filter-atom (hostReasonerAssessments) $row (== (index-atom $row 1) $id))
        (case $prior (
            (($record) $record)
            (() (let $comparator (hostReasonerPredictionComparator $envelope)
                (if (== $comparator ()) (ReasonerAssessmentDeferred UnsupportedPrediction)
                    (let* (
                        ($prediction (getProposalPrediction (mrcValue $envelope 4)))
                        ($timeout (mrcValue (mrcValue (mrcValue $envelope 2) 12) 9))
                        ($comparison (reasonerRuntimeCall $timeout (mrcValue $comparator 5) ($prediction $actual)))
                    )
                        (if (reasonerComparisonValid $comparison)
                            (case $comparison (
                                ((ReasonerPredictionComparison Unresolved Ungraded)
                                    (ReasonerAssessmentDeferred InsufficientEvidence))
                                ($_ (retainHostReasonerAssessment $id $envelope $comparator $comparison))))
                            (ReasonerAssessmentRejected InvalidComparison))))))
            ($_ (ReasonerAssessmentRejected ConflictingAssessment)))))
)

;; Append bounded immutable grades separately; this path deliberately performs no learning.
;; Example: an identical delivery returns the same assessment without another write.
(= (retainHostReasonerAssessment $id $envelope $comparator $comparison)
    (with_mutex omegaclaw_dispatch
        (let* (
            ($row (quote (HostReasonerAssessment $id $envelope $comparator $comparison)))
            ($prior (filter-atom (hostReasonerAssessments) $entry (== (index-atom $entry 1) $id)))
            ($limits (mrcValue (mrcValue $envelope 2) 12))
        )
            (case $prior (
                (() (if (and (< (size-atom (hostReasonerAssessments)) (mrcValue $limits 4))
                        (>= (reasonerProposalDataRemaining (quote $row) 32 (* 2 (mrcValue $limits 2))) 0))
                    (appendHostReasonerAssessment $row)
                    (ReasonerAssessmentRejected AuditLimit)))
                (($retained) (if (== $retained $row) $retained (ReasonerAssessmentRejected ConflictingAssessment)))
                ($_ (ReasonerAssessmentRejected ConflictingAssessment)))))
    )
)

;; A separate append call prevents PeTTa from prebinding rejection results to the candidate.
;; Example: (appendHostReasonerAssessment VALIDATED-ROW) returns that row.
(= (appendHostReasonerAssessment $row)
    (progn (change-state! &host-reasoner-assessments
        (cons-atom $row (hostReasonerAssessments)))
        (case (hostReasonerReceiptFor (index-atom $row 1)) (
            ((HostReasonerReceipt $_ $_ (OperationOutcome $decision $_ $_ $_))
                (collapse (catch (recordAssessmentTrace $row $decision
                    (mrcValue (mrcValue (index-atom $row 2) 2) 1)
                    (getProposalId (mrcValue (index-atom $row 2) 4))))))
            ($_ True))) $row)
)

(: HostReasonerLearningType Type)
(: HostReasonerLearning (-> Expression Expression Number Number HostReasonerLearningType))
(: HostReasonerLearningCommitted (-> Expression HostReasonerLearningType))
!(bind! &host-reasoner-learning (new-state ()))

;; Learning has its own audit and explicit entry point; assessment remains a preview.
;; Example: (hostReasonerLearning) stays () during pure shadow evaluation.
(= (hostReasonerLearning) (get-state &host-reasoner-learning))

;; Learn only from a retained validated grade, never a caller-supplied comparison.
;; Example: (learnHostReasonerOutcome OUTCOME-REF) is disabled unless explicitly configured.
(= (learnHostReasonerOutcome $id)
    (let $rows (filter-atom (hostReasonerAssessments) $row (== (index-atom $row 1) $id))
        (case $rows (
            (($assessment) (let $invocation (mrcValue (index-atom $assessment 2) 2)
                (if (hostReasonerStageEnabledFor (mrcValue $invocation 2) learning)
                    (commitHostReasonerLearning $assessment $invocation)
                    (ReasonerAssessmentDeferred LearningDisabled))))
            ($_ (ReasonerAssessmentDeferred MissingAssessment)))))
)

;; Reserve one learning update before adapter feedback, keeping engine calls outside locks.
;; Example: identical delivery returns its original learning record without another callback.
(= (commitHostReasonerLearning $assessment $invocation)
    (case (catch (with_mutex omegaclaw_dispatch
            (transaction (writeHostReasonerLearning $assessment $invocation)))) (
        ((HostReasonerLearningCommitted $record)
            (progn (notifyHostReasoner Assessment $invocation $assessment) $record))
        ($result $result)))
)

;; Recheck identity under the commit mutex, including concurrent duplicate deliveries.
;; Example: only the first writer receives the committed marker and sends feedback.
(= (writeHostReasonerLearning $assessment $invocation)
    (let $prior (filter-atom (hostReasonerLearning) $row (== (index-atom $row 1) (index-atom $assessment 1)))
        (case $prior (
            (($record) (if (== (index-atom $record 2) $assessment) $record
                (ReasonerAssessmentRejected ConflictingLearning)))
            (() (writeNewHostReasonerLearning $assessment $invocation))
            ($_ (ReasonerAssessmentRejected ConflictingLearning)))))
)

;; Source weighting uses the existing learner; native engine revision belongs to adapters.
;; Example: invalid reliability rejects without a marker, update or feedback.
(= (writeNewHostReasonerLearning $assessment $invocation)
    (let* (
        ((HostReasonerAssessment $id $envelope $_ $comparison) $assessment)
        ((ReasonerPredictionComparison $_ $grade) $comparison)
        ($source (getProposalSource (mrcValue $envelope 4)))
        ($before (reasonerSourceReliability $source))
        ($limits (mrcValue $invocation 12))
        ($audit (quote (HostReasonerLearning $id $assessment $before 0)))
    )
        (if (and (< (size-atom (hostReasonerLearning)) (mrcValue $limits 4))
                (>= (reasonerProposalDataRemaining (quote $audit) 32 (* 2 (mrcValue $limits 2))) 0))
            (case (updateReasonerSourceReliability $source $grade) (
                ((ReasonerAssessmentRejected $reason) (ReasonerAssessmentRejected $reason))
                ($after (let $record (HostReasonerLearning $id $assessment $before $after)
                    (progn (change-state! &host-reasoner-learning
                        (cons-atom $record (hostReasonerLearning))) (HostReasonerLearningCommitted $record))))))
            (ReasonerAssessmentRejected AuditLimit)))
)
