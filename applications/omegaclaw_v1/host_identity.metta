;; Trusted host publication and causal linkage. Deliberately opt-in: loading
;; this module does not open a ledger, publish runtime records or grant skills.
;; Host mutations/capture/invocation must be serialized by the host dispatcher.
;; Python supplies UUID allocation and durable opaque storage only.
!(import! &self (library MetaMo applications/omegaclaw_v1/contracts))
!(import! &self (library MetaMo applications/omegaclaw_v1/identity_store.py))

(= (identityReject $reason) (ContractRejection $reason None None None))
(= (identityOK $value)
   (case $value (((ContractRejection $r $s $v $ref) False) (() False) ($_ True))))
;; Higher-order, fail-closed traversal. A predicate receives shared context and
;; one item. Only literal True passes; unresolved expressions never do.
(= (identityEvery $predicate $context $items)
   (if (== $items ()) True
       (let ($head $tail) (decons-atom $items)
          (if (== (eval ($predicate (quote $context) (quote $head))) True)
              (identityEvery $predicate $context $tail) False))))
(= (identityCheck $_ $check) (== (eval $check) True))
(= (identityAll $checks) (identityEvery identityCheck () $checks))
(= (identityNatural $value)
   (if (== (get-type $value) Number)
       (== (catch (identityAll ((>= $value 0) (== (% $value 1) 0)))) True) False))
;; Construct tagged data without invoking a same-named PeTTa function (id).
(= (identityPair $key $value) (cons-atom $key (cons-atom $value ())))
(= (identityMember $value $rows)
   (if (== $rows ()) False
       (let ($head $tail) (decons-atom $rows)
          (if (== $head $value) True (identityMember $value $tail)))))
(= (identityAppend $a $b)
   (if (== $a ()) $b
       (let ($head $tail) (decons-atom $a)
          (cons-atom $head (identityAppend $tail $b)))))
(= (identityFields $fields $key)
   (if (== $fields ()) None
       (let ($head $tail) (decons-atom $fields)
          (case $head (
             (($name $value) (if (== $name $key) $value (identityFields $tail $key)))
             ($_ (identityFields $tail $key)))))))
(= (identityField $record $key)
   (case $record ((None None) (() None) ((ContractRejection $r $s $v $ref) None)
      ($_ (let ($tag $fields) (decons-atom $record) (identityFields $fields $key))))))
(= (identityFind $rows $key $value)
   (if (== $rows ()) None
       (let ($head $tail) (decons-atom $rows)
          (if (== (identityField $head $key) $value) $head
              (identityFind $tail $key $value)))))

;; Empty expected-host creates a new lineage and refuses existing data.
;; Ordinary restart supplies the previously recorded host string. Backup restore
;; or fork must create a fresh ledger/lineage; never resume a rolled-back image.
(= (identityOpen $path $expectedHost)
   (sread (py-call (identity_store.open_ledger $path $expectedHost))))
(= (identityClose) (let $_ (py-call (identity_store.close_ledger)) True))
(= (identityProducer $role) (sread (py-call (identity_store.producer (repr $role)))))
(= (identityAllocate $role $kind $cause)
   (sread (py-call (identity_store.reserve (repr $role) (repr $kind) $cause))))
(= (identityRead $kind $host $id $revision)
   (sread (py-call (identity_store.resolve (repr $kind) $host $id $revision))))
(= (identityWrite $kind $host $id $revision $data $entity)
   (sread (py-call (identity_store.commit (repr $kind) $host $id $revision (repr $data)
      (if $entity "entity" "record")))))
(= (identityEntityKind $kind)
   (identityMember $kind (FrameRef RelationRef BudgetRef ConstraintsRef HostPolicyRef)))

;; Preserve native frame/root IDs verbatim. Retained versions never disappear;
;; adopting an existing revision is allowed, later versions advance by one.
(= (identityAdoptEntity $kind $id $revision $data)
   (if (identityEntityKind $kind)
       (let $host (identityProducer host)
          (if (identityOK $host)
              (identityWrite $kind $host $id (repr $revision)
                 (IdentityEntity ($kind $host $id $revision) $data) True)
              $host))
       (identityReject MalformedRecord)))
