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
    Raw=[channel-Channel,route-Route,prepared-Prepared,answered-Answered|FrameRaw].

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
