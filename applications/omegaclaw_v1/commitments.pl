% Host-owned, session-only commitment lifecycle. Only read functions are
% exported to MeTTa; mutations are trusted host APIs, not model skills.
:- dynamic mm_commitment/5, mm_commitment_current/1,
           mm_commitment_event/3, mm_commitment_outcome/4.
:- meta_predicate mm_commitment_mutate(0).

% Share dispatch's mutation lock/revision when dispatch is loaded. Offline
% consumers use the same mutex without requiring a live dispatcher.
mm_commitment_mutate(Goal) :-
    (current_predicate(oc_dispatch_mutate/1)
     -> oc_dispatch_mutate(Goal)
     ; with_mutex(omegaclaw_dispatch, once(Goal))).

mm_commitment_text(X) :- string(X), normalize_space(string(T), X), T \== "".
mm_commitment_reject(Why, ['CommitmentRejected',Why]).

% IDs may never be reused, even after termination. Opening another task while
% one is active requires an explicit Superseded event instead of overwriting it.
mm_commitment_open(Id, Frame, Summary, Result) :-
    mm_commitment_mutate(mm_commitment_open_locked(Id,Frame,Summary,Result)).
mm_commitment_open_locked(Id,Frame,Summary,Result) :-
    ( \+ (ground(Id-Frame-Summary), maplist(mm_commitment_text,[Id,Frame,Summary]))
      -> mm_commitment_reject('InvalidCommitment',Result)
    ; mm_commitment(Id,OldFrame,OldSummary,Status,_)
      -> (OldFrame==Frame, OldSummary==Summary, Status=='Open'
          -> Result=['CommitmentOpened',Id]
          ; mm_commitment_reject('IdentityConflict',Result))
    ; mm_commitment_current(Current), mm_commitment(Current,_,_,'Open',_)
      -> mm_commitment_reject('ActiveCommitmentExists',Result)
    ; assertz(mm_commitment(Id,Frame,Summary,'Open',0)),
      retractall(mm_commitment_current(_)), assertz(mm_commitment_current(Id)),
      Result=['CommitmentOpened',Id]).

% A completion outcome is host-adjudicated task completion, not merely a
% returned command or a model assertion. Unknown/failed outcomes cannot close it.
mm_commitment_record_outcome(Outcome,Id,Revision,Status,Result) :-
    mm_commitment_mutate(
      ( \+ (ground(Outcome-Id-Revision-Status), mm_commitment_text(Outcome),
             memberchk(Status,['Completed','Failed','Unobserved']),
             mm_commitment(Id,_,_,'Open',Revision))
        -> mm_commitment_reject('InvalidOutcome',Result)
      ; mm_commitment_outcome(Outcome,OldId,OldRevision,OldStatus)
        -> (OldId==Id, OldRevision==Revision, OldStatus==Status
            -> Result=['OutcomeRecorded',Outcome]
            ; mm_commitment_reject('ConflictingOutcome',Result))
      ; assertz(mm_commitment_outcome(Outcome,Id,Revision,Status)),
        Result=['OutcomeRecorded',Outcome])).

mm_commitment_apply(Event,Result) :-
    mm_commitment_mutate(mm_commitment_apply_locked(Event,Result)).
mm_commitment_apply_locked(Event,Result) :-
    (ground(Event), Event=['CommitmentEvent',EventId,Id,Revision,Change],
     maplist(mm_commitment_text,[EventId,Id]), integer(Revision), Revision>=0
     -> mm_commitment_apply_validated(Event,EventId,Id,Revision,Change,Result)
     ; mm_commitment_reject('InvalidEvent',Result)).
mm_commitment_apply_validated(Event,EventId,Id,Revision,Change,Result) :-
    ( mm_commitment_event(EventId,Prior,Recorded)
      -> (Prior==Event -> Result=Recorded; mm_commitment_reject('ConflictingReplay',Result))
    ; \+ mm_commitment(Id,_,_,_,_)
      -> mm_commitment_reject('UnknownCommitment',Result)
    ; \+ mm_commitment(Id,_,_,'Open',_)
      -> mm_commitment_reject('AlreadyTerminal',Result)
    ; \+ mm_commitment(Id,_,_,'Open',Revision)
      -> mm_commitment_reject('StaleRevision',Result)
    ; \+ mm_commitment_current(Id)
      -> mm_commitment_reject('NotCurrentCommitment',Result)
    ; mm_commitment_change_check(Change,Id,Revision,Checked),
      (Checked=accepted(Status,Successor)
       -> transaction((
            retract(mm_commitment(Id,Frame,Summary,'Open',Revision)),
            NextRevision is Revision+1,
            assertz(mm_commitment(Id,Frame,Summary,Status,NextRevision)),
            mm_commitment_successor(Successor,Frame),
            Result=['CommitmentApplied',EventId,Id,Status,NextRevision],
            assertz(mm_commitment_event(EventId,Event,Result))))
       ; Result=Checked)).

mm_commitment_change_check(['Completed',Outcome],Id,Revision,Result) :- !,
    (mm_commitment_text(Outcome), mm_commitment_outcome(Outcome,Id,Revision,'Completed')
     -> Result=accepted('Completed',none)
     ; mm_commitment_reject('CompletionNotConfirmed',Result)).
mm_commitment_change_check(['Abandoned',Reason],_,_,Result) :- !,
    (mm_commitment_text(Reason) -> Result=accepted('Abandoned',none)
     ; mm_commitment_reject('ReasonRequired',Result)).
mm_commitment_change_check(['Superseded',Next,Summary,Reason],Id,_,Result) :- !,
    ( \+ maplist(mm_commitment_text,[Next,Summary,Reason])
      -> mm_commitment_reject('InvalidReplacement',Result)
    ; (Next==Id; mm_commitment(Next,_,_,_,_))
      -> mm_commitment_reject('IdentityConflict',Result)
    ; Result=accepted('Superseded',successor(Next,Summary))).
mm_commitment_change_check(_,_,_,Result) :- mm_commitment_reject('InvalidTransition',Result).

mm_commitment_successor(none,_).
mm_commitment_successor(successor(Id,Summary),Frame) :-
    assertz(mm_commitment(Id,Frame,Summary,'Open',0)),
    retractall(mm_commitment_current(_)), assertz(mm_commitment_current(Id)).

commitmentSnapshot(Snapshot) :-
    with_mutex(omegaclaw_dispatch,
      (mm_commitment_current(Id), mm_commitment(Id,Frame,Summary,Status,Revision)
       -> Snapshot=['CommitmentSnapshot',Id,Frame,Revision,Status,Summary]
       ; Snapshot='NoCommitment')).
commitmentEvents(Events) :-
    with_mutex(omegaclaw_dispatch, findall(Event,mm_commitment_event(_,Event,_),Events)).
