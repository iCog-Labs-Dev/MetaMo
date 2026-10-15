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
% Preserve native frame identity, including its symbol/string type.
% Example: mm_commitment_frame_id('Frame_1') succeeds without string conversion.
mm_commitment_frame_id(X) :- mm_commitment_text(X), !.
mm_commitment_frame_id(X) :- atom(X), normalize_space(atom(T), X), T \== ''.
mm_commitment_reject(Why, ['CommitmentRejected',Why]).

% IDs may never be reused, even after termination. Opening another task while
% one is active requires an explicit Superseded event instead of overwriting it.
mm_commitment_open(Id, Frame, Summary, Result) :-
    mm_commitment_mutate(mm_commitment_open_locked(Id,Frame,Summary,Result)).
mm_commitment_open_locked(Id,Frame,Summary,Result) :-
    ( \+ (ground(Id-Frame-Summary), maplist(mm_commitment_text,[Id,Summary]),
           mm_commitment_frame_id(Frame))
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

% Example: publish only after all required reads and the local answer are observed.
% Requirements/evidence are trusted host-retained data, not model assertions.
% Stable outcome/event IDs let the caller retry without a second publication.
mm_commitment_complete(Outcome,EventId,Requirements,Evidence,Result) :-
    with_mutex(omegaclaw_dispatch,
      (ground(Outcome-EventId-Requirements-Evidence),
       maplist(mm_commitment_text,[Outcome,EventId]),
       Requirements=['CompletionRequirements',Expected,_,_],
       Expected=['CommitmentSnapshot',Id,Frame,Revision,'Open',Summary],
       maplist(mm_commitment_text,[Id,Summary]), mm_commitment_frame_id(Frame),
       integer(Revision), Revision>=0
       -> Event=['CommitmentEvent',EventId,Id,Revision,['Completed',Outcome]],
          mm_commitment_complete_checked(Expected,Requirements,Evidence,Event,Result)
       ; mm_commitment_reject('InvalidCompletion',Result))).

% Example: replay returns its recorded receipt even after a successor is current.
% No new mutation occurs on replay, incomplete evidence, or displaced ownership.
mm_commitment_complete_checked(Expected,Requirements,Evidence,Event,Result) :-
    Event=['CommitmentEvent',EventId,_,_,_],
    (mm_commitment_event(EventId,_,_)
     -> mm_commitment_apply_locked(Event,Result)
     ; commitmentSnapshot(Current), Current \== Expected
     -> mm_commitment_reject('StaleCommitment',Result)
     ; mm_commitment_completion_ready(Expected,Requirements,Evidence)
     -> mm_commitment_publish_completion(Event,Result)
     ; mm_commitment_reject('IncompleteEvidence',Result)).

% Example: a stale session/frame fails against the live context, not caller context.
mm_commitment_completion_ready(Expected,Requirements,Evidence) :-
    Expected=['CommitmentSnapshot',_,Frame,_,_,_],
    nb_current('&cfv2-current-frame-id',CurrentFrame), CurrentFrame == Frame,
    nb_current('&operation-context',Context),
    once(eval([hostCompletionReady,[quote,Expected],[quote,Context],
               [quote,Requirements],[quote,Evidence]],true)).

% Example: an outcome-ID conflict leaves both the event and outcome stores unchanged.
% Reuse the existing outcome/event validation inside one rollback boundary.
mm_commitment_publish_completion(Event,Result) :-
    Event=['CommitmentEvent',_,Id,Revision,['Completed',Outcome]],
    (transaction((
       mm_commitment_record_outcome(Outcome,Id,Revision,'Completed',['OutcomeRecorded',Outcome]),
       mm_commitment_apply(Event,Applied),
       Applied=['CommitmentApplied',_,Id,'Completed',_]))
     -> Result=Applied
     ; mm_commitment_reject('PublicationConflict',Result)).

% Example: prepare after F2.6 archives only the exact completed owner's frame.
% Core's completed-frame record is the replay marker; no second lifecycle ledger.
mm_commitment_complete_frame(Result) :-
    with_mutex(omegaclaw_dispatch,
      (mm_commitment_current(Id), mm_commitment(Id,Frame,Summary,'Completed',Revision),
       Previous is Revision-1,
       mm_commitment_event(_,['CommitmentEvent',_,Id,Previous,['Completed',Outcome]],
                           ['CommitmentApplied',_,Id,'Completed',Revision]),
       mm_commitment_outcome(Outcome,Id,Previous,'Completed')
       -> mm_commitment_finish_frame(Id,Frame,Summary,Result)
       ; Result=['FrameCompletionSkipped','NoCompletedCommitment'])).

% Example: replay after Core selects another frame cannot close that next frame.
mm_commitment_finish_frame(Id,Frame,Summary,Result) :-
    (mm_commitment_frame_archived(Frame)
     -> Result=['FrameCompletionRetained',Id,Frame]
     ; \+ (nb_current('&cfv2-current-frame-id',Current), Current == Frame)
     -> Result=['FrameCompletionHeld','FrameMismatch']
     ; \+ current_predicate('cfv2-complete-current-frame-to-stm'/2)
     -> Result=['FrameCompletionHeld','CoreCompletionUnavailable']
     ; mm_commitment_mutate(mm_commitment_archive_frame(Frame,Summary)),
       mm_commitment_frame_archived(Frame)
     -> Result=['FrameCompleted',Id,Frame]
     ; Result=['FrameCompletionHeld','CoreCompletionFailed']).

% Example: Core's Frame-only removal also drops unrelated FrameRef entries.
% Preserve their exact records around its STM handler, then resume selection.
mm_commitment_archive_frame(Frame,Summary) :-
    nb_current('&cfv2-frame-indexspace',Index),
    findall(Ref,(member(Ref,Index), Ref=['FrameRef'|Fields],
                 memberchk([frameID,Other],Fields), Other \== Frame),Retained),
    once(eval(['cfv2-complete-current-frame-to-stm',[quote,Summary]],
              'FRAME-COMPLETED-STORED-STM')),
    nb_current('&cfv2-frame-indexspace',After),
    append(After,Retained,Combined), list_to_set(Combined,Restored),
    once(eval(['change-state!','&cfv2-frame-indexspace',[quote,Restored]],_)),
    (nb_current('&cfv2-current-frame-id',[]), Retained \== []
     -> once(eval(['cfv2-select-next-frame'],_))
     ; true).

% Example: symbol Frame-1 and string "Frame-1" remain different native identities.
mm_commitment_frame_archived(Frame) :-
    nb_current('&cfv2-completed-framespace',Frames),
    member(['Frame'|Fields],Frames),
    memberchk([frameID,Stored],Fields), Stored == Frame,
    memberchk([status,'Completed'],Fields), !.

commitmentSnapshot(Snapshot) :-
    with_mutex(omegaclaw_dispatch,
      (mm_commitment_current(Id), mm_commitment(Id,Frame,Summary,Status,Revision)
       -> Snapshot=['CommitmentSnapshot',Id,Frame,Revision,Status,Summary]
       ; Snapshot='NoCommitment')).
commitmentEvents(Events) :-
    with_mutex(omegaclaw_dispatch, findall(Event,mm_commitment_event(_,Event,_),Events)).
