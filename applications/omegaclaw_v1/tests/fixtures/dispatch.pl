dispatchFixtureSnapshot(Context) :- eval([dispatchTestContext],Context).
initDispatchFixture(true) :-
    oc_dispatch_configure(dispatchFixtureSnapshot,mm_dispatch_resolve,mm_dispatch_gate,mm_dispatch_execute),
    retractall(mm_dispatch_binding(_,_,_)),
    eval([dispatchTestRequest],Request), eval([dispatchTestOperation],Operation),
    mm_dispatch_register(['dispatch-test-execute'],Request,Operation).

% Test-only simulation of Core's pending/uncertain invocation record.
% Example: a recorded invocation blocks admission until trusted reconciliation.
taskProvisioningPending(true) :-
    assertz(oc_dispatch_result(['DispatchTicket',"pending-task-test"],['test-command'],
                              ['DispatchResult','Unobserved','ExecutionUncertain',none])).
taskProvisioningSettled(true) :-
    retractall(oc_dispatch_result(['DispatchTicket',"pending-task-test"],_,_)).
% Example: inspect the native owner stored with installed task bindings.
taskProvisioningOwner(Owner) :- mm_dispatch_owner(Owner).
