% Example: benchmarkSeed(37,true) seeds the test process, without claiming engine seed APIs.
benchmarkSeed(Seed,true) :- integer(Seed), Seed>=0, set_random(seed(Seed)).

% Example: benchmarkInitialHost(Snapshot) reads policies and accounts without reservation or invocation.
benchmarkInitialHost(['BenchmarkInitialHost',Global,Frame,Bindings,Accounts]) :-
    mm_dispatch_policies(Global,Frame),
    findall(['HostCommandBinding',Command,Request,Operation],
            mm_dispatch_binding(Command,Request,Operation), Bindings),
    eval(['get-state','&budget-account-state'],Accounts).
