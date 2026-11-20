;; Bounded volatile diagnostics. No provider, selection, assessment or dispatch calls.
!(import! &self (library MetaMo applications/omegaclaw_v1/trace_support.py))
(: TraceUnavailableType Type)
(: TraceUnavailable (-> Symbol TraceUnavailableType))
(: TraceValueType Type)
(: TraceValue (-> Expression TraceValueType))
(: TraceSummaryType Type)
(: TraceSummary (-> String TraceSummaryType))
(: TraceFieldType Type)
(: TraceField (-> Symbol Expression TraceFieldType))
(: TraceSignalType Type)
(: TraceSignal (-> Symbol Expression TraceSignalType))
(: TraceContributionType Type)
(: TraceContribution (-> Symbol Symbol Number TraceContributionType))
(: TraceStateNamesType Type)
(: TraceStateNames (-> Expression Expression TraceStateNamesType))
(: TraceModeExplanationType Type)
(: TraceModeExplanation (-> Expression Expression Expression Expression Expression Expression TraceModeExplanationType))
(: TraceModeRuleType Type)
(: TraceModeRule (-> Expression Symbol Expression TraceModeRuleType))
(: TraceModeTriggerType Type)
(: TraceModeTrigger (-> Symbol Expression TraceModeTriggerType))
(: TraceSchedulingType Type)
(: TraceScheduling (-> Number Expression TraceSchedulingType))
(: TraceCandidateType Type)
(: TraceCandidate (-> Symbol Symbol Number Symbol TraceCandidateType))
(: TraceNativeScoreType Type)
(: TraceNativeScore (-> Symbol Number TraceNativeScoreType))
(: TraceSelectionType Type)
(: TraceSelection (-> Symbol Symbol Expression TraceSelectionType))
(: TraceSelectionExplanationType Type)
(: TraceSelectionExplanation (-> Expression Expression TraceSelectionExplanationType))
(: TraceLegacyContextType Type)
(: TraceLegacyContext (-> Number Expression TraceLegacyContextType))
(: TraceCycleRefType Type)
(: TraceCycleRef (-> Expression TraceCycleRefType))
(: TraceDecisionRefType Type)
(: TraceDecisionRef (-> Expression Expression TraceDecisionRefType))
(: TraceProposalRefType Type)
(: TraceProposalRef (-> Expression Expression TraceProposalRefType))
(: TraceBudgetRefType Type)
(: TraceBudgetRef (-> Expression Symbol TraceBudgetRefType))
(: TracePrintConfigType Type)
(: TracePrintConfig (-> Symbol Number TracePrintConfigType))
(: TracePrintRejectedType Type)
(: TracePrintRejected (-> Symbol TracePrintRejectedType))
(: TraceEventRefType Type)
(: TraceEventRef (-> Symbol Expression TraceEventRefType))
(: MetaMoTraceEventType Type)
(: MetaMoTraceEvent (-> Symbol Expression Expression Expression MetaMoTraceEventType))
!(bind! &metamo-trace-events (new-state ()))
!(bind! &trace-native-scores (new-state ()))
!(bind! &trace-selection (new-state ()))
!(bind! &trace-scheduling (new-state ()))
!(bind! &trace-print-config (new-state (TracePrintConfig False 12000)))
!(bind! &trace-print-pending (new-state ()))

;; Trusted emission controls never disable structured recording or grant a model skill.
;; Example: (configureTracePrinting (TracePrintConfig True 6000)) enables bounded output.
(= (configureTracePrinting $config)
   (case $config (
      ((TracePrintConfig $enabled $limit)
       (if (tpAllTrue ((tpContains (True False) $enabled) (fsCount $limit) (fsNumberIn $limit 256 12000)))
          (progn (change-state! &trace-print-config $config) (change-state! &trace-print-pending ()) True)
          (TracePrintRejected InvalidConfiguration)))
      ($_ (TracePrintRejected InvalidConfiguration)))))

;; Clear per-cycle work without changing selection, counters or the retained history.
;; Example: the next bridge cycle cannot inherit a preceding score table.
(= (resetCycleSelectionTrace)
   (progn (change-state! &trace-native-scores ()) (change-state! &trace-selection ())
      (change-state! &trace-scheduling ()) True))

;; Read newest-first diagnostics independently of the live feedback slots.
;; Example: (metaMoTraceEvents) retains a selection after its callback arrives.
(= (metaMoTraceEvents) (get-state &metamo-trace-events))

