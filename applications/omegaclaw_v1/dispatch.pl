% Trusted host adapter for the session dispatcher. No model-accessible policy
% setters or registration functions are exported to MeTTa. Provision exact
% command/metadata bindings and typed policies from host configuration.
:- dynamic mm_dispatch_binding/3, mm_dispatch_policies/2, mm_dispatch_owner/1.

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
    Raw=[channel-Channel,route-Route,prepared-Prepared,answered-Answered,
         requirements-Requirements,continuation-Continuation|FrameRaw].

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
    sread(Source, Expected), mm_response_conversation(Owner, Current), Current == Expected.

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
mm_response_readiness('ReadEvidence', '', _, Task, ['ReadEvidenceReady',Task]).
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
    oc_dispatch_configure(mm_dispatch_snapshot,mm_dispatch_resolve,mm_dispatch_gate,mm_dispatch_execute),
    oc_dispatch_configure_guard(mm_dispatch_enter_route,mm_dispatch_leave_route),
    retractall(oc_dispatch_intent(_)), assertz(oc_dispatch_intent(mm_dispatch_intent)).
