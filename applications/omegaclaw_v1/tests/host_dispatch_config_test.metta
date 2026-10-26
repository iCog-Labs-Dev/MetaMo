;; Provision the real session adapter and invoke existing local Core handlers.
;; No channels, LLMs or storage providers are loaded.
!(import! &self (library OmegaClaw-Core src/helper.py))
!(import! &self (library OmegaClaw-Core src/utils))
!(import! &self (library OmegaClaw-Core src/context))
!(import! &self (library OmegaClaw-Core src/skills))
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
!(import! &self (library MetaMo applications/omegaclaw_v1/dispatch))
!(import! &self (library MetaMo applications/omegaclaw_v1/host_dispatch_config.py))
!(import! &self fixtures/host_config_fixture.py)
!(import_prolog_functions_from_file
   (library MetaMo applications/omegaclaw_v1/tests/fixtures/dispatch.pl)
   (hostBudgetFixturePublish hostBudgetFixtureFrame hostBudgetFixtureRejectProvision
    hostBudgetFixturePolicies hostBudgetFixtureRevoke hostBudgetFixtureReserve))
(= (maxOutputToken) 256)
(= (wakeupInterval) 1)
(= (getFrameSkillsCompact) (quote (read-file show-current-frame)))
!(bind! &prevmsg (new-state ""))
!(bind! &lastresults (new-state ""))
!(bind! &error (new-state ""))
!(bind! &loops (new-state 1))
!(bind! &nextWakeAt (new-state 0))
!(initContextFrame)
;; Supply a typed host frame identity for the concrete-operation contract.
;; Native Core ID migration is a separate production projection task.
!(change-state! &cfv2-current-frame-id "configured-frame")
!(change-state! &cfv2-current-status Active)
!(change-state! &cfv2-root-mode Fast)
!(change-state! &cfv2-current-frame-mode Fast)
!(setConstitutionalMode Engaged)
!(initMetaMoDispatch)
!(bind! &host-config-path (new-state (py-call (host_config_fixture.setup))))
!(bind! &host-read-command (new-state (sread (py-call (host_config_fixture.command)))))
(= (hostReadIntent) (AdmissionRequest propose-candidate current-frame execute-skill))
(= (hostFrameIntent) (AdmissionRequest propose-candidate current-frame search-knowledge))
(= (hostReadTicket) (coreDispatchCapture (hostReadIntent)))

;; Missing config does not authorize even a known Core handler.
!(bind! &missing-ticket (new-state (hostReadTicket)))
!(test (coreDispatchCommand (get-state &missing-ticket) (get-state &host-read-command))
   (DispatchResult Blocked UnsupportedOperation none))
!(test (sread (py-call (host_dispatch_config.provision (get-state &host-config-path))))
   (HostDispatchConfigured "configured-frame" 2))
!(bind! &allowed-ticket (new-state (hostReadTicket)))
!(test (coreDispatchCommand (get-state &allowed-ticket) (get-state &host-read-command))
   (DispatchResult Executed Feasible "observed local file content"))
!(test (coreDispatchCommand (get-state &allowed-ticket) (get-state &host-read-command))
   (DispatchResult Executed Feasible "observed local file content"))
!(test (coreDispatchCommand (hostReadTicket) (quote (read-file "/unregistered/path")))
   (DispatchResult Blocked UnsupportedOperation none))
!(test (coreDispatchCommand (hostReadTicket) (quote (read-file (change-state! &error "injected"))))
   (DispatchResult Blocked UnsupportedOperation none))
!(test (get-state &error) "")
!(test (coreDispatchCommand (hostReadTicket) (quote (shell "pwd")))
   (DispatchResult Blocked UnsupportedOperation none))
!(test (coreDispatchCommand (hostReadTicket) (quote (show-current-frame)))
   (DispatchResult Blocked UnsupportedOperation none))
!(test (coreDispatchCommand (coreDispatchCapture (hostFrameIntent)) (quote (show-current-frame)))
   (DispatchResult Executed Feasible (cfv2-current-frame)))

