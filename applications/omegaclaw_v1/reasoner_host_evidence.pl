% Trusted session-only causal links. All supplied records are data, never goals.
% Core's mutex protects capture/observation; its ledger remains execution authority.
:- dynamic mmre_session/1, mmre_link/6, mmre_observation/4.
:- meta_predicate mmre_run(1, -), mmre_require(0, +).

% Return one explicit rejection without exposing exceptions or changing evidence.
% Example: mmre_run(mmre_retain(Event), Result).
mmre_run(Goal, Result) :-
    with_mutex(omegaclaw_dispatch,
        catch((once(call(Goal, Value)) -> Result=Value
               ; Result=['ReasonerOutcomeRejected','InvalidHostEvidence']),
              Error, mmre_error(Error,Result))).

% Only deliberate validation failures have externally visible reason symbols.
% Example: mmre_error(reasoner_evidence('WrongSession'), Result).
mmre_error(reasoner_evidence(Reason), ['ReasonerOutcomeRejected',Reason]) :- !.
mmre_error(_, ['ReasonerOutcomeRejected','HostEvidenceUnavailable']).

% Fixed host predicates supply checks; proposal content is never passed as a goal.
% Example: mmre_require(ground(Event), 'MalformedEvidence').
mmre_require(Goal, Reason) :-
    (once(Goal) -> true; throw(reasoner_evidence(Reason))).

% Read the current operation session, preserving its native frame identity.
% Example: mmre_context(Context, Session, Frame).
mmre_context(Context, Session, Frame) :-
    mmre_require((nb_current('&operation-context',Context), ground(Context),
        Context=['OperationContext',Session,Cycle,Frame], string(Session),
        number(Cycle), Cycle > 0, Frame \== []), 'MissingOperationContext').

% Require an actually retained accepted decision with a valid matching proposal.
% Example: a fabricated Accepted label absent from the audit is rejected.
mmre_event(Event, Proposal, Candidate) :-
    mmre_require(ground(Event), 'MalformedEvidence'),
    mmre_require((Event=['ReasonerProposalEvent',[proposal,Proposal],
        [decision,['ReasonerMotivationalDecision','Accepted','Feasible',Same,Candidate,Score]],
        [disposition,'Accepted']], Same == Proposal,
        eval([reasonerProposalValid,[quote,Proposal]],true),
        eval([reasonerProposalConfidenceValid,Score],true)), 'InvalidProposalDecision'),
    mmre_require((eval([reasonerProposalEvents],Events), memberchk(Event,Events)),
        'UnretainedDecision').

% Preserve observations only within the current operation-session namespace.
% Example: a valid new session starts an empty bounded link store.
mmre_start_session(Session) :-
    (mmre_session(Session) -> true
     ; retractall(mmre_session(_)), retractall(mmre_link(_,_,_,_,_,_)),
       retractall(mmre_observation(_,_,_,_)), assertz(mmre_session(Session))).

% Explicit host attribution must precede execution and match the publication.
% Example: retainReasonerProposalSelection(Event, ['ReasonerProposalLinked',Decision]).
retainReasonerProposalSelection(Event, Result) :- mmre_run(mmre_retain(Event),Result).

% Validate first; rejected attribution never clears or allocates stored links.
% Example: the same candidate on a later cycle cannot adopt an old event.
mmre_retain(Event, ['ReasonerProposalLinked',Decision]) :-
    mmre_event(Event,Proposal,Candidate),
    mmre_context(Context,Session,Frame),
    mmre_require((Proposal=['ReasonerMotivationalProposal',_,_,'propose-candidate',Target,
        Candidate,_,_,_,_,_], (Target == 'current-frame'; Target == ['FrameTarget',Frame])),
        'ProposalTargetMismatch'),
    mmre_require((commitmentSnapshot(Owner),
        Owner=['CommitmentSnapshot',_,Frame,_, 'Open',_]), 'MissingCommitmentOwner'),
    mmre_require((eval([activeFrameBundle],Bundle), eval([reasonerProposalOrigins],Origins),
        memberchk(['ReasonerProposalOrigin',Event,Context,Bundle,Owner],Origins)),
        'StaleProposalContext'),
    mmre_selected(Context,Candidate,Decision,Ticket),
    mmre_require((nb_current('&selected-signal-owner',SelectedOwner),
        SelectedOwner == ['SignalOwner',Session,Frame,Owner]), 'OwnerMismatch'),
    mmre_fresh_ticket(Ticket,Candidate,Epoch,Snapshot),
    mmre_require((Snapshot=['DispatchContext',Expected,_,_,_,_],
        maplist(mm_dispatch_schedule_field,Bundle,Canonical), Expected == Canonical),
        'StaleProposalContext'),
    mmre_require(\+ oc_dispatch_result(Ticket,_,_), 'ExecutionAlreadyRecorded'),
    mmre_store_link(Session,Event,Owner,Decision,Epoch,Snapshot).

