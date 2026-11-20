;; Copy optional reasoner audit records; no inference, comparison or learning calls.
!(import! &self (library MetaMo applications/omegaclaw_v1/trace))
(: TraceParameterRefType Type)
(: TraceParameterRef (-> Expression Symbol TraceParameterRefType))
(: TraceParameterChangeType Type)
(: TraceParameterChange (-> Expression Number Number TraceParameterChangeType))
(: TraceProposalAdmissionType Type)
(: TraceProposalAdmission (-> Expression Symbol Expression String TraceProposalAdmissionType))

;; Intake is retained before the events predicted by its original proposals.
;; Example: an empty Timeout intake is observed unavailability, not negative evidence.
(= (recordHostReasonerCycleTrace $row)
   (let* (
      ((HostReasonerCycle $context $invocation $intake $envelopes $_ $_) $row)
      ($id (mrcValue $invocation 1))
   )
      (progn
         (recordMetaMoTrace ReasonerIntake $id (TraceCycleRef $context)
            ((traceField adapter (mrcValue $invocation 2))
             (traceField configuration (mrcValue $invocation 4))
             (traceField phase (mrcValue $invocation 10))
             (traceField status (mrcValue $intake 3))))
         (map-atom $envelopes $envelope
            (recordHostReasonerProposalTrace $context $id (mrcValue $envelope 4))) True)))

;; Keep native claims/support and evidence as data, with a separately bounded prediction.
;; Example: an oversized claim cannot hide its proposal identity or replace its prediction.
(= (recordHostReasonerProposalTrace $context $invocation $proposal)
   (let (ReasonerMotivationalProposal $id $source $kind $target $candidate $claim $support $confidence $evidence $prediction) $proposal
      (recordMetaMoTrace ReasonerProposal (TraceProposalRef $invocation $id) (TraceCycleRef $context)
         ((traceField proposal-key (repr (quote (TraceProposalRef $invocation $id))))
          (traceField source (quote $source)) (traceField kind (quote $kind))
          (traceField target (quote $target)) (traceField candidate (quote $candidate))
          (traceField claim (quote $claim)) (traceField support (quote $support))
          (traceField confidence (quote $confidence)) (traceField evidence (quote $evidence))
          (traceField prediction (quote $prediction))))))

;; Admission remains distinct from actual selection and from an observed outcome grade.
;; Example: a rejected alternative is displayed without borrowing the primary's grade.
(= (recordHostReasonerAdmissionsTrace $batch)
   (let (HostReasonerAdmissions $context $id $entries) $batch
      (recordMetaMoTrace ReasonerAdmission $id (TraceCycleRef $context)
         ((traceField decisions (map-atom $entries $entry
            (let* (
               ($proposal (mrcValue (index-atom $entry 1) 4))
               ($proposalId (getProposalId $proposal))
               ($decision (index-atom $entry 2))
            ) (TraceProposalAdmission $proposalId
               (getStatus $decision) (index-atom $decision 2)
               (repr (quote (TraceProposalRef $id $proposalId)))))))))))

;; Copy queued/final statuses beside their original grade identity and status context.
;; Example: Pending does not assert application; StaleSession never becomes Applied.
(= (recordHostReasonerParameterTrace $batch)
   (let (HostReasonerParameterBatch $id $learner $queued $edits $status $at) $batch
      (recordMetaMoTrace ParameterUpdate (TraceParameterRef $id $status) (TraceCycleRef $queued)
         ((traceField learner (quote $learner)) (traceField queued-at (quote $queued))
          (traceField status (quote $status)) (traceField status-at (quote $at))
          (traceField changes (map-atom $edits $edit
             (let (HostReasonerParameterEdit (HostReasonerParameterChange $key $before $after $_) $_ $_) $edit
                (TraceParameterChange $key $before $after))))))))