;; Reset diagnostics only; no motivational, host or reasoner state is touched.
;; Example: initialization starts a fresh volatile trace window.
(= (resetMetaMoTrace)
   (progn (change-state! &metamo-trace-events ()) (change-state! &trace-print-pending ())
      (resetCycleSelectionTrace)))

;; One bounded prefix rule avoids overlapping empty/nonempty alternatives.
;; Example: (tracePrefix 2 (a b c)) returns (a b).
(= (tracePrefix $limit $items)
   (if (or (<= $limit 0) (== $items ())) ()
      (cons-atom (car-atom $items) (tracePrefix (- $limit 1) (cdr-atom $items)))))

;; Queue references only; recording under a host lock never performs console I/O.
;; Example: a budget event and accepted callback can be rendered together after dispatch.
(= (queueTracePrinting $stage $identity)
   (case (get-state &trace-print-config) (
      ((TracePrintConfig True $_)
       (let $ref (quote (TraceEventRef $stage $identity))
          (if (tpContains (get-state &trace-print-pending) $ref) True
             (change-state! &trace-print-pending (tracePrefix 32
                (cons-atom $ref (get-state &trace-print-pending)))))))
      ($_ True))))

;; Consume one bounded emission batch using retained observations, newest cycles first.
;; Example: repeated flushes with no new events print nothing and consume no feedback.
(= (emitPendingMetaMoTrace)
   (let* (
      ((TracePrintConfig $enabled $limit) (get-state &trace-print-config))
      ($pending (get-state &trace-print-pending))
      ($history (metaMoTraceEvents))
      ($_ (change-state! &trace-print-pending ()))
   )
      (if (and (== $enabled True) (!= $pending ()))
         (let $text (py-call (trace_support.render_pending (quote $history) (quote $pending) $limit))
            (if (== (py-call (trace_support.is_empty $text)) 1) True (progn (println! $text) True))) True)))

;; Emission failure cannot change a cycle, dispatch, assessment or learner result.
;; Example: safe runtime boundaries call this after releasing their host locks.
(= (flushMetaMoTrace) (progn (collapse (catch (emitPendingMetaMoTrace))) True))

;; Observe only scores already calculated by the native decision traversal.
;; Example: later bimonad probes cannot overwrite the first decision's numbers.
(= (recordTraceNativeScore $candidate $score)
   (if (or (!= (get-state &trace-selection) ()) (>= (size-atom (get-state &trace-native-scores)) 32)) True
      (change-state! &trace-native-scores
         (append (get-state &trace-native-scores) ((TraceNativeScore $candidate $score))))))

;; Freeze the native and actual winners before the safety counter changes.
;; Example: differing winners indicate an advisory choice, not a higher native score.
(= (retainTraceSelection $native $chosen)
   (if (!= (get-state &trace-selection) ()) True
      (change-state! &trace-selection
         (TraceSelection (actionId $native) (actionId $chosen) (get-state &trace-native-scores)))))

;; Copy admitted classes and the actual scheduling survivors using the cycle's inputs.
;; Example: a lower-class candidate is deferred, not recorded as policy-rejected.
(= (captureSchedulingTrace $pool $scheduled)
   (change-state! &trace-scheduling
      (TraceScheduling (size-atom $pool)
         (map-atom (tracePrefix 32 $pool) $action
            (let $class (schedulingPriorityForCandidate (getSignals) (actionId $action))
               (TraceCandidate (actionId $action) $class (schedulingPriorityRank $class)
                  (tpContains $scheduled $action)))))))

;; Copy only matched predicates; full provenance remains in the original mode observation.
;; Example: retain the exact ratio threshold used or the host's frame-present condition.
(= (traceModeTriggers (TriggerEvidence $signals $context))
   (append
      (map-atom (filter-atom $signals $row
         (== (index-atom $row (- (size-atom $row) 1)) (matched True))) $evidence
         (TraceModeTrigger (index-atom (index-atom $evidence 1) 1)
            (index-atom (index-atom $evidence 2) 1)))
      (map-atom (filter-atom $context $row (== (index-atom $row 2) True)) $evidence
         (TraceModeTrigger (index-atom $evidence 1) IsTrue))))

;; Preserve structured data up to 2048 characters; larger fields keep a digest.
;; Example: an observed empty signal list is (TraceValue ()), not missing evidence.
(= (traceField $name $value)
   (let $text (repr (quote $value))
      (if (== (py-call (trace_support.fits $text)) 1)
         (quote (TraceField $name (TraceValue $value)))
         (TraceField $name (TraceSummary (py-call (trace_support.summarize $text)))))))

