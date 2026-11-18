% Trusted test adapter: real rent accounting uses production queue/dispatch code.
maintenanceFixtureQueue(Id,Items,Result) :- mm_maintenance_queue('memory-rent',Id,Items,Result).
maintenanceFixtureTotal(Total) :-
    mm_maintenance_owner(Owner), (mm_maintenance_rent_total(Owner,Total) -> true ; Total=0).
% Read a retained session ledger even while user input makes that scope inapplicable.
maintenanceFixtureIdleTotal(Session,Total) :-
    (mm_maintenance_rent_total([Session,['SessionMaintenanceOwner',Session,_]],Total) -> true ; Total=0).
maintenanceFixtureRemaining(Count) :-
    (mm_maintenance_owner(Owner), mm_maintenance_job('memory-rent',_,_,Items,Owner)
     -> length(Items,Count) ; Count=0).
% Example: changing handler availability invalidates an already captured ticket.
maintenanceFixtureRevoke(true) :-
    oc_dispatch_mutate(retractall(mm_maintenance_handler('memory-rent',_,_))).
% Example: this fixture advertises an engine dependency without impersonating native learning.
maintenanceFixtureDependency(Dependency,true) :-
    mm_maintenance_register('memory-rent',Dependency,mm_maintenance_rent).
% Example: a 17-item observed rent batch needs two native cycles under the 16-item limit.
maintenanceFixtureBatch(Id,Count,Result) :-
    findall(['MemoryRentCharge',Name,1],(between(1,Count,N),number_string(N,Name)),Items),
    mm_maintenance_queue('memory-rent',Id,Items,Result).
% Probe only: exercises a third-party work adapter, not real compression/engine learning.
:- dynamic maintenance_fixture_processed/1.
maintenanceFixtureProbe(Dependency,true) :-
    mm_maintenance_register('memory-compression',Dependency,maintenance_fixture_probe).
maintenanceFixtureWork(Op,Id,Items,Result) :- mm_maintenance_queue(Op,Id,Items,Result).
% Example: bridge bookkeeping cannot acquire a worker even with a work-class declaration.
maintenanceFixtureRegistrationDenied(Op,true) :-
    \+ mm_maintenance_register(Op,'Host',maintenance_fixture_probe).
maintenanceFixtureProcessed(N) :- (maintenance_fixture_processed(N) -> true ; N=0).
% Example: a direct call before dispatch must not record rent or consume the job.
maintenanceFixtureDirectDenied(true) :- \+ hostMaintenanceRun('memory-rent',_).
% Probe timeout rolls back its transactional effect and leaves work unconsumed.
maintenanceFixtureSlow(true) :-
    mm_maintenance_register('memory-compression','Host',maintenance_fixture_slow).
maintenance_fixture_slow(Items,Limits,Details) :-
    maintenance_fixture_probe(Items,Limits,Details), sleep(0.05).
maintenance_fixture_probe(Items,_,['ProbeProcessed',After]) :-
    maintenanceFixtureProcessed(Before), length(Items,Count), After is Before+Count,
    retractall(maintenance_fixture_processed(_)), assertz(maintenance_fixture_processed(After)).
