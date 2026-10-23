% Trusted host adapter for the session dispatcher. No model-accessible policy
% setters or registration functions are exported to MeTTa. Provision exact
% command/metadata bindings and typed policies from host configuration.
:- dynamic mm_dispatch_binding/3, mm_dispatch_policies/2, mm_dispatch_owner/1.
:- dynamic mm_completion_policy/2.

% Example: an invoked command with unresolved effects prevents task handoff.
mm_dispatch_busy :-
    oc_dispatch_result(_,_,['DispatchResult','Unobserved','ExecutionUncertain',none]).

% Example: an arbitrary frame switch cannot inherit the operator's task policy.
mm_dispatch_task_owner(Owner) :-
    commitmentSnapshot(Owner),
    Owner=['CommitmentSnapshot',_,Frame,_,'Open',_],
    nb_current('&cfv2-current-frame-id',Current), Current == Frame,
    nb_current('&cfv2-last-admitted-frame-id',Admitted), Admitted == Frame,
    nb_current('&cfv2-current-source','UserDirective'),
    nb_current('&cfv2-current-status',Status), memberchk(Status,['Active','Focused']).

% Example: terminal or replaced owners cannot execute previously installed bindings.
mm_dispatch_owner_current :-
    (mm_dispatch_owner(Owner) -> commitmentSnapshot(Current), Current == Owner ; true).

mm_dispatch_register(Command, Request, Operation) :-
    ground(Command-Request-Operation), is_list(Command), Command=[_|_],
    oc_dispatch_mutate((retractall(mm_dispatch_binding(Command,_,_)),
                       assertz(mm_dispatch_binding(Command,Request,Operation)))).
mm_dispatch_set_policies(Global, Frame) :-
    ground(Global-Frame),
    oc_dispatch_mutate((retractall(mm_dispatch_policies(_,_)),
                       assertz(mm_dispatch_policies(Global,Frame)),
                       eval(['change-state!','&prepared-host-operation',[]],_))).
mm_dispatch_revoke(Command) :-
    oc_dispatch_mutate((retractall(mm_dispatch_binding(Command,_,_)),
                       eval([revokePreparedHostCommand,[quote,Command]],_))).

mm_dispatch_intent(Intent) :-
    eval(['get-state','&last-meta-mo-policy-output'], Policy),
    Policy=['MetaMoPolicyOutput',_,['operation-class',Candidate],['feasibility','Admitted'],_],
    Candidate \== none,
    Intent=['AdmissionRequest','propose-candidate','current-frame',Candidate].

mm_dispatch_snapshot(['DispatchContext',Bundle,Global,Frame,Mode,Raw]) :-
    eval([frameStateForMetaMo],Current), Current=['FrameStateBundle'|_],
    maplist(mm_dispatch_schedule_field, Current, Bundle),
    eval([constitutionalMode],Mode),
    (mm_dispatch_policies(Global,Frame) -> true; Global=[], Frame=[]),
    findall(K-V, (nb_current(K,V), atom(K), sub_atom(K,0,6,_,'&cfv2-')), Unsorted),
    sort(Unsorted,FrameRaw),
    eval([commchannel], Channel),
    mm_dispatch_route(Channel, Route),
    eval(['get-state','&prepared-host-operation'], Prepared),
    eval(['get-state','&answered-operation-key'], Answered),
    eval(['get-state','&host-task-requirements'], Requirements),
    eval(['get-state','&host-continuation'], Continuation),
    eval(['get-state','&continuation-evidence'], Evidence),
    eval(['get-state','&continuation-recovery'], Recovery),
    eval(['get-state','&continuation-clarification'], Clarification),
    (mm_completion_policy(Criterion,Destination) -> Completion=[Criterion,Destination]
     ; Completion=['Disabled',""]),
    Raw=[completion-policy-Completion,channel-Channel,route-Route,prepared-Prepared,answered-Answered,
         requirements-Requirements,continuation-Continuation,continuation-evidence-Evidence,
         continuation-recovery-Recovery,continuation-clarification-Clarification|FrameRaw].

