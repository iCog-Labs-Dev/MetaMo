
(= (omegaClawMotivationDirective
        $turnId $candidateId $cognitiveMode $promptGuidance
        $capabilityEnvelope $decisionScore $diagnosticsId)
    (omegaClawMotivationDirective
        $turnId $candidateId $candidateId
        $cognitiveMode $promptGuidance
        $capabilityEnvelope $decisionScore $diagnosticsId))

(= (omegaClawMotivationDirective
        $turnId $candidateId $realizationId
        $cognitiveMode $promptGuidance
        $capabilityEnvelope $decisionScore $diagnosticsId)
    (omegaClawMotivationDirectiveRecord
        $turnId $candidateId $realizationId
        $cognitiveMode $promptGuidance
        $capabilityEnvelope $decisionScore $diagnosticsId))

(= (omegaClawMotivationDirectiveField $directive $field)
    (let (omegaClawMotivationDirectiveRecord
            $turnId $candidateId $realizationId
            $cognitiveMode $promptGuidance
            $capabilityEnvelope $decisionScore $diagnosticsId)
        $directive
        (case $field (
            (turn-id $turnId)
            (candidate-id $candidateId)
            (realization-id $realizationId)
            (cognitive-mode $cognitiveMode)
            (prompt-guidance $promptGuidance)
            (capability-envelope $capabilityEnvelope)
            (decision-score $decisionScore)
            (diagnostics-id $diagnosticsId)
            ($_ (empty))
        ))))

