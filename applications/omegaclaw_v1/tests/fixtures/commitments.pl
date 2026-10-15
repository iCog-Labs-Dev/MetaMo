% Test-only access to trusted host APIs. Never imported by live composition.
commitmentFixtureReset(true) :-
    retractall(mm_commitment(_,_,_,_,_)), retractall(mm_commitment_current(_)),
    retractall(mm_commitment_event(_,_,_)), retractall(mm_commitment_outcome(_,_,_,_)).
commitmentFixtureOpen(Id,Frame,Summary,Result) :- mm_commitment_open(Id,Frame,Summary,Result).
commitmentFixtureOutcome(Outcome,Id,Revision,Status,Result) :-
    mm_commitment_record_outcome(Outcome,Id,Revision,Status,Result).
commitmentFixtureApply(Event,Result) :- mm_commitment_apply(Event,Result).
% Example: exercise the trusted publisher without exposing it as a live MeTTa skill.
commitmentFixtureComplete(Outcome,Event,Requirements,Evidence,Result) :-
    mm_commitment_complete(Outcome,Event,Requirements,Evidence,Result).
% Example: rejected evidence must not leave a registered completion outcome.
commitmentFixtureOutcomes(Records) :-
    findall(['CompletionOutcome',Outcome,Id,Revision,Status],
            mm_commitment_outcome(Outcome,Id,Revision,Status),Records).
% Example: pure rejection/replay must preserve the dispatch epoch.
commitmentFixtureEpoch(Epoch) :- oc_dispatch_epoch(Epoch).
% Example: inspect the retained predecessor after a replacement opens its successor.
commitmentFixtureRecord(Id,Record) :-
    mm_commitment(Id,Frame,Summary,Status,Revision),
    Record=['CommitmentSnapshot',Id,Frame,Revision,Status,Summary].
