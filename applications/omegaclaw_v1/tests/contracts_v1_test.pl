:- ensure_loaded('../contracts.pl').
:- ensure_loaded('fixtures/contracts_v1.pl').
:- begin_tests(contracts_v1).

test(shared_ownership_cases,
     [forall(contractOwnershipCase(Name,Schema,Record,Expected))]) :-
    findall(Result,integrationValidateRecord(Record,Result),Results),
    assertion(Results == [Expected]),
    contractOwnershipConsumed(Name,Consumed),
    findall(Payload,integrationConsumeRecord(Schema,Record,Payload),Payloads),
    assertion(Payloads == [Consumed]).

valid(R) :- integrationValidateRecord(R, ['ContractValid',_,1]).
invalid(R, Reason) :-
    findall(V,integrationValidateRecord(R,V),Values),
    assertion(Values = [['ContractRejection',Reason,_,_,'None']]).
change(S,Path,Value,R) :- contractFixtureRecord(S,Base), contractFixtureSet(Path,Value,Base,R).

test(all_six_publish_and_consume, [forall(mmc_schema(S))]) :-
    contractFixtureRecord(S,R),
    mmc_envelope(R,_,_,ID,Producer,Context,Payload),
    integrationMakeRecord(S,ID,Producer,Context,Payload,R),
    findall(V,integrationValidateRecord(R,V),[['ContractValid',S,1]]),
    integrationConsumeRecord(S,R,Payload).

test(no_implicit_legacy_upgrade, [forall(mmc_schema(S))]) :-
    contract_fixture_payload(S,P), invalid(P,'MalformedRecord').
test(wrong_consumer, [forall(mmc_schema(S))]) :-
    contractFixtureRecord(S,R), integrationConsumeRecord('WrongSchema',R,
        ['ContractRejection','UnsupportedSchema',S,1,'None']).
test(version_rejected, [forall(member(V,[0,2,"1",1.0]))]) :-
    contractFixtureRecord('MetaMoPolicyOutput',R),
    R = [Tag,[schema,S,_]|Rest], invalid([Tag,[schema,S,V]|Rest],'UnsupportedVersion').
test(unknown_schema) :- invalid(['IntegrationRecord',[schema,'Unknown',1],
    ['record-id',"id"],[producer,"p"],[context,'NoSnapshot'],[payload,[]]],'UnsupportedSchema').
test(malformed, [forall(member(R,[broken,[],['IntegrationRecord']]))]) :- invalid(R,'MalformedRecord').
test(variables_not_bound) :- invalid(['IntegrationRecord',X],'MalformedRecord'), assertion(var(X)).
test(extra_field, [forall(mmc_schema(S))]) :-
    contractFixtureRecord(S,R), append(R,[[extra,1]],Bad), invalid(Bad,'MalformedRecord').
test(missing_payload_field, [forall(mmc_schema(S))]) :-
    contractFixtureRecord(S,R), mmc_envelope(R,_,_,_,_,_,[Tag,_|Fields]),
    contractFixtureSet([payload],[Tag|Fields],R,Bad), invalid(Bad,'InvalidValue').
test(duplicate_payload_field, [forall(mmc_schema(S))]) :-
    contractFixtureRecord(S,R), mmc_envelope(R,_,_,_,_,_,[Tag,F|Fields]),
    contractFixtureSet([payload],[Tag,F,F|Fields],R,Bad), invalid(Bad,'InvalidValue').
test(unknown_payload_field, [forall(mmc_schema(S))]) :-
    contractFixtureRecord(S,R), mmc_envelope(R,_,_,_,_,_,P), append(P,[[unexpected,1]],BadP),
    contractFixtureSet([payload],BadP,R,Bad), invalid(Bad,'InvalidValue').
test(invalid_priority, [forall(member(N,[-0.1,1.1,"0.5",'True']))]) :-
    change('MetaMoPolicyOutput',[payload,priority],N,R), invalid(R,'InvalidValue').
test(nonfinite_priority, [forall(member(Text,['1.5NaN','1.0Inf','-1.0Inf']))]) :-
    atom_number(Text,N), change('MetaMoPolicyOutput',[payload,priority],N,R), invalid(R,'InvalidValue').
test(unknown_mode) :- change('MetaMoPolicyOutput',[payload,mode],'Mystery',R), invalid(R,'InvalidValue').
test(none_cannot_be_admitted) :- change('MetaMoPolicyOutput',[payload,'operation-class'],none,R), invalid(R,'InvalidValue').
test(startup_shapes, [forall(member(Mode,['Engaged','Threat','Rumination','Sleep']))]) :-
    integrationStartupPolicy("startup-policy","metamo-A",Mode,P), valid(P),
    integrationStartupAttention("startup-attention","adapter-A",A), valid(A),
    integrationAttentionFromPolicy("startup-attention","adapter-A",P,'None','None',A).
test(startup_invalid_mode) :- integrationStartupPolicy("id","p",unknown,R),
    assertion(R = ['ContractRejection','InvalidValue',_,1,'None']).
