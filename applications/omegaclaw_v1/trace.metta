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
(: TraceLegacyContextType Type)
(: TraceLegacyContext (-> Number Expression TraceLegacyContextType))
(: TraceCycleRefType Type)
(: TraceCycleRef (-> Expression TraceCycleRefType))
(: TraceDecisionRefType Type)
(: TraceDecisionRef (-> Expression Expression TraceDecisionRefType))
(: MetaMoTraceEventType Type)
(: MetaMoTraceEvent (-> Symbol Expression Expression Expression MetaMoTraceEventType))
!(bind! &metamo-trace-events (new-state ()))

;; Read newest-first diagnostics independently of the live feedback slots.
;; Example: (metaMoTraceEvents) retains a selection after its callback arrives.
(= (metaMoTraceEvents) (get-state &metamo-trace-events))

;; Reset diagnostics only; no motivational, host or reasoner state is touched.
;; Example: initialization starts a fresh volatile trace window.
(= (resetMetaMoTrace) (change-state! &metamo-trace-events ()))

;; One bounded prefix rule avoids overlapping empty/nonempty alternatives.
;; Example: (tracePrefix 2 (a b c)) returns (a b).
(= (tracePrefix $limit $items)
   (if (or (<= $limit 0) (== $items ())) ()
      (cons-atom (car-atom $items) (tracePrefix (- $limit 1) (cdr-atom $items)))))

;; Preserve structured data up to 2048 characters; larger fields keep a digest.
;; Example: an observed empty signal list is (TraceValue ()), not missing evidence.
(= (traceField $name $value)
   (let $text (repr (quote $value))
      (if (== (py-call (trace_support.fits $text)) 1)
         (quote (TraceField $name (TraceValue $value)))
         (TraceField $name (TraceSummary (py-call (trace_support.summarize $text)))))))

;; Missing fields remain explicit rather than becoming zero, False or an empty fact list.
;; Example: (traceEventField EVENT publication) may return (TraceUnavailable NoPublication).
(= (traceEventField $event $name)
   (let $rows (filter-atom (index-atom $event 4) $row (== (index-atom $row 1) $name))
      (if (== $rows ()) (TraceUnavailable NotRecorded) (index-atom (car-atom $rows) 2))))

;; Bound history to 32 events and 16 fields each; identities remain exact or are omitted.
;; Duplicate stage/identity deliveries never overwrite the first retained event.
;; Example: an execution callback appends an event instead of editing its selection.
(= (recordMetaMoTrace $stage $identity $cycle $fields)
   (if (!= (py-call (trace_support.fits (repr (quote ($identity $cycle))))) 1) False
      (let $prior (filter-atom (metaMoTraceEvents) $event
         (tpAllTrue ((== (index-atom $event 1) $stage) (== (index-atom $event 2) $identity))))
         (if (!= $prior ()) True
            (let $bounded (tracePrefix 16 $fields)
               (change-state! &metamo-trace-events
                  (cons-atom (quote (MetaMoTraceEvent $stage $identity $cycle $bounded))
                     (tracePrefix 31 (metaMoTraceEvents)))))))))

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
          (traceField decision (get-state &selected-operation-decision))))))

;; A validated callback has its own exact decision/ticket identity and ungraded result.
;; Example: a late grade cannot change this execution event or its originating cycle.
(= (recordExecutionTrace $outcome)
   (let (OperationOutcome (OperationDecision $context $_ $_ $ticket) $_ $status $result) $outcome
      (recordMetaMoTrace Execution (TraceDecisionRef $context $ticket) (TraceCycleRef $context)
         ((traceField status (quote $status)) (traceField result (quote $result))
          (TraceField assessment (TraceUnavailable NotAssessed))))))

;; Copy an already retained grade and its original receipt decision, without comparing again.
;; Example: grading an earlier outcome after another cycle still links to its old ticket.
(= (recordAssessmentTrace $assessment $decision)
   (let (OperationDecision $context $_ $_ $ticket) $decision
      (recordMetaMoTrace Assessment (index-atom $assessment 1) (TraceCycleRef $context)
         ((traceField decision-ref (TraceDecisionRef $context $ticket))
          (traceField comparison (index-atom $assessment 4))
          (traceField comparator (index-atom $assessment 3))))))
