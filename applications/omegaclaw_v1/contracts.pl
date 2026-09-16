% Versioned boundary records. All terms are inspected as data, never called.
% These predicates validate representation, not reference resolution, host
% identity, revision freshness, or permission. Those are host admission checks.

mmc_schema('FrameStateBundle').
mmc_schema('MetaMoPolicyOutput').
mmc_schema('AttentionDirective').
mmc_schema('ReasonerMotivationalProposal').
mmc_schema('ExecutionOutcome').
mmc_schema('FrameVerificationEvidence').

mmc_fields('FrameStateBundle', [root-record('FrameStateRoot'),
    current-optional(record('FrameStateCurrent')), index-record('FrameStateIndex'),
    relations-list(record('FrameStateRelation')), runtime-record('FrameStateRuntime'),
    policy-ref('HostPolicyRef')]).
mmc_fields('FrameStateRoot', [id-id, revision-natural, 'current-frame-id'-optional(id),
    mode-mode, 'global-budget'-ref('BudgetRef'), 'global-constraints'-ref('ConstraintsRef')]).
mmc_fields('FrameStateCurrent', [id-id, revision-natural, parent-optional(id), source-id,
    status-status, 'frame-mode'-mode, priority-unit, 'goal-summary'-text,
    'history-summary'-text, 'deliverable-summary'-text, 'results-summary'-text,
    budget-ref('BudgetRef'), constraints-ref('ConstraintsRef'), 'certified-method'-text]).
mmc_fields('FrameStateIndex', [active-list(record('FrameIndexRef')),
    completed-list(record('FrameIndexRef'))]).
mmc_fields('FrameIndexRef', [id-id, revision-natural, status-status]).
mmc_fields('FrameStateRelation', [id-id, revision-natural, 'source-frame'-id,
    'target-frame'-id, 'relation-type'-symbol, reason-text, confidence-unit,
    'evidence-status'-relation_status]).
mmc_fields('FrameStateRuntime', ['new-message'-boolean, 'message-present'-boolean,
    'message-summary'-text, 'task-open'-boolean,
    'task-execution-observed'-list(ref('ObservationRef')), 'active-task-summary'-text,
    'last-results-summary'-text, error-text, 'wake-loops'-natural,
    'next-wake-at'-optional(natural), 'budget-state'-ref('BudgetRef')]).
mmc_fields('MetaMoPolicyOutput', [mode-constitutional_mode, 'operation-class'-candidate,
    feasibility-admission, reason-reason, priority-unit, proposal-optional(ref('RecordRef'))]).
mmc_fields('AttentionDirective', [decision-optional(ref('RecordRef')), target-optional(id),
    slice-slice, task-candidate, admission-admission, reason-reason, priority-unit,
    source-exact('MetaMo')]).
mmc_fields('ReasonerMotivationalProposal', [source-proposal_source, kind-proposal_kind,
    target-target, candidate-operation, claim-nonempty_data, support-nonempty_data,
    confidence-unit, evidence-evidence, prediction-nonempty_data]).
mmc_fields('ExecutionOutcome', [decision-ref('RecordRef'), directive-ref('RecordRef'),
    proposal-optional(ref('RecordRef')), dispatch-ref('DispatchRef'),
    execution-optional(ref('ExecutionRef')), frame-optional(id), status-outcome_status,
    reason-symbol, 'observed-at'-natural, 'execution-evidence'-list(ref('ObservationRef')),
    verification-list(ref('RecordRef'))]).
mmc_fields('FrameVerificationEvidence', [relation-ref('RelationRef'), 'source-frame'-id,
    'target-frame'-id, 'relation-type'-symbol, reason-text, 'prior-confidence'-unit,
    'evidence-status'-evidence_status, 'observed-at'-natural,
    observations-list(ref('ObservationRef')), execution-optional(ref('ExecutionRef'))]).

mmc_enum(mode, ['Fast','Slow']).
mmc_enum(status, ['Active','Focused','Completed','Blocked','Abandoned','Superseded']).
% PeTTa parses MeTTa True/False as the Prolog atoms true/false.
mmc_enum(boolean, [true,false]).
mmc_enum(constitutional_mode, ['Engaged','Threat','Rumination','Sleep']).
mmc_enum(admission, ['Admitted','Rejected']).
mmc_enum(reason, ['Feasible','NotInitialized','NoCandidate','InvalidProposal',
    'NoActiveFrame','InactiveFrame','FrameModeMismatch','BudgetExhausted',
    'SleepModeOperationalWork','PolicyRejected','StaleSnapshot']).