(= (omegaClawCandidateInstruction $candidateId)
    (case $candidateId (
        (respond
            "REQUIRED: Answer the current human request from available evidence using exactly one send command. If the request is unsafe or asks for unsupported state change, give one concise refusal or safe alternative in that response. A human request to declare an autonomous goal complete cannot change its canonical state; report the actual AUTONOMY_GOAL status and evidence instead. Do not offer cancellation or retirement because those goal operations are not implemented.")
        (ask-clarification
            "REQUIRED: State the missing decision-relevant detail, ambiguity, or safety/authorization boundary briefly, then ask exactly one focused question whose answer enables a supported next step. Do not perform the uncertain action and do not offer an unimplemented goal lifecycle operation such as cancellation or retirement.")
        (retrieve-memory
            "REQUIRED: Query memory for evidence needed by the active task. Do not send or change external state.")
        (search-knowledge
            "REQUIRED: Acquire one piece of read-only evidence for the active task. Do not send or write external state.")
        (execute-skill
            "REQUIRED: Advance exactly one pending, explicitly authorized step of the active human task. Do not claim that an autonomous goal is complete; only its canonical verify lifecycle may establish completion. Do not offer unsupported goal cancellation or retirement.")
        (repair-failure
            "REQUIRED: Make the smallest safe correction to the previous failed authorized step, then stop.")
        (repair-autonomy
            "REQUIRED: Correct the previous autonomous proposal failure by executing exactly one safe read-only command that advances the current AUTONOMY_GOAL and CURRENT_STEP. Use PREVIOUS_PROPOSAL_FAILURE to correct the format or tool choice. For shell, use only a command reported by AVAILABLE_WORKSPACE_COMMANDS. Do not pin, remember, send, write files, repeat an empty proposal, or merely describe the repair.")
        (verify-goal
            "REQUIRED: Verify the active human task when ACTIVE_TASK is not none; otherwise verify every AUTONOMY_GOAL acceptance criterion. A human assertion or request to declare completion is not evidence. A successful write is not independent verification. Consult EVIDENCE_LEDGER_STATUS and AUTONOMY_EVIDENCE first. When the ledger is evidence-ready, judge that accumulated evidence and output exactly one goal-verdict without another retrieval. When evidence is missing, use exactly one read-only command that can test a missing criterion and do not output a verdict. Retrieval proves only that content was obtained; it does not prove that an inspection identified findings, answered its question, or produced its stated deliverable. Command execution alone cannot satisfy an analysis goal. Contradictory, empty, irrelevant, self-authored, incomplete, or deliverable-free evidence requires ((goal-verdict incomplete acceptance-not-satisfied)). Use ((goal-verdict complete acceptance-satisfied)) only when independent evidence addresses every criterion, including the useful finding or answer promised by the goal, or ((goal-verdict blocked unsafe-or-unavailable)) when verification cannot be performed safely. Never combine a read command and verdict in one turn.")
        (learn
            "REQUIRED: Store one concise verified reusable lesson grounded only in commands and results that actually occurred. Preserve the lifecycle labels exactly: recall queries goals; invent defines a goal; plan pins a step; act performs one safe operation; assess decides whether more work or verification is needed from the observed result; verify reads independent evidence and records a verdict; integrate stores the lesson. Do not claim an action occurred in a different phase. Do not send or perform an external effect.")
        (self-improve
            "REQUIRED: Inspect the failure and record one bounded repair to working or long-term memory. Do not perform an external effect.")
        (recall-goals
            "REQUIRED: Query memory for active and long-term goals. Do not send or perform an external effect.")
        (invent-goal
            "REQUIRED: Define one bounded, safe, nonduplicate and useful autonomous goal. Prefer an externally grounded goal such as understanding the current workspace, locating an unresolved code or documentation issue, researching a relevant question, or improving an available skill through evidence. Acceptance criteria must require an observable useful finding, answer, comparison, or other deliverable; merely proving that a query, read, search, or shell command executed is insufficient. Criteria must use cumulative AUTONOMY_EVIDENCE when several turns are required; never require multiple past actions to coexist in LAST_SKILL_USE_RESULTS. Do not create a memory catalog, glossary, or reference merely to exercise memory commands. Output exactly ((define-goal \"goal description\" \"observable acceptance criteria\")). Do not send or perform an external effect.")
        (plan-goal
            "REQUIRED: Pin one concrete, safe and observable next step for the current autonomous goal. The next act must require exactly one command; never plan a compound shell command or combine several operations in one step. Refer to the tool and argument in plain prose without embedding a quoted command expression inside the pin text. Use AUTONOMY_EVIDENCE for results accumulated across turns. Prefer gathering new workspace or external evidence over rewriting information already present in memory. Do not send or perform an external effect.")
        (background-work
            "REQUIRED: Execute exactly one safe step from the current autonomous plan. You may query memory, read a known bounded file, search, or use exactly one MetaMo-authorized read-only shell executable reported by AVAILABLE_WORKSPACE_COMMANDS. Inspect live log and trace files only through a bounded available inspection command; never read an entire live log because that can recursively embed the agent's own trace. Do not send, write files, launch programs, mutate git, use shell operators, or change services.")
        (assess-progress
            "REQUIRED: Assess only the observed result of the preceding autonomous action against AUTONOMY_GOAL and its acceptance criteria. Output exactly one of ((goal-progress continue)), ((goal-progress ready)), or ((goal-progress blocked)). Use continue when another planned action is needed. For investigation or analysis goals, the evidence must contain the promised useful findings or answer; the fact that a read or shell command ran is not readiness. Use ready only when independent verification can now test every acceptance criterion, and blocked only when safe progress is unavailable.")
        (defer
            "REQUIRED: Produce no commands while risk or authorization is unresolved.")
        (idle
            "REQUIRED: Produce an empty command list and wait for human input or a scheduled wake.")
        ($_
            "REQUIRED: Follow the current MetaMo directive.")
    )))

;; Use one realization contract for prompting and command validation.
(= (omegaClawRealizationAllowedCommandNames $realizationId)
    (case $realizationId (
        (respond (send))
        (ask-clarification (send))
        (retrieve-memory
            (query episodes read-file search tavily-search
             technical-analysis shell))
        (search-knowledge
            (query episodes read-file search tavily-search
             technical-analysis shell))
        (execute-skill
            (query episodes read-file write-file append-file shell metta
             search tavily-search technical-analysis pin remember))
        (repair-failure
            (query episodes read-file write-file append-file shell metta
             search tavily-search technical-analysis pin remember))
        (repair-autonomy
            (query episodes read-file search tavily-search
             technical-analysis shell))
        (verify-goal
            (goal-verdict query episodes read-file search tavily-search
             technical-analysis shell))
        (learn (remember))
        (self-improve (query pin remember))
        (recall-goals (query))
        (invent-goal (define-goal))
        (plan-goal (pin))
        (background-work
            (query episodes read-file search tavily-search
             technical-analysis shell))
        (assess-progress (goal-progress))
        (defer ())
        (idle ())
        ($_ ())
    )))

