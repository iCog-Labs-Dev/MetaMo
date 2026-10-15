;; Real admission, config installation, policy gate and read handler; external I/O doubled.
!(import! &self fixtures/full_loop.metta)
!(import! &self (library MetaMo applications/omegaclaw_v1/runtime_support))
!(import! &self (library MetaMo applications/omegaclaw_v1/host_startup))
!(import! &self fixtures/host_startup_fixture.py)
!(import_prolog_functions_from_file
    (library MetaMo applications/omegaclaw_v1/tests/fixtures/commitments.pl)
    (commitmentFixtureReset commitmentFixtureEpoch))
!(import_prolog_functions_from_file
    (library MetaMo applications/omegaclaw_v1/tests/fixtures/dispatch.pl)
    (taskProvisioningPending taskProvisioningSettled taskProvisioningOwner))
!(commitmentFixtureReset)
!(py-call (host_config_fixture.setup))
!(initContextFrame)
!(fullLoopStartSession)
!(py-call (host_startup_fixture.configure))
!(initializeHostStartup)

!(test (coreLoopPrepare) 1)

!(test (get-state &last-host-task-provisioning) (TaskProvisioning NoAdmittedCommitment))
!(coreLoopIngest "Read the allowed file")
!(cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
!(coreLoopPrepare)
!(setConstitutionalMode Engaged)
!(bind! &provision-owner (new-state (commitmentSnapshot)))
!(bind! &provision-frame (new-state (get-state &cfv2-current-frame-id)))
!(bind! &provision-command (new-state (sread (py-call (host_config_fixture.command)))))

!(test (get-state &last-host-task-provisioning) (TaskProvisioning Installed))

!(test (taskProvisioningOwner) (get-state &provision-owner))

;; Example: capture an exact read ticket under the current native task's policy.
(= (provisionReadTicket)
    (coreDispatchCapture (AdmissionRequest propose-candidate current-frame execute-skill))
)
!(bind! &provision-ticket (new-state (provisionReadTicket)))
!(bind! &provision-epoch (new-state (commitmentFixtureEpoch)))
!(coreLoopPrepare)

!(test (get-state &last-host-task-provisioning) (TaskProvisioning Retained))

!(test (commitmentFixtureEpoch) (get-state &provision-epoch))

!(test (coreDispatchCommand (get-state &provision-ticket) (get-state &provision-command))
    (DispatchResult Executed Feasible "observed local file content"))

;; An unresolved invocation prevents replacement and fresh admission.
!(bind! &pending-replacement (new-state (hostIngressDecision Replace)))
!(taskProvisioningPending)

!(test (coreLoopIngest "replace: Another read") (HostInput Held OutstandingInvocation))

!(test (hostIngressApply (get-state &pending-replacement) "replace: delayed decision")
    (HostInput Held OutstandingInvocation))

!(test (commitmentSnapshot) (get-state &provision-owner))
!(coreLoopPrepare)

!(test (get-state &last-host-task-provisioning) (TaskProvisioning OutstandingInvocation))
!(coreLoopIngest "cancel: stop this task")

!(test (coreLoopIngest "A different task") (HostInput Held OutstandingInvocation))

!(test (get-state &cfv2-last-admitted-frame-id) (get-state &provision-frame))
!(coreLoopPrepare)

!(test (get-state &last-host-commitment-admission) (CommitmentRejected OutstandingInvocation))
!(taskProvisioningSettled)

;; The next admitted frame receives the same explicit template, with fresh ownership.
!(bind! &provision-old-ticket (new-state (provisionReadTicket)))
!(coreLoopIngest "A different task")
!(cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
!(coreLoopPrepare)
!(bind! &second-provision-owner (new-state (commitmentSnapshot)))

!(test (get-state &last-host-task-provisioning) (TaskProvisioning Installed))

!(test (!= (get-state &cfv2-current-frame-id) (get-state &provision-frame)) True)

!(test (taskProvisioningOwner) (get-state &second-provision-owner))

!(test (py-call (host_startup_fixture.stale_owner (repr (get-state &provision-owner)))) 1)

!(test (taskProvisioningOwner) (get-state &second-provision-owner))

!(test (coreDispatchCommand (get-state &provision-old-ticket) (get-state &provision-command))
    (DispatchResult Blocked StaleSnapshot none))

!(test (coreDispatchCommand (provisionReadTicket) (get-state &provision-command))
    (DispatchResult Executed Feasible "observed local file content"))

;; Replacement changes ownership even on the same frame; no old ticket follows it.
!(bind! &replacement-old-ticket (new-state (provisionReadTicket)))
!(coreLoopIngest "replace: Inspect it again")

!(test (coreDispatchCommand (provisionReadTicket) (get-state &provision-command))
    (DispatchResult Blocked UnsupportedOperation none))
!(coreLoopPrepare)

!(test (get-state &last-host-task-provisioning) (TaskProvisioning Installed))

!(test (!= (taskProvisioningOwner) (get-state &second-provision-owner)) True)

!(test (coreDispatchCommand (get-state &replacement-old-ticket) (get-state &provision-command))
    (DispatchResult Blocked StaleSnapshot none))

!(test (coreDispatchCommand (provisionReadTicket) (get-state &provision-command))
    (DispatchResult Executed Feasible "observed local file content"))

;; Operator restrictions remain effective after reconfiguration and replacement.
!(py-call (host_startup_fixture.configure "permission-denied"))
!(coreLoopPrepare)

!(test (coreDispatchCommand (provisionReadTicket) (get-state &provision-command))
    (DispatchResult Blocked PermissionDenied none))
!(coreLoopIngest "replace: Still restricted")
!(coreLoopPrepare)

!(test (coreDispatchCommand (provisionReadTicket) (get-state &provision-command))
    (DispatchResult Blocked PermissionDenied none))

;; A concrete target never becomes a wildcard for another admitted frame.
!(py-call (host_startup_fixture.disable))
!(coreLoopPrepare)

!(test (get-state &last-host-task-provisioning) (TaskProvisioning MissingConfiguration))

!(test (coreDispatchCommand (provisionReadTicket) (get-state &provision-command))
    (DispatchResult Blocked UnsupportedOperation none))

!(py-call (host_startup_fixture.configure "allowed" "different-frame"))
!(coreLoopIngest "replace: Target remains pinned")
!(coreLoopPrepare)

!(test (get-state &last-host-task-provisioning) (TaskProvisioning TargetMismatch))

!(test (coreDispatchCommand (provisionReadTicket) (get-state &provision-command))
    (DispatchResult Blocked UnsupportedOperation none))
!(py-call (host_config_fixture.cleanup))