;; Project retained mode evidence without rerunning rules or timing evaluation.
;; Example: an unchanged posture can still have a requested transition held by timers.
(= (traceModeExplanationField $observation)
   (case $observation (
      ((ModeObservation $_ $_ $_ $before $after (ModeEvaluation $winner $target $rules $timing))
       (traceField mode-explanation (TraceModeExplanation $before $after $winner $target
         (map-atom $rules $row (let (ModeRuleEvidence $rule $active $evidence) $row
            (TraceModeRule $rule $active (traceModeTriggers $evidence))))
         $timing)))
      ($_ (TraceField mode-explanation (TraceUnavailable NoModeObservation))))))

;; Missing fields remain explicit rather than becoming zero, False or an empty fact list.
;; Example: (traceEventField EVENT publication) may return (TraceUnavailable NoPublication).
(= (traceEventField $event $name)
   (let $rows (filter-atom (index-atom $event 4) $row (== (index-atom $row 1) $name))
      (if (== $rows ()) (TraceUnavailable NotRecorded) (index-atom (car-atom $rows) 2))))

;; Bound history to 32 events and 20 fields each; identities remain exact or are omitted.
;; Duplicate stage/identity deliveries never overwrite the first retained event.
;; Example: an execution callback appends an event instead of editing its selection.
(= (recordMetaMoTrace $stage $identity $cycle $fields)
   (if (!= (py-call (trace_support.fits (repr (quote ($identity $cycle))))) 1) False
      (let $prior (filter-atom (metaMoTraceEvents) $event
         (tpAllTrue ((== (index-atom $event 1) $stage) (== (index-atom $event 2) $identity))))
         (if (!= $prior ()) True
            (let $bounded (tracePrefix 20 $fields)
               (progn (change-state! &metamo-trace-events
                  (cons-atom (quote (MetaMoTraceEvent $stage $identity $cycle $bounded))
                     (tracePrefix 31 (metaMoTraceEvents))))
                  (queueTracePrinting $stage $identity) True))))))

;; Find the latest completed selection without interpreting any retained payload.
;; Example: (lastCycleTrace) is unchanged when an execution or grade arrives later.
(= (lastCycleTrace)
   (let $rows (filter-atom (metaMoTraceEvents) $event (== (index-atom $event 1) CycleSelection))
      (if (== $rows ()) (TraceUnavailable NoCycle) (car-atom $rows))))

;; Capture the live cycle before signal cleanup; do not poll optional reasoner modules.
;; Example: absent host publication is distinct from an observed empty signal set.
(= (captureCycleTrace $bundle $before $selfBefore)
   (let* (
      ($context (get-state &operation-context))
      ($cycle (TraceCycleRef (if (== $context ())
         (TraceLegacyContext (get-state &cycle-count) (frameBundleCurrentId $bundle)) $context)))
      ($publication (case (frameRuntimeSignalObservations $bundle) (
         ((SignalObservationView $ref $_ $_) (traceField publication (quote $ref)))
         ($_ (TraceField publication (TraceUnavailable NoPublication))))))
      ($signalValues (traceField signal-values (map-atom (getSignals) $fact
         (let (FactualSignal (kind $kind) (value $value) $_) $fact (TraceSignal $kind $value)))))
   )
      (recordMetaMoTrace CycleSelection $cycle $cycle
         ($publication
          (traceField state-before (quote $before))
          (traceField self-before (quote $selfBefore))
          (traceField state-after (motivosToMetamoState))
          (traceField self-after (getSelfModel))
          (traceField signals (getSignals))
          (traceField appraisals (collapse (match &appraisal-space (appraisal $dim $value) (appraisal $dim $value))))
          (traceField mode (get-state &last-mode-observation))
          (traceField admitted (get-state &operation-admitted-actions))
          (traceField rejected (candidateRejections))
          (traceField policy (get-state &last-meta-mo-policy-output))
          (case (get-state &selected-operation-decision) (
             ((OperationDecision $origin $_ $_ $ticket)
              (traceField decision-ref (TraceDecisionRef $origin $ticket)))
             ($_ (TraceField decision-ref (TraceUnavailable NoHostDecision)))))
          (traceField decision (get-state &selected-operation-decision))
          (case (signalRefreshStatus) (
             ((SignalRefreshReady $_) $signalValues)
             (LegacySignalCycle $signalValues)
             ($_ (TraceField signal-values (TraceUnavailable SignalRefreshRejected)))))
          (if (== (appraisalStatus) AppraisalReady)
             (traceField contributions (map-atom (lastAppraisalContributions) $row
                (let (AppraisalContribution (kind $kind) (dimension $dim) $_ $_
                   (contribution $value) $_) $row (TraceContribution $kind $dim $value))))
             (TraceField contributions (TraceUnavailable AppraisalRejected)))
          (traceField state-names (TraceStateNames
             (collapse (match &self (GoalSpec $name $_)
                (match &self (GoalIndex $name $index) (GoalIndex $name $index))))
             (collapse (match &self (ModulatorSpec $name $_)
                (match &self (ModulatorIndex $name $index) (ModulatorIndex $name $index))))))
          (traceModeExplanationField (get-state &last-mode-observation))
          (traceField scheduling (get-state &trace-scheduling))
          (traceField selection (TraceSelectionExplanation (get-state &last-motivation-decision)
             (get-state &trace-selection)))
          (if (== (frameBundleCurrentId $bundle) ())
             (TraceField frame-mode (TraceUnavailable NoCurrentFrame))
             (traceField frame-mode (frameBundleCurrentMode $bundle)))))))

