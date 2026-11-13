% Trusted callback timing and invocation identity; no execution or model skills.
:- use_module(library(time)).
:- use_module(library(uuid)).

% Example: reasonerRuntimeIdentity(1000, ['ReasonerRuntimeIdentity',Id,Deadline]).
reasonerRuntimeIdentity(Milliseconds, ['ReasonerRuntimeIdentity',Id,Deadline]) :-
    uuid(UUID), atom_string(UUID,Id), get_time(Now),
    Deadline is floor(Now*1000)+Milliseconds.

% Example: reasonerRuntimeCall(1000, Collector, [Invocation,View,Actions], Result).
% Quote every supplied argument so callbacks receive data, never executable terms.
reasonerRuntimeCall(Milliseconds, Callback, Arguments, Result) :-
    integer(Milliseconds), Milliseconds > 0, atom(Callback), ground(Arguments),
    maplist(reasoner_runtime_quote, Arguments, Quoted),
    Goal =.. [eval, [Callback|Quoted], Value], Seconds is Milliseconds/1000,
    catch((call_with_time_limit(Seconds, once(call(Goal)))
           -> Result=Value ; Result=['ReasonerRuntimeError','Unavailable']),
          Error, reasoner_runtime_error(Error,Result)).
reasoner_runtime_quote(Value,[quote,Value]).
reasoner_runtime_error(reasoner_limit,['ReasonerRuntimeError','LimitExceeded']) :- !.
reasoner_runtime_error(time_limit_exceeded,['ReasonerRuntimeError','Timeout']) :- !.
reasoner_runtime_error(_,['ReasonerRuntimeError','Unavailable']).

% Example: owned collection rejects a changed commitment even if frame ID is unchanged.
reasonerRuntimeCollect(Invocation, Callback, Arguments, Result) :-
    (nb_current(omega_reasoner_allowance,_) -> Result=['ReasonerRuntimeError','ReentrantInvocation']
    ; reasoner_runtime_holds_dispatch -> Result=['ReasonerRuntimeError','DispatchLocked']
    ; with_mutex(omegaclaw_dispatch, reasoner_runtime_owner(Invocation, Before))
    -> setup_call_cleanup(
        nb_setval(omega_reasoner_allowance, Invocation),
        reasoner_runtime_collect(Invocation,Callback,Arguments,Before,Result),
        nb_delete(omega_reasoner_allowance))
    ; Result=['ReasonerRuntimeError','StaleInvocation']).

reasoner_runtime_holds_dispatch :-
    thread_self(Thread), mutex_property(omegaclaw_dispatch,status(locked(Thread,_))).
reasoner_runtime_owner(I, [Owner,State]) :-
    I=['ReasonerInvocation',_,_,_,_,[session,S],[cycle,C],[frame,F],_,[commitment,Commit]|_],
    nb_current('&operation-context',['OperationContext',S,C,F]),
    eval([hostSignalOwner],Owner), Owner=['SignalOwner',S,F,Snapshot],
    (Snapshot=['CommitmentSnapshot',Id,F,Revision,'Open',_]
        -> Commit=['ReasonerCommitmentRef',Id,Revision]
        ; Snapshot='NoCommitment', Commit='NoCommitment'),
    findall(K-V,(member(K,['&cfv2-current-frame-id','&cfv2-current-status',
        '&cfv2-current-mode','&host-reasoner-registration','&active-frame-bundle']),nb_current(K,V)),State).

% The absolute deadline includes preparation; uninterruptible callbacks are checked on return.
reasoner_runtime_collect(I,Callback,Arguments,Before,Result) :-
    last(I,['deadline-ms',Deadline]), get_time(Now), Remaining is Deadline-floor(Now*1000),
    (Remaining =< 0 -> Raw=['ReasonerRuntimeError','Timeout']
    ; reasonerRuntimeCall(Remaining,Callback,Arguments,Raw)),
    get_time(After),
    (After*1000 > Deadline -> Result=['ReasonerRuntimeError','Timeout']
    ; with_mutex(omegaclaw_dispatch,reasoner_runtime_owner(I,Current)), Current==Before
      -> Result=Raw
      ; Result=['ReasonerRuntimeError','StaleInvocation']).