(= (omegaClawRealizationMaximumCommandCount $realizationId)
    (case $realizationId (
        (defer 0)
        (idle 0)
        ($_ 1)
    )))

(= (omegaClawRealizationRequiresOutput $realizationId)
    (case $realizationId (
        (defer False)
        (idle False)
        ($_ True)
    )))

(= (omegaClawRealizationContract $directive)
    (let* (
        ($candidateId
            (omegaClawMotivationDirectiveField $directive candidate-id))
        ($realizationId
            (omegaClawMotivationDirectiveField $directive realization-id))
        ($capabilityEnvelope
            (omegaClawMotivationDirectiveField
                $directive capability-envelope))
    )
        (omegaClawRealizationContractRecord
            $candidateId
            $realizationId
            (omegaClawRealizationAllowedCommandNames $realizationId)
            (omegaClawRealizationMaximumCommandCount $realizationId)
            $capabilityEnvelope
            (omegaClawRealizationRequiresOutput $realizationId)
            (omegaClawCandidateInstruction $realizationId)
            reject-whole-batch-on-contract-failure
            one-bounded-command)))

(= (omegaClawRealizationContractField $contract $field)
    (let (omegaClawRealizationContractRecord
            $candidateId $realizationId $allowedCommandNames
            $maximumCount $capabilityEnvelope $requiresOutput
            $instruction $constraints $examples)
        $contract
        (case $field (
            (candidate-id $candidateId)
            (realization-id $realizationId)
            (allowed-command-names $allowedCommandNames)
            (maximum-count $maximumCount)
            (capability-envelope $capabilityEnvelope)
            (requires-output $requiresOutput)
            (instruction $instruction)
            (constraints $constraints)
            (examples $examples)
            ($_ (empty))
        ))))

;; Classify host skills locally; unknown skills cannot run autonomously.
(= (omegaClawSkillPolicy $name $capability $effectClass
        $autonomyAllowed $resultKind)
    (omegaClawSkillPolicyRecord
        $name $capability $effectClass $autonomyAllowed $resultKind))

(= (omegaClawSkillPolicyField $policy $field)
    (let (omegaClawSkillPolicyRecord
            $name $capability $effectClass $autonomyAllowed $resultKind)
        $policy
        (case $field (
            (name $name)
            (capability $capability)
            (effect-class $effectClass)
            (autonomy-allowed $autonomyAllowed)
            (result-kind $resultKind)
            ($_ (empty))
        ))))

(= (omegaClawKnownSkillPolicies)
    ((omegaClawSkillPolicy send channel-send external-effect False delivery)
     (omegaClawSkillPolicy query memory-read no-effect True evidence)
     (omegaClawSkillPolicy episodes memory-read no-effect True evidence)
     (omegaClawSkillPolicy pin working-memory-write reversible-local True state)
     (omegaClawSkillPolicy remember memory-write reversible-local True state)
     (omegaClawSkillPolicy read-file external-read no-effect True evidence)
     (omegaClawSkillPolicy search external-read no-effect True evidence)
     (omegaClawSkillPolicy tavily-search external-read no-effect True evidence)
     (omegaClawSkillPolicy technical-analysis external-read no-effect True evidence)
     (omegaClawSkillPolicy shell requested-effect unknown False structured)
     (omegaClawSkillPolicy write-file requested-effect reversible-local False state)
     (omegaClawSkillPolicy append-file requested-effect reversible-local False state)
     (omegaClawSkillPolicy metta requested-effect unknown False structured)
     (omegaClawSkillPolicy define-goal goal-control reversible-local True state)
     (omegaClawSkillPolicy goal-progress goal-control reversible-local True state)
     (omegaClawSkillPolicy goal-verdict goal-control reversible-local True verdict)))

