
;; Mirror public OmegaClaw options needed by the local host bridge.
(= (omegaClawCoreConfig $field)
    (case $field (
        (channel (argk commchannel irc))
        (irc-channel (argk omegaClawIRCChannel ##placeholder_for_actual_channel_name))
        (irc-server (argk omegaClawIRCServer "irc.quakenet.org"))
        (irc-port (argk omegaClawIRCPort 6667))
        (irc-user (argk omegaClawIRCUser omegaclaw))
        (max-new-input-loops (argk maxNewInputLoops 50))
        (max-wake-loops (argk maxWakeLoops 1))
        (spam-shield (argk spamShield True))
        (sleep-interval (argk sleepInterval 1))
        (llm (argk LLM gpt-5.4))
        (provider (argk provider ASICloud))
        (max-output-token (argk maxOutputToken 6000))
        (autonomy-max-output-token (argk autonomyMaxOutputToken 1500))
        (human-provider-timeout
            (argk humanProviderTimeoutSeconds
                (omegaClawHumanProviderTimeoutSeconds)))
        (autonomy-provider-timeout
            (argk autonomyProviderTimeoutSeconds
                (omegaClawAutonomyProviderTimeoutSeconds)))
        (autonomy-main-llm-limit
            (argk autonomyMainLlmCallLimit
                (omegaClawAutonomyMainLlmCallLimit)))
        (autonomy-effect-limit
            (argk autonomyEffectLimit
                (omegaClawAutonomyEffectLimit)))
        (autonomy-failure-limit
            (argk autonomyFailureLimit
                (omegaClawAutonomyFailureLimit)))
        (autonomy-time-budget
            (argk autonomyTimeBudgetSeconds
                (omegaClawAutonomyTimeBudgetSeconds)))
        (autonomy-action-score-threshold
            (argk autonomyActionScoreThreshold
                (omegaClawAutonomyActionScoreThreshold)))
        (autonomy-yield-margin-threshold
            (argk autonomyYieldMarginThreshold
                (omegaClawAutonomyYieldMarginThreshold)))
        (human-response-wait-iterations
            (argk humanResponseWaitIterations
                (omegaClawHumanResponseWaitIterationLimit)))
        (reasoning-mode (argk reasoningMode medium))
        (wakeup-interval (argk wakeupInterval 600))
        (feedback-limit (argk maxFeedback 12000))
        (host-prompt-path
            MetaMo/usecase/omegaclaw_v1/omegaclaw_host_prompt.txt)
        (history-path repos/OmegaClaw-Core/memory/history.metta)
        (history-limit (argk maxHistory 16000))
        ($_ (empty))
    )))


(= (omegaClawCoreInitializeRuntime)
    (progn
        (change-state! &omegaClawCorePreviousMessage "")
        (change-state! &omegaClawCoreLastResults "")
        (change-state! &omegaClawCoreErrors ())
        (change-state! &omegaClawCoreSessionHistory ())
        (change-state! &omegaClawCoreStaticContext
            (omegaClawCoreBuildStaticContext))
        (change-state! &omegaClawCoreWakePending False)
        (change-state! &omegaClawCorePendingHumanMessage none)
        (change-state! &omegaClawCoreHumanWaitIterations 0)
        (change-state! &omegaClawCoreAutonomyBudget
            (omegaClawCoreAutonomyBudget none 0 0 0))
        (change-state! &omegaClawCoreLoops
            (omegaClawCoreConfig max-new-input-loops))
        (change-state! &omegaClawCoreNextWakeAt
            (+ (get_time) (omegaClawCoreConfig wakeup-interval)))
        True))

(= (omegaClawCoreRuntimeState $field)
    (case $field (
        (previous-message
            (get-state &omegaClawCorePreviousMessage))
        (last-results
            (get-state &omegaClawCoreLastResults))
        (errors
            (get-state &omegaClawCoreErrors))
        (session-history
            (get-state &omegaClawCoreSessionHistory))
        (static-context
            (get-state &omegaClawCoreStaticContext))
        (loop-budget
            (get-state &omegaClawCoreLoops))
        (next-wake-at
            (get-state &omegaClawCoreNextWakeAt))
        (wake-pending
            (get-state &omegaClawCoreWakePending))
        (pending-human-message
            (get-state &omegaClawCorePendingHumanMessage))
        (human-wait-iterations
            (get-state &omegaClawCoreHumanWaitIterations))
        (autonomy-budget
            (get-state &omegaClawCoreAutonomyBudget))
        ($_ (empty))
    )))

(= (omegaClawCoreRuntimeUpdate $field $value)
    (case $field (
        (previous-message
            (change-state! &omegaClawCorePreviousMessage $value))
        (last-results
            (change-state! &omegaClawCoreLastResults $value))
        (errors
            (change-state! &omegaClawCoreErrors $value))
        (session-history
            (change-state! &omegaClawCoreSessionHistory $value))
        (loop-budget
            (change-state! &omegaClawCoreLoops $value))
        (next-wake-at
            (change-state! &omegaClawCoreNextWakeAt $value))
        (wake-pending
            (change-state! &omegaClawCoreWakePending $value))
        (pending-human-message
            (change-state! &omegaClawCorePendingHumanMessage $value))
        (human-wait-iterations
            (change-state! &omegaClawCoreHumanWaitIterations $value))
        (autonomy-budget
            (change-state! &omegaClawCoreAutonomyBudget $value))
        ($_ (empty))
    )))


(= (omegaClawCoreAutonomyBudget
        $startedAt $mainLlmCalls $effectCount $failureCount)
    (omegaClawCoreAutonomyBudgetRecord
        $startedAt $mainLlmCalls $effectCount $failureCount))

(= (omegaClawCoreAutonomyBudgetField $budget $field)
    (let (omegaClawCoreAutonomyBudgetRecord
            $startedAt $mainLlmCalls $effectCount $failureCount)
        $budget
        (case $field (
            (started-at $startedAt)
            (main-llm-calls $mainLlmCalls)
            (effect-count $effectCount)
            (failure-count $failureCount)
            ($_ (empty))
        ))))

(= (omegaClawCoreFreshAutonomyBudget)
    (omegaClawCoreAutonomyBudget none 0 0 0))

(= (omegaClawCoreAutonomyBudgetStartedAt $budget $now)
    (case (omegaClawCoreAutonomyBudgetField $budget started-at) (
        (none
            (omegaClawCoreAutonomyBudget
                $now
                (omegaClawCoreAutonomyBudgetField
                    $budget main-llm-calls)
                (omegaClawCoreAutonomyBudgetField
                    $budget effect-count)
                (omegaClawCoreAutonomyBudgetField
                    $budget failure-count)))
        ($_ $budget)
    )))

(= (omegaClawCoreAutonomyBudgetExhaustionReasonAt $budget $now)
    (let* (
        ($startedAt
            (omegaClawCoreAutonomyBudgetField $budget started-at))
        ($timeExhausted
            (case $startedAt (
                (none False)
                ($_ (>= (- $now $startedAt)
                        (omegaClawCoreConfig autonomy-time-budget)))
            )))
    )
        (if $timeExhausted
            time-budget-exhausted
            (if (>= (omegaClawCoreAutonomyBudgetField
                        $budget main-llm-calls)
                    (omegaClawCoreConfig autonomy-main-llm-limit))
                main-llm-budget-exhausted
                (if (>= (omegaClawCoreAutonomyBudgetField
                            $budget effect-count)
                        (omegaClawCoreConfig autonomy-effect-limit))
                    effect-budget-exhausted
                    (if (>= (omegaClawCoreAutonomyBudgetField
                                $budget failure-count)
                            (omegaClawCoreConfig autonomy-failure-limit))
                        failure-budget-exhausted
                        none))))))

(= (omegaClawCoreAutonomyBudgetAvailableAt $budget $now)
    (== (omegaClawCoreAutonomyBudgetExhaustionReasonAt $budget $now)
        none))

(= (omegaClawCoreAutonomyBudgetIncrement
        $budget $field $amount)
    (let* (
        ($startedAt
            (omegaClawCoreAutonomyBudgetField $budget started-at))
        ($mainLlmCalls
            (omegaClawCoreAutonomyBudgetField $budget main-llm-calls))
        ($effectCount
            (omegaClawCoreAutonomyBudgetField $budget effect-count))
        ($failureCount
            (omegaClawCoreAutonomyBudgetField $budget failure-count))
    )
        (case $field (
            (main-llm-calls
                (omegaClawCoreAutonomyBudget
                    $startedAt (+ $mainLlmCalls $amount)
                    $effectCount $failureCount))
            (effect-count
                (omegaClawCoreAutonomyBudget
                    $startedAt $mainLlmCalls
                    (+ $effectCount $amount) $failureCount))
            (failure-count
                (omegaClawCoreAutonomyBudget
                    $startedAt $mainLlmCalls
                    $effectCount (+ $failureCount $amount)))
            ($_ $budget)
        ))))

(= (omegaClawCoreResetAutonomyBudget)
    (omegaClawCoreRuntimeUpdate
        autonomy-budget
        (omegaClawCoreFreshAutonomyBudget)))

(= (omegaClawCoreStartAutonomyBudgetAt $now)
    (omegaClawCoreRuntimeUpdate
        autonomy-budget
        (omegaClawCoreAutonomyBudgetStartedAt
            (omegaClawCoreRuntimeState autonomy-budget) $now)))

(= (omegaClawCoreAutonomyBudgetAvailable)
    (omegaClawCoreAutonomyBudgetAvailableAt
        (omegaClawCoreRuntimeState autonomy-budget)
        (get_time)))

(= (omegaClawCoreAutonomyBudgetExhaustionReason)
    (omegaClawCoreAutonomyBudgetExhaustionReasonAt
        (omegaClawCoreRuntimeState autonomy-budget)
        (get_time)))

(= (omegaClawCoreRecordAutonomyBudget $field $amount)
    (omegaClawCoreRuntimeUpdate
        autonomy-budget
        (omegaClawCoreAutonomyBudgetIncrement
            (omegaClawCoreRuntimeState autonomy-budget)
            $field $amount)))

(= (omegaClawCoreEndAutonomyBurst)
    (omegaClawCoreRuntimeUpdate loop-budget 0))

(= (omegaClawCoreResetHumanWaitIterations)
    (omegaClawCoreRuntimeUpdate human-wait-iterations 0))

(= (omegaClawCoreIncrementHumanWaitIterations)
    (let $next
        (+ (omegaClawCoreRuntimeState human-wait-iterations) 1)
        (prog1
            $next
            (omegaClawCoreRuntimeUpdate human-wait-iterations $next))))


(= (omegaClawHostTurn
        $turnId $wakeReason $timestamp $newMessage
        $messageId $messageText $channel
        $previousResults $previousErrors $loopBudget)
    (omegaClawHostTurnRecord
        $turnId $wakeReason $timestamp $newMessage
        $messageId $messageText $channel
        $previousResults $previousErrors $loopBudget))

(= (omegaClawHostTurnField $turn $field)
    (let (omegaClawHostTurnRecord
            $turnId $wakeReason $timestamp $newMessage
            $messageId $messageText $channel
            $previousResults $previousErrors $loopBudget)
        $turn
        (case $field (
            (turn-id $turnId)
            (wake-reason $wakeReason)
            (timestamp $timestamp)
            (new-message $newMessage)
            (message-id $messageId)
            (message-text $messageText)
            (channel $channel)
            (previous-results $previousResults)
            (previous-errors $previousErrors)
            (loop-budget $loopBudget)
            ($_ (empty))
        ))))

(= (omegaClawCoreDispatchBatch $displayResults $commandResults)
    (omegaClawCoreDispatchBatchRecord $displayResults $commandResults))

(= (omegaClawCoreDispatchBatchField $batch $field)
    (let (omegaClawCoreDispatchBatchRecord $displayResults $commandResults)
        $batch
        (case $field (
            (display-results $displayResults)
            (command-results $commandResults)
            ($_ (empty))
        ))))

(= (omegaClawCoreProposal $response $parsedCommands $authorizedCommands)
    (omegaClawCoreProposal
        $response $parsedCommands $authorizedCommands none))

(= (omegaClawCoreProposal
        $response $parsedCommands $authorizedCommands $providerFailure)
    (omegaClawCoreProposalRecord
        $response $parsedCommands $authorizedCommands $providerFailure))

(= (omegaClawCoreProposalField $proposal $field)
    (let (omegaClawCoreProposalRecord
            $response $parsedCommands $authorizedCommands $providerFailure)
        $proposal
        (case $field (
            (response $response)
            (parsed-commands $parsedCommands)
            (authorized-commands $authorizedCommands)
            (provider-failure $providerFailure)
            ($_ (empty))
        ))))


(= (omegaClawCoreHandleError $message $command $result)
    (case $result (
        ((Error $errorType $details)
            (let $errors
                (append
                    (omegaClawCoreRuntimeState errors)
                    (($message $command)))
                (prog1
                    $result
                    (omegaClawCoreRuntimeUpdate errors $errors))))
        ($_ $result)
    )))

(= (omegaClawCorePersistentHistory)
    (read_file_tail
        (omegaClawCoreConfig history-path)
        (omegaClawCoreConfig history-limit)))

(= (omegaClawCorePersistHistory $entry)
    (append-file
        (omegaClawCoreConfig history-path)
        (swrite $entry)))

(= (omegaClawCoreHistoryBase
        $timestamp $message $response $newMessage $workingOn)
    (case $newMessage (
        (True
            ($timestamp
             (newline)
             "HUMAN_MESSAGE: " $message
             (newline)
             $response
             (newline)))
        ($_
            (case $workingOn (
                (none
                    ($timestamp
                     (newline)
                     $response
                     (newline)))
                ($_
                    ($timestamp
                     (newline)
                     "WORKING_ON: " $workingOn
                     (newline)
                     $response
                     (newline)))
            )))
    )))

(= (omegaClawCoreHistoryAddition
        $timestamp $message $response $errors $newMessage $workingOn)
    (omegaClawCoreHistoryBase
        $timestamp $message $response $newMessage $workingOn))

(= (omegaClawCoreShouldRecordTurn $newMessage $commands $errors)
    (or
        $newMessage
        (not (== $commands ()))))

(= (omegaClawCoreAddToHistory
        $message $response $commands $displayResults $newMessage)
    (omegaClawCoreAddToHistory
        $message $response $commands $displayResults $newMessage none))

(= (omegaClawCoreAddToHistory
        $message $response $commands $displayResults
        $newMessage $workingOn)
    (let $entry
        (omegaClawCoreHistoryAddition
            (get_time_as_string)
            $message
            $response
            (omegaClawCoreRuntimeState errors)
            $newMessage
            $workingOn)
        (progn
            (omegaClawCoreRuntimeUpdate
                session-history
                (append
                    (omegaClawCoreRuntimeState session-history)
                    ($entry)))
            (omegaClawCorePersistHistory $entry))))


(= (omegaClawCoreInitializeChannels)
    (case (omegaClawCoreConfig channel) (
        (irc
            (progn
                (println! "Initializing channels")
                (configure commchannel irc)
                (configure IRC_channel
                    (omegaClawCoreConfig irc-channel))
                (configure IRC_server
                    (omegaClawCoreConfig irc-server))
                (configure IRC_port
                    (omegaClawCoreConfig irc-port))
                (configure IRC_user
                    (omegaClawCoreConfig irc-user))
                (py-call (irc.start_irc
                    (IRC_channel) (IRC_server)
                    (IRC_port) (IRC_user)))))
        ($_ (initChannels))
    )))

(= (omegaClawCoreInitialize)
    (progn
        (initMemory)
        (omegaClawCoreInitializeChannels)
        (omegaClawCoreInitializeRuntime)))

(= (omegaClawCoreSkillIndex)
    (eval (getSkills)))

(= (omegaClawCoreBuildStaticContext)
    (let* (
        ($skillIndex (omegaClawCoreSkillIndex))
        ($capabilityView
            (omegaClawSkillCapabilityView $skillIndex))
    )
        (eval (string-safe
        (eval (py-str (
            "HOST_POLICY: "
                (read-file (omegaClawCoreConfig host-prompt-path))
            " SKILLS: " $skillIndex
            " SKILL_CAPABILITY_VIEW: " $capabilityView
            " AVAILABLE_WORKSPACE_COMMANDS: "
                (py-call (workspace_policy.available_workspace_commands))
            " OUTPUT_FORMAT: Output a single valid MeTTa s-expression list of commands."
            " Example - one command: ((send \"message\"))"
            " Example - multiple commands: ((query \"topic\") (send \"message\"))"
            " Do not output conversational text outside the expression.")))))))

(= (omegaClawCoreBaseContext)
    (eval (string-safe
        (eval (py-str (
            (omegaClawCoreRuntimeState static-context)
            " LAST_SKILL_USE_RESULTS: "
                (eval (last_chars
                    (omegaClawCoreRuntimeState last-results)
                    (omegaClawCoreConfig feedback-limit)))
            " HISTORY: " (omegaClawCorePersistentHistory)
            " TIME: " (eval (get_time_as_string)))))))
        )

(= (omegaClawCoreWakeReason $newMessage $wakePending $loopBudget)
    (if $newMessage
        user-input
        (if $wakePending
            scheduled-wake
            (if (> $loopBudget 0)
                continuation
                idle))))

(= (omegaClawCoreMessagePresent $received)
    (== (py-call
            (stimulus_adapter.message_present $received))
        true))

(= (omegaClawCoreMessageNew $received)
    (and
        (omegaClawCoreMessagePresent $received)
        (!= $received
            (omegaClawCoreRuntimeState previous-message))))

;; Buffer human input detected during pre-dispatch polling.
(= (omegaClawCoreTakePendingOrReceive)
    (case (omegaClawCoreRuntimeState pending-human-message) (
        (none (string-safe (repr (receive))))
        ($pending
            (prog1
                $pending
                (omegaClawCoreRuntimeUpdate
                    pending-human-message none)))
    )))

(= (omegaClawCoreHumanInputPending)
    (not (==
        (omegaClawCoreRuntimeState pending-human-message)
        none)))

(= (omegaClawCorePollHumanInput)
    (if (omegaClawCoreHumanInputPending)
        True
        (let $received (string-safe (repr (receive)))
            (if (omegaClawCoreMessageNew $received)
                (progn
                    (omegaClawCoreRuntimeUpdate
                        pending-human-message $received)
                    (omegaClawCoreRuntimeUpdate
                        loop-budget
                        (omegaClawCoreConfig max-new-input-loops))
                    True)
                False))))

(= (omegaClawCoreReceiveTurn $turnId)
    (omegaClawCoreReceiveTurn $turnId $turnId))

;; Receive a durable turn while applying session-local loop semantics.
(= (omegaClawCoreReceiveTurn $turnId $iteration)
    (let* (
        ($received (omegaClawCoreTakePendingOrReceive))
        ($hasMessage (omegaClawCoreMessagePresent $received))
        ($newMessage
            (prog1
                (and
                    $hasMessage
                    (!= $received
                        (omegaClawCoreRuntimeState previous-message)))
                (if $hasMessage
                    (omegaClawCoreRuntimeUpdate
                        previous-message $received)
                    _)))
        ($_ (if (and (> $iteration 1) $newMessage)
            (progn
                (omegaClawCoreRuntimeUpdate
                    loop-budget
                    (omegaClawCoreConfig max-new-input-loops))
                (omegaClawCoreResetAutonomyBudget)
                (omegaClawCoreResetHumanWaitIterations))
            _))
        ($wakePending
            (omegaClawCoreRuntimeState wake-pending))
        ($wakeReason
            (omegaClawCoreWakeReason
                $newMessage
                $wakePending
                (omegaClawCoreRuntimeState loop-budget)))
        ($_ (if $wakePending
            (progn
                (omegaClawCoreRuntimeUpdate wake-pending False)
                (omegaClawCoreResetAutonomyBudget))
            _))
    )
        (omegaClawHostTurn
            $turnId
            $wakeReason
            (get_time)
            $newMessage
            runtime-message
            (omegaClawCoreRuntimeState previous-message)
            (omegaClawCoreConfig channel)
            (omegaClawCoreRuntimeState last-results)
            (omegaClawCoreRuntimeState errors)
            (omegaClawCoreRuntimeState loop-budget))))

(= (omegaClawCoreLastMessage $turn)
    (if (omegaClawHostTurnField $turn new-message)
        (HUMAN-MSG: (omegaClawHostTurnField $turn message-text))
        (if (omegaClawCoreConfig spam-shield)
            " DO NOT RE-SEND OR SPAM!"
            "")))

(= (omegaClawCoreProviderResponse $prompt $lastMessage)
    (omegaClawCoreProviderResponse
        $prompt $lastMessage
        (omegaClawCoreConfig max-output-token)
        (omegaClawCoreConfig human-provider-timeout)
        human-realization))

(= (omegaClawCoreProviderResponse $prompt $lastMessage $maxOutputToken)
    (omegaClawCoreProviderResponse
        $prompt $lastMessage $maxOutputToken
        (omegaClawCoreConfig human-provider-timeout)
        human-realization))

(= (omegaClawCoreProviderResponse
        $prompt $lastMessage $maxOutputToken $timeoutSeconds $operation)
    (let $request (py-str ($prompt :-:-:-: $lastMessage))
        (py-call (provider_transport.call_provider_text
                (omegaClawCoreConfig provider)
                $request
                $maxOutputToken
                (omegaClawCoreConfig reasoning-mode)
                $timeoutSeconds
                $operation))))

(= (omegaClawCoreNormalizedResponse $rawResponse)
    (if (== (py-call
                (stimulus_adapter.command_response_empty $rawResponse))
            true)
        (repr ())
        (let $normalized
            (py-call
                (stimulus_adapter.normalize_command_response
                    $rawResponse))
            (if (== "(" (first_char $normalized))
                $normalized
                (progn
                    (println! $normalized)
                    (repr (REMEMBER:OUTPUT_NOTHING_ELSE_THAN:
                        ((skill arg) ...))))))))

(= (omegaClawCoreParsedCommands $parsed)
    (case $parsed (
        ((Error $errorType $details) ())
        ($_ $parsed)
    )))

(= (omegaClawCoreAuthorizeCommands ())
    ())

(= (omegaClawCoreAuthorizeCommands $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
        ($remaining (omegaClawCoreAuthorizeCommands $tail))
    )
        (if (== (omegaClawCommandCapability (quote $head)) unknown)
            $remaining
            (cons-atom $head $remaining))))

(= (omegaClawCoreRequestCommands $prompt $turn)
    (omegaClawCoreRequestCommands
        $prompt $turn
        (omegaClawCoreConfig max-output-token)
        (omegaClawCoreConfig human-provider-timeout)
        human-realization))

(= (omegaClawCoreRequestCommands $prompt $turn $maxOutputToken)
    (omegaClawCoreRequestCommands
        $prompt $turn $maxOutputToken
        (omegaClawCoreConfig human-provider-timeout)
        human-realization))

(= (omegaClawCoreRequestCommands
        $prompt $turn $maxOutputToken $timeoutSeconds $operation)
    (let* (
        ($lastMessage (omegaClawCoreLastMessage $turn))
        ($_ (omegaClawCoreRuntimeUpdate
            next-wake-at
            (+ (get_time) (omegaClawCoreConfig wakeup-interval))))
        ($_ (println! $lastMessage))
        ($providerStartedAt
            (py-call (workspace_policy.monotonic_seconds)))
        ($rawResponse
            (omegaClawCoreProviderResponse
                $prompt $lastMessage $maxOutputToken
                $timeoutSeconds $operation))
        ($providerFailure
            (py-call
                (provider_transport.provider_failure_reason
                    $rawResponse)))
        ($providerText
            (py-call
                (provider_transport.provider_response_text
                    $rawResponse)))
        ($providerFinishedAt
            (py-call (workspace_policy.monotonic_seconds)))
        ($providerElapsed
            (eval (- $providerFinishedAt $providerStartedAt)))
        ($_ (println!
            (METAMO-TIMING: provider $providerElapsed)))
        ($response (omegaClawCoreNormalizedResponse $providerText))
        ($parsed (catch (sread $response)))
        ($_ (omegaClawCoreRuntimeUpdate errors ()))
        ($_ (omegaClawCoreHandleError
            MULTI_COMMAND_FAILURE_NOTHING_WAS_DONE_PLEASE_CORRECT_PARENTHESES_AND_USE_QUOTES_AND_RETRY
            $response
            $parsed))
        ($parsedCommands (omegaClawCoreParsedCommands $parsed))
        ($authorizedCommands
            (omegaClawCoreAuthorizeCommands $parsedCommands))
    )
        (omegaClawCoreProposal
            $response $parsedCommands $authorizedCommands
            $providerFailure)))


(= (omegaClawCoreDispatchCommands ())
    (omegaClawCoreDispatchBatch () ()))

(= (omegaClawCoreEvaluateHostCommand $command)
    (let* (
        ($results
            (collapse
                (catch
                    (let $result (eval $command)
                        (py-call
                            (helper.normalize_string $result))))))
        ($resultCount (length $results))
        ($commandData (quote $command))
    )
        (case $resultCount (
            (0 (Error command-produced-no-result $commandData))
            (1 (car-atom $results))
            ($_ (Error command-produced-multiple-results
                    ($commandData $resultCount)))
        ))))

(= (omegaClawCoreShellExecutionResult
        $command $status $exitCode $output)
    (case $status (
        (success $output)
        (empty ())
        (timeout
            (Error shell-command-timeout $command))
        (unavailable
            (Error shell-executor-unavailable $output))
        (failure
            (Error shell-command-failed ($exitCode $output)))
        ($_
            (Error invalid-shell-execution-result ($status $output)))
    )))

(= (omegaClawCoreEvaluateShellSnapshot $snapshot)
    (let* (
        ($shellText
            (omegaClawCommandSnapshotField $snapshot first))
        ($representation
            (omegaClawCommandSnapshotField $snapshot representation))
        ($execution
            (py-call (workspace_policy.execute_shell_command
                $shellText 5.0)))
        ($status
            (py-call (workspace_policy.shell_result_field
                $execution status)))
        ($exitCode
            (py-call (workspace_policy.shell_result_field
                $execution exit-code)))
        ($output
            (py-call (workspace_policy.shell_result_field
                $execution output)))
    )
        (omegaClawCoreShellExecutionResult
            $representation $status $exitCode $output)))

;; Dispatch only implemented commands from inert metadata.
(= (omegaClawCoreEvaluateSnapshotCommand $snapshot)
    (case (omegaClawCommandSnapshotField $snapshot name) (
        (define-goal GOAL-DEFINED)
        (goal-verdict GOAL-VERDICT-RECORDED)
        (goal-progress GOAL-PROGRESS-RECORDED)
        (shell (omegaClawCoreEvaluateShellSnapshot $snapshot))
        ($_ (Error command-requires-host-evaluation
                (omegaClawCommandSnapshotField
                    $snapshot representation)))
    )))

(= (omegaClawCoreDispatchCommands $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
        ($snapshot
            (omegaClawCommandSnapshotFromCommand (quote $head)))
        ($name (omegaClawCommandSnapshotField $snapshot name))
        ($representation
            (omegaClawCommandSnapshotField $snapshot representation))
;; Dispatch shell effects from inert command fields.
        ($rawResult
            (case $name (
                (define-goal
                    (omegaClawCoreEvaluateSnapshotCommand $snapshot))
                (goal-verdict
                    (omegaClawCoreEvaluateSnapshotCommand $snapshot))
                (goal-progress
                    (omegaClawCoreEvaluateSnapshotCommand $snapshot))
                (shell
                    (catch
                        (omegaClawCoreEvaluateSnapshotCommand $snapshot)))
                ($_
                    (catch
                        (omegaClawCoreEvaluateHostCommand
                            (quote $head))))
            )))
        ($handledResult
            (omegaClawCoreHandleError
                SINGLE_COMMAND_FORMAT_ERROR_NOTHING_WAS_DONE_PLEASE_FIX_AND_RETRY
                $representation
                $rawResult))
        ($status
            (case $handledResult (
                ((Error $errorType $details) failure)
                ($_ success)
            )))
        ($remaining (omegaClawCoreDispatchCommands $tail))
        ($displayResults
            (cons-atom
                (COMMAND_RETURN: ($representation $handledResult))
                (omegaClawCoreDispatchBatchField
                    $remaining display-results)))
        ($commandResults
            (cons-atom
                (omegaClawCommandResultFromSnapshot
                    $snapshot $status $handledResult)
                (omegaClawCoreDispatchBatchField
                    $remaining command-results)))
    )
        (omegaClawCoreDispatchBatch $displayResults $commandResults)))