% Reservation uses requested engine steps, so early conclusions cannot overspend the allowance.
reasonerRuntimeEngine(Steps,Tasks,Beliefs,true) :-
    (nb_current(omega_reasoner_allowance,I)
      -> (integer(Steps),Steps>=0 -> true ; throw(reasoner_limit)),
         nth0(12,I,[limits,L]), nth0(6,L,['max-engine-queue',MaxQueue]),
         (integer(Tasks),integer(Beliefs),Tasks>=0,Beliefs>=0,
          Tasks=<MaxQueue,Beliefs=<MaxQueue -> true ; throw(reasoner_limit)),
         reasoner_runtime_spend(5,Steps)
      ; true).
reasoner_runtime_spend(Index,Amount) :-
    nb_getval(omega_reasoner_allowance,I), nth0(12,I,[limits,L]), nth0(Index,L,[Key,Available]),
    (number(Amount),Amount>=0,Amount=<Available -> true ; throw(reasoner_limit)),
    Left is Available-Amount, nth0(Index,L,_,Rest), nth0(Index,Next,[Key,Left],Rest),
    nth0(12,I,_,Outer), nth0(12,Updated,[limits,Next],Outer), nb_setval(omega_reasoner_allowance,Updated).

% Provider adapters use this gateway; trusted callbacks are not an arbitrary-code sandbox.
% Example: zero provider allowance prevents the provider callback from being invoked.
reasonerRuntimeProvider(Callback,Arguments,Unit,Cost,Result) :-
    nb_current(omega_reasoner_allowance,I),
    nth0(12,I,[limits,L]), nth0(8,L,['provider-cost',
        ['ReasonerProviderCostLimit',[unit,Unit],[amount,Available]]]),
    (number(Cost),Cost>=0,Cost=<Available -> true ; throw(reasoner_limit)),
    reasoner_runtime_spend(7,1),
    nb_getval(omega_reasoner_allowance,Current), nth0(12,Current,[limits,CurrentLimits]),
    Left is Available-Cost,
    nth0(8,CurrentLimits,_,Tail), nth0(8,Next,['provider-cost',
        ['ReasonerProviderCostLimit',[unit,Unit],[amount,Left]]],Tail),
    nth0(12,Current,_,Rest), nth0(12,Updated,[limits,Next],Rest),nb_setval(omega_reasoner_allowance,Updated),
    maplist(reasoner_runtime_quote,Arguments,Quoted), eval([Callback|Quoted],Result).

% Example: recheck ownership/deadline before advice enters candidate admission.
reasonerRuntimeCurrent(I,Result) :-
    last(I,['deadline-ms',Deadline]), get_time(Now),
    (Now*1000=<Deadline, with_mutex(omegaclaw_dispatch,reasoner_runtime_owner(I,_))
        -> Result=true ; Result=false).

% Match the admitted binding to the current exact host decision before execution.
% Example: another ticket for the same candidate gives false, never a new ticket.
reasonerRuntimeSelectionCurrent(I,Operation,Decision,Result) :-
    with_mutex(omegaclaw_dispatch,
        (reasoner_runtime_selection(I,Operation,Decision) -> Result=true ; Result=false)).

% Native selection remains valid independently when stale advice cannot be linked.
% Example: an already observed receipt cannot acquire retrospective attribution.
reasoner_runtime_selection(I,Operation,Decision) :-
    last(I,['deadline-ms',Deadline]), get_time(Now), Now*1000=<Deadline,
    reasoner_runtime_owner(I,[Owner,_]),
    nb_current('&selected-signal-owner',Owner),
    Operation=['HostOperation',Candidate,Command,_,_,_,Ticket], Command\==[],
    nb_current('&selected-host-operation',Selected), Selected==Operation,
    nb_current('&operation-context',Context),
    Decision=['OperationDecision',Context,Candidate,Command,Ticket],
    nb_current('&selected-operation-decision',Actual), Actual==Decision,
    oc_dispatch_ticket(Ticket,_,Epoch,Snapshot), oc_dispatch_epoch(Epoch),
    mm_dispatch_snapshot(Current), Current==Snapshot,
    \+ oc_dispatch_result(Ticket,_,_).
