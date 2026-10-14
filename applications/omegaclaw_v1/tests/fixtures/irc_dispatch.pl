irc_test_gate(Intent, Context, Operation, Decision) :-
    mm_dispatch_gate(Intent, Context, Operation, Decision),
    (Decision == ['GateDecision','Admitted','Feasible']
     -> py_call(irc_routing_fixture:start_writer(), 1) ; true).

installIrcTestGate(true) :-
    % Test instrumentation after capture: preserve policy, context and epoch.
    % The real gate still runs; the wrapper only starts a concurrent writer.
    retract(oc_dispatch_hooks(S,R,mm_dispatch_gate,E)),
    assertz(oc_dispatch_hooks(S,R,irc_test_gate,E)).
