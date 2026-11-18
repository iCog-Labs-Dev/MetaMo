% Trusted task-owned maintenance queue. No setters are exported as model skills.
:- use_module(library(time)).
:- dynamic mm_maintenance_handler/3, mm_maintenance_job/5, mm_maintenance_done/4.
:- dynamic mm_maintenance_held/2, mm_maintenance_rent_total/2.

% Example: dispatcher initialization installs a local accounting handler, not work.
mm_maintenance_init :-
    retractall(mm_maintenance_handler(_,_,_)), retractall(mm_maintenance_job(_,_,_,_,_)),
    retractall(mm_maintenance_done(_,_,_,_)), retractall(mm_maintenance_held(_,_)),
    retractall(mm_maintenance_rent_total(_,_)),
    assertz(mm_maintenance_handler('memory-rent','Host',mm_maintenance_rent)),
    eval(['change-state!','&maintenance-view-hook',hostMaintenanceStatuses],_).

% Example: limits and candidate identity come from registry classes, never queued data.
mm_maintenance_policy(Op, Candidate, Limits) :-
    findall([C,L], (match('&self',['MaintenanceWork',Op,Class,L],L,L),
        match('&self',['MaintenanceCandidate',Class,C],C,C)), [[Candidate,Limits]]).

% Example: a queue belongs to one operation session and exact open commitment.
mm_maintenance_owner([Session,Owner]) :-
    nb_current('&operation-context',['OperationContext',Session,_,_]),
    mm_dispatch_task_owner(Owner).

% Trusted adapters own their worker semantics and enforcement of engine/provider allowances.
% Example: register a worker with dependency "pln"; absence of that selected adapter disables it.
mm_maintenance_register(Op, Dependency, Worker) :-
    mm_maintenance_policy(Op,_,_), Op \== 'motivational-decay',
    (Dependency == 'Host' ; string(Dependency)), atom(Worker), current_predicate(Worker/3),
    with_mutex(omegaclaw_dispatch, oc_dispatch_mutate((
        retractall(mm_maintenance_handler(Op,_,_)), assertz(mm_maintenance_handler(Op,Dependency,Worker))))).

% Example: declared classes without installed workers remain unavailable.
mm_maintenance_available(Op, true) :-
    mm_maintenance_handler(Op,Dependency,_),
    (Dependency == 'Host' -> true
     ; catch(eval([hostReasonerSelection],Selected),_,fail), Selected == Dependency), !.
mm_maintenance_available(_, false).

% Example: identical queue delivery is idempotent; changed ownership/payload is rejected.
mm_maintenance_queue(Op,Id,Items,Result) :-
    with_mutex(omegaclaw_dispatch,
        (mm_maintenance_queue_valid(Op,Id,Items,Owner)
         -> mm_maintenance_enqueue(Op,Id,Items,Owner,Result)
         ; Result=['MaintenanceRejected','InvalidBatch'])).
mm_maintenance_queue_valid(Op,Id,Items,Owner) :-
    mm_maintenance_policy(Op,_,_), Op \== 'motivational-decay',
    string(Id), string_length(Id,N), between(1,256,N),
    ground(Items), is_list(Items), length(Items,Count), between(1,128,Count),
    term_size(Items,Nodes), Nodes =< 4096, write_length(Items,Chars,[max_length(16384)]), Chars =< 16384,
    mm_maintenance_items_valid(Op,Items), mm_maintenance_owner(Owner).
mm_maintenance_items_valid('memory-rent',Items) :- !,
    maplist(mm_maintenance_charge,Items), findall(Id,member(['MemoryRentCharge',Id,_],Items),Ids),
    sort(Ids,Unique), same_length(Ids,Unique).
mm_maintenance_items_valid(_, _).
mm_maintenance_charge(['MemoryRentCharge',Id,Units]) :-
    string(Id), string_length(Id,N), between(1,256,N),
    integer(Units), Units >= 0, Units =< 9007199254740991.
mm_maintenance_enqueue(Op,Id,Items,Owner,Result) :-
    (mm_maintenance_job(Op,Id,Original,_,Actual)
     -> (Original-Actual == Items-Owner -> Result=['MaintenanceQueued',Id]
         ; Result=['MaintenanceRejected','ConflictingBatch'])
     ; mm_maintenance_done(Op,Id,Original,Actual)
     -> (Original-Actual == Items-Owner -> Result=['MaintenanceDuplicate',Id]
         ; Result=['MaintenanceRejected','ConflictingBatch'])
     ; mm_maintenance_job(Op,_,_,_,Owner)
     -> Result=['MaintenanceRejected','PendingBatch']
     ; aggregate_all(count,(mm_maintenance_done(_,_,_,_);mm_maintenance_job(_,_,_,_,_)),Count), Count >= 128
     -> Result=['MaintenanceRejected','AuditLimit']
     ; oc_dispatch_mutate(assertz(mm_maintenance_job(Op,Id,Items,Items,Owner))),
       Result=['MaintenanceQueued',Id]).