(= (identityResolve $kind $ref)
   (case $ref (
      ((RecordRef $producer $id)
       (if (identityMember $kind (FrameStateBundle MetaMoPolicyOutput AttentionDirective
               ReasonerMotivationalProposal ExecutionOutcome FrameVerificationEvidence))
           (identityRead $kind $producer $id "") (identityReject MalformedRecord)))
      (($tag $host $id)
       (if (identityAll ((== $kind $tag)
                  (identityMember $tag (DispatchRef ExecutionRef ObservationRef))))
           (if (== $host (identityProducer host)) (identityRead $kind $host $id "")
               (identityReject MissingReference)) (identityReject MalformedRecord)))
      (($tag $host $id $rev)
       (if (identityAll ((== $tag $kind)
                  (identityEntityKind $kind)))
           (if (== $host (identityProducer host)) (identityRead $kind $host $id (repr $rev))
               (identityReject MissingReference)) (identityReject MalformedRecord)))
      ($_ (identityReject MalformedRecord)))))
(= (identitySnapshotPayload $context)
   (case $context (
      ((SnapshotRef $host $id $stateRev $policyRev)
       (if (== $host (identityProducer host))
           (let $record (identityResolve FrameStateBundle (RecordRef $host $id))
              (if (identityOK $record)
                  (if (== (identityField $record context) $context) (identityField $record payload)
                      (identityReject StaleSnapshot)) $record))
           (identityReject MissingReference)))
      ($_ (identityReject MalformedRecord)))))
(= (identityLinked $kind $ref $context)
   (let $record (identityResolve $kind $ref)
      (if (identityOK $record)
          (if (== (identityField $record context) $context) (identityField $record payload)
              (identityReject MalformedRecord)) $record)))

(= (identityFrameRows $snapshot)
   (let* (($root (identityField $snapshot root)) ($current (identityField $snapshot current))
          ($index (identityField $snapshot index))
          ($rows (identityAppend (identityField $index active) (identityField $index completed))))
      (cons-atom $root (if (== $current None) $rows (cons-atom $current $rows)))))
(= (identityFrameIn $snapshot $id)
   (let $row (identityFind (identityFrameRows $snapshot) id $id)
      (if (== $row None) (identityReject MissingReference)
          (FrameRef (identityProducer host) $id (identityField $row revision)))))
(= (identityFrameAt $context $id)
   (let $snapshot (identitySnapshotPayload $context)
      (if (identityOK $snapshot) (identityFrameIn $snapshot $id) $snapshot)))
(= (identityFrameRowsValid $snapshot $rows)
   (identityEvery identityFrameRowValid $snapshot $rows))
(= (identityFrameRowValid $snapshot $row)
   (let* (($id (identityField $row id))
          ($ref (FrameRef (identityProducer host) $id (identityField $row revision))))
      (identityAll (
         (== (identityFrameIn $snapshot $id) $ref)
         (identityOK (identityResolve FrameRef $ref))))))
(= (identityRelationIn $snapshot $ref)
   (case $ref (
      ((RelationRef $host $id $rev)
       (let* (($row (identityFind (identityField $snapshot relations) id $id))
              ($stored (identityResolve RelationRef $ref)))
          (if (identityAll ((!= $row None)
                  (== (identityField $row revision) $rev)))
              (if (identityOK $stored)
                  (if (== $stored (IdentityEntity $ref $row)) $row (identityReject IdentityConflict)) $stored)
              (identityReject MissingReference))))
      ($_ (identityReject MalformedRecord)))))
(= (identityRelationsValid $snapshot $rows)
   (identityEvery identityRelationValid $snapshot $rows))
(= (identityRelationValid $snapshot $row)
   (let $ref (RelationRef (identityProducer host) (identityField $row id) (identityField $row revision))
      (identityAll (
         (== (identityRelationIn $snapshot $ref) $row)
         (identityOK (identityFrameIn $snapshot (identityField $row source-frame)))
         (identityOK (identityFrameIn $snapshot (identityField $row target-frame)))))))
(= (identityPolicyRefsValid $data)
   (case $data (
      ((BudgetRef $h $id $r) (identityOK (identityResolve BudgetRef $data)))
      ((ConstraintsRef $h $id $r) (identityOK (identityResolve ConstraintsRef $data)))
      ((HostPolicyRef $h $id $r) (identityOK (identityResolve HostPolicyRef $data)))
      (() True)
      ($_ (if (== (get-metatype $data) Expression)
          (let ($head $tail) (decons-atom $data)
             (identityAll ((identityPolicyRefsValid $head)
                  (identityPolicyRefsValid $tail)))) True)))))