test(runtime_default_same_field_shape) :-
    integrationStartupPolicy("s","m",'Engaged',S), contractFixtureRecord('MetaMoPolicyOutput',R),
    mmc_envelope(S,_,_,_,_,_,[_|SF]), mmc_envelope(R,_,_,_,_,_,[_|RF]),
    pairs_keys(SF,SK), pairs_keys(RF,RK), assertion(SK == RK).
test(attention_default_same_field_shape) :-
    integrationStartupAttention("s","a",S), contractFixtureRecord('AttentionDirective',R),
    mmc_envelope(S,_,_,_,_,_,[_|SF]), mmc_envelope(R,_,_,_,_,_,[_|RF]),
    pairs_keys(SF,SK), pairs_keys(RF,RK), assertion(SK == RK).
test(admitted_work_needs_target) :-
    change('AttentionDirective',[payload,target],'None',R), invalid(R,'InvalidValue').
test(no_snapshot_for_data_records, [forall(member(S,['FrameStateBundle','ReasonerMotivationalProposal','ExecutionOutcome','FrameVerificationEvidence']))]) :-
    change(S,[context],'NoSnapshot',R), invalid(R,'InvalidValue').
test(admitted_directive_link) :-
    contractFixtureRecord('MetaMoPolicyOutput',P),
    integrationAttentionFromPolicy("directive-1","scheduler-A",P,"frame-1",'CurrentFrameTask',A),
    valid(A), mmc_envelope(A,_,_,_,_,Context,Payload), contractFixtureContext(Context),
    mmc_get(Payload,decision,['RecordRef',"adapter-A","record-1"]),
    mmc_get(Payload,admission,'Admitted'), mmc_get(Payload,priority,0.7).
test(rejected_and_no_action, [forall(member(Op,[none,'execute-skill']))]) :-
    contractFixtureContext(C),
    integrationPolicyRecord("decision","metamo-A",C,'Engaged',Op,'Rejected','NoCandidate',0,'None',P),
    valid(P), integrationAttentionFromPolicy("directive","adapter-A",P,'None','CurrentFrameTask',A),
    valid(A), mmc_envelope(A,_,_,_,_,_,Payload),
    mmc_get(Payload,task,none), mmc_get(Payload,slice,'None'), mmc_get(Payload,priority,0).
test(rejection_propagates) :-
    integrationAttentionFromPolicy("id","p",broken,'None','None',R),
    assertion(R = ['ContractRejection','MalformedRecord',_,_,'None']).
test(no_current_frame) :-
    contractFixtureRecord('FrameStateBundle',R),
    contractFixtureSet([payload,current],'None',R,R1),
    contractFixtureSet([payload,root,'current-frame-id'],'None',R1,R2),
    contractFixtureSet([payload,runtime,'budget-state'],['BudgetRef',"host-A","global-budget",2],R2,R3), valid(R3).
test(mismatched_current) :- change('FrameStateBundle',[payload,root,'current-frame-id'],"other",R), invalid(R,'InvalidValue').
test(snapshot_identity) :- change('FrameStateBundle',['record-id'],"other",R), invalid(R,'InvalidValue').
test(cross_host) :- change('ExecutionOutcome',[payload,dispatch],['DispatchRef',"host-B","dispatch"],R), invalid(R,'InvalidValue').
test(wrong_ref_type) :- change('ExecutionOutcome',[payload,dispatch],['RecordRef',"host-A","dispatch"],R), invalid(R,'InvalidValue').
test(proposal_kinds, [forall(member(K,['propose-candidate','request-attention','request-frame-switch','request-mode-change']))]) :-
    change('ReasonerMotivationalProposal',[payload,kind],K,R),
    (K == 'request-mode-change' ->
        contractFixtureSet([payload,target],['ModeTarget','Slow'],R,R1)
    ; R1 = R),
    (memberchk(K,['request-mode-change','request-frame-switch']) ->
        contractFixtureSet([payload,candidate],defer,R1,R2)
    ; R2 = R1), valid(R2).
test(proposal_needs_observations) :- change('ReasonerMotivationalProposal',[payload,evidence],['EvidenceReferences',[]],R), invalid(R,'InvalidValue').
test(outcome_statuses, [forall(member(S,['Completed','Failed','Blocked','Unobserved']))]) :-
    change('ExecutionOutcome',[payload,status],S,R), valid(R).
test(completion_needs_execution) :- change('ExecutionOutcome',[payload,execution],'None',R), invalid(R,'InvalidValue').
test(completion_needs_observation) :- change('ExecutionOutcome',[payload,'execution-evidence'],[],R), invalid(R,'InvalidValue').
test(evidence_statuses, [forall(member(S,['Confirmed','Refuted','Unresolved']))]) :-
    change('FrameVerificationEvidence',[payload,'evidence-status'],S,R), valid(R).
test(confirmed_needs_observations) :- change('FrameVerificationEvidence',[payload,observations],[],R), invalid(R,'InvalidValue').
test(verification_request_is_not_observation) :- change('FrameVerificationEvidence',[payload,'evidence-status'],'VerificationRequired',R), invalid(R,'InvalidValue').

pairs_keys([], []).
pairs_keys([[K,_]|Pairs], [K|Keys]) :- pairs_keys(Pairs, Keys).
:- end_tests(contracts_v1).