% Example: snapshots expose counts/identity only, never raw queued evidence or memories.
hostMaintenanceStatuses(Rows) :-
    with_mutex(omegaclaw_dispatch,
        findall(['MaintenanceStatus',Op,Candidate,Available,Count,Id],
            (mm_dispatch_binding(['host-maintenance',Op],_,_),
             mm_maintenance_policy(Op,Candidate,_),
             mm_maintenance_available(Op,Ready),
             (mm_maintenance_held(Op,_) -> Available=false ; Available=Ready),
             (mm_maintenance_job(Op,Job,_,Items,Owner), mm_maintenance_owner(Current), Current == Owner
              -> length(Items,Count), Id=Job ; Count=0, Id=[])),Rows)).

% Example: choose the first available pending binding for this candidate, retaining host order.
mm_maintenance_selected(Op) :-
    hostMaintenanceStatuses(Rows), member(['MaintenanceStatus',Op,Candidate,true,Count,_],Rows), Count > 0,
    once((member(['MaintenanceStatus',First,Candidate,true,N,_],Rows),N > 0)), First == Op,
    eval([maintenanceWorkFitsMode,Op,[constitutionalMode]],true).

% Example: final dispatch rechecks posture, engine availability and the exact live queue owner.
hostMaintenanceRun(Op,Result) :-
    mm_maintenance_dispatching(Op),
    mm_maintenance_selected(Op),
    mm_maintenance_handler(Op,_,Worker), mm_maintenance_policy(Op,_,Limits),
    Limits=['MaintenanceWorkLimits',Max,Steps,Providers,Ms],
    maplist(integer,[Max,Steps,Providers,Ms]), Max > 0, Max =< 128,
    Steps >= 0, Providers >= 0, Ms > 0, Ms =< 1000,
    mm_maintenance_job(Op,Id,Original,Items,Owner), mm_maintenance_owner(Current), Current == Owner,
    length(Items,N), Count is min(N,Max), length(Batch,Count), append(Batch,Rest,Items),
    Seconds is Ms/1000,
    (catch(call_with_time_limit(Seconds,transaction(
        mm_maintenance_apply(Op,Id,Original,Items,Rest,Owner,Batch,Worker,Limits,Details))),_,fail)
     -> true ; assertz(mm_maintenance_held(Op,'Uncertain')),fail),
    Result=['MaintenanceCompleted',Op,Id,Count,Details].

% Example: direct expression evaluation cannot bypass Core's ticket/reservation boundary.
mm_maintenance_dispatching(Op) :-
    Command=['host-maintenance',Op],
    nb_current('&operation-context',Context),
    nb_current('&selected-operation-decision',['OperationDecision',Context,_,Command,Ticket]),
    Pending=['DispatchResult','Unobserved','ExecutionUncertain',none],
    oc_dispatch_result(Ticket,Command,Pending),
    \+ (oc_dispatch_result(Other,_,Pending), Other \== Ticket).

% Example: successful batches consume their queued items once; a failed transaction consumes none.
mm_maintenance_apply(Op,Id,Original,Items,Rest,Owner,Batch,Worker,Limits,Details) :-
    call(Worker,Batch,Limits,Details), ground(Details),
    write_length(Details,Chars,[max_length(4096)]), Chars =< 4096,
    oc_dispatch_mutate((retract(mm_maintenance_job(Op,Id,Original,Items,Owner)),
        (Rest == [] -> assertz(mm_maintenance_done(Op,Id,Original,Owner))
         ; assertz(mm_maintenance_job(Op,Id,Original,Rest,Owner))))).

% Observed charge amounts are supplied by trusted host code; no rent law or deletion is invented.
% Example: two charges of 2 and 3 units add five observed retention units to this owner's ledger.
mm_maintenance_rent(Items,['MaintenanceWorkLimits',_,0,0,_],['MemoryRentAccounted',Total]) :-
    mm_maintenance_owner(Owner), maplist(mm_maintenance_charge,Items),
    findall(Units,member(['MemoryRentCharge',_,Units],Items),Charges), sum_list(Charges,Delta),
    (mm_maintenance_rent_total(Owner,Before) -> true ; Before=0),
    Total is Before+Delta, Total =< 9007199254740991,
    retractall(mm_maintenance_rent_total(Owner,_)), assertz(mm_maintenance_rent_total(Owner,Total)).