% Example: native identity stays data across the Python provider boundary.
mm_response_context(Context, [Session,Frame,Commitment,Task,Input,ResponseInput,Transport]) :-
    eval(['get-state','&operation-context'], Context),
    Context=['OperationContext',Session,_,Frame], Frame \== [],
    commitmentSnapshot(Commitment),
    eval(['get-state','&active-task'], Task),
    eval(['get-state','&cfv2-last-admitted-frame-id'], Input),
    eval(['get-state','&host-response-input'], ResponseInput),
    eval(['get-state','&host-transport-input'], Transport).

% Example: only the current, provisioned host assessment can authorize preparation.
mm_response_conversation(Owner, Requirements) :-
    Owner=[_,Frame,Commitment,_,Frame,_,_],
    mm_dispatch_task_owner(Commitment), mm_dispatch_owner(Commitment),
    \+ mm_dispatch_busy,
    eval(['get-state','&host-continuation'], []),
    eval(['get-state','&host-task-requirements'], Requirements),
    Requirements=['HostTaskRequirements',Owner,[],['RequiredWork',[]],
                  ['RequirementAssessment','Conversational',Reason],['AssessedRequest',Request]],
    memberchk(Reason,['BoundedGreeting','ValidatedProposal']),
    string(Request), string_length(Request,Length), Length > 0, Length =< 4096.

% Example: an exact retained contract is rechecked both before and after inference.
mm_response_contract('', _) :- !.
mm_response_contract(Source, Owner) :-
    sread(Source, Expected), mm_response_proof(Expected, Owner).

% Example: the retained read proof cannot be replaced while inference is running.
mm_response_proof(Expected, Owner) :-
    Expected=['ContinuationEvidence'|_], !,
    mm_response_continuation(Owner, Current, _, _, _), Current == Expected.
mm_response_proof(Expected, Owner) :-
    mm_response_conversation(Owner, Current), Current == Expected.

% Example: a completed B-then-A plan supplies B and A's actual Core results in that order.
% This collector is read-specific; retention and response publication remain separate.
mm_response_continuation(Owner, Proof, Paths, Observations, Pairs) :-
    Owner=[Session,Frame,Commitment|_],
    Commitment=['CommitmentSnapshot',Id,Frame,Revision,'Open',_],
    commitmentSnapshot(Current), Current == Commitment, mm_dispatch_owner_current,
    \+ mm_dispatch_busy,
    eval(['get-state','&host-continuation'],
         ['HostContinuation',Session,Id,Frame,Revision,Plan,'AwaitingCompletion',[]]),
    eval(['get-state','&continuation-evidence'], Proof),
    Proof=['ContinuationEvidence',Session,Commitment,Plan,Steps,Reversed],
    is_list(Steps), length(Steps,Count), between(1,16,Count),
    reverse(Reversed,Observations), same_length(Steps,Observations),
    maplist(mm_plan_read_evidence(Session,Frame,Commitment),Steps,Observations,Paths,Pairs).

% Example: forged text, failed reads and results from a different session cannot be evidence.
mm_plan_read_evidence(Session,Frame,Owner,['ExecutionStep',_,Command],Outcome,Path,[Owner,Outcome]) :-
    Command=['read-file',Path],
    Outcome=['OperationOutcome',Decision,['attempted-command',Command],'Success',Result],
    Decision=['OperationDecision',['OperationContext',Session,_,Frame],'execute-skill',Command,Ticket],
    Result=['DispatchResult','Executed','Feasible',Text], string(Text),
    oc_dispatch_result(Ticket,Command,Recorded), Recorded == Result.