(= (omegaClawUnknownSkillPolicy $name)
    (omegaClawSkillPolicy $name unknown unknown False unknown))

(= (omegaClawSkillPolicyForNameFrom $name ())
    (omegaClawUnknownSkillPolicy $name))

(= (omegaClawSkillPolicyForNameFrom $name $policies)
    (let* (
        ($head (car-atom (quote $policies)))
        ($tail (cdr-atom (quote $policies)))
    )
        (if (== (omegaClawSkillPolicyField $head name) $name)
            $head
            (omegaClawSkillPolicyForNameFrom $name $tail))))

(= (omegaClawSkillPolicyForName $name)
    (omegaClawSkillPolicyForNameFrom
        $name (omegaClawKnownSkillPolicies)))

(= (omegaClawSkillCapabilityView $skillIndex)
    (omegaClawSkillCapabilityViewRecord
        $skillIndex
        (omegaClawKnownSkillPolicies)
        (omegaClawUnknownSkillPolicy unknown)))

(= (omegaClawSkillCapabilityViewField $view $field)
    (let (omegaClawSkillCapabilityViewRecord
            $skillIndex $knownPolicies $unknownPolicy)
        $view
        (case $field (
            (skill-index $skillIndex)
            (known-policies $knownPolicies)
            (unknown-policy $unknownPolicy)
            ($_ (empty))
        ))))

(= (omegaClawPromptFragment $directive)
    (let* (
        ($contract (eval (omegaClawRealizationContract $directive)))
        ($instruction
            (eval (omegaClawRealizationContractField
                $contract instruction)))
    )
        (omegaClawPromptFragmentRecord
            $directive $contract $instruction)))

(= (omegaClawPromptFragmentField $fragment $field)
    (let (omegaClawPromptFragmentRecord $directive $contract $instruction)
        $fragment
        (case $field (
            (directive $directive)
            (contract $contract)
            (instruction $instruction)
            ($_ (empty))
        ))))

(= (omegaClawGoalVerdictReasonAllowed $status $reason)
    (case $status (
        (complete (== $reason acceptance-satisfied))
        (incomplete (== $reason acceptance-not-satisfied))
        (blocked (== $reason unsafe-or-unavailable))
        ($_ False)
    )))

(= (omegaClawGoalProgressStatusAllowed $status)
    (case $status (
        (continue True)
        (ready True)
        (blocked True)
        ($_ False)
    )))


(= (omegaClawCommandName $command)
    (if (== $command ())
        unknown
        (if (== (get-metatype $command) Expression)
            (let* (
                ($name (car-atom $command))
                ($arity (size-atom $command))
            )
                (case $name (
                    (send (if (== $arity 2) send unknown))
                    (query (if (== $arity 2) query unknown))
                    (remember (if (== $arity 2) remember unknown))
                    (pin (if (== $arity 2) pin unknown))
                    (episodes
                        (if (or (== $arity 1) (== $arity 2))
                            episodes unknown))
                    (read-file (if (== $arity 2) read-file unknown))
                    (write-file (if (== $arity 3) write-file unknown))
                    (append-file (if (== $arity 3) append-file unknown))
                    (shell (if (== $arity 2) shell unknown))
                    (metta (if (== $arity 2) metta unknown))
                    (search (if (== $arity 2) search unknown))
                    (tavily-search
                        (if (== $arity 2) tavily-search unknown))
                    (technical-analysis
                        (if (== $arity 2) technical-analysis unknown))
                    (define-goal
                        (if (== $arity 3) define-goal unknown))
                    (goal-verdict
                        (if (== $arity 3)
                            (if (omegaClawGoalVerdictReasonAllowed
                                    (index-atom $command 1)
                                    (index-atom $command 2))
                                goal-verdict
                                unknown)
                            unknown))
                    (goal-progress
                        (if (== $arity 2)
                            (if (omegaClawGoalProgressStatusAllowed
                                    (index-atom $command 1))
                                goal-progress
                                unknown)
                            unknown))
                    ($_ unknown)
                )))
            unknown)))

