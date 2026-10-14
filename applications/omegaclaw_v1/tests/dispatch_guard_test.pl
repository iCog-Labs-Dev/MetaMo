:- prolog_load_context(directory, Dir),
   (getenv('OMEGACLAW_CORE_TEST_ROOT', Core)
    -> directory_file_path(Core, 'src/dispatch.pl', Source)
    ; directory_file_path(Dir, '../../../../repos/OmegaClaw-Core/src/dispatch.pl', Source)),
   ensure_loaded(Source).
:- use_module(library(plunit)).
:- dynamic guard_held/0, guard_releases/1, guard_effects/1.

guard_enter(token) :- assertz(guard_held).
guard_leave(token) :- retractall(guard_held), retract(guard_releases(N)),
                      M is N+1, assertz(guard_releases(M)).
guard_fail(_) :- throw(unavailable).
guard_snapshot(context).
guard_resolve(work, [send,"text"], operation).
guard_gate(_,_,_,['GateDecision','Admitted','Feasible']) :- guard_held.
guard_deny(_,_,_,['GateDecision','Rejected','PermissionDenied']).
guard_execute(_,_,done) :- guard_held, retract(guard_effects(N)),
                          M is N+1, assertz(guard_effects(M)).
guard_partial(Op,C,_) :- guard_execute(Op,C,_), throw(partial).
guard_setup :-
    retractall(guard_held), retractall(guard_releases(_)), assertz(guard_releases(0)),
    retractall(guard_effects(_)), assertz(guard_effects(0)),
    oc_dispatch_configure(guard_snapshot,guard_resolve,guard_gate,guard_execute),
    oc_dispatch_configure_guard(guard_enter,guard_leave).

:- begin_tests(dispatch_guard, [setup(guard_setup)]).
test(held_through_gate_and_invocation, [setup(guard_setup)]) :-
    coreDispatchCapture(work,T), coreDispatch(T,[send,"text"],R),
    assertion(R == ['DispatchResult','Executed','Feasible',done]),
    assertion(guard_effects(1)), assertion(guard_releases(1)), assertion(\+ guard_held),
    coreDispatch(T,[send,"text"],Replay), assertion(Replay == R),
    assertion(guard_effects(1)), assertion(guard_releases(2)).
test(rejection_releases_guard, [setup(guard_setup)]) :-
    retract(user:oc_dispatch_hooks(S,R,_,E)), assertz(user:oc_dispatch_hooks(S,R,guard_deny,E)),
    coreDispatchCapture(work,T), coreDispatch(T,[send,"text"],Result),
    assertion(Result == ['DispatchResult','Blocked','PermissionDenied',none]),
    assertion(guard_effects(0)), assertion(guard_releases(1)), assertion(\+ guard_held).
test(exception_releases_guard_and_preserves_uncertainty, [setup(guard_setup)]) :-
    retract(user:oc_dispatch_hooks(S,R,G,_)), assertz(user:oc_dispatch_hooks(S,R,G,guard_partial)),
    coreDispatchCapture(work,T), coreDispatch(T,[send,"text"],Result),
    assertion(Result == ['DispatchResult','Unobserved','ExecutionUncertain',none]),
    assertion(guard_releases(1)), assertion(\+ guard_held),
    coreDispatch(T,[send,"text"],Result), assertion(guard_effects(1)).
test(acquire_failure_is_closed, [setup(guard_setup)]) :-
    oc_dispatch_configure_guard(guard_fail,guard_leave),
    coreDispatchCapture(work,T), coreDispatch(T,[send,"text"],Result),
    assertion(Result == ['DispatchResult','Blocked','MissingPolicyContext',none]),
    assertion(guard_effects(0)), assertion(guard_releases(0)).
test(reconfiguration_clears_guard, [setup(guard_setup)]) :-
    oc_dispatch_configure(guard_snapshot,guard_resolve,guard_gate,guard_execute),
    assertion(\+ oc_dispatch_guard(_,_)).
:- end_tests(dispatch_guard).
:- initialization((run_tests -> halt(0); halt(1)), main).
