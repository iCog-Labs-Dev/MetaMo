% PeTTa compiles definitions globally, even when imported into another space.
% Load the two local libraries with every library-defined function renamed,
% including higher-order references. Data constructors (Sentence/stv) stay intact.
:- dynamic metamo_engine_loaded/1.
:- ( current_predicate(mm_root/2), mm_root(petta, Root)
   -> directory_file_path(Root, lib, Lib)
   ; prolog_load_context(directory, Dir),
     directory_file_path(Dir, '../../../lib', Lib) ),
   asserta(metamo_engine_library_dir(Lib)).

loadReasonerEngines(true) :-
    metamo_load_engine('lib_nars.metta', 'MetaMoNARS.'),
    metamo_load_engine('lib_pln.metta', 'MetaMoPLN.').

metamo_load_engine(_, Prefix) :- metamo_engine_loaded(Prefix), !.
metamo_load_engine(File, Prefix) :-
    metamo_engine_library_dir(Dir), directory_file_path(Dir, File, Path),
    read_file_to_string(Path, Source, []), string_codes(Source, Cs),
    strip(Cs, 0, Codes), phrase(top_forms(Forms, 1), Codes),
    maplist(metamo_engine_term, Forms, Terms),
    findall(F, (member([=, [F|_], _], Terms), atom(F)), Names0),
    sort(Names0, Names),
    maplist(metamo_engine_rename(Names, Prefix), Terms, Renamed),
    maplist(metamo_engine_register, Renamed, Parsed),
    maplist(process_form('&self'), Parsed, _),
    assertz(metamo_engine_loaded(Prefix)), !.

% These libraries are declarative. Reject startup commands instead of executing
% unscoped code if a future library revision adds any.
metamo_engine_term(form(Source), Term) :- sread(Source, Term).
metamo_engine_rename(_, _, Term, Term) :- var(Term), !.
metamo_engine_rename(Names, Prefix, Term, Renamed) :-
    atom(Term), memberchk(Term, Names), !, atom_concat(Prefix, Term, Renamed).
metamo_engine_rename(Names, Prefix, Term, Renamed) :-
    is_list(Term), !, maplist(metamo_engine_rename(Names, Prefix), Term, Renamed).
metamo_engine_rename(_, _, Term, Term).
metamo_engine_register(Term, parsed(function, Text, Term)) :-
    Term = [=, [F|Args], _], atom(F), !,
    register_fun(F), length(Args, N), Arity is N + 1,
    assertz(arity(F, Arity)), swrite(Term, Text).
metamo_engine_register(Term, parsed(expression, Text, Term)) :- swrite(Term, Text).