;; Atomic reprovision replaces prior bindings and invalidates outstanding work.
!(bind! &old-ticket (new-state (hostReadTicket)))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "permission-denied"))))
!(test (coreDispatchCommand (get-state &old-ticket) (get-state &host-read-command))
   (DispatchResult Blocked StaleSnapshot none))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
   (DispatchResult Blocked PermissionDenied none))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "global-denied"))))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
   (DispatchResult Blocked SkillNotAllowed none))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "budget-denied"))))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
   (DispatchResult Blocked BudgetExhausted none))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "constraint-denied"))))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
   (DispatchResult Blocked ConstraintDenied none))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "cost-denied"))))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
   (DispatchResult Blocked ConstraintDenied none))
;; Invalid configuration preserves the installed restriction.
!(test (py-call (host_config_fixture.rejects_invalid)) 1)
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
   (DispatchResult Blocked ConstraintDenied none))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "empty"))))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
   (DispatchResult Blocked UnsupportedOperation none))

;; Live accounting reaches normal capture/admission and final Core invocation.
;; Updates below simulate host metering; automatic dispatch charging is item 1.3.
(= (hostBudgetId $scope)
    (BudgetAccountId "host" $scope "commands" "units")
)

(= (hostBudgetState $globalSpent $globalReserved $frameSpent $frameReserved)
    (BudgetAccounts
        ((BudgetAccount (hostBudgetId Global) 10 $globalSpent $globalReserved Open 1)
         (BudgetAccount (hostBudgetId (FrameTarget "configured-frame"))
            2 $frameSpent $frameReserved Open 1)) ())
)

;; Example: this traverses the actual production provider, not a pure gate fixture.
(= (hostBudgetAdmission)
    (let*
        (
            ($bundle (frameStateForMetaMo))
            ($_ (setActiveFrameBundle $bundle))
            ($rows (captureCandidateOperations $bundle))
        )
        (hostOperationGate $bundle execute-skill $rows)
    )
)

;; Example: both installed scopes expose their live command availability.
(= (hostBudgetPublishedAmounts)
    (map-atom (hostBudgetFixturePolicies) $scope
        (index-atom (index-atom (index-atom $scope 6) 1) 0))
)

!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "allowed"))))
!(test (budgetAvailability (hostBudgetId Global)) (ResourceBudget "commands" "units" 10 Open))
!(test (budgetAvailability (hostBudgetId (FrameTarget "configured-frame")))
    (ResourceBudget "commands" "units" 2 Open))

!(hostBudgetFixturePublish (hostBudgetState 7 3 0 0))
!(test (hostBudgetPublishedAmounts)
    ((ResourceBudget "commands" "units" 0 Open) (ResourceBudget "commands" "units" 2 Open)))
!(test (hostBudgetAdmission) (GateDecision Rejected BudgetExhausted))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
    (DispatchResult Blocked BudgetExhausted none))

!(hostBudgetFixturePublish (hostBudgetState 0 0 1 1))
!(test (hostBudgetAdmission) (GateDecision Rejected BudgetExhausted))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
    (DispatchResult Blocked BudgetExhausted none))

!(hostBudgetFixturePublish (hostBudgetState 7 2 1 0))
!(test (hostBudgetPublishedAmounts)
    ((ResourceBudget "commands" "units" 1 Open) (ResourceBudget "commands" "units" 1 Open)))
!(test (hostBudgetAdmission) (GateDecision Admitted Feasible))

;; Repeated policy installation and task revocation never replenish accounts.
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "allowed"))))
!(test (get-state &budget-account-state) (hostBudgetState 7 2 1 0))
!(hostBudgetFixtureRevoke)
!(test (get-state &budget-account-state) (hostBudgetState 7 2 1 0))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "allowed"))))
!(test (get-state &budget-account-state) (hostBudgetState 7 2 1 0))

;; Native symbol frame IDs remain distinct from strings. Returning to the old
;; frame retains its balance; a new frame cannot replenish the global account.
!(hostBudgetFixtureFrame frame-next)
!(test (budgetAvailability (hostBudgetId Global)) (ResourceBudget "commands" "units" 1 Open))
!(test (budgetAvailability (hostBudgetId (FrameTarget frame-next)))
    (ResourceBudget "commands" "units" 2 Open))
!(test (budgetAvailability (hostBudgetId (FrameTarget "frame-next")))
    (BudgetAccountingRejected MissingBudgetAccount))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "allowed"))))
!(test (budgetAvailability (hostBudgetId (FrameTarget "configured-frame")))
    (ResourceBudget "commands" "units" 1 Open))

;; A tighter policy ceiling still wins over accounting availability.
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "budget-denied"))))
!(test (hostBudgetPublishedAmounts)
    ((ResourceBudget "commands" "units" 1 Open) (ResourceBudget "commands" "units" 0 Open)))