(= (identitySnapshotLinks $payload)
   (let* (($current (identityField $payload current)) ($parent (identityField $current parent)))
      (identityAll ((identityFrameRowsValid $payload (identityFrameRows $payload))
                  (if (== $parent None) True (identityOK (identityFrameIn $payload $parent)))
                  (identityRelationsValid $payload (identityField $payload relations))
                  (identityPolicyRefsValid $payload)
                  (identityAdmittedObservations $payload
                     (identityField (identityField $payload runtime) task-execution-observed))))))

(= (identitySaveRecord $record)
   (case (integrationValidateRecord $record) (
      ((ContractValid $schema 1)
       (let (IntegrationRecord $_ (record-id $id) (producer $producer) $_ $_) $record
          (identityWrite $schema $producer $id "" $record False)))
      ($rejection $rejection))))
(= (identityCapture $stateRevision $policyRevision $payload)
   (case (identityAllocate host FrameStateBundle "") (
      ((IdentityAllocation $host $id)
       (let $record (integrationMakeRecord FrameStateBundle $id $host
              (SnapshotRef $host $id $stateRevision $policyRevision) $payload)
          (if (identityOK $record)
              (if (identitySnapshotLinks $payload) (identitySaveRecord $record)
                  (identityReject MissingReference)) $record)))
      ($rejection $rejection))))
(= (identityPublisher $schema $role $payload)
   (case $schema (
      (MetaMoPolicyOutput (== $role metamo)) (AttentionDirective (== $role scheduler))
      (FrameVerificationEvidence (== $role verification)) (ExecutionOutcome (== $role executor))
      (ReasonerMotivationalProposal
       (identityAll ((identityMember $role (nars pln llm rule-engine human-adapter))
                  (== (identityField $payload source) $role))))
      ($_ False))))
(= (identityPublish $role $context $payload)
   (if (identityAll ((is-ground ($role $context $payload))
                    (== (get-metatype $payload) Expression) (!= $payload ())))
       (identityPublishPayload $role $context $payload) (identityReject MalformedRecord)))
(= (identityPublishPayload $role $context $payload)
   (let ($schema $_) (decons-atom $payload)
      (if (identityPublisher $schema $role $payload)
          (case (identityAllocate $role $schema "") (
             ((IdentityAllocation $producer $id)
              (let $record (integrationMakeRecord $schema $id $producer $context $payload)
                 (if (identityOK $record)
                     (let $dependencies (identityDependencies $schema $context $payload)
                        (if (identityOK $dependencies)
                            (if (identityRecordLinks $schema $context $payload) (identitySaveRecord $record)
                                (identityReject MalformedRecord)) $dependencies)) $record)))
             ($rejection $rejection)))
          (identityReject InvalidProducer))))

;; Resolve required references before agreement checks so unavailable references
;; retain MissingReference and wrong types retain MalformedRecord.
(= (identityFirstError $values)
   (if (== $values ()) True
       (let ($head $tail) (decons-atom $values)
          (if (identityOK $head) (identityFirstError $tail) $head))))
(= (identityResolveOptional $kind $ref)
   (if (== $ref None) True (identityResolve $kind $ref)))
(= (identityResolveMany $kind $refs)
   (identityFirstError (map-atom $refs $ref (identityResolve $kind $ref))))
