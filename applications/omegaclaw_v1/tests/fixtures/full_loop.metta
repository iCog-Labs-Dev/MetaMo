;; Shared offline full-loop harness. Only providers and memory are doubled.
;; Core ingestion, projection, MetaMo, policy and dispatch are imported unchanged.
!(import! &self offline_services/offline_guard.py)
!(py-call (offline_guard.install))
!(import! &self offline_services/frame_relation.py)
!(import! &self offline_services/lib_llm_ext.py)
(= (provider) "Offline")
(= (embeddingprovider) "Offline")
(= (maxOutputToken) 256)
(= (wakeupInterval) 1)
(= (getFrameSkillsCompact) (send query))
(= (query $key) "")
(= (remember $payload) True)
!(import! &self (library OmegaClaw-Core src/helper.py))
!(import! &self (library OmegaClaw-Core src/utils))
!(import! &self (library OmegaClaw-Core src/context))
!(import! &self (library OmegaClaw-Core src/skills))
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
!(import! &self (library OmegaClaw-Core src/dispatch))
!(import! &self (library MetaMo applications/omegaclaw_v1/dispatch))
!(import! &self (library MetaMo applications/omegaclaw_v1/host_dispatch_config.py))
!(import! &self host_config_fixture.py)
!(bind! &prevmsg (new-state ""))
!(bind! &lastresults (new-state ""))
!(bind! &error (new-state ""))
!(bind! &loops (new-state 1))
!(bind! &nextWakeAt (new-state 0))

(= (fullLoopStartSession)
   (progn
      (initMetaMoDispatch)
      (initOperationSession)
      (initOmegaClawMotivation)))

(= (fullLoopIngest $message)
   (progn
      (ctx-ingest-user-message $message)
      (cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
      (change-state! &prevmsg $message)
      (change-state! &new-msg-flag True)))

;; Trace actual state/results without recomputing scores or capturing new tickets.
;; Preserve every bridge result so scenario assertions detect missing/extra ones.
(= (fullLoopCycle $label)
   (let* (
      ($before (motivosToMetamoState))
      ($_ (println! (FullLoopCycleBegin $label
         (previous-context (get-state &operation-context)) (state-before $before))))
      ($outputs (collapse (motivationContextBlock))))
      (progn
         (println! (FullLoopCycle $label
            (snapshot (activeFrameBundle))
            (mode (lastModeObservation))
            (state-before $before)
            (state-after (motivosToMetamoState))
            (admitted (map-atom (get-state &operation-admitted-actions) $a (actionId $a)))
            (decision (get-state &last-motivation-decision))
            (operation (get-state &selected-operation-decision))
            (policy $outputs)))
         (superpose $outputs))))

(= (fullLoopDispatch $label $ticket $command)
   (let $result (coreLoopDispatchCommand $ticket $command)
      (progn
         (println! (FullLoopDispatch $label
            (context (get-state &operation-context))
            (ticket $ticket) (attempt $command) (result $result)
            (outcome (get-state &last-operation-outcome))))
         $result)))

(= (fullLoopFinish $label)
   (if (== (py-call (offline_guard.optional_modules_absent)) 1)
       (println! (FullLoopFinished $label))
       (println! (FullLoopRejected ExternalServiceImport))))
