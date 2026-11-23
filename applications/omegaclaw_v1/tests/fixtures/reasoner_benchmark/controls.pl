% Example: benchmarkSeed(37,true) seeds the test process, without claiming engine seed APIs.
benchmarkSeed(Seed,true) :- integer(Seed), Seed>=0, set_random(seed(Seed)).

% Example: benchmarkInitialHost(Snapshot) reads policies and accounts without reservation or invocation.
benchmarkInitialHost(['BenchmarkInitialHost',Global,Frame,Bindings,Accounts]) :-
    mm_dispatch_policies(Global,Frame),
    findall(['HostCommandBinding',Command,Request,Operation],
            mm_dispatch_binding(Command,Request,Operation), Bindings),
    eval(['get-state','&budget-account-state'],Accounts).

% Example: enable counters once per fresh benchmark process; episodes never reset them.
benchmarkMeterStart(true) :- nb_setval(omega_reasoner_usage,[0,0,0]).

% Example: these are actual allowance reservations, not a claim about internal engine instruction counts.
benchmarkUsage(['BenchmarkUsage',Steps,Calls,Reservations]) :-
    nb_getval(omega_reasoner_usage,[Steps,Calls,Reservations]).

% Example: read only configured comparator routes; absence uses the declared built-in route.
benchmarkComparatorRoutes(Routes) :-
    (nb_current('&host-reasoner-comparators',Routes) -> true ; Routes=[]).
