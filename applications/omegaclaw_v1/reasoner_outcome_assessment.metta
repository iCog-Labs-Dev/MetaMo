;; Optional host assessment/learning service. Load reasoner_proposals once first.
;; Motivational admission and execution-receipt recording never invoke this module.
;; Example: (assessReasonerProposalOutcome EVENT EXECUTION-EVIDENCE).
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
