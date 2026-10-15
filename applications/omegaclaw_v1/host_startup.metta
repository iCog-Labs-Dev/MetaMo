;; Trusted startup only; no configuration API is registered as a command skill.
!(import! &self (library MetaMo applications/omegaclaw_v1/host_dispatch_config.py))
!(import! &self (library MetaMo applications/omegaclaw_v1/host_ingress))
!(bind! &last-host-commitment-admission (new-state ()))
;; Example: after Core admits a user frame, open its commitment before selection.
(= (prepareHostStartup)
   (progn
      (change-state! &new-msg-flag (hostInputIsFresh))
      (py-call (host_dispatch_config.provision_startup))
      (change-state! &last-host-commitment-admission
         (sread (py-call (host_dispatch_config.admit_startup_commitment))))
      (refreshTaskCommitment)
      1))
(= (initializeHostStartup)
   (progn
      (py-call (host_dispatch_config.configure_startup))
      (if (== (eval (configureCoreLoopIngest ingestHostMessage)) True)
          True (py-call (host_operations.incompatible_core)))
      (if (== (eval (configureCoreLoopContext metaMoContext)) True)
          True (py-call (host_operations.incompatible_core)))
      (if (== (eval (configureCoreLoopPrepare prepareHostStartup)) True)
          True (py-call (host_operations.incompatible_core)))))