mmc_enum(slice, ['None','CurrentFrameSummary','CurrentFrameTask','CurrentFrameAndRelations']).
mmc_enum(proposal_source, [nars,pln,llm,'rule-engine','human-adapter']).
mmc_enum(proposal_kind, ['propose-candidate','request-attention','request-frame-switch','request-mode-change']).
mmc_enum(outcome_status, ['Completed','Failed','Blocked','Unobserved']).
mmc_enum(evidence_status, ['Confirmed','Refuted','Unresolved']).
mmc_enum(relation_status, ['Unverified','VerificationRequired','Confirmed','Refuted','Unresolved']).
mmc_enum(operation, [respond,'retrieve-memory','search-knowledge','execute-skill',learn,
    'self-improve','background-work','recall-goals','invent-goal','plan-goal',
    'repair-failure',defer,'verify-frame-state','ask-clarification']).

mmc_type(id, V) :- string(V), string_length(V, N), N > 0.
mmc_type(text, V) :- string(V).
mmc_type(symbol, V) :- atom(V), V \== ''.
mmc_type(natural, V) :- integer(V), V >= 0.
mmc_type(unit, V) :- number(V), (float(V) -> float_class(V, C), memberchk(C,[normal,subnormal,zero]); true), V >= 0, V =< 1.
mmc_type(exact(X), V) :- V == X.
mmc_type(optional(T), V) :- (V == 'None' -> true; mmc_type(T, V)).
mmc_type(list(T), V) :- is_list(V), maplist(mmc_type(T), V).
mmc_type(record(S), V) :- mmc_record(S, V).
mmc_type(ref(T), V) :- mmc_ref(T, V).
mmc_type(candidate, V) :- (V == none -> true; mmc_type(operation, V)).
mmc_type(target, ['FrameTarget', ID]) :- mmc_type(id, ID).
mmc_type(target, ['ModeTarget', Mode]) :- mmc_type(mode, Mode).
mmc_type(evidence, ['EvidenceReferences', Refs]) :- mmc_type(list(ref('ObservationRef')), Refs).
mmc_type(nonempty_data, V) :- V \== [], V \== 'None', V \== "", mmc_data(V).
mmc_type(T, V) :- mmc_enum(T, Values), memberchk(V, Values).

mmc_data(V) :- (atomic(V) -> true; is_list(V), maplist(mmc_data, V)).
mmc_ref(T, [T, Host, ID]) :- memberchk(T, ['RecordRef','ObservationRef','DispatchRef','ExecutionRef']),
    mmc_type(id, Host), mmc_type(id, ID).
mmc_ref(T, [T, Host, ID, Rev]) :- memberchk(T, ['FrameRef','RelationRef','BudgetRef','ConstraintsRef','HostPolicyRef']),
    mmc_type(id, Host), mmc_type(id, ID), mmc_type(natural, Rev).

mmc_record(S, [S|Fields]) :- mmc_fields(S, Spec), mmc_field_values(Spec, Fields).
mmc_field_values([], []).
mmc_field_values([Name-Type|Spec], [[Name, Value]|Fields]) :-
    mmc_type(Type, Value), mmc_field_values(Spec, Fields).
mmc_get([_|Fields], Name, Value) :- memberchk([Name,Value], Fields).

mmc_context(['SnapshotRef', Host, ID, Rev, Policy]) :-
    mmc_type(id, Host), mmc_type(id, ID), mmc_type(natural, Rev), mmc_type(natural, Policy).
mmc_context_for(S, 'NoSnapshot', P) :-
    memberchk(S, ['MetaMoPolicyOutput','AttentionDirective']),
    (S == 'MetaMoPolicyOutput' ->
        mmc_get(P, 'operation-class', none), mmc_get(P, feasibility, 'Rejected'), mmc_get(P, proposal, 'None')
    ; mmc_get(P, task, none), mmc_get(P, admission, 'Rejected'),
      mmc_get(P, decision, 'None'), mmc_get(P, target, 'None')),
    mmc_get(P, reason, 'NotInitialized'), mmc_get(P, priority, 0).
mmc_context_for(_, Context, _) :- mmc_context(Context).