% Example: queueing binds the completed-plan proof to the current response owner.
mm_response_plan_contract(ExpectedOwner, Source) :-
    with_mutex(omegaclaw_dispatch, (
        sread(ExpectedOwner,Owner), mm_response_context(_,Current), Current == Owner,
        sread(Source,Expected), Expected=['ContinuationEvidence'|_],
        mm_response_proof(Expected,Owner))).

% Example: obtain bounded evidence from host state, never a model-supplied history.
mm_continuation_response_input(OwnerSource, ProofSource, Request, Paths, Observations, Provider) :-
    with_mutex(omegaclaw_dispatch, (
        mm_response_context(_,Owner),
        mm_response_continuation(Owner,Proof,Paths,Observations,_),
        Owner=[_,_,['CommitmentSnapshot',_,_,_,'Open',Summary],_,_,Input,_],
        mm_continuation_request(Input,Summary,Request),
        eval([provider],Provider), swrite(Owner,OwnerSource), swrite(Proof,ProofSource))).

% Example: a follow-up stays attached to the current task's summary.
mm_continuation_request(['HostResponseInput',_,'FollowUp',Message],Summary,Request) :- !,
    atomics_to_string([Summary,Message],"\n",Request).
mm_continuation_request(['HostResponseInput',_,Kind,Message],_,Message) :-
    memberchk(Kind,['NewTask','Replace']), !.
mm_continuation_request(_,Summary,Summary).

% Example: queuing a conversational request cannot borrow another task's eligibility.
mm_response_conversation_source(ExpectedOwner, RequestSource, Requirements, Source) :-
    with_mutex(omegaclaw_dispatch, (
        sread(ExpectedOwner, Expected), mm_response_context(_,Owner), Owner == Expected,
        sread(RequestSource, Request),
        mm_response_conversation(Owner,Requirements),
        last(Requirements,['AssessedRequest',Assessed]), Assessed == Request,
        swrite(Requirements,Source))).

% Example: capture precedes provider calls and retains the full dispatch snapshot.
mm_response_capture(ExpectedOwner, Contract, Context, ContextSource, Snapshot, Epoch, Answered) :-
    with_mutex(omegaclaw_dispatch, (
        oc_dispatch_mutate(eval(['change-state!','&prepared-host-operation',[]],_)),
        sread(ExpectedOwner,Expected), mm_response_context(Context,Owner), Owner == Expected,
        mm_response_contract(Contract,Owner),
        eval(['get-state','&active-frame-bundle'],Bundle), eval([frameStateForMetaMo],Bundle),
        mm_dispatch_snapshot(Current), term_string(Current,Snapshot),
        swrite(Context,ContextSource), oc_dispatch_epoch(Epoch),
        eval(['get-state','&answered-operation-key'],Answered))).

% Example: this marker expresses answer readiness, never task completion.
mm_response_readiness('ConversationNoTools', Contract, Owner, Task,
                      ['NoToolEvidenceReady','Conversation',Task]) :-
    Contract \== '', mm_response_contract(Contract,Owner).
mm_response_readiness('ReadEvidence', Contract, Owner, Task, ['ReadEvidenceReady',Task]) :-
    mm_response_contract(Contract,Owner).
mm_response_readiness('', '', _, _, 'NoReadReadiness').

% Example: validated response text is wrapped by the existing fixed send catalog.
mm_response_value(['ResponsePrepared',Text], Template, Readiness, Contract,
                  Context, Owner, Key, Raw, Value) :- !,
    Context=['OperationContext',_,_,Frame], Owner=[_,_,Commitment,Task|_],
    sread(Template,Binding),
    Binding=['HostCommandBinding',_,Request,
        ['PolicyOperation',Candidate,_,Skill,Permissions,Egress,Costs]],
    Operation=['PolicyOperation',Candidate,[target,Frame],Skill,Permissions,Egress,Costs],
    mm_response_readiness(Readiness,Contract,Owner,Task,Ready),
    memberchk(channel-Channel,Raw), memberchk(route-Route,Raw),
    Value=['PreparedHostOperation',Context,Commitment,[send,Text],Request,Operation,
           Ready,Key,['PreparedRouting',Channel,Route]].