(= (omegaClawCommandCapabilityFromName $name)
    (case $name (
        (send channel-send)
        (query memory-read)
        (pin working-memory-write)
        (episodes memory-read)
        (remember memory-write)
        (read-file external-read)
        (search external-read)
        (tavily-search external-read)
        (technical-analysis external-read)
        (define-goal goal-control)
        (goal-verdict goal-control)
        (goal-progress goal-control)
        (write-file requested-effect)
        (append-file requested-effect)
        (shell requested-effect)
        (metta requested-effect)
        ($_ unknown)
    )))

(= (omegaClawCommandCapability $command)
    (case (omegaClawCommandName $command) (
        (read-file
            (case $command (
                ((read-file $path)
                    (if (== (py-call
                                (workspace_policy.safe_workspace_path
                                    $path))
                            true)
                        external-read
                        requested-effect))
                ($_ requested-effect)
            )))
        (shell
            (case $command (
                ((shell $shellText)
                    (if (== (py-call
                                (workspace_policy.safe_workspace_shell
                                    $shellText))
                            true)
                        external-read
                        requested-effect))
                ($_ requested-effect)
            )))
        ($name (omegaClawCommandCapabilityFromName $name))
    )))

(= (omegaClawEnvelopeAllowsCapability $envelope $capability)
    (case $envelope (
        (send-only (== $capability channel-send))
        (memory-read (== $capability memory-read))
        (working-memory-write
            (== $capability working-memory-write))
        (memory-write (== $capability memory-write))
        (memory-update
            (or
                (== $capability memory-read)
                (or
                    (== $capability working-memory-write)
                    (== $capability memory-write))))
        (external-read
            (or
                (== $capability memory-read)
                (== $capability external-read)))
        (goal-definition (== $capability goal-control))
        (goal-assessment (== $capability goal-control))
        (autonomy-work
            (or
                (== $capability memory-read)
                (or
                    (== $capability working-memory-write)
                    (or
                        (== $capability memory-write)
                        (== $capability external-read)))))
        (verification
            (or
                (== $capability goal-control)
                (or
                    (== $capability memory-read)
                    (== $capability external-read))))
        (requested-effect (not (== $capability unknown)))
        (no-effect False)
        ($_ False)
    )))

(= (omegaClawContentBounded $content $maximum)
    (== (py-call
            (workspace_policy.bounded_content $content $maximum))
        true))

(= (omegaClawCommandPayloadBounded $command)
    (case (omegaClawCommandName $command) (
        (query
            (omegaClawContentBounded (index-atom $command 1) 500))
        (remember
            (omegaClawContentBounded (index-atom $command 1) 3000))
        (pin
            (omegaClawContentBounded (index-atom $command 1) 1200))
        (read-file
            (omegaClawContentBounded (index-atom $command 1) 1000))
        (shell
            (omegaClawContentBounded (index-atom $command 1) 1000))
        (define-goal
            (and
                (omegaClawContentBounded
                    (index-atom $command 1) 600)
                (omegaClawContentBounded
                    (index-atom $command 2) 600)))
        ($_ True)
    )))

(= (omegaClawCommandsPayloadsBounded ())
    True)

(= (omegaClawCommandsPayloadsBounded $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
    )
        (and
            (omegaClawCommandPayloadBounded $head)
            (omegaClawCommandsPayloadsBounded $tail))))

(= (omegaClawCommandWorkspacePolicyReason $command $envelope)
    (case (omegaClawCommandName $command) (
        (read-file
            (if (== $envelope requested-effect)
                ok
                (py-call (workspace_policy.workspace_path_reason
                    (index-atom $command 1)))))
        (shell
            (if (== $envelope requested-effect)
                ok
                (py-call (workspace_policy.workspace_shell_reason
                    (index-atom $command 1)))))
        ($_ ok)
    )))