!(test (hostBudgetAdmission) (GateDecision Rejected BudgetExhausted))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "allowed"))))

;; Existing reservation records also survive provisioning and reduce admission.
!(test (hostBudgetFixtureReserve (DispatchTicket "host-budget-reservation")
    (BudgetOperation (quote (show-current-frame))
        (PolicyOperation (candidate search-knowledge) (target "configured-frame")
            (skill "show-current-frame") (permissions ("frames.read")) (egress ())
            (costs ((ResourceCost "commands" "units" 1)))))
    ((AccountCost (hostBudgetId Global) 1)
     (AccountCost (hostBudgetId (FrameTarget "configured-frame")) 1)))
    (BudgetReserved (DispatchTicket "host-budget-reservation")
        ((AccountCost (hostBudgetId Global) 1)
         (AccountCost (hostBudgetId (FrameTarget "configured-frame")) 1))))
!(bind! &reserved-host-budget (new-state (get-state &budget-account-state)))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "allowed"))))
!(test (get-state &budget-account-state) (get-state &reserved-host-budget))
!(test (hostBudgetAdmission) (GateDecision Rejected BudgetExhausted))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
    (DispatchResult Blocked BudgetExhausted none))

;; A balance update after ticket capture is revalidated at final invocation.
!(hostBudgetFixturePublish (hostBudgetState 0 0 0 0))
!(bind! &accounting-ticket (new-state (hostReadTicket)))
!(hostBudgetFixturePublish (hostBudgetState 9 1 0 0))
!(test (coreDispatchCommand (get-state &accounting-ticket) (get-state &host-read-command))
    (DispatchResult Blocked StaleSnapshot none))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
    (DispatchResult Blocked BudgetExhausted none))

;; Even an out-of-contract state write with unchanged availability cannot reuse
;; a ticket: the host snapshot retains accounting revisions, not only balances.
!(hostBudgetFixturePublish (hostBudgetState 7 2 1 0))
!(bind! &revision-ticket (new-state (hostReadTicket)))
!(change-state! &budget-account-state (hostBudgetState 8 1 1 0))
!(test (coreDispatchCommand (get-state &revision-ticket) (get-state &host-read-command))
    (DispatchResult Blocked StaleSnapshot none))

;; Closed accounting cannot be reopened by an Open configured policy.
!(hostBudgetFixturePublish (BudgetAccounts
    ((BudgetAccount (hostBudgetId Global) 10 0 0 Closed 2)
     (BudgetAccount (hostBudgetId (FrameTarget "configured-frame")) 2 0 0 Open 1)) ()))
!(test (hostBudgetAdmission) (GateDecision Rejected BudgetExhausted))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
    (DispatchResult Blocked BudgetExhausted none))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "allowed"))))
!(test (budgetAvailability (hostBudgetId Global)) (ResourceBudget "commands" "units" 10 Closed))

;; Missing accounts and corrupt storage cannot fall back to configured limits.
!(hostBudgetFixturePublish (BudgetAccounts () ()))
!(test (hostBudgetAdmission) (GateDecision Rejected InvalidGlobalPolicy))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
    (DispatchResult Blocked InvalidGlobalPolicy none))
!(hostBudgetFixturePublish (BudgetAccounts
    ((BudgetAccount (hostBudgetId Global) 10 0 0 Open 1)) ()))
!(test (hostBudgetAdmission) (GateDecision Rejected InvalidFramePolicy))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
    (DispatchResult Blocked InvalidFramePolicy none))
!(hostBudgetFixturePublish (BudgetAccounts Broken ()))
!(test (hostBudgetAdmission) (GateDecision Rejected InvalidGlobalPolicy))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
    (DispatchResult Blocked InvalidGlobalPolicy none))
!(test (hostBudgetFixtureRejectProvision) True)
!(test (get-state &budget-account-state) (BudgetAccounts Broken ()))
!(hostBudgetFixturePublish BudgetAccountsUninitialized)
!(test (hostBudgetAdmission) (GateDecision Rejected InvalidGlobalPolicy))
!(test (coreDispatchCommand (hostReadTicket) (get-state &host-read-command))
    (DispatchResult Blocked InvalidGlobalPolicy none))

!(test (py-call (host_config_fixture.cleanup)) 1)