;; Pure formatting reads only the supplied retained event, including its original labels.
;; Example: (formatCycleSummary (lastCycleTrace)) returns bounded text without printing.
(= (formatCycleSummary $event)
   (let $history (metaMoTraceEvents)
      (py-call (trace_support.format_cycle (quote $event) (quote $history)))))

;; Explicit printing does not rerun a cycle, appraisal, provider or callback.
;; Example: (printCycleSummary (lastCycleTrace)) prints one labelled selection summary.
(= (printCycleSummary $event)
   (let (TracePrintConfig $_ $limit) (get-state &trace-print-config)
      (progn (println! (py-call (trace_support.limit_output (formatCycleSummary $event) $limit))) True)))

;; Print the latest retained selection even if later execution or assessment events exist.
;; Example: (printLastCycleSummary) reports unavailable when no cycle has been captured.
(= (printLastCycleSummary) (printCycleSummary (lastCycleTrace)))

;; A validated callback has its own exact decision/ticket identity and ungraded result.
;; Example: a late grade cannot change this execution event or its originating cycle.
(= (recordExecutionTrace $outcome)
   (let (OperationOutcome (OperationDecision $context $_ $_ $ticket) $_ $status $result) $outcome
      (recordMetaMoTrace Execution (TraceDecisionRef $context $ticket) (TraceCycleRef $context)
         ((traceField status (quote $status)) (traceField result (quote $result))
          (TraceField assessment (TraceUnavailable NotAssessed))))))

;; Copy settlement balances inside the host accounting callback, never during printing.
;; Example: unknown usage retains its reservation instead of reporting zero consumption.
(= (recordBudgetTrace $ticket $costs $actual $settlement $before $after $result)
   (let* (
      ($ids (map-atom $costs $cost (index-atom $cost 1)))
      ($cycle (case (get-state &selected-operation-decision) (
         ((OperationDecision $context $_ $_ $ticket) (TraceCycleRef $context))
         ($_ (TraceUnavailable NoSelectedDecision)))))
   )
      (recordMetaMoTrace BudgetSettlement (TraceBudgetRef $ticket (car-atom $settlement)) $cycle
         ((traceField reserved-costs (quote $costs)) (traceField actual-costs (quote $actual))
          (traceField settlement (quote $settlement)) (traceField dispatch-result (quote $result))
          (traceField accounts-before (filter-atom $before $row (tpContains $ids (index-atom $row 1))))
          (traceField accounts-after (filter-atom $after $row (tpContains $ids (index-atom $row 1))))))))

;; Copy an already retained grade and its original receipt decision, without comparing again.
;; Example: grading an earlier outcome after another cycle still links to its old ticket.
(= (recordAssessmentTrace $assessment $decision $invocation $proposal)
   (let (OperationDecision $context $_ $_ $ticket) $decision
      (recordMetaMoTrace Assessment (index-atom $assessment 1) (TraceCycleRef $context)
         ((traceField decision-ref (TraceDecisionRef $context $ticket))
          (traceField proposal-ref (TraceProposalRef $invocation $proposal))
          (traceField proposal-key (repr (quote (TraceProposalRef $invocation $proposal))))
          (traceField comparison (index-atom $assessment 4))
          (traceField comparator (index-atom $assessment 3))))))
