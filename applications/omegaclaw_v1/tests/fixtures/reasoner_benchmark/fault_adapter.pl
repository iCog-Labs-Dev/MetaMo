% Test-only lost service result after selection, using the existing visible-effect executor double.
% Example: benchmarkFaultLoseResult(true) leaves the retained operation/ticket unchanged.
benchmarkFaultLoseResult(true) :-
    with_mutex(omegaclaw_dispatch,
        (retract(oc_dispatch_hooks(S,R,G,E)),
         nb_setval(benchmark_fault_executor,E),
         assertz(oc_dispatch_hooks(S,R,G,hostBudgetFixturePartialExecute)))).

% Example: restore the real executor in the actual callback; held invocation evidence remains intact.
benchmarkFaultRestore(true) :-
    (nb_current(benchmark_fault_executor,E)
        -> with_mutex(omegaclaw_dispatch,
             (retract(oc_dispatch_hooks(S,R,G,_)),
              assertz(oc_dispatch_hooks(S,R,G,E)))),
           nb_delete(benchmark_fault_executor)
        ; true).

% Example: count real handler invocations to prove a duplicate dispatch never reads again.
benchmarkFaultCountResult(true) :-
    with_mutex(omegaclaw_dispatch,
        (retract(oc_dispatch_hooks(S,R,G,E)),
         nb_setval(benchmark_fault_executor,E),
         assertz(oc_dispatch_hooks(S,R,G,benchmarkFaultCountExecute)))).

% Example: delegate the actual selected file operation after incrementing the test-only counter.
benchmarkFaultCountExecute(Context,Command,Result) :-
    eval(['get-state','&budget-test-effects'],Before), After is Before+1,
    eval(['change-state!','&budget-test-effects',After],_),
    nb_getval(benchmark_fault_executor,E), call(E,Context,Command,Result).
