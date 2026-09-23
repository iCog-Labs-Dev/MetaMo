% Repository-owned launch boundary. PeTTa compiler sources remain unchanged.
:- use_module(library(filesex)).
:- use_module(library(http/json)).
:- dynamic mm_root/2, mm_source/1, mm_loaded/2, mm_loading/2, mm_edge/4, mm_audited/1.

mm_existing(Input, Path) :-
    ( absolute_file_name(Input, Absolute, [access(read), file_errors(fail)])
    -> py_call('os.path':realpath(Absolute), Physical), atom_string(Path, Physical)
    ; throw(error(existence_error(import_source, Input), _)) ).

mm_library(Name, Path) :-
    mm_root(petta, Root), directory_file_path(Root, lib, Lib),
    directory_file_path(Lib, Name, Path).
mm_library(Package, Name, Path) :-
    ( mm_root(Package, Root) -> directory_file_path(Root, Name, Path)
    ; throw(error(existence_error(import_package, Package), _)) ).

mm_resolve(Input, Path) :-
    ( is_absolute_file_name(Input) -> Base = Input
    ; once(mm_source(Owner)), file_directory_name(Owner, Dir),
      directory_file_path(Dir, Input, Base) ),
    ( file_name_extension(_, Ext, Base), memberchk(Ext, [py, pl, metta])
    -> File = Base
    ; atom_concat(Base, '.metta', File) ),
    mm_existing(File, Path).

mm_record(Kind, Requested, Path) :-
    once(mm_source(Owner)), assertz(mm_edge(Owner, Kind, Requested, Path)).

mm_import(Space, Input, true) :-
    mm_resolve(Input, Path), mm_record(import, Input, Path),
    mm_load_once(Space, Path).

mm_load_once(Space, Path) :-
    ( mm_loading(_, Path) -> throw(error(cyclic_module_import(Path), _))
    ; mm_loaded(Space, Path) -> true
    ; mm_loaded(Other, Path), \+ file_name_extension(_, py, Path)
    -> throw(error(module_space_conflict(Path, Other, Space), _))
    ; setup_call_cleanup(
          assertz(mm_loading(Space, Path), Ref),
          ( (file_name_extension(_, py, Path) -> mm_python(Path)
            ; mm_load(Space, Path))
          -> assertz(mm_loaded(Space, Path))
          ; throw(error(module_load_failed(Path), _)) ),
          erase(Ref)) ).

mm_python(Path) :-
    file_directory_name(Path, Dir), file_base_name(Path, Base),
    file_name_extension(Module, py, Base),
    py_call(sys:path:insert(0, Dir), _),
    py_call(builtins:'__import__'(Module), _),
    py_call(Module:'__file__', Actual),
    ( same_file(Path, Actual) -> true
    ; throw(error(python_import_collision(Module, Path, Actual), _)) ).

mm_load(Space, Path) :-
    setup_call_cleanup(
        asserta(mm_source(Path), Ref),
        load_metta_file(Path, _, Space),
        erase(Ref)).

% Audit parses declarations only: no channel startup, Python imports, or bangs.
mm_audit(Path) :-
    ( mm_audited(Path) -> true
    ; assertz(mm_audited(Path)),
      ( file_name_extension(_, metta, Path)
      -> setup_call_cleanup(asserta(mm_source(Path), Ref),
             mm_audit_forms(Path), erase(Ref))
      ; true ) ).
mm_audit_forms(Path) :-
    read_file_to_string(Path, Source, []), string_codes(Source, Cs),
    strip(Cs, 0, Codes), phrase(top_forms(Forms, 1), Codes),
    forall(member(runnable(Text), Forms),
           (sread(Text, Term), mm_audit_term(Term))).
mm_audit_term(['import!', _, Spec]) :- !,
    mm_spec(Spec, Input), mm_resolve(Input, Path),
    mm_record(import, Spec, Path), mm_audit(Path).
mm_audit_term([import_prolog_functions_from_file, Spec, _]) :- !,
    mm_spec(Spec, Input), mm_resolve(Input, Path),
    mm_record(prolog, Spec, Path),
    ( file_base_name(Path, 'reasoner_engines.pl')
    -> forall(member(Name, ['lib_nars.metta', 'lib_pln.metta']),
              (mm_library(Name, Engine), mm_existing(Engine, Actual),
               mm_record(reasoner_engine, Name, Actual)))
    ; true ).
mm_audit_term(_).
mm_spec([library, Name], Path) :- !, mm_library(Name, Path).
mm_spec([library, Package, Name], Path) :- !, mm_library(Package, Name, Path).
mm_spec(Path, Path) :- atomic(Path), !.
mm_spec(Spec, _) :- throw(error(unsupported_import(Spec), _)).

mm_report(File) :-
    findall(_{owner:Owner, kind:Kind, requested:Text, resolved:Path},
            (mm_edge(Owner, Kind, Spec, Path), term_string(Spec, Text)), Edges),
    setup_call_cleanup(open(File, write, Out),
                       json_write_dict(Out, Edges, [width(0)]), close(Out)).

mm_main :-
    current_prolog_flag(argv, [Workspace, MetaMo, Entry, Mode, Report|_]),
    assertz(mm_root(petta, Workspace)), assertz(mm_root('MetaMo', MetaMo)),
    directory_file_path(Workspace, 'repos/OmegaClaw-Core', Omega),
    directory_file_path(Workspace, 'repos/petta_lib_chromadb', Chroma),
    assertz(mm_root('OmegaClaw-Core', Omega)),
    assertz(mm_root(petta_lib_chromadb, Chroma)),
    directory_file_path(Workspace, 'src/metta.pl', Compiler),
    consult(Compiler),
    % Use the same explicit namespace map for audit and execution.
    abolish(library/2), abolish(library/3), abolish('import!'/3),
    assertz((library(N, P) :- mm_library(N, P))),
    assertz((library(K, N, P) :- mm_library(K, N, P))),
    assertz(('import!'(S, I, R) :- mm_import(S, I, R))),
    mm_existing(Entry, Path),
    file_directory_name(Path, Dir), assertz(working_dir(Dir)),
    mm_audit(Path),
    ( Report == '-' -> true ; mm_report(Report) ),
    ( Mode == audit -> true
    ; mm_load_once('&self', Path) ).

:- initialization((catch((mm_main -> halt(0) ; halt(1)), Error,
                         (print_message(error, Error), halt(1)))), main).
