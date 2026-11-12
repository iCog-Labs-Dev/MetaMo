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
reasoner_runtime_error(time_limit_exceeded,['ReasonerRuntimeError','Timeout']) :- !.
reasoner_runtime_error(_,['ReasonerRuntimeError','Unavailable']).