% Only the host's exact selected command/ticket can be attributed to a proposal.
% Example: an unrelated selected candidate returns SelectionMismatch.
mmre_selected(Context,Candidate,Decision,Ticket) :-
    mmre_require((nb_current('&selected-operation-decision',Decision), ground(Decision),
        Decision=['OperationDecision',Context,Candidate,Command,Ticket],
        eval([selectedHostCommand],Selected), Selected == Command, Command \== [],
        eval([selectedHostTicket],SelectedTicket), SelectedTicket == Ticket),
        'SelectionMismatch').

% Core owns the ticket; attribution cannot revive a stale or revoked selection.
% Example: a policy mutation after selection returns StaleDispatch.
mmre_fresh_ticket(Ticket,Candidate,Epoch,Snapshot) :-
    mmre_require((oc_dispatch_ticket(Ticket,Intent,Epoch,Snapshot),
        Intent == ['AdmissionRequest','propose-candidate','current-frame',Candidate],
        oc_dispatch_epoch(Epoch), mm_dispatch_snapshot(Current), Current == Snapshot),
        'StaleDispatch').

% One event names one selection; this is attribution, not grading deduplication.
% Example: reattaching the same event to another ticket returns ConflictingSelection.
mmre_store_link(Session,Event,Owner,Decision,Epoch,Snapshot) :-
    Decision=['OperationDecision',_,_,_,Ticket],
    mmre_require(\+ (mmre_link(Session,Other,_,D,_,_), Other \== Event,
        D=['OperationDecision',_,_,_,Ticket]), 'ConflictingSelection'),
    (mmre_link(Session,Event,O,D,E,S)
     -> mmre_require((O==Owner,D==Decision,E==Epoch,S==Snapshot),'ConflictingSelection')
     ; findall(1,mmre_link(Session,_,_,_,_,_),Rows), length(Rows,N),
       mmre_require(N < 128,'EvidenceCapacity'),
       mmre_start_session(Session),
       assertz(mmre_link(Session,Event,Owner,Decision,Epoch,Snapshot))).

% Resolve identity from already captured evidence, without regrading or allocating.
% Example: the same session/ticket always gives the same ReasonerOutcomeRef.
resolveReasonerOutcomeIdentity(Event,Execution,Result) :-
    mmre_run(mmre_identity(Event,Execution),Result).

% Retained receipts may be redelivered after later cycles or frame completion.
% New reports still undergo the full validation before their first commit.
% Example: another proposal or execution cannot claim this receipt's identity.
mmre_identity(Event,Execution,['ReasonerOutcomeIdentity',['ReasonerOutcomeRef',Session,Id]]) :-
    mmre_require(ground(Event-Execution),'MalformedEvidence'),
    mmre_require((nb_current('&operation-context',Context), ground(Context),
        Context=['OperationContext',Session,_,_], string(Session)), 'MissingOperationContext'),
    mmre_require(mmre_link(Session,Event,_,Decision,_,_),'MissingSelectionLink'),
    mmre_require((Decision=['OperationDecision',_,_,_,Ticket],
        Ticket=['DispatchTicket',Id], string(Id),
        Execution == ['ReasonerExecutionEvidence',Ticket],
        mmre_observation(Session,Event,Stored,_), Stored == Decision), 'MissingExecutionEvidence').

% Capture the validated callback plus Core's exact immutable receipt, without executing.
% Example: observeReasonerProposalExecution(Event, Evidence) after normal dispatch.
observeReasonerProposalExecution(Event, Result) :- mmre_run(mmre_observe(Event),Result).

