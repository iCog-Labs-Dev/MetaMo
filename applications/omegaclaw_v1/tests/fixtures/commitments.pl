% Test-only access to trusted host APIs. Never imported by live composition.
commitmentFixtureReset(true) :-
    retractall(mm_commitment(_,_,_,_,_)), retractall(mm_commitment_current(_)),
    retractall(mm_commitment_event(_,_,_)), retractall(mm_commitment_outcome(_,_,_,_)).
commitmentFixtureOpen(Id,Frame,Summary,Result) :- mm_commitment_open(Id,Frame,Summary,Result).
commitmentFixtureOutcome(Outcome,Id,Revision,Status,Result) :-
    mm_commitment_record_outcome(Outcome,Id,Revision,Status,Result).
commitmentFixtureApply(Event,Result) :- mm_commitment_apply(Event,Result).
