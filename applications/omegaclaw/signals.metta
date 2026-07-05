;; Signal extraction from OmegaClaw loop state.


!(bind! &new-msg-flag (new-state False))


(= (hasContent $value)
   (> (eval (string_length (eval (string-safe $value)))) 2))

(= (clearSignals)
   (clearSpace &signal-space))

(= (addSignal $kind $strength)
   (add-atom &signal-space (signal $kind $strength)))

(= (getSignals)
   (collapse (match &signal-space (signal $kind $strength) (signal $kind $strength))))


;; Returns the registered strength for a signal kind (fallback to default).
(= (signalStrength $kind $default)
   (let $v (collapse (match &self (SignalStrength $kind $s) $s))
      (if (== $v ()) $default (car-atom $v))))

;; Returns the registered threshold for a named check (fallback to default).
(= (signalThreshold $key $default)
   (let $v (collapse (match &self (SignalThreshold $key $t) $t))
      (if (== $v ()) $default (car-atom $v))))


;; refreshSignals
;; Extract signals from current OmegaClaw state.
(= (refreshSignals)
   (let* (
      ($_ (collapse (clearSignals)))
      ;; Read OmegaClaw state (interface contract)
      ($msg        (get-state &prevmsg))
      ($activeTask (get-state &active-task))
      ($results    (get-state &lastresults))
      ($error      (get-state &error))
      ($isNewMsg   (get-state &new-msg-flag))
      ($hasMsg     (hasContent $msg))
      ($hasResults (hasContent $results))
      ($hasError   (> (eval (string_length (eval (string-safe (repr $error))))) 4))
      ($resultsLen (eval (string_length (eval (string-safe $results)))))

      ;; Failure streak: updated based on error presence.
      ($_ (if $hasError
              (change-state! &failure-streak (+ (get-state &failure-streak) 1))
              (change-state! &failure-streak 0)))
      ($failureStreak (get-state &failure-streak))
      ($repeatThresh  (signalThreshold failure-streak-repeat 1))

      ;; 1. Repeated failure: multiple consecutive errors
      ($_ (if (and (> $failureStreak $repeatThresh) $hasError)
              (addSignal repeated-failure (signalStrength repeated-failure 0.85))
              _))

      ;; 2. Single failure (first error)
      ($_ (if (and $hasError (<= $failureStreak $repeatThresh))
              (addSignal failure (signalStrength failure 0.80))
              _))

      ;; 3. Task drift — only on a new message when topic changed
      ($_ (if (and $isNewMsg (and (hasContent $activeTask) (!= $msg $activeTask)))
              (addSignal task-drift (signalStrength task-drift 0.45))
              _))

      ;; 4. Ambiguity — new message with no results and no error
      ($_ (if (and $isNewMsg (and (not $hasResults) (not $hasError)))
              (addSignal ambiguity (signalStrength ambiguity 0.60))
              _))

      ;; 5. Progress made — skills executed and returned results without error.
      ($_ (if (and $hasResults (not $hasError))
              (addSignal progress-made (signalStrength progress-made 0.40))
              _))

      ;; 6. Stalled progress — new message, no results, no error
      ($_ (if (and $isNewMsg (and (not $hasResults) (not $hasError)))
              (addSignal stalled-progress (signalStrength stalled-progress 0.35))
              _))

      ;; 7. User waiting — fires when a new message has arrived and awaits reply.
      ($_ (if (and $hasMsg $isNewMsg)
              (addSignal user-waiting (signalStrength user-waiting 0.30))
              _))

      ;; 8. Semantic extraction — only on new messages (skip LLM call on idle)
      ($_ (if $isNewMsg
              (collapse (let* (($prov (provider))
                               ($semStr (py-call (lib_llm_ext.extractSemantics $prov $msg)))
                               ($semList (catch (sread $semStr))))
                          (if (and (!= $semList ()) (!= $semList (Error)))
                              (let $s (superpose $semList)
                                   (add-atom &signal-space $s))
                              (empty))))
              _))

      ;; Track the active task (update only when a new message arrived)
      ($_ (if $isNewMsg
              (change-state! &active-task $msg)
              _))
   )
   (getSignals)))
