:- prolog_load_context(directory, Dir),
   (getenv('OMEGACLAW_CORE_TEST_ROOT', Core)
    -> directory_file_path(Core, 'src/dispatch.pl', Source)
    ; directory_file_path(Dir, '../../../../repos/OmegaClaw-Core/src/dispatch.pl', Source)),
   ensure_loaded(Source).
:- use_module(library(plunit)).
:- dynamic guard_held/0, guard_releases/1, guard_effects/1.
:- dynamic guard_reserved/1, guard_spent/1.

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

% Example: reserve requires the route lock, and execution sees claimed capacity.
guard_reserve(_,_,_,['GateDecision','Admitted','Feasible']) :-
    guard_held, retract(guard_reserved(N)), M is N+1, assertz(guard_reserved(M)).
guard_reserve_deny(_,_,_,['GateDecision','Rejected','BudgetExhausted']).
guard_accounted_execute(Op,C,Value) :- guard_reserved(1), guard_execute(Op,C,Value).
guard_settle(Ticket,_,Command,Result,settled) :-
    guard_held, oc_dispatch_result(Ticket,Command,Result),
    retract(guard_reserved(1)), assertz(guard_reserved(0)),
    retract(guard_spent(N)), M is N+1, assertz(guard_spent(M)).
guard_settle_fail(_,_,_,_,_) :- throw(lost_callback).
guard_accounting_setup :-
    guard_setup,
    retractall(guard_reserved(_)), assertz(guard_reserved(0)),
    retractall(guard_spent(_)), assertz(guard_spent(0)),
    retract(oc_dispatch_hooks(S,R,G,_)),
    assertz(oc_dispatch_hooks(S,R,G,guard_accounted_execute)),
    oc_dispatch_configure_accounting(guard_reserve,guard_settle).
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

test(reservation_precedes_invocation_and_replay_is_free, [setup(guard_accounting_setup)]) :-
    coreDispatchCapture(work,T), coreDispatch(T,[send,"text"],R),
    assertion(R == ['DispatchResult','Executed','Feasible',done]),
    assertion(guard_effects(1)), assertion(guard_spent(1)), assertion(guard_reserved(0)),
    coreDispatch(T,[send,"text"],R),
    assertion(guard_effects(1)), assertion(guard_spent(1)),
    assertion(oc_dispatch_accounting_result(T,settled)).

test(reservation_denial_never_invokes, [setup(guard_accounting_setup)]) :-
    oc_dispatch_configure_accounting(guard_reserve_deny,guard_settle),
    coreDispatchCapture(work,T), coreDispatch(T,[send,"text"],R),
    assertion(R == ['DispatchResult','Blocked','BudgetExhausted',none]),
    assertion(guard_effects(0)), assertion(guard_reserved(0)), assertion(guard_spent(0)).

test(lost_settlement_preserves_capacity_and_receipt, [setup(guard_accounting_setup)]) :-
    oc_dispatch_configure_accounting(guard_reserve,guard_settle_fail),
    coreDispatchCapture(work,T), coreDispatch(T,[send,"text"],R),
    assertion(R == ['DispatchResult','Executed','Feasible',done]),
    assertion(guard_reserved(1)), assertion(guard_spent(0)),
    assertion(oc_dispatch_accounting_result(T,['AccountingPending','SettlementUnavailable'])),
    coreDispatch(T,[send,"text"],R), assertion(guard_effects(1)), assertion(guard_reserved(1)).

test(competing_tickets_cannot_both_spend, [setup(guard_accounting_setup)]) :-
    coreDispatchCapture(work,A), coreDispatchCapture(work,B),
    thread_create(coreDispatch(A,[send,"text"],_),First,[]),
    thread_create(coreDispatch(B,[send,"text"],_),Second,[]),
    thread_join(First,true), thread_join(Second,true),
    assertion(guard_effects(1)), assertion(guard_spent(1)),
    assertion(guard_reserved(0)).

test(reconfiguration_clears_accounting_hooks, [setup(guard_accounting_setup)]) :-
    oc_dispatch_configure(guard_snapshot,guard_resolve,guard_gate,guard_execute),
    assertion(\+ oc_dispatch_accounting(_,_)).
:- end_tests(dispatch_guard).
:- initialization((run_tests -> halt(0); halt(1)), main).