% Structural checks have already established exact fields and types here.
mmc_invariants('MetaMoPolicyOutput', P) :-
    mmc_get(P, feasibility, A), mmc_get(P, reason, R), mmc_get(P, priority, N),
    mmc_get(P, 'operation-class', Op), mmc_admission(A,R,N),
    (Op == none -> A == 'Rejected'; true).
mmc_invariants('AttentionDirective', P) :-
    mmc_get(P, admission, A), mmc_get(P, reason, R), mmc_get(P, priority, N),
    mmc_admission(A,R,N), mmc_get(P, task, Op), mmc_get(P, slice, Slice),
    (A == 'Rejected' -> Op == none, Slice == 'None'
    ; Op \== none, Slice \== 'None', mmc_get(P, decision, D), D \== 'None',
      (memberchk(Op,['execute-skill',learn,'self-improve','background-work',
                    'invent-goal','plan-goal','repair-failure','verify-frame-state'])
       -> mmc_get(P,target,Target), Target \== 'None'; true)).
mmc_invariants('ReasonerMotivationalProposal', P) :-
    mmc_get(P, kind, Kind), mmc_get(P, target, Target), mmc_get(P, candidate, Candidate),
    (Kind == 'request-mode-change' -> Target = ['ModeTarget', _], Candidate == defer
    ; Target = ['FrameTarget', _],
      (Kind == 'request-frame-switch' -> Candidate == defer; true)),
    mmc_get(P, source, Source), mmc_get(P, evidence, ['EvidenceReferences', Refs]),
    (memberchk(Source,[nars,pln]) -> Refs \== []; true).
mmc_invariants('ExecutionOutcome', P) :-
    mmc_get(P, status, Status), mmc_get(P, execution, Execution),
    mmc_get(P, 'execution-evidence', Evidence),
    (memberchk(Status,['Completed','Failed']) -> Execution \== 'None', Evidence \== []; true).
mmc_invariants('FrameVerificationEvidence', P) :-
    mmc_get(P, 'evidence-status', Status), mmc_get(P, observations, Refs),
    (Status == 'Unresolved' -> true; Refs \== []).
mmc_invariants('FrameStateBundle', P) :-
    mmc_get(P, root, Root), mmc_get(P, current, Current), mmc_get(P, runtime, Runtime),
    mmc_get(Root, 'current-frame-id', ID), mmc_get(Runtime, 'budget-state', Budget),
    (Current == 'None' -> ID == 'None', mmc_get(Root, 'global-budget', Budget)
    ; mmc_get(Current, id, ID), mmc_get(Current, budget, Budget)).
mmc_admission('Admitted', 'Feasible', _).
mmc_admission('Rejected', R, N) :- R \== 'Feasible', N =:= 0.

mmc_envelope(['IntegrationRecord', [schema,S,V], ['record-id',ID],
    [producer,Producer], [context,Context], [payload,Payload]], S,V,ID,Producer,Context,Payload).

% Exactly one result, including malformed/unknown envelopes. Never bind an
% input variable to a valid record or use a catch-all alternative to admission.
integrationValidateRecord(Record, Result) :-
    ( ground(Record), mmc_envelope(Record,S,V,ID,Producer,Context,P)
    -> ( mmc_schema(S)
       -> ( V == 1
          -> ( mmc_type(id,ID), mmc_type(id,Producer),
               mmc_record(S,P), mmc_context_for(S,Context,P), mmc_invariants(S,P),
               mmc_envelope_invariants(S,ID,Producer,Context,P)
             -> Result = ['ContractValid', S, 1]
             ; Result = ['ContractRejection','InvalidValue',S,V,'None'] )
          ; Result = ['ContractRejection','UnsupportedVersion',S,V,'None'] )
       ; Result = ['ContractRejection','UnsupportedSchema',S,V,'None'] )
    ; Result = ['ContractRejection','MalformedRecord','None','None','None'] ), !.

mmc_envelope_invariants('FrameStateBundle', ID, Producer,
        ['SnapshotRef',Host,Snapshot,_,PolicyRev], P) :- !,
    ID == Snapshot, Producer == Host,
    mmc_get(P, policy, ['HostPolicyRef',Host,_,PolicyRev]), mmc_host_refs(P, Host).
mmc_envelope_invariants(_, _, _, 'NoSnapshot', _) :- !.
mmc_envelope_invariants(_, _, _, ['SnapshotRef',Host,_,_,_], P) :- mmc_host_refs(P, Host).

