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

% Example: simulate a trusted meter update using Core's mutation lock and epoch.
hostBudgetFixturePublish(Snapshot, true) :-
    ground(Snapshot),
    oc_dispatch_mutate(eval(['change-state!','&budget-account-state',[quote,Snapshot]],_)).

% Example: a new native frame adds capacity without resetting global consumption.
hostBudgetFixtureFrame(Id, true) :-
    mm_dispatch_policies(Global,['PolicyScope',_|Fields]),
    mm_dispatch_set_policies(Global,['PolicyScope',[target,['FrameTarget',Id]]|Fields]).

% Example: malformed accounting cannot be repaired by ordinary reprovisioning.
hostBudgetFixtureRejectProvision(true) :-
    mm_dispatch_policies(Global,Frame),
    eval(['get-state','&budget-account-state'],Before),
    \+ mm_dispatch_set_policies(Global,Frame),
    eval(['get-state','&budget-account-state'],After), Before == After.

% Example: read the same projected policies consumed by production dispatch.
hostBudgetFixturePolicies([Global,Frame]) :-
    with_mutex(omegaclaw_dispatch,mm_dispatch_live_policies(Global,Frame,_)).

% Example: revoking a task's grants must not discard any accounting state.
hostBudgetFixtureRevoke(true) :- mm_dispatch_set_policies([],[]).

% Example: reserve through the existing component under the host mutation lock.
hostBudgetFixtureReserve(Ticket, Operation, Costs, Result) :-
    oc_dispatch_mutate(eval([reserveOperationBudget,[quote,Ticket],
                            [quote,Operation],[quote,Costs]],Result)).
