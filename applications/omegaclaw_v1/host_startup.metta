;; Trusted startup only; no configuration API is registered as a command skill.
!(import! &self (library MetaMo applications/omegaclaw_v1/host_dispatch_config.py))
!(import! &self (library MetaMo applications/omegaclaw_v1/host_ingress))
!(bind! &last-host-commitment-admission (new-state ()))
!(bind! &last-host-frame-completion (new-state ()))
!(bind! &last-host-task-provisioning (new-state ()))
;; Example: after Core admits a user frame, open its commitment before selection.
(= (prepareHostStartup)
   (progn
      (change-state! &new-msg-flag (hostInputIsFresh))
      (change-state! &last-host-frame-completion
         (sread (py-call (host_dispatch_config.complete_host_frame))))
      (change-state! &last-host-commitment-admission
         (sread (py-call (host_dispatch_config.admit_startup_commitment))))
      (change-state! &last-host-task-provisioning
         (sread (py-call (host_dispatch_config.provision_admitted_task))))
      (refreshTaskCommitment)
      1)
)


;; Disabled startup imports no reasoner modules or audit spaces.
;; Example: reasoner=disabled (the default); reasoner=nars or reasoner=pln opts in.
(= (initializeHostReasoner)
   (case (collapse (argk "reasoner")) (
      (() True)
      ((disabled) True)
      (($adapter)
         (progn
            (import! &self (library MetaMo applications/omegaclaw_v1/host_reasoner))
            (eval (startHostReasoner $adapter))))
      ($_ (ReasonerStartupRejected InvalidSelection))
   ))
)

;; Install the normal host hooks only after optional reasoner selection succeeds.
;; Example: (initializeHostStartup) -> True for a valid or disabled selection.
(= (initializeHostStartup)
   (progn
      (py-call (host_dispatch_config.configure_startup))
      (case (initializeHostReasoner) (
         (True
            (progn
               (if (== (eval (configureCoreLoopIngest ingestHostMessage True)) True)
                   True (py-call (host_operations.incompatible_core)))
               (if (== (eval (configureCoreLoopContext metaMoContext)) True)
                   True (py-call (host_operations.incompatible_core)))
               (if (== (eval (configureCoreLoopPrepare prepareHostStartup)) True)
                   True (py-call (host_operations.incompatible_core)))
            ))
         ($rejection $rejection)
      ))
   )
)
