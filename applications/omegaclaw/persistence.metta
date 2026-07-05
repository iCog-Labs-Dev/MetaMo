;; Motivational State Persistence
;; Stores X=(G,M,S) in long-term ChromaDB memory so that the motivational state survives session boundaries.

;; Restoration:
;;   On startup, query ChromaDB for the most recent MOTIVOS_STATE_V1 entry.
(= (persistenceKey) "MOTIVOS_STATE_V1")


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


;; restoreMotivationalState
(= (restoreMotivationalState)
   (let* (
      ($_ (println! ("Querying long-term memory for prior motivational state...")))
      ($results (eval (query (persistenceKey))))
      ($raw     (eval (string-safe $results)))
   )
   (if (hasContent $raw)
       (let* (
          ($parsed  (py-call (lib_llm_ext.parseMotivosState $raw)))
          ($_ (if (and (!= $parsed ()) (!= $parsed (Error)))
                  (let* (
                     ($_ (collapse
                            (let $entry (superpose $parsed)
                               (case $entry (
                                  ((goal $name $val)
                                    (replaceGoal $name $val))
                                  ((modulator $name $val)
                                    (replaceModulator $name $val))
                                  ((motive $name $val)
                                    (replaceMotive $name $val))
                                  ((self-metric $name $val)
                                    (replaceSelfMetric $name $val))
                                  ($_ (empty)))))))
                     ($_ (println! ("Prior motivational state successfully restored.")))
                  ) ())
                  (println! ("No prior motivational state found. Using registry defaults."))
                  ))
       ) ())
       (println! ("No prior motivational state found. Using registry defaults.")))))


;; tryRestoreOrInit - Called once during startup after default initialisation.
(= (tryRestoreOrInit)
   (let* (
      ($_ (println! ("Checking long-term memory for persisted motivational state...")))
      ($_ (restoreMotivationalState))
      ($_ (println! ("Startup restoration complete (defaults remain active as fallback).")))
   ) ()))