mm_response_value(['ResponseNoAction',Reason], _, _, _, _, _, _, _, ['ResponseNoAction',Reason]).

% Example: stale input, requirements, route or policy cannot publish a generated send.
mm_response_publish(ExpectedOwner, Contract, ContextSource, Snapshot, Epoch,
                    PreparedSource, Template, Readiness, Key) :-
    with_mutex(omegaclaw_dispatch, (
        oc_dispatch_epoch(Epoch), mm_dispatch_snapshot(Current),
        term_string(ExpectedSnapshot,Snapshot), Current == ExpectedSnapshot,
        Current=['DispatchContext',_,_,_,_,Raw],
        sread(ExpectedOwner,Expected), mm_response_context(Context,Owner), Owner == Expected,
        mm_response_contract(Contract,Owner),
        sread(ContextSource,ExpectedContext), Context == ExpectedContext,
        sread(PreparedSource,Prepared),
        mm_response_value(Prepared,Template,Readiness,Contract,Context,Owner,Key,Raw,Value),
        oc_dispatch_mutate(eval(['change-state!','&prepared-host-operation',[quote,Value]],_)))).

% Example: Core updates next-wake-at after capture and before command generation.
% This scheduling timestamp grants no authority. Preserve every other field,
% including wake-loop budget, task identity and all native frame/policy state.
mm_dispatch_schedule_field([runtime,['FrameStateRuntime'|Fields]],
                           [runtime,['FrameStateRuntime'|Stable]]) :- !,
    maplist(mm_dispatch_wake_field, Fields, Stable).
mm_dispatch_schedule_field(Value, Value).
mm_dispatch_wake_field(['next-wake-at',_], ['next-wake-at',0]) :- !.
mm_dispatch_wake_field(Value, Value).

mm_dispatch_route(irc, Route) :- !,
    py_call(host_operations:irc_route_snapshot(), Source), sread(Source, Parsed), Route=Parsed.
mm_dispatch_route(_, none).

dispatchRoutingAllowed(Destinations, Result) :-
    eval([commchannel], Channel),
    ( (Channel == local, Destinations == ["local:stdout"]
      ; Channel == irc, mm_dispatch_route(irc, ['IrcRoute',Egress,_, 'Ready']),
        Destinations == [Egress]) -> Result=true ; Result=false).

mm_dispatch_operation_route(Operation) :-
    (memberchk([skill,"send"], Operation)
     -> memberchk([egress,Destinations], Operation), dispatchRoutingAllowed(Destinations,true)
     ; true).

% Core holds its mutex before acquiring the transport guard. The IRC receiver
% owns only its route lock and must never call the interpreter while holding it.
mm_dispatch_enter_route(Token) :-
    eval([commchannel], Channel),
    (Channel == irc -> py_call(host_operations:acquire_irc_route(), 1), Token=irc
     ; Token=none).
mm_dispatch_leave_route(irc) :- !, py_call(host_operations:release_irc_route(), 1).
mm_dispatch_leave_route(none).
mm_dispatch_resolve(Intent, Command, Operation) :-
    mm_dispatch_owner_current,
    mm_dispatch_binding(Command,Intent,Operation).
mm_dispatch_resolve(Intent, Command, Operation) :-
    mm_dispatch_owner_current,
    eval([preparedHostBinding], ['HostCommandBinding',Command,Intent,Operation]),
    eval(['get-state','&prepared-host-operation'],
         ['PreparedHostOperation',_,_,Command,Intent,Operation,_,_,
          ['PreparedRouting',Channel,Route]]),
    eval([commchannel], Channel), mm_dispatch_route(Channel, Current), Route == Current.
