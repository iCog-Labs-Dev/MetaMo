;; Motivational State Persistence
;; Stores X=(G,M,S) in long-term ChromaDB memory so that the motivational state survives session boundaries.

;; Restoration:
;;   On startup, query ChromaDB for the most recent MOTIVOS_STATE_V1 entry.
!(bind! &motivation-restored       (new-state False))
!(bind! &motivation-save-countdown (new-state 10))

(= (persistenceKey) "MOTIVOS_STATE_V1")

(= (persistenceInterval)
   (let $v (collapse (match &self (DynamicsConfig persistence_interval $x) $x))
      (if (== $v ()) 10 (car-atom $v))))


;; saveMotivationalState
(= (saveMotivationalState)
   (let* (
      ($timestamp (get_time_as_string))
      ($goals     (eval (string-safe (repr (getGoals)))))
      ($antiGoals (eval (string-safe (repr (getAntiGoals)))))
      ($mods      (eval (string-safe (repr (getModulators)))))
      ($self      (eval (string-safe (repr (getSelfModel)))))
      ($payload   (eval (py-str (
                     (persistenceKey) " time:" $timestamp
                     " G:" $goals " AG:" $antiGoals
                     " M:" $mods
                     " S:" $self))))
      ($_ (remember $payload))
      ($_ (println! ("Motivational state saved to long-term memory.")))
   ) saved))


;; Example: malformed self-metric arity cannot disappear during S extraction.
(= (motivationalRestoreEntryValid $entry)
   (case $entry (
      ((self-metric $_ $_) (selfModelMetricValid $entry))
      ((goal $name $value) (and (== (get-metatype $name) Symbol) (fsNumberIn $value 0 1)))
      ((anti-goal $name $value) (and (== (get-metatype $name) Symbol) (fsNumberIn $value 0 1)))
      ((modulator $name $value) (and (== (get-metatype $name) Symbol) (fsNumberIn $value 0 1)))
      ($_ False))))

;; Example: parsed snapshots are ground lists with valid entries and unique S names.
(= (motivationalRestoreValid $parsed)
   (if (or (not (is-ground $parsed)) (!= (get-metatype $parsed) Expression)) False
       (if (!= (filter-atom $parsed $entry (not (motivationalRestoreEntryValid $entry))) ()) False
           (selfModelMetricsValid (filter-atom $parsed $entry
               (case $entry (((self-metric $_ $_) True) ($_ False))))))))

;; Example: a legacy memory_confidence field rejects the entire parsed snapshot.
;; Validate S before any G/AG/M/S write; rejected restores preserve current state.
;; Old snapshots with forbidden fields require explicit migration, never projection.
(= (restoreParsedMotivationalState $parsed)
      (if (not (motivationalRestoreValid $parsed))
          (SelfModelRejected InvalidSnapshot)
          (let* (
             ($_ (collapse
                    (let $entry (superpose $parsed)
                       (case $entry (
                          ((goal $name $val) (replaceGoal $name $val))
                          ((anti-goal $name $val) (replaceAntiGoal $name $val))
                          ((modulator $name $val) (replaceModulator $name $val))
                          ((self-metric $name $val) (replaceSelfMetric $name $val))
                          ($_ (empty)))))))
          ) MotivationalStateRestored)))

;; Example: restore valid S through the application schema after Core text parsing.
(= (restoreMotivationalState)
   (let* (
      ($_ (println! ("Querying long-term memory for prior motivational state...")))
      ($results (eval (query (persistenceKey))))
      ($parsed (sread (py-call (lib_llm_ext.parseMotivosState $results))))
   )
      (if (and (!= $parsed ()) (!= $parsed (Error)))
          (let $result (restoreParsedMotivationalState $parsed)
             (progn (println! $result) $result))
          (println! ("No prior motivational state found. Using registry defaults.")))))


;; tryRestoreOrInit - Called once during startup after default initialisation.
(= (tryRestoreOrInit)
   (let* (
      ($_ (println! ("Checking long-term memory for persisted motivational state...")))
      ($_ (restoreMotivationalState))
      ($_ (println! ("Startup restoration complete (defaults remain active as fallback).")))
   ) ()))

(= (ensureMotivationRestored)
   (if (get-state &motivation-restored)
       True
       (let* (
          ($_ (tryRestoreOrInit))
          ($_ (change-state! &motivation-restored True))
          ($_ (change-state! &motivation-save-countdown
                  (persistenceInterval)))
       ) True)))

(= (maybeSaveMotivationalState)
   (let $count (get-state &motivation-save-countdown)
      (if (<= $count 0)
          (let* (
             ($_ (saveMotivationalState))
             ($_ (change-state! &motivation-save-countdown
                     (persistenceInterval)))
          ) True)
          (let $_
               (change-state! &motivation-save-countdown (- $count 1))
               False))))
