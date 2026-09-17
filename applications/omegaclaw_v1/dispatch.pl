% Trusted host adapter for the session dispatcher. No model-accessible policy
% setters or registration functions are exported to MeTTa. Provision exact
% command/metadata bindings and typed policies from host configuration.
:- dynamic mm_dispatch_binding/3, mm_dispatch_policies/2.

mm_dispatch_register(Command, Request, Operation) :-
    ground(Command-Request-Operation), is_list(Command), Command=[_|_],
    oc_dispatch_mutate((retractall(mm_dispatch_binding(Command,_,_)),
                       assertz(mm_dispatch_binding(Command,Request,Operation)))).
mm_dispatch_set_policies(Global, Frame) :-
    ground(Global-Frame),
    oc_dispatch_mutate((retractall(mm_dispatch_policies(_,_)),
                       assertz(mm_dispatch_policies(Global,Frame)))).
mm_dispatch_revoke(Command) :-
    oc_dispatch_mutate(retractall(mm_dispatch_binding(Command,_,_))).

mm_dispatch_intent(Intent) :-
    eval(['get-state','&last-meta-mo-policy-output'], Policy),
    Policy=['MetaMoPolicyOutput',_,['operation-class',Candidate],['feasibility','Admitted'],_],
    Candidate \== none,
    Intent=['AdmissionRequest','propose-candidate','current-frame',Candidate].

mm_dispatch_snapshot(['DispatchContext',Bundle,Global,Frame,Mode,Raw]) :-
    eval([frameStateForMetaMo],Bundle), Bundle=['FrameStateBundle'|_],
    eval([constitutionalMode],Mode),
    (mm_dispatch_policies(Global,Frame) -> true; Global=[], Frame=[]),
    findall(K-V, (nb_current(K,V), atom(K), sub_atom(K,0,6,_,'&cfv2-')), Unsorted),
    sort(Unsorted,Raw).
mm_dispatch_resolve(Intent, Command, Operation) :-
    mm_dispatch_binding(Command,Intent,Operation).
mm_dispatch_gate(Intent, ['DispatchContext',Bundle,Global,Frame,_,_], Operation, Decision) :-
    eval([feasibilityGateForRequest, [quote,Bundle], [quote,Bundle],
          [quote,Intent], [quote,Operation], [quote,Global], [quote,Frame]],Decision).
mm_dispatch_execute(_, Command, Result) :- eval(Command,Result).

initMetaMoDispatch(true) :-
    oc_dispatch_configure(mm_dispatch_snapshot,mm_dispatch_resolve,mm_dispatch_gate,mm_dispatch_execute),
    retractall(oc_dispatch_intent(_)), assertz(oc_dispatch_intent(mm_dispatch_intent)).