% Observe while the selection/owner is current; retained evidence can be graded later.
% Example: a callback from another frame or commitment cannot supply this evidence.
mmre_observe(Event, Evidence) :-
    mmre_event(Event,_,_), mmre_context(_,Session,_),
    mmre_require(mmre_link(Session,Event,Owner,Decision,Epoch,Snapshot),'MissingSelectionLink'),
    mmre_require((commitmentSnapshot(Current), Current == Owner),'OwnerMismatch'),
    mmre_require((nb_current('&last-operation-outcome',Outcome), ground(Outcome),
        Outcome=['OperationOutcome',D,_,_,_], D == Decision,
        eval([validateOperationOutcome,[quote,Outcome]],'OutcomeValid')),
        'MismatchedObservation'),
    mmre_receipt(Decision,Epoch,Snapshot,Outcome,_),
    Decision=['OperationDecision',_,_,_,Ticket],
    Evidence=['ReasonerExecutionEvidence',Ticket],
    (mmre_observation(Session,Event,Decision,Prior)
     -> mmre_require(Prior == Outcome,'ConflictingObservation')
     ; assertz(mmre_observation(Session,Event,Decision,Outcome))).

% An observed handler success/failure is execution evidence, never task completion.
% Example: blocked or uncertain results return NoObservedExecution.
mmre_receipt(Decision,Epoch,Snapshot,Outcome,Status) :-
    Decision=['OperationDecision',_,_,Command,Ticket],
    mmre_require((oc_dispatch_ticket(Ticket,_,Epoch,Stored), Stored == Snapshot,
        oc_dispatch_result(Ticket,Actual,Result), Actual == Command,
        Outcome=['OperationOutcome',D,['attempted-command',Attempt],Observed,R],
        D == Decision, Attempt == Command, R == Result), 'MismatchedExecution'),
    mmre_require(Result=['DispatchResult','Executed','Feasible',_],'NoObservedExecution'),
    mmre_require(mmre_status(Observed,Status),'NoObservedExecution').

% Map only the host's documented observations, not caller-supplied grade labels.
% Example: mmre_status('Success','Completed').
mmre_status('Success','Completed').
mmre_status('Failure','Failed').

% No authoritative frame-verification adapter is installed by this bounded slice.
% Example: Confirmed with empty evidence returns MissingVerificationEvidence.
mmre_verification(Status,Evidence) :-
    (Status == 'Unresolved', Evidence == [] -> true
     ; memberchk(Status,['Confirmed','Refuted']), Evidence == []
     -> throw(reasoner_evidence('MissingVerificationEvidence'))
     ; throw(reasoner_evidence('UnsupportedVerificationEvidence'))).

% Grading accepts only a previously captured receipt linked to this exact event.
% Example: validateReasonerExecutionEvidence(Event,'Completed',Evidence,'Unresolved',[],R).
validateReasonerExecutionEvidence(Event,Status,Execution,FrameStatus,FrameEvidence,Result) :-
    mmre_run(mmre_validate(Event,Status,Execution,FrameStatus,FrameEvidence),Result).

% Recheck historical receipt identity, allowing later cycles without relabelling owners.
% Example: a genuine later task's receipt cannot be substituted for the original one.
mmre_validate(Event,Status,Execution,FrameStatus,FrameEvidence,'ReasonerExecutionEvidenceValid') :-
    mmre_require(ground(Event-Status-Execution-FrameStatus-FrameEvidence),'MalformedEvidence'),
    mmre_event(Event,_,_), mmre_context(_,Session,_),
    mmre_require(mmre_link(Session,Event,_,Decision,Epoch,Snapshot),'MissingSelectionLink'),
    mmre_require((Decision=['OperationDecision',_,_,_,Ticket],
        Execution == ['ReasonerExecutionEvidence',Ticket],
        mmre_observation(Session,Event,D,Outcome), D == Decision),
        'MissingExecutionEvidence'),
    mmre_receipt(Decision,Epoch,Snapshot,Outcome,ObservedStatus),
    mmre_require(Status == ObservedStatus,'ExecutionStatusMismatch'),
    mmre_verification(FrameStatus,FrameEvidence).
