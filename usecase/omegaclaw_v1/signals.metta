;; Signal extraction and signal-to-appraisal conversion.

!(bind! &signal-space    (new-space))
!(bind! &appraisal-space (new-space))
!(bind! &failure-streak  (new-state 0))

!(bind! &new-msg-flag (new-state False))
!(bind! &last-results-seen (new-state ""))


(= (hasTextContent $value)
   (> (eval (string_length (eval (string-safe $value)))) 2))

(= (clearSignals)
   (clearSpace &signal-space))

(= (addSignal $kind $strength)
   (let* (
      ($_ (collapse (let $old (match &signal-space (signal $kind $_) (signal $kind $_)) (remove-atom &signal-space $old))))
   )
   (add-atom &signal-space (signal $kind $strength))))

(= (getSignals)
   (collapse (match &signal-space (signal $kind $strength) (signal $kind $strength))))

(= (hasSignal $kind)
   (let $res (collapse (match &signal-space (signal $kind $_) True))
      (if (== $res ()) False True)))

(= (hasErrors)
   (or (hasSignal failure) (hasSignal repeated-failure)))

(= (hasResults)
   (or (hasSignal progress-made) (hasSignal verified-success)))


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
      ($taskOpen   (get-state &task-open))
      ($results    (get-state &lastresults))
      ($error      (get-state &error))
      ($isNewMsg   (get-state &new-msg-flag))
      ($hasMsg     (hasTextContent $msg))
      ($hasResults (hasTextContent $results))
      ($freshResults (and $hasResults (!= $results (get-state &last-results-seen))))
      ($hasError   (> (eval (string_length (eval (string-safe (repr $error))))) 4))
      ($resultsLen (eval (string_length (eval (string-safe $results)))))
      ($prov       (provider))
      ($confirmScore (if $isNewMsg
                         (py-call (lib_llm_ext.executionConfirmationScore $prov $msg $activeTask))
                         0.0))
      ($executionFollowup (and $isNewMsg (> $confirmScore 0.75)))

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
      ($_ (if (and $isNewMsg (and $taskOpen (and (hasTextContent $activeTask) (!= $msg $activeTask))))
              (addSignal task-drift (signalStrength task-drift 0.45))
              _))

      ;; 4. Ambiguity — new message with no results and no error
      ($_ (if (and $isNewMsg (and (not $freshResults) (not $hasError)))
              (addSignal ambiguity (signalStrength ambiguity 0.60))
              _))

      ;; 5. Progress made — skills executed and returned results without error.
      ($_ (if (and $freshResults (not $hasError))
              (addSignal progress-made (signalStrength progress-made 0.40))
              _))

      ;; 6. Stalled progress — new message, no results, no error
      ($_ (if (and $isNewMsg (and (not $freshResults) (not $hasError)))
              (addSignal stalled-progress (signalStrength stalled-progress 0.35))
              _))

      ;; 7. User waiting — fires when a new message has arrived and awaits reply.
      ($_ (if (and $hasMsg $isNewMsg)
              (addSignal user-waiting (signalStrength user-waiting 0.30))
              _))

      ;; 8. Semantic extraction — only on new messages (skip LLM call on idle)
      ($_ (if $isNewMsg
              (collapse (let* (($semStr (py-call (lib_llm_ext.extractSemantics $prov $msg)))
                               ($semList (catch (sread $semStr))))
                          (if (and (!= $semList ()) (!= $semList (Error)))
                              (let $s (superpose $semList)
                                   (add-atom &signal-space $s))
                              (empty))))
              _))

      ;; Confirmation replies inherit semantic execution intent from the open
      ;; task instead of becoming generic chat.
      ($_ (if $executionFollowup
              (addSignal execution-request $confirmScore)
              _))

      ;; Track the active task (update only when a new message arrived)
      ($_ (if (and $isNewMsg
                   (and (not $executionFollowup)
                        (or (not $hasError) (not (hasTextContent $activeTask)))))
              (change-state! &active-task $msg)
              _))
      ($_ (if $isNewMsg
              (change-state! &task-open True)
              _))
      ($_ (if $hasResults
              (change-state! &last-results-seen $results)
              _))
   )
   (getSignals)))


;; Convert the current signals into the six appraisal dimensions.
(= (signalDimContrib $kind $strength $dim)
   (let $weights (collapse (match &self (SignalAppraisal $kind $dim $w) $w))
      (if (== $weights ()) 0.0 (* $strength (car-atom $weights)))))

(= (sumDimFromSignals $dim () $acc) $acc)
(= (sumDimFromSignals $dim $signals $acc)
   (let* (
      (($head $tail) (decons-atom $signals))
      ((signal $kind $strength) $head)
      ($contrib (signalDimContrib $kind $strength $dim))
   )
      (sumDimFromSignals $dim $tail (+ $acc $contrib))))

(= (computeDimension $dim)
   (let $signals
         (collapse (match &signal-space (signal $kind $strength)
                                        (signal $kind $strength)))
      (clamp01 (sumDimFromSignals $dim $signals 0.0))))

(= (computeAllDimensions)
   (let* (
      ($novelty (computeDimension novelty))
      ($risk (computeDimension risk))
      ($importance (computeDimension importance))
      ($uncertainty (computeDimension uncertainty))
      ($opportunity (computeDimension opportunity))
      ($progress (computeDimension progress))
      ($_ (add-atom &appraisal-space (appraisal novelty $novelty)))
      ($_ (add-atom &appraisal-space (appraisal risk $risk)))
      ($_ (add-atom &appraisal-space (appraisal importance $importance)))
      ($_ (add-atom &appraisal-space (appraisal uncertainty $uncertainty)))
      ($_ (add-atom &appraisal-space (appraisal opportunity $opportunity)))
      ($_ (add-atom &appraisal-space (appraisal progress $progress)))
   ) True))