(= (omegaClawValidateContractCommand $contract $command)
    (let* (
        ($name (omegaClawCommandName $command))
        ($allowedNames
            (omegaClawRealizationContractField
                $contract allowed-command-names))
        ($envelope
            (omegaClawRealizationContractField
                $contract capability-envelope))
        ($workspaceReason
            (omegaClawCommandWorkspacePolicyReason
                $command $envelope))
    )
        (if (== $name unknown)
            (validationError unsupported-command $command)
            (if (not (listContains $allowedNames $name))
                (validationError command-not-allowed $name)
                (if (not (== $workspaceReason ok))
                    (validationError $workspaceReason $command)
                    (if (not (omegaClawCommandPayloadBounded $command))
                        (validationError payload-too-large $name)
                        (if (omegaClawEnvelopeAllowsCapability
                                $envelope
                                (omegaClawCommandCapability $command))
                            (validationOk $command)
                            (validationError
                                capability-not-allowed
                                (omegaClawCommandCapability $command)))))))))

(= (omegaClawValidateContractCommands $contract ())
    (validationOk ()))

(= (omegaClawValidateContractCommands $contract $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
        ($headResult
            (omegaClawValidateContractCommand $contract $head))
    )
        (case $headResult (
            ((validationOk $_)
                (omegaClawValidateContractCommands $contract $tail))
            ($_ $headResult)
        ))))

(= (omegaClawValidateCommandsAgainstContract $contract $commands)
    (let* (
        ($count (size-atom (quote $commands)))
        ($maximum
            (omegaClawRealizationContractField $contract maximum-count))
        ($requiresOutput
            (omegaClawRealizationContractField $contract requires-output))
    )
        (if (> $count $maximum)
            (validationError too-many-commands ($count $maximum))
            (if (and $requiresOutput (== $count 0))
                (validationError empty-required-output
                    (omegaClawRealizationContractField
                        $contract realization-id))
                (omegaClawValidateContractCommands
                    $contract $commands)))))

(= (omegaClawDirectiveCommandValidation $directive $commands)
    (omegaClawValidateCommandsAgainstContract
        (omegaClawRealizationContract $directive)
        $commands))

(= (omegaClawDirectiveCommandsHaveValidShape $directive $commands)
    (case (omegaClawDirectiveCommandValidation
                $directive $commands) (
        ((validationOk $_) True)
        ($_ False)
    )))

(= (omegaClawDirectiveAllowsCommand $directive $command)
    (let* (
        ($envelope
            (eval (omegaClawMotivationDirectiveField
                $directive capability-envelope)))
        ($capability
            (omegaClawCommandCapability $command))
    )
        (omegaClawEnvelopeAllowsCapability
            $envelope $capability)))

(= (omegaClawCommandPartition $allowed $blocked)
    (omegaClawCommandPartitionRecord $allowed $blocked))

(= (omegaClawCommandPartitionField $partition $field)
    (let (omegaClawCommandPartitionRecord $allowed $blocked)
        $partition
        (case $field (
            (allowed $allowed)
            (blocked $blocked)
            ($_ (empty))
        ))))

(= (omegaClawPartitionCommands $directive ())
    (omegaClawCommandPartition () ()))

(= (omegaClawPartitionCommands $directive $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
        ($rest (omegaClawPartitionCommands $directive $tail))
        ($allowed
            (omegaClawCommandPartitionField $rest allowed))
        ($blocked
            (omegaClawCommandPartitionField $rest blocked))
    )
        (if (omegaClawDirectiveAllowsCommand
                $directive $head)
            (omegaClawCommandPartition
                (cons-atom $head $allowed)
                $blocked)
            (omegaClawCommandPartition
                $allowed
                (cons-atom $head $blocked)))))

(= (omegaClawCommandsDifference $superset ())
    $superset)

(= (omegaClawCommandsDifference $superset $subset)
    (let* (
        ($head (car-atom (quote $subset)))
        ($tail (cdr-atom (quote $subset)))
    )
        (case (omegaClawRemoveFirst $superset $head) (
            ((validationOk $remaining)
                (omegaClawCommandsDifference $remaining $tail))
            ($_ $superset)
        ))))

(= (omegaClawCommandBoundary
        $turnId $parsedCommands $hostAuthorizedCommands
        $executableCommands $blockedCommands)
    (omegaClawCommandBoundary
        $turnId $parsedCommands $hostAuthorizedCommands
        $executableCommands $blockedCommands
        (validationOk contract-satisfied)
        (omegaClawProposalFingerprint $parsedCommands)
        1
        none))