(= (identityDependencies $schema $context $payload)
   (if (== $context NoSnapshot) True
       (let $snapshot (identitySnapshotPayload $context)
          (if (identityOK $snapshot)
              (case $schema (
                 (MetaMoPolicyOutput
                  (identityResolveOptional ReasonerMotivationalProposal (identityField $payload proposal)))
                 (AttentionDirective
                  (identityFirstError (
                     (identityResolve MetaMoPolicyOutput (identityField $payload decision))
                     (if (== (identityField $payload target) None) True
                         (identityFrameIn $snapshot (identityField $payload target))))))
                 (ReasonerMotivationalProposal
                  (let (EvidenceReferences $refs) (identityField $payload evidence)
                     (identityFirstError (
                        (identityProposalTarget $snapshot (identityField $payload target))
                        (identityResolveMany ObservationRef $refs)))))
                 (FrameVerificationEvidence
                  (identityFirstError (
                     (identityRelationIn $snapshot (identityField $payload relation))
                     (identityResolveOptional ExecutionRef (identityField $payload execution))
                     (identityResolveMany ObservationRef (identityField $payload observations)))))
                 (ExecutionOutcome
                  (identityFirstError (
                     (identityResolve DispatchRef (identityField $payload dispatch))
                     (identityResolveOptional ExecutionRef (identityField $payload execution))
                     (identityResolve MetaMoPolicyOutput (identityField $payload decision))
                     (identityResolve AttentionDirective (identityField $payload directive))
                     (identityResolveOptional ReasonerMotivationalProposal (identityField $payload proposal))
                     (identityResolveMany ObservationRef (identityField $payload execution-evidence))
                     (identityResolveMany FrameVerificationEvidence (identityField $payload verification)))))
                 ($_ (identityReject MalformedRecord)))) $snapshot))))
(= (identityRedeliver $record)
   (case (integrationValidateRecord $record) (
      ((ContractValid $schema 1)
       (let $stored (identityResolve $schema (integrationRecordReference $record))
          (if (identityOK $stored)
              (if (== $stored $record) $stored (identityReject IdentityConflict)) $stored)))
      ($rejection $rejection))))

(= (identityProposalTarget $snapshot $target)
   (case $target (
      ((FrameTarget $id) (identityFrameIn $snapshot $id))
      ((ModeTarget $mode)
       (identityFrameIn $snapshot (identityField (identityField $snapshot root) current-frame-id)))
      ($_ (identityReject MalformedRecord)))))
(= (identitySameFields $left $right $keys)
   (identityEvery identitySameField ($left $right) $keys))
(= (identitySameField ($left $right) $key)
   (== (identityField $left $key) (identityField $right $key)))
(= (identityDecisionLinks $context $payload)
   (let $ref (identityField $payload proposal)
      (if (== $ref None) True
          (let $proposal (identityLinked ReasonerMotivationalProposal $ref $context)
             (identityAll ((identityOK $proposal)
                  (if (== (identityField $payload operation-class) none)
                    (== (identityField $payload feasibility) Rejected)
                    (== (identityField $payload operation-class) (identityField $proposal candidate)))))))))
(= (identityDirectiveLinks $context $snapshot $payload)
   (let* (($decision (identityLinked MetaMoPolicyOutput (identityField $payload decision) $context))
          ($admission (identityField $payload admission)) ($target (identityField $payload target))
          ($proposalRef (identityField $decision proposal)))
      (identityAll ((identityOK $decision)
                  (== $admission (identityField $decision feasibility))
                  (identitySameFields $payload $decision (reason priority))
                  (if (== $admission Rejected) (== (identityField $payload task) none)
                       (== (identityField $payload task) (identityField $decision operation-class)))
                  (if (== $target None) (== $admission Rejected)
                          (identityOK (identityFrameIn $snapshot $target)))
                  (if (== $proposalRef None) True
                         (let $proposal (identityLinked ReasonerMotivationalProposal $proposalRef $context)
                            (== (identityProposalTarget $snapshot (identityField $proposal target))
                                (identityFrameIn $snapshot $target))))))))
(= (identityRecordLinks $schema $context $payload)
   (if (== $context NoSnapshot) True ;; representation validator restricts this to startup
       (let $snapshot (identitySnapshotPayload $context)
          (if (identityOK $snapshot)
              (case $schema (
                 (ReasonerMotivationalProposal
                  (identityAll ((identityOK (identityProposalTarget $snapshot (identityField $payload target)))
                  (let (EvidenceReferences $refs) (identityField $payload evidence)
                        (identityAdmittedObservations $snapshot $refs)))))
                 (MetaMoPolicyOutput (identityDecisionLinks $context $payload))
                 (AttentionDirective (identityDirectiveLinks $context $snapshot $payload))
                 (FrameVerificationEvidence (identityEvidenceLinks $context $snapshot $payload))
                 (ExecutionOutcome (identityOutcomeLinks $context $snapshot $payload))
                 ($_ False))) False))))

;; Observations keep admitted entity IDs and actual observed revisions.
;; Execution-bound observations may refer to later versions, while proposal
;; evidence must match the versions of the snapshot consuming it.
(= (identityObservedFrames $snapshot $refs $exact)
   (identityEvery identityObservedFrame ($snapshot $exact) $refs))
