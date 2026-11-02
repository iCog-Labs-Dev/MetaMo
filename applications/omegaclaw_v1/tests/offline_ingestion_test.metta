;; Real host ingestion and real MetaMo logic; only external providers are doubled.
!(import! &self fixtures/offline_services/offline_guard.py)
!(py-call (offline_guard.install))
!(import! &self fixtures/offline_services/frame_relation.py)
!(import! &self fixtures/offline_services/lib_llm_ext.py)
;; Host configuration, with no channel loop, provider credentials, or storage.
(= (provider) "Offline")
(= (embeddingprovider) "Offline")
(= (maxOutputToken) 256)
(= (wakeupInterval) 1)
(= (getFrameSkillsCompact) (send query))
!(import! &self (library OmegaClaw-Core src/helper.py))
!(import! &self (library OmegaClaw-Core src/utils))
!(import! &self (library OmegaClaw-Core src/context))
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
!(bind! &prevmsg (new-state ""))
!(bind! &lastresults (new-state ""))
!(bind! &error (new-state ""))
!(bind! &loops (new-state 1))
!(bind! &nextWakeAt (new-state 0))
!(initContextFrame)
!(initOmegaClawMotivation)
!(py-call (frame_relation.reset))
!(py-call (lib_llm_ext.reset))

!(ctx-ingest-user-message "Summarize the first task")
!(bind! &first-offline-frame (new-state (get-state &cfv2-last-admitted-frame-id)))
!(test (ctx-has-active-goals) True)
!(test (get-state &cfv2-relational-space) ())
!(test (py-call (frame_relation.call_count)) 1)
!(ctx-ingest-user-message "Summarize the second task")
!(bind! &second-offline-frame (new-state (get-state &cfv2-last-admitted-frame-id)))
!(test (!= (get-state &first-offline-frame) (get-state &second-offline-frame)) True)
!(cfv2-load-frame (get-state &second-offline-frame))
!(change-state! &prevmsg "Summarize the second task")
!(change-state! &new-msg-flag True)
!(change-state! &task-open True)
!(change-state! &active-task "Summarize the second task")
;; A real host error exercises failure appraisal. Empty-observation behavior
;; through the full bridge is covered separately by bridge_cycle_test.metta.
!(change-state! &error "observed execution failure")
!(bind! &offline-bundle (new-state (prepareTaskStateForMetaMo)))
!(test (frameBundleCurrentId (get-state &offline-bundle)) (get-state &second-offline-frame))
!(test (size-atom (get-state &cfv2-relational-space)) 1)
!(test (frameBundleRelations (get-state &offline-bundle))
   (frameStateBoundRelations (cfv2-get-relation (get-state &second-offline-frame))))
!(test (py-call (frame_relation.call_count)) 2)
;; Check endpoint direction and advisory status independently of the summary.
(= (offlineRelationIdentity $relation)
   (let (FrameStateRelation (source-frame $source) (target-frame $target)
           (relation-type $kind) $_reason $_confidence (evidence-status $status))
        (frameStateProjectRelation $relation)
        ($source $target $kind $status)))
!(test (offlineRelationIdentity (car-atom (get-state &cfv2-relational-space)))
   ((get-state &second-offline-frame) (get-state &first-offline-frame)
      RelatedButSeparate Unverified))

;; Keep signal extraction, appraisal, candidate conversion, scoring and policy real.
;; No persistence, command dispatch, or full bridge-cycle claim is made here.
!(refreshSignals (get-state &offline-bundle))
!(test (py-call (lib_llm_ext.call_count "confirmation")) 1)