(= (omegaClawCommandBoundary
        $turnId $parsedCommands $hostAuthorizedCommands
        $executableCommands $blockedCommands
        $proposalValidation $proposalFingerprint $proposalAttempt $contract)
    (omegaClawCommandBoundaryRecord
        $turnId $parsedCommands $hostAuthorizedCommands
        $executableCommands $blockedCommands
        $proposalValidation $proposalFingerprint $proposalAttempt $contract))

(= (omegaClawCommandBoundaryField $boundary $field)
    (let (omegaClawCommandBoundaryRecord
            $turnId $parsedCommands $hostAuthorizedCommands
            $executableCommands $blockedCommands
            $proposalValidation $proposalFingerprint $proposalAttempt $contract)
        $boundary
        (case $field (
            (turn-id $turnId)
            (parsed-commands $parsedCommands)
            (host-authorized-commands $hostAuthorizedCommands)
            (executable-commands $executableCommands)
            (blocked-commands $blockedCommands)
            (proposal-validation $proposalValidation)
            (proposal-fingerprint $proposalFingerprint)
            (proposal-attempt $proposalAttempt)
            (contract $contract)
            ($_ (empty))
        ))))

(= (omegaClawProposalFingerprint $commands)
    (repr (quote $commands)))

(= (omegaClawProposalAttempt $fingerprint $previousOutcome)
    (case $previousOutcome (
        (none 1)
        ($_
            (if (== $fingerprint
                    (omegaClawOutcomeField
                        $previousOutcome proposal-fingerprint))
                (+ 1
                    (omegaClawOutcomeField
                        $previousOutcome proposal-attempt))
                1))
    )))

(= (omegaClawProposalRepeatValidation $fingerprint $attempt)
    (if (> $attempt (omegaClawProposalRetryLimit))
        (validationError repeated-proposal $fingerprint)
        (validationOk within-retry-limit)))

(= (omegaClawFilterAuthorizedByDirective $directive $hostAuthorizedCommands)
    (let* (
        ($partition
            (omegaClawPartitionCommands
                $directive $hostAuthorizedCommands))
    )
        (omegaClawCommandPartitionField $partition allowed)))

(= (omegaClawBuildCommandBoundary
        $turnId $directive $parsedCommands $hostAuthorizedCommands)
    (omegaClawBuildCommandBoundary
        $turnId $directive $parsedCommands $hostAuthorizedCommands none))

(= (omegaClawBuildCommandBoundary
        $turnId $directive $parsedCommands $hostAuthorizedCommands
        $previousOutcome)
    (if (omegaClawCommandMultisetSubset
            $hostAuthorizedCommands $parsedCommands)
        (let* (
            ($contract (omegaClawRealizationContract $directive))
            ($requiresOutput
                (omegaClawRealizationContractField
                    $contract requires-output))
            ($fingerprint (omegaClawProposalFingerprint $parsedCommands))
            ($attempt
                (if $requiresOutput
                    (omegaClawProposalAttempt
                        $fingerprint $previousOutcome)
                    1))
            ($contractValidation
                (omegaClawValidateCommandsAgainstContract
                    $contract $parsedCommands))
            ($repeatValidation
                (if $requiresOutput
                    (omegaClawProposalRepeatValidation
                        $fingerprint $attempt)
                    (validationOk not-applicable)))
            ($proposalValidation
                (case $repeatValidation (
                    ((validationError $_ $_) $repeatValidation)
                    ($_ $contractValidation)
                )))
            ($executable
                (case $proposalValidation (
                    ((validationOk $_)
                        (omegaClawFilterAuthorizedByDirective
                            $directive $hostAuthorizedCommands))
                    ($_ ())
                )))
            ($blocked
                (omegaClawCommandsDifference
                    $parsedCommands $executable))
        )
            (validationOk
                (omegaClawCommandBoundary
                    $turnId
                    $parsedCommands
                    $hostAuthorizedCommands
                    $executable
                    $blocked
                    $proposalValidation
                    $fingerprint
                    $attempt
                    $contract)))
        (validationError
            invalid-host-authorization-expansion
            ($parsedCommands $hostAuthorizedCommands))))
