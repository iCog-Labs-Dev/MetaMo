:- ensure_loaded('../commitments.pl').
:- ensure_loaded('fixtures/commitments.pl').
:- ensure_loaded('../../../../repos/OmegaClaw-Core/src/dispatch.pl').
commitment_dispatch_snapshot(S) :- commitmentSnapshot(S).
commitment_dispatch_resolve(_,_,operation).
commitment_dispatch_gate(_,_,_,['GateDecision','Admitted','Feasible']).
commitment_dispatch_execute(_,_,unexpected_execution).
:- begin_tests(commitments, [setup(commitmentFixtureReset(_))]).

open_task :- mm_commitment_open("task-1","frame-1","Read the file",['CommitmentOpened',"task-1"]).
event(Change,E) :- E=['CommitmentEvent',"event-1","task-1",0,Change].

test(completed, [setup((commitmentFixtureReset(_),open_task))]) :-
    mm_commitment_record_outcome("outcome-1","task-1",0,'Completed',_),
    event(['Completed',"outcome-1"],E), mm_commitment_apply(E,R),
    assertion(R==['CommitmentApplied',"event-1","task-1",'Completed',1]),
    commitmentSnapshot(S), assertion(S==['CommitmentSnapshot',"task-1","frame-1",1,'Completed',"Read the file"]).
test(unconfirmed, [setup((commitmentFixtureReset(_),open_task))]) :-
    event(['Completed',"missing"],E), mm_commitment_apply(E,R),
    assertion(R==['CommitmentRejected','CompletionNotConfirmed']), mm_commitment("task-1",_,_,'Open',0).
test(failed_outcome, [setup((commitmentFixtureReset(_),open_task))]) :-
    mm_commitment_record_outcome("outcome-1","task-1",0,'Failed',_),
    event(['Completed',"outcome-1"],E), mm_commitment_apply(E,R),
    assertion(R==['CommitmentRejected','CompletionNotConfirmed']).
test(uncertain_outcome, [setup((commitmentFixtureReset(_),open_task))]) :-
    mm_commitment_record_outcome("outcome-1","task-1",0,'Unobserved',_),
    event(['Completed',"outcome-1"],E), mm_commitment_apply(E,R),
    assertion(R==['CommitmentRejected','CompletionNotConfirmed']).
test(abandoned, [setup((commitmentFixtureReset(_),open_task))]) :-
    event(['Abandoned',"User cancelled"],E), mm_commitment_apply(E,_),
    mm_commitment("task-1",_,_,'Abandoned',1), commitmentEvents([E]).
test(reason_required, [setup((commitmentFixtureReset(_),open_task)), forall(member(Reason,["","  ",none,[]]))]) :-
    event(['Abandoned',Reason],E), mm_commitment_apply(E,R),
    assertion(R==['CommitmentRejected','ReasonRequired']), commitmentEvents([]).
test(superseded, [setup((commitmentFixtureReset(_),open_task))]) :-
    event(['Superseded',"task-2","Read another file","User replaced the request"],E),
    mm_commitment_apply(E,_), mm_commitment("task-1",_,_,'Superseded',1),
    commitmentSnapshot(['CommitmentSnapshot',"task-2","frame-1",0,'Open',"Read another file"]),
    commitmentEvents([E]).
test(invalid_replacement_atomic, [setup((commitmentFixtureReset(_),open_task))]) :-
    event(['Superseded',"task-1","Other","Replacement"],E), mm_commitment_apply(E,R),
    assertion(R==['CommitmentRejected','IdentityConflict']), mm_commitment("task-1",_,_,'Open',0), commitmentEvents([]).
test(no_implicit_replacement, [setup((commitmentFixtureReset(_),open_task))]) :-
    mm_commitment_open("task-2","frame-1","Other",R),
    assertion(R==['CommitmentRejected','ActiveCommitmentExists']).