!(test (py-call (lib_llm_ext.call_count "semantics")) 1)
!(test (signalTrue failure) True)
!(refreshConstitutionalMode (get-state &offline-bundle))
!(clearSpace &appraisal-space)
!(computeAllDimensions)
(= (offlineNeutralState)
   (motivation
      (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
      (0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5)))
!(bind! &offline-appraised
   (new-state (omegaclawAppraise (offlineNeutralState) (appraisalToStimulus))))
!(test (!= (get-state &offline-appraised) (offlineNeutralState)) True)
!(test (> (extractAppraisalDim risk) 0.0) True)
!(bind! &offline-score (new-state
   (omegaclawScoreForBundle (get-state &offline-bundle)
      (get-state &offline-appraised) (candidateToAction respond))))
!(test (>= (get-state &offline-score) 0.0) True)
!(test (<= (get-state &offline-score) 1.0) True)
!(test (!= (get-state &offline-score)
   (omegaclawScoreForBundle (get-state &offline-bundle)
      (offlineNeutralState) (candidateToAction respond))) True)
!(test (feasibilityGate (get-state &offline-bundle) respond)
   (GateDecision Admitted Feasible))
;; Re-project actual host status; the real policy must reject completed work.
!(change-state! &cfv2-current-status Completed)
!(bind! &offline-completed (new-state (prepareTaskStateForMetaMo)))
!(test (feasibilityGate (get-state &offline-completed) execute-skill)
   (GateDecision Rejected InactiveFrame))
!(test (py-call (offline_guard.optional_modules_absent)) 1)

;; R2 / 2.2: classifier observations are estimates with cached, inspectable sources.
(= (r22ClassifierFact $kind)
   (car-atom (filter-atom (getFactualSignals) $fact
      (== (factualSignalField kind $fact) $kind))))
!(change-state! &error "")
!(change-state! &lastresults "")
!(change-state! &prevmsg "Proceed with this task")
!(change-state! &new-msg-flag True)
!(bind! &r22-classified (new-state (prepareTaskStateForMetaMo)))
!(py-call (lib_llm_ext.reset))
!(py-call (lib_llm_ext.semantic_response (frameStateRuntimeSummary "Proceed with this task" 1200)
   "((signal execution-request 0.8) (signal danger 0.2))"))
!(py-call (lib_llm_ext.confirmation_response (frameStateRuntimeSummary "Proceed with this task" 1200) 0.9))
!(refreshSignals (get-state &r22-classified))
!(test (factualSignalField value (r22ClassifierFact execution-request)) (quote (RatioFact 0.9 classifier-score)))
!(test (size-atom (filter-atom (getFactualSignals) $fact
   (== (factualSignalField kind $fact) execution-request))) 1)
!(test (let $ref (car-atom (factualSignalField provenance (r22ClassifierFact danger)))
   (let (SourceObservation $_ $_ (ClassifierObservation $_ $provider $confirmation $semantics) $_)
      (resolveSignalObservation $ref)
      ($provider $confirmation $semantics)))
   ("Offline" 0.9 ((signal execution-request 0.8) (signal danger 0.2))))
!(bind! &r22-classifier-facts (new-state (getFactualSignals)))
!(bind! &r22-classifier-store (new-state (get-state &signal-observation-state)))
!(refreshSignals (get-state &r22-classified))
!(test (getFactualSignals) (get-state &r22-classifier-facts))
!(test (get-state &signal-observation-state) (get-state &r22-classifier-store))
!(test (py-call (lib_llm_ext.call_count "semantics")) 1)
!(test (py-call (lib_llm_ext.call_count "confirmation")) 1)

;; Source retention outlives the small call cache without another provider request.
!(change-state! &signal-classifications ())
!(refreshSignals (get-state &r22-classified))
!(test (getFactualSignals) (get-state &r22-classifier-facts))
!(test (py-call (lib_llm_ext.call_count "semantics")) 1)
!(test (py-call (lib_llm_ext.call_count "confirmation")) 1)

;; The classifier reducer is independent of appraisal.
!(test (signalExecutionRequestScore 0.8 0.9) 0.9)
!(add-atom &self (SignalReduction execution-request maximum))
!(test (signalExecutionRequestScore 0.8 0.9) (FactualSignalRejected InvalidSignalReduction))
!(remove-atom &self (SignalReduction execution-request maximum))
!(add-atom &self (SignalReduction execution-request maximum))


;; Example: floating-point appraisal comparisons tolerate arithmetic rounding.
(= (r23Near $actual $expected)
   (and (< (- $actual $expected) 0.000000001)
        (> (- $actual $expected) -0.000000001)))

;; R2 / 2.3: real producer facts bypass compatibility intensities in appraisal.
!(refreshSignals (get-state &r22-classified))
!(computeAllDimensions)
!(bind! &r23-original-stimulus (new-state (appraisalToStimulus)))
!(bind! &r23-original-trace (new-state (lastAppraisalContributions)))
!(test (r23Near (computeDimension risk) 0.16) True)
!(test (computeDimension opportunity) 0.81)
!(test (appraisalStatus) AppraisalReady)
!(test (size-atom (filter-atom (lastAppraisalContributions) $row
   (== (index-atom $row 1) (kind execution-request)))) 3)
!(test (let $row (car-atom (filter-atom (lastAppraisalContributions) $row
   (and (== (index-atom $row 1) (kind user-waiting))
        (== (index-atom $row 2) (dimension importance)))))
   (index-atom $row 5)) (quote (contribution 0.18)))
!(test (let $row (car-atom (filter-atom (lastAppraisalContributions) $row
   (== (index-atom $row 1) (kind danger))))
   (index-atom $row 6)) (let $refs (factualSignalField provenance (r22ClassifierFact danger)) (provenance $refs)))


!(bind! &r24-mode-before (new-state (modeEvaluationForContext
   (ModeTransitionState Engaged 0 none 0 0) (getSignals) True)))
!(bind! &r24-scheduling-before (new-state
   (schedulingPriorityForCandidate (getSignals) verify-frame-state)))
!(bind! &r24-gate-before (new-state (feasibilityGate (get-state &r22-classified) execute-skill)))

;; Editing the sole effective coefficient changes appraisal, leaving facts intact.
!(remove-atom &self (SignalAppraisalRule user-waiting importance BooleanIndicator 0.18))
!(add-atom &self (SignalAppraisalRule user-waiting importance BooleanIndicator -0.5))
!(test (getFactualSignals) (get-state &r22-classifier-facts))
!(test (lastAppraisalContributions) (get-state &r23-original-trace))
!(computeAllDimensions)
!(test (!= (appraisalToStimulus) (get-state &r23-original-stimulus)) True)
!(test (modeEvaluationForContext (ModeTransitionState Engaged 0 none 0 0) (getSignals) True)
   (get-state &r24-mode-before))
!(test (schedulingPriorityForCandidate (getSignals) verify-frame-state)
   (get-state &r24-scheduling-before))
!(test (feasibilityGate (get-state &r22-classified) execute-skill) (get-state &r24-gate-before))
!(test (py-call (lib_llm_ext.call_count "semantics")) 1)
!(remove-atom &self (SignalAppraisalRule user-waiting importance BooleanIndicator -0.5))
!(add-atom &self (SignalAppraisalRule user-waiting importance BooleanIndicator 0.18))
!(computeAllDimensions)
!(test (appraisalToStimulus) (get-state &r23-original-stimulus))

;; A duplicate or incompatible transform rejects the complete appraisal and selection.
!(add-atom &self (SignalAppraisalRule danger risk IdentityRatio 0.7))
!(test (computeAllDimensions) False)
!(test (appraisalStatus) (AppraisalRejected InvalidAppraisalRule))
!(test (signalCycleReady) False)
!(test (lastAppraisalContributions) ())
!(test (appraisalToStimulus) (stimulus (0.0 0.0 0.0 0.0 0.0 0.0)))
!(remove-atom &self (SignalAppraisalRule danger risk IdentityRatio 0.7))
!(add-atom &self (SignalAppraisalRule failure-streak risk BooleanIndicator 0.1))
!(test (computeAllDimensions) False)
!(test (appraisalStatus) (AppraisalRejected InvalidAppraisalTransform))
!(remove-atom &self (SignalAppraisalRule failure-streak risk BooleanIndicator 0.1))
!(computeAllDimensions)
!(test (signalCycleReady) True)

;; Provider expressions are inert data; an invalid response rejects the cycle.
!(change-state! &prevmsg "Malformed classification")
!(py-call (lib_llm_ext.semantic_response (frameStateRuntimeSummary "Malformed classification" 1200)
   "((signal danger (change-state! &failure-streak 99)))"))
!(bind! &r22-malformed (new-state (prepareTaskStateForMetaMo)))
!(test (refreshSignals (get-state &r22-malformed)) (FactualSignalRejected InvalidClassifierObservation))
!(test (get-state &failure-streak) 0)
!(test (signalCycleReady) False)
!(test (getFactualSignals) ())
!(test (refreshSignals (get-state &r22-malformed)) (FactualSignalRejected InvalidClassifierObservation))
!(test (py-call (lib_llm_ext.call_count "semantics")) 2)
!(test (hostSemanticListValid (quote (1))) False)
!(test (hostSemanticListValid (quote ((signal danger 0.5) (signal danger 0.7)))) False)
!(test (hostSemanticListValid (quote ((signal verified-success 1)))) False)

;; A well-typed source from one input cannot be reused as another input's estimate.
!(change-state! &prevmsg "Another request")
!(bind! &r22-next (new-state (prepareTaskStateForMetaMo)))
!(test (let (SignalObservationView $next $_ $_) (frameRuntimeSignalObservations (get-state &r22-next))
   (let $ref (car-atom (factualSignalField provenance (car-atom (filter-atom
      (get-state &r22-classifier-facts) $fact (== (factualSignalField kind $fact) danger)))))
      (hostCheckedClassifications $next (ClassifierResults $ref 0.9
         ((signal execution-request 0.8) (signal danger 0.2))))))
   (FactualSignalRejected MismatchedClassifierObservation))


;; Pure arithmetic regressions use explicit fixture references, without asserting
;; host authentication. Validate all migrated boolean contributions and ratios.
(= (r23FixtureFact $kind $value)
   (makeFactualSignal $kind $value ((SessionObservationRef "appraisal-fixture" 0))))

(= (r23FixtureDimension $kind $value $dim)
   (appraisalDimensionFromTrace $dim (appraiseFactualSignal (r23FixtureFact $kind $value))))

!(test (r23FixtureDimension failure (quote (BooleanFact True)) risk) 0.56)
!(test (r23FixtureDimension failure (quote (BooleanFact False)) risk) 0.0)
!(test (r23FixtureDimension repeated-failure (quote (BooleanFact True)) risk) 0.7225)
!(test (r23FixtureDimension message-differs-from-task (quote (BooleanFact True)) novelty) 0.27)
!(test (r23FixtureDimension new-input-without-outcome (quote (BooleanFact True)) uncertainty) 0.36)
!(test (r23FixtureDimension progress-made (quote (BooleanFact True)) opportunity) 0.12)
!(test (r23FixtureDimension stalled-progress (quote (BooleanFact True)) importance) 0.175)
!(test (r23FixtureDimension user-waiting (quote (BooleanFact True)) importance) 0.18)
!(test (r23FixtureDimension verified-success (quote (BooleanFact True)) progress) 0.7)
!(test (r23FixtureDimension danger (quote (RatioFact 0.5 classifier-score)) risk) 0.4)
!(test (r23FixtureDimension user-angry (quote (RatioFact 0.5 classifier-score)) risk) 0.3)
!(test (r23FixtureDimension execution-request (quote (RatioFact 0.5 classifier-score)) opportunity) 0.45)
!(test (appraiseFactualSignal (r23FixtureFact failure-streak (quote (QuantityFact 5 count)))) ())
!(test (appraiseFactualSignal (r23FixtureFact frame-blocked (quote (BooleanFact True)))) ())
!(test (appraiseFactualSignal (quote (FactualSignal (kind failure) (value (BooleanFact 1))
   (provenance ((SessionObservationRef "appraisal-fixture" 0))))))
   ((AppraisalRejected InvalidFactualSignal)))

;; Sum signed contributions before clamping. Failure + success = 0.46 progress;
;; failure + repeated failure exceed the risk ceiling while both progress terms < 0.
!(clearSignals)
!(let $fact (r23FixtureFact failure (quote (BooleanFact True))) (add-atom &signal-space $fact))
!(let $fact (r23FixtureFact verified-success (quote (BooleanFact True))) (add-atom &signal-space $fact))
!(test (r23Near (computeDimension progress) 0.46) True)
!(clearSignals)
!(let $fact (r23FixtureFact failure (quote (BooleanFact True))) (add-atom &signal-space $fact))
!(let $fact (r23FixtureFact repeated-failure (quote (BooleanFact True))) (add-atom &signal-space $fact))
!(test (computeDimension risk) 1.0)
!(test (computeDimension progress) 0.0)
!(computeAllDimensions)
!(bind! &r23-retained (new-state (lastAppraisalContributions)))
!(test (let $row (car-atom (filter-atom (lastAppraisalContributions) $row
   (and (== (index-atom $row 1) (kind failure))
        (== (index-atom $row 2) (dimension progress)))))
   (index-atom $row 5)) (quote (contribution -0.24)))
!(clearSignals)
!(test (lastAppraisalContributions) (get-state &r23-retained))

;; Pure fixtures now use the same typed boolean path as production.
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/factual_signals))
!(fixturePutSignal failure (quote (BooleanFact True)))
!(test (computeDimension risk) 0.56)
!(clearSignals)
!(resetSignalObservations "appraisal-reset")
!(test (lastAppraisalContributions) ())
!(test (appraisalStatus) AppraisalReady)