(= (identityObservedFrame ($snapshot $exact) $ref)
   (case $ref (
      ((FrameRef $h $id $rev)
       (let $captured (identityFrameIn $snapshot $id)
          (identityAll (
             (identityOK (identityResolve FrameRef $ref))
             (if $exact (== $captured $ref) (identityOK $captured))))))
      ($_ False))))
(= (identityObservedRelations $snapshot $refs $exact)
   (identityEvery identityObservedRelation ($snapshot $exact) $refs))
(= (identityObservedRelation ($snapshot $exact) $ref)
   (case $ref (
      ((RelationRef $h $id $rev)
       (let $row (identityFind (identityField $snapshot relations) id $id)
          (identityAll (
             (identityOK (identityResolve RelationRef $ref))
             (!= $row None)
             (if $exact (== (identityField $row revision) $rev) True)))))
      ($_ False))))
(= (identityAdmittedObservations $snapshot $refs)
   (identityEvery identityAdmittedObservation $snapshot $refs))
(= (identityAdmittedObservation $snapshot $ref)
   (let $observation (identityResolve ObservationRef $ref)
      (if (identityOK $observation)
          (identityAll (
             (identityObservedFrames $snapshot (identityField $observation frames) True)
             (identityObservedRelations $snapshot (identityField $observation relations) True))) False)))
(= (identityExecutionContext $execution $context)
   (if (== $execution None) True
       (let* (($link (identityResolve ExecutionRef $execution))
              ($dispatch (identityResolve DispatchRef (identityField $link dispatch))))
          (identityAll ((identityOK $dispatch)
                  (== (identityField $dispatch context) $context))))))
(= (identityObserve $context $frames $relations $execution $provenance)
   (let $snapshot (identitySnapshotPayload $context)
      (if (identityOK $snapshot)
          (if (identityAll ((identityExecutionContext $execution $context)
                  (!= $provenance ())
                  (identityObservedFrames $snapshot $frames (== $execution None))
                  (identityObservedRelations $snapshot $relations (== $execution None))))
              (case (identityAllocate host ObservationRef "") (
                 ((IdentityAllocation $host $id)
                  (identityWrite ObservationRef $host $id ""
                     (ObservationLink (identityPair id (ObservationRef $host $id)) (context $context)
                        (frames $frames) (relations $relations) (execution $execution)
                        (provenance $provenance)) False)) ($rejection $rejection)))
              (identityReject MalformedRecord)) $snapshot)))

;; Link allocation is NOT policy admission or an execution claim. The caller
;; supplies revisions observed at its actual check, including blocked attempts.
;; Redelivery by directive/dispatch returns the original link across restart.
(= (identityDispatch $directiveRef $checkedState $checkedPolicy)
   (if (identityAll ((identityNatural $checkedState) (identityNatural $checkedPolicy)))
       (identityDispatchChecked $directiveRef $checkedState $checkedPolicy) (identityReject InvalidValue)))
(= (identityDispatchChecked $directiveRef $checkedState $checkedPolicy)
   (let* (($directive (identityResolve AttentionDirective $directiveRef))
          ($context (identityField $directive context)) ($payload (identityField $directive payload)))
      (if (identityOK $directive)
          (if (identityAll ((!= $context NoSnapshot)
                  (identityRecordLinks AttentionDirective $context $payload)))
              (case (identityAllocate host DispatchRef (repr $directiveRef)) (
                 ((IdentityAllocation $host $id)
                  (let $prior (identityResolve DispatchRef (DispatchRef $host $id))
                     (if (identityOK $prior) $prior
                         (let* (($decisionRef (identityField $payload decision))
                                ($decision (identityLinked MetaMoPolicyOutput $decisionRef $context))
                                ($target (identityField $payload target)))
                            (identityWrite DispatchRef $host $id ""
                               (DispatchLink (identityPair id (DispatchRef $host $id)) (context $context)
                                  (decision $decisionRef) (directive $directiveRef)
                                  (proposal (identityField $decision proposal))
                                  (target (if (== $target None) None (identityFrameAt $context $target)))
                                  (checked-state-revision $checkedState) (checked-policy-revision $checkedPolicy)) False)))))
                 ($rejection $rejection))) (identityReject MalformedRecord)) $directive)))