test(replay, [setup((commitmentFixtureReset(_),open_task))]) :-
    event(['Abandoned',"Cancelled"],E), mm_commitment_apply(E,A), mm_commitment_apply(E,B),
    assertion(A==B), commitmentEvents([E]), mm_commitment("task-1",_,_,'Abandoned',1).
test(conflicting_replay, [setup((commitmentFixtureReset(_),open_task))]) :-
    event(['Abandoned',"Cancelled"],E), mm_commitment_apply(E,_),
    event(['Abandoned',"Different"],Other), mm_commitment_apply(Other,R),
    assertion(R==['CommitmentRejected','ConflictingReplay']).
test(terminal_cannot_reopen, [setup((commitmentFixtureReset(_),open_task))]) :-
    event(['Abandoned',"Cancelled"],E), mm_commitment_apply(E,_),
    mm_commitment_open("task-1","frame-1","Read the file",R),
    assertion(R==['CommitmentRejected','IdentityConflict']).
test(stale_revision, [setup((commitmentFixtureReset(_),open_task))]) :-
    mm_commitment_apply(['CommitmentEvent',"event-1","task-1",1,['Abandoned',"Cancelled"]],R),
    assertion(R==['CommitmentRejected','StaleRevision']).
test(unknown, [setup(commitmentFixtureReset(_))]) :-
    event(['Abandoned',"Cancelled"],E), mm_commitment_apply(E,R),
    assertion(R==['CommitmentRejected','UnknownCommitment']).
test(malformed, [setup((commitmentFixtureReset(_),open_task)), forall(member(E,[[],['Completed'],['CommitmentEvent',"e","task-1",0,['Decay',0]]]))]) :-
    mm_commitment_apply(E,['CommitmentRejected',_]), mm_commitment("task-1",_,_,'Open',0).
test(late_old_completion, [setup((commitmentFixtureReset(_),open_task))]) :-
    mm_commitment_record_outcome("outcome-1","task-1",0,'Completed',_),
    event(['Superseded',"task-2","Other","Replacement"],E), mm_commitment_apply(E,_),
    mm_commitment_apply(['CommitmentEvent',"late","task-1",0,['Completed',"outcome-1"]],R),
    assertion(R==['CommitmentRejected','AlreadyTerminal']),
    mm_commitment_apply(['CommitmentEvent',"wrong","task-2",0,['Completed',"outcome-1"]],R2),
    assertion(R2==['CommitmentRejected','CompletionNotConfirmed']),
    mm_commitment("task-2",_,_,'Open',0).
test(commitment_mutation_invalidates_dispatch, [setup((commitmentFixtureReset(_),open_task))]) :-
    oc_dispatch_configure(commitment_dispatch_snapshot,commitment_dispatch_resolve,
      commitment_dispatch_gate,commitment_dispatch_execute),
    coreDispatchCapture(intent,Ticket),
    event(['Abandoned',"Cancelled"],E), mm_commitment_apply(E,_),
    coreDispatch(Ticket,command,R),
    assertion(R==['DispatchResult','Blocked','StaleSnapshot',none]).
test(outcome_conflict, [setup((commitmentFixtureReset(_),open_task))]) :-
    mm_commitment_record_outcome("o","task-1",0,'Failed',_),
    mm_commitment_record_outcome("o","task-1",0,'Completed',R),
    assertion(R==['CommitmentRejected','ConflictingOutcome']).
test(open_idempotent, [setup((commitmentFixtureReset(_),open_task))]) :-
    open_task, findall(Id,mm_commitment(Id,_,_,_,_),Ids), assertion(Ids==["task-1"]).
test(replay_after_replacement_does_not_close_successor, [setup((commitmentFixtureReset(_),open_task))]) :-
    event(['Superseded',"task-2","Other","Replacement"],E),
    mm_commitment_apply(E,A), mm_commitment_apply(E,B), assertion(A==B),
    mm_commitment("task-2",_,_,'Open',0), commitmentEvents([E]).
:- end_tests(commitments).