mm_dispatch_gate(Intent, ['DispatchContext',Bundle,Global,Frame,_,_], Operation, Decision) :-
    eval([dispatchOperationGate, [quote,Bundle], [quote,Bundle],
          [quote,Intent], [quote,Operation], [quote,Global], [quote,Frame]],Decision).
mm_dispatch_execute(_, Command, Result) :- eval(Command,Result).

initMetaMoDispatch(true) :-
    retractall(mm_completion_policy(_,_)),
    oc_dispatch_configure(mm_dispatch_snapshot,mm_dispatch_resolve,mm_dispatch_gate,mm_dispatch_execute),
    oc_dispatch_configure_guard(mm_dispatch_enter_route,mm_dispatch_leave_route),
    retractall(oc_dispatch_intent(_)), assertz(oc_dispatch_intent(mm_dispatch_intent)).

% Example: policy is installed atomically with the task's dispatch configuration.
mm_completion_install(Source) :-
    sread(Source, Policy), Policy=['CompletionPolicy',Criterion,Destination],
    retractall(mm_completion_policy(_,_)),
    assertz(mm_completion_policy(Criterion,Destination)).

% Example: only a real selected, prepared answer can publish completion.
% Preserve the existing hook name for callers; read plans use the F2.5 read contract.
% Reuse Core's immutable ticket/result and F2.6 replay/transaction handling.
completeHostConversation(Result) :-
    with_mutex(omegaclaw_dispatch,
      ((mm_conversation_completion(Requirements,Evidence,Ticket);
        mm_read_completion(Requirements,Evidence,Ticket))
       -> term_string(Ticket,Key),
          string_concat("conversation-outcome:",Key,Outcome),
          string_concat("conversation-event:",Key,Event),
          mm_commitment_complete(Outcome,Event,Requirements,Evidence,Result)
       ; Result=['CompletionSkipped','NoMatchingConversation'])).

% Example: classification alone, a clarification, or a predecessor ticket cannot close work.
mm_conversation_completion(Requirements,[[Commitment,Outcome]],Ticket) :-
    mm_completion_policy(Criterion,Destination), Criterion \== 'Disabled',
    mm_response_context(Context,Owner), mm_response_conversation(Owner,Assessment),
    Owner=[_,_,Commitment,Task|_],
    eval(['get-state','&prepared-host-operation'],
         ['PreparedHostOperation',Context,Commitment,Command,_,_,
          ['NoToolEvidenceReady','Conversation',Task],_,_]),
    eval(['get-state','&selected-operation-decision'],Decision),
    Decision=['OperationDecision',Context,respond,Command,Ticket],
    eval(['get-state','&last-operation-outcome'],Outcome),
    Outcome=['OperationOutcome',Decision,['attempted-command',Command],'Success',Result],
    eval([validateOperationOutcome,[quote,Outcome]],'OutcomeValid'),
    oc_dispatch_result(Ticket,Command,Result),
    oc_dispatch_ticket(Ticket,_,_,['DispatchContext',_,_,_,_,Raw]),
    memberchk(requirements-Captured,Raw), Captured == Assessment,
    memberchk(completion-policy-[Criterion,Destination],Raw),
    Requirements=['CompletionRequirements',Commitment,
        ['NoToolRequirements',Assessment,Criterion],['RequiredAnswer',Decision,Destination]].