(= (omegaClawCoreRecordTurn
        $turn $response $commands $displayResults)
    (omegaClawCoreRecordTurn
        $turn $response $commands $displayResults none))

(= (omegaClawCoreRecordTurn
        $turn $response $commands $displayResults $workingOn)
    (let* (
        ($message (omegaClawHostTurnField $turn message-text))
        ($newMessage (omegaClawHostTurnField $turn new-message))
        ($errors (omegaClawCoreRuntimeState errors))
        ($_ (if (omegaClawCoreShouldRecordTurn
                    $newMessage $commands $errors)
            (omegaClawCoreAddToHistory
                $message $response $commands $displayResults
                $newMessage $workingOn)
            (println!
                (METAMO-HISTORY-SKIPPED:
                    no-human-or-executed-command))))
    )
        (omegaClawCoreRuntimeUpdate
            last-results
            (string-safe (repr $displayResults)))))

(= (omegaClawCoreBeginIteration $iteration)
    (if (and
            (> $iteration 1)
            (> (omegaClawCoreRuntimeState loop-budget) 0))
        (omegaClawCoreRuntimeUpdate
            loop-budget
            (- (omegaClawCoreRuntimeState loop-budget) 1))
        True))

(= (omegaClawCoreCanRun)
    (> (omegaClawCoreRuntimeState loop-budget) 0))

(= (omegaClawCoreEnsureLoopBudget $minimum)
    (if (< (omegaClawCoreRuntimeState loop-budget) $minimum)
        (omegaClawCoreRuntimeUpdate loop-budget $minimum)
        True))

(= (omegaClawCoreIdleAt $now)
    (if (> $now (omegaClawCoreRuntimeState next-wake-at))
        (progn
            (omegaClawCoreRuntimeUpdate
                loop-budget
                (+ 1 (omegaClawCoreConfig max-wake-loops)))
            (omegaClawCoreRuntimeUpdate wake-pending True)
            (omegaClawCoreResetAutonomyBudget)
            (omegaClawCoreRuntimeUpdate
                next-wake-at
                (+ $now (omegaClawCoreConfig wakeup-interval))))
        (omegaClawCoreRuntimeUpdate errors ())))

(= (omegaClawCoreIdle)
    (omegaClawCoreIdleAt (get_time)))

(= (omegaClawCoreFinishIteration)
    (let $interval (omegaClawCoreConfig sleep-interval)
        (progn
            (println!
                (METAMO-TIMING: configured-sleep $interval))
            (sleep $interval)
            True)))