(= (identityExecution $dispatchRef)
   (let $dispatch (identityResolve DispatchRef $dispatchRef)
      (if (identityOK $dispatch)
          (case (identityAllocate host ExecutionRef (repr $dispatchRef)) (
             ((IdentityAllocation $host $id)
              (identityWrite ExecutionRef $host $id ""
                 (ExecutionLink (identityPair id (ExecutionRef $host $id)) (dispatch $dispatchRef)) False))
             ($rejection $rejection))) $dispatch)))
(= (identityExecutionMatches $execution $dispatchRef)
   (if (== $execution None)
       (== (sread (py-call (identity_store.lookup_cause "ExecutionRef" (repr $dispatchRef)))) IdentityUnallocated)
       (== (identityField (identityResolve ExecutionRef $execution) dispatch) $dispatchRef)))

(= (identityEvidenceObservations $snapshot $payload $refs)
   (identityEvery identityEvidenceObservation ($snapshot $payload) $refs))
(= (identityEvidenceObservation ($snapshot $payload) $ref)
   (let* (($observation (identityResolve ObservationRef $ref))
          ($source (identityFrameIn $snapshot (identityField $payload source-frame)))
          ($target (identityFrameIn $snapshot (identityField $payload target-frame))))
      (if (identityOK $observation)
          (identityAll (
             (== (identityField $observation execution) (identityField $payload execution))
             (identityMember (identityField $payload relation) (identityField $observation relations))
             (identityMember $source (identityField $observation frames))
             (identityMember $target (identityField $observation frames)))) False)))
(= (identityEvidenceLinks $context $snapshot $payload)
   (let $relation (identityRelationIn $snapshot (identityField $payload relation))
      (if (identityOK $relation)
          (identityAll ((identitySameFields $payload $relation (source-frame target-frame relation-type))
                  (== (identityField $payload prior-confidence) (identityField $relation confidence))
                  (identityExecutionContext (identityField $payload execution) $context)
                  (identityEvidenceObservations $snapshot $payload (identityField $payload observations)))) False)))
(= (identityOutcomeObservations $context $execution $frame $refs)
   (identityEvery identityOutcomeObservation ($context $execution $frame) $refs))
(= (identityOutcomeObservation ($context $execution $frame) $ref)
   (let $observation (identityResolve ObservationRef $ref)
      (if (identityOK $observation)
          (identityAll (
             (== (identityField $observation execution) $execution)
             (== (identityField $observation context) $context)
             (if (== $frame None) True
                 (identityHasFrameId (identityField $observation frames) $frame)))) False)))
(= (identityHasFrameId $frames $id)
   (if (== $frames ()) False
       (let ((FrameRef $h $frame $rev) $tail) (decons-atom $frames)
          (if (== $frame $id) True (identityHasFrameId $tail $id)))))
(= (identityOutcomeVerification $context $snapshot $payload $refs)
   (identityEvery identityOutcomeEvidence ($context $snapshot $payload) $refs))
(= (identityOutcomeEvidence ($context $snapshot $payload) $ref)
   (let* (($evidence (identityLinked FrameVerificationEvidence $ref $context))
          ($frame (identityField $payload frame)))
      (if (identityOK $evidence)
          (identityAll (
             (identityEvidenceLinks $context $snapshot $evidence)
             (== (identityField $payload execution) (identityField $evidence execution))
             (identityMember $frame ((identityField $evidence source-frame)
                                    (identityField $evidence target-frame))))) False)))
(= (identityOutcomeLinks $context $snapshot $payload)
   (let* (($dispatchRef (identityField $payload dispatch))
          ($dispatch (identityResolve DispatchRef $dispatchRef))
          ($execution (identityField $payload execution)) ($frame (identityField $payload frame))
          ($target (identityField $dispatch target)))
      (identityAll ((identityOK $dispatch)
                  (== (identityField $dispatch context) $context)
                  (identitySameFields $payload $dispatch (decision directive proposal))
                  (if (== $target None) (== $frame None)
                       (case $target (((FrameRef $h $id $rev) (== $frame $id)) ($_ False))))
                  (identityExecutionMatches $execution $dispatchRef)
                  (identityOutcomeObservations $context $execution $frame
                             (identityField $payload execution-evidence))
                  (identityOutcomeVerification $context $snapshot $payload
                             (identityField $payload verification))))))