% Example: only a successful prepared answer plus all retained reads can close a read plan.
% F2.5's read-answer contract currently supports LocalAccepted, not IRC acknowledgement.
mm_read_completion(Requirements,Evidence,Ticket) :-
    mm_completion_policy('LocalAccepted',"local:stdout"),
    mm_response_context(Context,Owner), Owner=[_,_,Commitment,Task|_],
    mm_response_continuation(Owner,Proof,_,Observations,ReadPairs),
    eval(['get-state','&prepared-host-operation'],
         ['PreparedHostOperation',Context,Commitment,Command,_,_,['ReadEvidenceReady',Task],_,_]),
    eval(['get-state','&selected-operation-decision'],Decision),
    Decision=['OperationDecision',Context,respond,Command,Ticket],
    eval(['get-state','&last-operation-outcome'],Outcome),
    Outcome=['OperationOutcome',Decision,['attempted-command',Command],'Success',Result],
    eval([validateOperationOutcome,[quote,Outcome]],'OutcomeValid'),
    oc_dispatch_result(Ticket,Command,Result),
    oc_dispatch_ticket(Ticket,_,_,['DispatchContext',_,_,_,_,Raw]),
    memberchk(continuation-evidence-Captured,Raw), Captured == Proof,
    memberchk(completion-policy-['LocalAccepted',"local:stdout"],Raw),
    maplist(mm_read_decision,Observations,Reads),
    append(ReadPairs,[[Commitment,Outcome]],Evidence),
    Requirements=['CompletionRequirements',Commitment,Reads,
                  ['RequiredAnswer',Decision,"local:stdout"]].

% Example: completion requires the exact read decisions, including their original tickets.
mm_read_decision(['OperationOutcome',Decision,_,_,_],Decision).


% Example: only a provisioned admitted task at an empty selection slot may propose a plan.
mm_read_plan_context(Owner, Context, Request, Snapshot, Epoch) :-
    mm_response_context(Context,Owner),
    Owner=[Session,Frame,Commitment,_,Frame,Input,_],
    mm_dispatch_task_owner(Commitment), mm_dispatch_owner(Commitment),
    Input=['HostResponseInput',Frame,Kind,_], memberchk(Kind,['NewTask','Replace','FollowUp']),
    Commitment=['CommitmentSnapshot',_,Frame,_,'Open',Summary],
    Context=['OperationContext',Session,_,Frame],
    \+ mm_dispatch_busy,
    eval(['get-state','&selected-operation-decision'],[]),
    eval(['get-state','&selected-host-operation'],[]),
    eval([continuationSlotAvailable,[quote,Session],[quote,Commitment]],true),
    mm_continuation_request(Input,Summary,Request),
    mm_dispatch_snapshot(Current), term_string(Current,Snapshot), oc_dispatch_epoch(Epoch).

% Example: a follow-up or policy mutation during extraction cannot install stale work.
mm_install_read_plan(OwnerSource,ContextSource,Snapshot,Epoch,IdSource,StepsSource,Text) :-
    with_mutex(omegaclaw_dispatch, (
        sread(OwnerSource,ExpectedOwner), sread(ContextSource,ExpectedContext),
        (mm_read_plan_context(Owner,Context,_,CurrentSnapshot,Epoch),
         Owner == ExpectedOwner, Context == ExpectedContext,
         term_string(ExpectedSnapshot,Snapshot), term_string(CurrentState,CurrentSnapshot),
         CurrentState == ExpectedSnapshot
         -> sread(IdSource,Id), sread(StepsSource,Steps),
            eval([hostAdmitContinuation,[quote,Id],[quote,Steps]],Admission),
            Owner=[_,_,Commitment|_],
            (Admission=['ContinuationAdmitted'|_]
             -> eval([hostInstallAdmittedContinuation,[quote,Context],[quote,Commitment],
                      [quote,Admission]],Result)
             ; Result=Admission)
         ; Result=['ContinuationRejected','StaleInput']),
        swrite(Result,Text))).

% Example: an unallowed read request cannot fall back to an unrelated catalog read.
hostReadPlanRequired(Result) :-
    (mm_response_context(_, [Session,Frame,Commitment|_]),
     mm_dispatch_task_owner(Commitment), mm_dispatch_owner(Commitment),
     eval(['get-state','&host-task-requirements'],
          ['HostTaskRequirements',[Session,Frame,Commitment|_],_,['RequiredWork',Work],_,_]),
     memberchk('Files',Work)
     -> Result=true ; Result=false).