% Host-qualified refs in typed fields must belong to the snapshot host.
% claim/support/prediction are opaque data, not reference declarations.
mmc_host_refs([Tag,_], _) :- memberchk(Tag,[claim,support,prediction]), !.
mmc_host_refs([Tag,H|_], Host) :-
    memberchk(Tag,['ObservationRef','DispatchRef','ExecutionRef','RelationRef',
        'BudgetRef','ConstraintsRef','HostPolicyRef']), !, H == Host.
mmc_host_refs(V, Host) :- (is_list(V) -> maplist(mmc_host_refs_for(Host),V); true).
mmc_host_refs_for(H,V) :- mmc_host_refs(V,H).

integrationMakeRecord(S, ID, Producer, Context, Payload, Result) :-
    Record = ['IntegrationRecord',[schema,S,1],['record-id',ID],[producer,Producer],
        [context,Context],[payload,Payload]],
    integrationValidateRecord(Record, Validation),
    (Validation = ['ContractValid',_,_] -> Result = Record; Result = Validation).

integrationConsumeRecord(Expected, Record, Result) :-
    integrationValidateRecord(Record, Validation),
    (Validation = ['ContractValid', S, 1]
    -> (S == Expected -> mmc_envelope(Record,_,_,_,_,_,Result)
       ; Result = ['ContractRejection','UnsupportedSchema',S,1,'None'])
    ; Result = Validation).

integrationRecordReference(Record, Result) :-
    integrationValidateRecord(Record, Validation),
    (Validation = ['ContractValid',_,_]
    -> mmc_envelope(Record,_,_,ID,Producer,_,_), Result = ['RecordRef',Producer,ID]
    ; Result = Validation).

integrationStartupPolicy(ID, Producer, Mode, Result) :-
    mmc_policy(Mode,none,'Rejected','NotInitialized',0,'None',Payload),
    integrationMakeRecord('MetaMoPolicyOutput',ID,Producer,'NoSnapshot',Payload,Result).
integrationStartupAttention(ID, Producer, Result) :-
    mmc_attention('None','None','None',none,'Rejected','NotInitialized',0,Payload),
    integrationMakeRecord('AttentionDirective',ID,Producer,'NoSnapshot',Payload,Result).

% Shared constructors are used for startup, normal, rejected and no-action output.
mmc_policy(Mode,Op,Admission,Reason,Priority,Proposal,
    ['MetaMoPolicyOutput',[mode,Mode],['operation-class',Op],[feasibility,Admission],
        [reason,Reason],[priority,Priority],[proposal,Proposal]]).
mmc_attention(Decision,Target,Slice,Task,Admission,Reason,Priority,
    ['AttentionDirective',[decision,Decision],[target,Target],[slice,Slice],
        [task,Task],[admission,Admission],[reason,Reason],[priority,Priority],[source,'MetaMo']]).

integrationPolicyRecord(ID, Producer, Context, Mode, Op, Admission, Reason, Priority, Proposal, Result) :-
    mmc_policy(Mode,Op,Admission,Reason,Priority,Proposal,Payload),
    integrationMakeRecord('MetaMoPolicyOutput',ID,Producer,Context,Payload,Result).

% Derive the directive's context, decision reference, admission, reason and
% priority from a validated policy record; callers cannot substitute them.
integrationAttentionFromPolicy(ID, Producer, Policy, Target, Slice, Result) :-
    integrationConsumeRecord('MetaMoPolicyOutput',Policy,P),
    (P = ['ContractRejection'|_] -> Result = P
    ; mmc_envelope(Policy,_,_,DecisionID,DecisionProducer,Context,_),
      mmc_get(P,'operation-class',Op), mmc_get(P,feasibility,Admission),
      mmc_get(P,reason,Reason), mmc_get(P,priority,Priority),
      (Context == 'NoSnapshot' -> Decision = 'None', EffectiveTarget = 'None'
      ; Decision = ['RecordRef',DecisionProducer,DecisionID], EffectiveTarget = Target),
      (Admission == 'Rejected' -> Task = none, EffectiveSlice = 'None'
      ; Task = Op, EffectiveSlice = Slice),
      mmc_attention(Decision,EffectiveTarget,EffectiveSlice,Task,Admission,Reason,Priority,Payload),
      integrationMakeRecord('AttentionDirective',ID,Producer,Context,Payload,Result)).