;; Frozen pre-migration dimension vectors cover every registry coefficient.
;; This checks both renamed heuristics and every signed contribution before clamp.
(R23Expected failure (0 0.56 0.4 0.32 0 -0.24))
(R23Expected repeated-failure (0 0.7225 0.595 0.51 0 -0.425))
(R23Expected new-input-without-outcome (0.18 0 0.24 0.36 0 0))
(R23Expected verified-success (0 -0.3 0 0 0.5 0.7))
(R23Expected progress-made (0 0 0 0 0.12 0.18))
(R23Expected stalled-progress (0 0 0.175 0 0 -0.07))
(R23Expected user-waiting (0 0 0.18 0 0 0))
(R23Expected message-differs-from-task (0.27 0 0 0.18 0 0))
(R23Expected user-angry (0 0.6 0.5 0 0 0))
(R23Expected danger (0 0.8 0.7 0.4 0 0))
(R23Expected execution-request (0 0 0.7 0 0.9 0.6))

;; Example: compare all six raw sums against the old strength × weight table.
(= (r23MigrationMatches $kind $expected)
   (let* (
      ($value (case (factualSignalSpec $kind) (
         ((FactualSignalSpec $_ Boolean $_ $_) (BooleanFact True))
         ($_ (RatioFact 1 classifier-score)))))
      ($trace (appraiseFactualSignal (r23FixtureFact $kind $value)))
      ($dimensions (novelty risk importance uncertainty opportunity progress))
      ($invalid (filter-atom (0 1 2 3 4 5) $index
         (let* (
            ($dim (index-atom $dimensions $index))
            ($rows (filter-atom $trace $row (== (index-atom $row 2) (dimension $dim))))
            ($values (map-atom $rows $row (index-atom (index-atom $row 5) 1)))
         ) (not (r23Near (sumAppraisalValues $values 0) (index-atom $expected $index))))))
   ) (== $invalid ())))

!(test (collapse (match &self (R23Expected $kind $vector)
   (r23MigrationMatches $kind $vector)))
   (True True True True True True True True True True True))


;; Zero semantic estimates remain in their classifier source, but never appear
;; as mode-triggering ratio facts at the inclusive zero default threshold.
!(change-state! &prevmsg "No classified danger")
!(change-state! &new-msg-flag True)
!(py-call (lib_llm_ext.semantic_response (frameStateRuntimeSummary "No classified danger" 1200)
   "((signal danger 0) (signal user-angry 0) (signal execution-request 0))"))
!(bind! &r24-zero-bundle (new-state (prepareTaskStateForMetaMo)))
!(refreshSignals (get-state &r24-zero-bundle))
!(test (signalFact danger) (FactualSignalAbsent danger))
!(test (signalFact user-angry) (FactualSignalAbsent user-angry))
!(test (signalFact execution-request) (FactualSignalAbsent execution-request))
!(test (modeSignalGroupActive threat Enter (getSignals)) False)
!(test (signalTrue user-waiting) True)
!(test (signalCycleReady) True)
