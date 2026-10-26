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

% Example: a synthetic failing handler still declares its real skill and unit cost.
hostFailureFixtureScope(['PolicyScope',Target,[skills,Skills],Permissions,Egress,
                        [constraints,Constraints],Budgets],
                       ['PolicyScope',Target,[skills,Allowed],Permissions,Egress,
                        [constraints,Restrictions],Budgets]) :-
    (memberchk("read-file",Skills)
     -> sort(["outcome-test-failure"|Skills],Allowed) ; Allowed=Skills),
    (memberchk(['DenySkill',"read-file"],Constraints)
     -> Restrictions=[['DenySkill',"outcome-test-failure"]|Constraints]
     ; Restrictions=Constraints).
hostFailureFixtureInstall :-
    oc_dispatch_mutate((
        mm_dispatch_policies(Global,Frame),
        maplist(hostFailureFixtureScope,[Global,Frame],[NewGlobal,NewFrame]),
        mm_dispatch_set_policies(NewGlobal,NewFrame),
        mm_dispatch_binding(Command,Request,['PolicyOperation',Candidate,Target,_|Fields]),
        Command=['read-file',_],
        mm_dispatch_revoke(Command),
        mm_dispatch_register(['outcome-test-failure'],Request,
            ['PolicyOperation',Candidate,Target,[skill,"outcome-test-failure"]|Fields]))).

% Example: deliver a duplicate or forged observation through the trusted callback.
hostBudgetFixtureSettle(Ticket, Command, Reported, Settlement) :-
    oc_dispatch_mutate((
        eval(['get-state','&budget-account-state'],['BudgetAccounts',_,Records]),
        eval([baFindReservation,[quote,Records],[quote,Ticket]],Record),
        eval([baOriginalReservation,[quote,Record]],
             ['BudgetReservation',_,['BudgetOperation',_,Operation],_,_]),
        mm_budget_settle(Ticket,Operation,Command,Reported,Settlement))).

% Example: lose the result after a visible handler effect; Core retains uncertainty.
hostBudgetFixturePartialExecute(_,_,_) :-
    eval(['get-state','&budget-test-effects'],Before), After is Before+1,
    eval(['change-state!','&budget-test-effects',After],_), throw(partial_effect).
hostBudgetFixtureExecutor(Mode, true) :-
    memberchk(Mode-Execute,[uncertain-hostBudgetFixturePartialExecute,normal-mm_dispatch_execute]),
    oc_dispatch_mutate((retract(oc_dispatch_hooks(S,R,G,_)),
                       assertz(oc_dispatch_hooks(S,R,G,Execute)))).
