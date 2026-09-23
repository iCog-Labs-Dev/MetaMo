"""Read trusted dispatch bindings and capture existing Core tickets atomically.

Policy evaluation and selection live in MeTTa. This bridge neither provisions
permissions nor executes commands. Use only in the serialized host interpreter.
"""


def new_session():
    from uuid import uuid4
    return '"' + str(uuid4()) + '"'  # Preserve String type through PeTTa's Python bridge.


def capture():
    import janus
    result = janus.query_once("""
with_mutex(omegaclaw_dispatch, (
    eval(['get-state','&active-frame-bundle'], _Bundle),
    (oc_dispatch_hooks(mm_dispatch_snapshot, mm_dispatch_resolve,
                       mm_dispatch_gate, mm_dispatch_execute),
     eval([frameStateForMetaMo], _Current), _Current == _Bundle,
     mm_dispatch_policies(_Global, _Frame)
     -> findall([_Candidate,_Command,_Operation],
          mm_dispatch_binding(_Command,
            ['AdmissionRequest','propose-candidate','current-frame',_Candidate],
            _Operation), _Bindings),
        length(_Bindings, _Count),
        (_Count =< 128
         -> findall(['HostOperation',_Candidate,_Command,_Operation,_Global,_Frame,_Ticket],
              (member([_Candidate,_Command,_Operation], _Bindings),
               coreDispatchCapture(
                 ['AdmissionRequest','propose-candidate','current-frame',_Candidate], _Ticket)),
              _Rows)
         ; _Rows=[])
     ; _Rows=[]),
    swrite(_Rows, Text)
))
""")
    if not result.get("truth", False):
        return "()"
    return result["Text"]


def incompatible_core():
    raise RuntimeError("OmegaClaw-Core requires the MeTTa loop dispatch hooks; refusing startup")
