dispatchFixtureSnapshot(Context) :- eval([dispatchTestContext],Context).
initDispatchFixture(true) :-
    oc_dispatch_configure(dispatchFixtureSnapshot,mm_dispatch_resolve,mm_dispatch_gate,mm_dispatch_execute),
    retractall(mm_dispatch_binding(_,_,_)),
    eval([dispatchTestRequest],Request), eval([dispatchTestOperation],Operation),
    mm_dispatch_register(['dispatch-test-execute'],Request,Operation).
