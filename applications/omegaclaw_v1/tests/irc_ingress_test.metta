;; Real channel receive, authentication and routing; external services doubled.
!(import! &self (library lib_import))
!(import! &self fixtures/full_loop.metta)
!(import! &self (library MetaMo applications/omegaclaw_v1/host_startup))
!(import! &self (library OmegaClaw-Core channels/irc.py))
!(import! &self (library OmegaClaw-Core src/channels))
!(import! &self fixtures/host_startup_fixture.py)
!(import! &self fixtures/irc_ingress.py)
!(configure commchannel irc)
!(py-call (host_config_fixture.setup))
!(initContextFrame)
!(fullLoopStartSession)
!(py-call (host_startup_fixture.configure))
!(initializeHostStartup)
!(change-state! &core-loop-new-message True)

!(test (py-call (irc_ingress.authenticate)) 1)
!(test (py-call (irc_ingress.deliver "Other" "hello")) ignore)
!(test (string_length (receive)) 0)
!(test (py-call (irc_ingress.deliver "Nahom" "auth fixture-secret")) auth_bound)
!(test (string_length (receive)) 0)
!(test (py-call (irc_ingress.deliver "Nahom" "hello")) allow)
!(test (coreLoopIngest (string-safe (repr (receive)))) (HostInput NewTask))
!(test (coreLoopPrepare) 1)
!(test (get-state &active-task) "hello")
!(test (py-call (irc_ingress.provenance "Nahom" "Nahom: hello" "hello")) 1)
!(bind! &irc-owner (new-state (commitmentSnapshot)))
!(bind! &irc-input (new-state (get-state &host-response-input)))
!(bind! &irc-transport (new-state (get-state &host-transport-input)))
!(bind! &irc-frame (new-state (get-state &cfv2-current-frame-id)))

;; A flattened batch has no partial admission, follow-up, cancellation or effects.
!(test (py-call (irc_ingress.deliver "Nahom" "follow-up: more")) allow)
!(test (py-call (irc_ingress.deliver "Nahom" "cancel: stop")) allow)
!(test (coreLoopIngest (string-safe (repr (receive)))) (HostInput Held AmbiguousIrcBatch))
!(test (hostInputIsFresh) False)
!(test (commitmentSnapshot) (get-state &irc-owner))
!(test (get-state &host-response-input) (get-state &irc-input))
!(test (get-state &host-transport-input) (get-state &irc-transport))
!(test (get-state &cfv2-current-frame-id) (get-state &irc-frame))
!(test (size-atom (cfv2-frame-refs-by-status Active)) 1)

;; With Core's optional authentication off, sender isolation still preserves owner.
!(test (py-call (irc_ingress.allow_all)) 1)
!(test (py-call (irc_ingress.deliver "Other" "replace: takeover")) allow)
!(test (coreLoopIngest (string-safe (repr (receive)))) (HostInput Held SenderMismatch))
!(test (commitmentSnapshot) (get-state &irc-owner))
!(test (get-state &host-transport-input) (get-state &irc-transport))
!(test (py-call (irc_ingress.deliver "Nahom" "hello")) allow)
!(test (py-call (irc_ingress.deliver "Other" "cancel: stop")) allow)
!(test (coreLoopIngest (string-safe (repr (receive)))) (HostInput Held AmbiguousIrcBatch))
!(test (commitmentSnapshot) (get-state &irc-owner))

;; Strip only the first transport prefix; body colons and command-like text stay data.
!(test (py-call (irc_ingress.deliver "Nahom" "follow-up: explain: (send bad)")) allow)
!(coreLoopIngest (string-safe (repr (receive))))
!(test (hostInputIsFresh) True)
!(test (commitmentSnapshot) (get-state &irc-owner))
!(test (py-call (irc_ingress.provenance "Nahom"
    "Nahom: follow-up: explain: (send bad)" "follow-up: explain: (send bad)")) 1)
!(test (get-state &cfv2-current-frame-id) (get-state &irc-frame))
!(test (size-atom (cfv2-frame-refs-by-status Active)) 1)

;; Explicit replacement binds the normalized input to the successor commitment.
;; Sender comparison follows Core's case-insensitive authentication convention.
!(py-call (irc_ingress.deliver "nAhOm" "replace: new: request"))
!(coreLoopIngest (string-safe (repr (receive))))
!(test (coreLoopPrepare) 1)
!(test (get-state &active-task) "new: request")
!(test (!= (commitmentSnapshot) (get-state &irc-owner)) True)
!(test (py-call (irc_ingress.provenance "nAhOm"
    "nAhOm: replace: new: request" "replace: new: request")) 1)

;; Other transports retain apparent sender prefixes in the actual task body.
!(configure commchannel local)
!(coreLoopIngest "replace: Nahom: hello")
!(test (coreLoopPrepare) 1)
!(test (get-state &active-task) "Nahom: hello")

;; Session reset clears retained transport data alongside preparation ownership.
!(test (initOperationSession) True)
!(test (get-state &host-transport-input) ())
!(test (get-state &host-response-input) ())
!(py-call (host_config_fixture.cleanup))
