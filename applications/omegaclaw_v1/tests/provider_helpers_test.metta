;; Real Python helpers and MeTTa restoration, with provider transport doubled.
!(import! &self (library OmegaClaw-Core lib_llm_ext.py))
!(import! &self fixtures/provider_helpers_fixture.py)
!(import! &self (library OmegaClaw-Core src/utils))
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
!(import! &self (library MetaMo applications/omegaclaw_v1/runtime_support))
!(test (collapse (py-str ("count:" 2))) ("count:2"))
!(test (collapse (py-str ())) (""))
!(bind! &helper-memory (new-state ""))
(= (remember $payload) (change-state! &helper-memory $payload))
(= (query $key) (("time" (get-state &helper-memory))))

!(py-call (provider_helpers_fixture.reply "{\"score\":0.9}"))
!(test (py-call (lib_llm_ext.executionConfirmationScore "ASICloud" "Go ahead" "Read file")) 0.9)
!(py-call (provider_helpers_fixture.reply "{\"execution-request\":0.8}"))
!(test (sread (py-call (lib_llm_ext.extractSemantics "ASICloud" "Read file"))) ((signal execution-request 0.8)))
!(py-call (provider_helpers_fixture.reply "{\"verified-success\":1}"))
!(test (sread (py-call (lib_llm_ext.extractSemantics "ASICloud" "done"))) ())

!(replaceGoal progress 0.4)
!(replaceAntiGoal harm 0.8)
!(replaceModulator urgency 0.2)
!(replaceSelfMetric energy 0.3)
!(saveMotivationalState)
!(replaceGoal progress 0.1)
!(replaceAntiGoal harm 0.1)
!(replaceModulator urgency 0.1)
!(replaceSelfMetric energy 0.1)
!(restoreMotivationalState)
!(test (getGoals) ((goal progress 0.4)))

!(test (getAntiGoals) ((anti-goal harm 0.8)))
!(test (getModulators) ((modulator urgency 0.2)))
!(test (getSelfModel) ((self-metric energy 0.3)))
!(change-state! &helper-memory "MOTIVOS_STATE_V1 time:today G:((goal progress 0.9)) AG:() M:((eval unsafe)) S:()")
!(restoreMotivationalState)
!(test (getGoals) ((goal progress 0.4)))

;; R2 / 2.1: factual shapes are pure and leave legacy live signals unchanged.
;; Example: a declared boolean with a reference is shape-valid, not authenticated.
(= (r21Refs) (quote ((SessionObservationRef "shape-session" 17))))
(= (r21Check $kind $value $refs)
   (validateFactualSignal (FactualSignal (kind $kind) (value $value) (provenance $refs))))

!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/factual_signals))
!(fixturePutSignal user-waiting (quote (BooleanFact True)))
!(test (size-atom (collapse (match &self (FactualSignalSpec $kind $type $unit $source) $kind))) 13)
!(test (filter-atom
   (collapse (match &self (FactualSignalSpec $kind $type $unit $source)
      (FactualSignalSpec $kind $type $unit $source))) $spec (not (fsSpecValid $spec))) ())
!(test (factualSignalSpec failure) (FactualSignalSpec failure Boolean None observation))
!(test (factualSignalSpec danger) (FactualSignalSpec danger Ratio classifier-score estimate))
!(test (factualSignalSpec made-up) (FactualSignalRejected UnknownSignalKind))

;; True and explicit False are both facts; intensities cannot stand in for them.
!(test (r21Check failure (quote (BooleanFact True)) (r21Refs)) (FactualSignalValid Boolean None observation))
!(test (r21Check frame-blocked (quote (BooleanFact False)) (r21Refs)) (FactualSignalValid Boolean None observation))
!(test (r21Check failure (quote (BooleanFact 0.80)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check failure True (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check failure (quote (BooleanFact "True")) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check failure (quote (BooleanFact Unknown)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check failure (quote (RatioFact 1 classifier-score)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))

;; Unit scores remain estimates. Bounds include zero and one; units match exactly.
!(test (r21Check danger (quote (RatioFact 0 classifier-score)) (r21Refs)) (FactualSignalValid Ratio classifier-score estimate))
!(test (r21Check danger (quote (RatioFact 1 classifier-score)) (r21Refs)) (FactualSignalValid Ratio classifier-score estimate))
!(test (r21Check execution-request (quote (RatioFact 0.85 classifier-score)) (r21Refs)) (FactualSignalValid Ratio classifier-score estimate))
!(test (r21Check danger (quote (RatioFact -0.1 classifier-score)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check danger (quote (RatioFact 1.1 classifier-score)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check danger (quote (RatioFact True classifier-score)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check danger (quote (RatioFact "0.9" classifier-score)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check danger (quote (RatioFact 0.9 probability)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check danger (quote (RatioFact 0.9 "classifier-score")) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check danger (RatioFact (py-call (provider_helpers_fixture.numeric_anomaly "nan")) classifier-score) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check danger (RatioFact (py-call (provider_helpers_fixture.numeric_anomaly "inf")) classifier-score) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check failure-streak (QuantityFact (py-call (provider_helpers_fixture.numeric_anomaly "-inf")) count) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check failure-streak (quote (QuantityFact 0 count)) (r21Refs)) (FactualSignalValid Quantity count observation))
!(test (r21Check failure-streak (quote (QuantityFact 9007199254740991 count)) (r21Refs)) (FactualSignalValid Quantity count observation))
!(test (r21Check failure-streak (quote (QuantityFact 2.5 count)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check failure-streak (quote (QuantityFact -1 count)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check failure-streak (quote (QuantityFact 9007199254740992 count)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check failure-streak (quote (QuantityFact 2 milliseconds)) (r21Refs)) (FactualSignalRejected InvalidSignalValue))

;; Provenance must have 1..16 unique, same-session references, with bounded IDs.
!(test (r21Check failure (quote (BooleanFact True)) ()) (FactualSignalRejected InvalidSignalProvenance))
!(test (r21Check failure (quote (BooleanFact True)) absent) (FactualSignalRejected InvalidSignalProvenance))
!(test (r21Check failure (quote (BooleanFact True)) (quote ((SessionObservationRef "" 1)))) (FactualSignalRejected InvalidSignalProvenance))
!(test (r21Check failure (quote (BooleanFact True)) (quote ((SessionObservationRef session 1)))) (FactualSignalRejected InvalidSignalProvenance))
!(test (r21Check failure (quote (BooleanFact True)) (quote ((SessionObservationRef "shape-session" 1.5)))) (FactualSignalRejected InvalidSignalProvenance))
!(test (r21Check failure (quote (BooleanFact True)) (quote ((SessionObservationRef "shape-session" -1)))) (FactualSignalRejected InvalidSignalProvenance))
!(test (r21Check failure (quote (BooleanFact True)) (quote ((SessionObservationRef "shape-session" 9007199254740992)))) (FactualSignalRejected InvalidSignalProvenance))
!(test (r21Check failure (quote (BooleanFact True)) (quote ((ObservationRef "shape-session" 17)))) (FactualSignalRejected InvalidSignalProvenance))
!(test (r21Check failure (quote (BooleanFact True)) (quote ((SessionObservationRef "shape-session" 17) (SessionObservationRef "shape-session" 17)))) (FactualSignalRejected InvalidSignalProvenance))
!(test (r21Check failure (quote (BooleanFact True)) (quote ((SessionObservationRef "shape-session" 17) (SessionObservationRef "other-session" 18)))) (FactualSignalRejected InvalidSignalProvenance))
!(test (r21Check failure (quote (BooleanFact True)) (quote ((SessionObservationRef "shape-session" 17) (SessionObservationRef "shape-session" 18)))) (FactualSignalValid Boolean None observation))
!(test (fsReferenceList (map-atom (0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15) $i (SessionObservationRef "shape-session" $i))) True)
!(test (fsReferenceList (map-atom (0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16) $i (SessionObservationRef "shape-session" $i))) False)

;; Exact record shape: missing, reordered, extra, unground and legacy inputs reject.
!(test (validateFactualSignal ()) (FactualSignalRejected InvalidSignalRecord))
!(test (validateFactualSignal (quote (signal failure 0.80))) (FactualSignalRejected InvalidSignalRecord))
!(test (validateFactualSignal (quote (FactualSignal (kind failure) (value (BooleanFact True))))) (FactualSignalRejected InvalidSignalRecord))
!(test (validateFactualSignal (quote (FactualSignal (value (BooleanFact True)) (kind failure) (provenance ((SessionObservationRef "s" 1)))))) (FactualSignalRejected InvalidSignalRecord))
!(test (validateFactualSignal (quote (FactualSignal (kind failure) (value (BooleanFact True)) (provenance ((SessionObservationRef "s" 1))) (extra True)))) (FactualSignalRejected InvalidSignalRecord))
!(test (validateFactualSignal (quote (FactualSignal (kind failure) (value (BooleanFact $unknown)) (provenance ((SessionObservationRef "s" 1)))))) (FactualSignalRejected NonGroundSignal))
!(test (r21Check made-up (quote (BooleanFact True)) (r21Refs)) (FactualSignalRejected UnknownSignalKind))

;; Constructor and field access preserve False; validation never runs literal data.
!(test (makeFactualSignal failure (quote (BooleanFact False)) (r21Refs))
   (quote (FactualSignal (kind failure) (value (BooleanFact False)) (provenance ((SessionObservationRef "shape-session" 17))))))
!(test (factualSignalField value (makeFactualSignal failure (quote (BooleanFact False)) (r21Refs))) (quote (BooleanFact False)))
!(test (factualSignalField provenance (makeFactualSignal failure (quote (BooleanFact True)) (r21Refs))) (r21Refs))
!(test (factualSignalField kind (makeFactualSignal danger (quote (RatioFact 0.9 classifier-score)) (r21Refs))) danger)
!(test (factualSignalField value ()) (FactualSignalRejected InvalidSignalRecord))
!(test (factualSignalField made-up (makeFactualSignal failure (quote (BooleanFact True)) (r21Refs))) (FactualSignalRejected UnknownSignalField))
!(test (makeFactualSignal failure 0.8 (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (r21Check failure (quote (BooleanFact (change-state! &failure-streak 99))) (r21Refs)) (FactualSignalRejected InvalidSignalValue))
!(test (get-state &failure-streak) 0)

;; Missing/duplicate/invalid domain declarations fail instead of selecting a row.
!(add-atom &self (FactualSignalSpec failure Boolean None observation))
!(test (factualSignalSpec failure) (FactualSignalRejected InvalidSignalSpec))
!(remove-atom &self (FactualSignalSpec failure Boolean None observation))
!(add-atom &self (FactualSignalSpec failure Boolean None observation))
!(test (factualSignalSpec failure) (FactualSignalSpec failure Boolean None observation))
!(add-atom &self (FactualSignalRange danger 0 1))
!(test (factualSignalSpec danger) (FactualSignalRejected InvalidSignalSpec))
!(remove-atom &self (FactualSignalRange danger 0 1))
!(test (factualSignalSpec danger) (FactualSignalRejected InvalidSignalSpec))
!(add-atom &self (FactualSignalRange danger 0 1))
!(add-atom &self (FactualSignalSpec unsupported Quantity milliseconds observation))
!(test (factualSignalSpec unsupported) (FactualSignalRejected InvalidSignalSpec))
!(remove-atom &self (FactualSignalSpec unsupported Quantity milliseconds observation))
!(remove-atom &self (FactualSignalRange failure-streak 0 9007199254740991))
!(add-atom &self (FactualSignalRange failure-streak "zero" 10))
!(test (factualSignalSpec failure-streak) (FactualSignalRejected InvalidSignalSpec))
!(remove-atom &self (FactualSignalRange failure-streak "zero" 10))
!(add-atom &self (FactualSignalRange failure-streak 10 2))
!(test (factualSignalSpec failure-streak) (FactualSignalRejected InvalidSignalSpec))
!(remove-atom &self (FactualSignalRange failure-streak 10 2))
!(add-atom &self (FactualSignalRange failure-streak 0 9007199254740991))
!(test (getSignals) ((FactualSignal (kind user-waiting) (value (BooleanFact True)) (provenance ((SessionObservationRef "typed-signal-fixture" 0))))))
!(clearSignals)

;; R5 / 3.1: S declares internal condition only; legacy metrics are classified.
!(test (collapse (match &self (SelfModelFieldSpec $n $c $u $lo $hi $seed) $n))
   (energy fatigue urgency))

!(test (filter-atom (collapse (match &self
   (SelfModelFieldSpec $n $c $u $lo $hi $seed)
   (SelfModelFieldSpec $n $c $u $lo $hi $seed))) $spec
      (not (selfModelFieldSpecValid $spec))) ())

!(test (selfModelFieldSpec energy)
   (SelfModelFieldSpec energy physiological normalized 0 1 1.0))

!(test (selfModelFieldSpec memory_confidence) (SelfModelFieldRejected UnknownField))

!(test (selfModelFieldSpec capabilities) (SelfModelFieldRejected UnknownField))

!(test (selfModelMetricValid (quote (self-metric energy 0))) True)

!(test (selfModelMetricValid (quote (self-metric fatigue 1))) True)

!(test (selfModelMetricValid (quote (self-metric urgency 0.5))) True)

!(test (selfModelMetricValid (quote (self-metric energy -0.1))) False)

!(test (selfModelMetricValid (quote (self-metric energy 1.1))) False)

!(test (selfModelMetricValid (quote (self-metric energy "0.5"))) False)

!(test (selfModelMetricValid (quote (self-metric energy True))) False)

!(test (selfModelMetricValid (self-metric energy
   (py-call (provider_helpers_fixture.numeric_anomaly "nan")))) False)

!(test (selfModelMetricValid (self-metric energy
   (py-call (provider_helpers_fixture.numeric_anomaly "inf")))) False)

!(test (selfModelMetricValid (quote (self-metric knowledge 0.5))) False)

!(test (selfModelMetricValid (quote (self-metric beliefs 0.5))) False)

!(test (selfModelMetricValid (quote (self-metric energy 0.5 extra))) False)

!(test (selfModelFieldSpecValid
   (quote (SelfModelFieldSpec capability cognitive normalized 0 1 0.5))) False)

!(test (selfModelFieldSpecValid
   (quote (SelfModelFieldSpec energy physiological normalized 0 1 2))) False)

;; Every legacy default has exactly one destination and is excluded from S.
!(test (filter-atom
   (collapse (match &self (LegacySelfMetricClass $name $_ $_) $name)) $name
   (or (!= (size-atom (collapse (match &self
      (LegacySelfMetricClass $name $destination $meaning)
      ($destination $meaning)))) 1)
      (selfModelMetricValid (self-metric $name 0.5)))) ())

!(test (collapse (match &self
   (LegacySelfMetricClass memory_confidence $destination $meaning)
   ($destination $meaning))) ((adjudicated-claim memory-reliability)))

;; Ambiguous declarations reject; inspection never mutates the current S store.
!(bind! &r31-self-before (new-state (getSelfModel)))
!(add-atom &self (SelfModelFieldSpec energy motivational normalized 0 1 0.5))

!(test (selfModelFieldSpec energy) (SelfModelFieldRejected InvalidFieldSpec))

!(test (selfModelMetricValid (quote (self-metric energy 0.5))) False)
!(remove-atom &self (SelfModelFieldSpec energy motivational normalized 0 1 0.5))

!(test (selfModelMetricValid (quote (self-metric energy
   (change-state! &failure-streak 99)))) False)

!(test (get-state &failure-streak) 0)

!(test (getSelfModel) (get-state &r31-self-before))

;; R2 / 2.4: typed readers distinguish false, absence, quantities and scores.
!(fixturePutSignal failure (quote (BooleanFact False)))
!(test (signalFact failure) (fixtureSignalFact failure (quote (BooleanFact False))))
!(test (signalTrue failure) False)
!(test (hasErrors) False)
!(test (hasResults) False)
!(test (signalFact danger) (FactualSignalAbsent danger))
!(test (signalRatioAtLeast danger 0.0) False)
!(test (signalProvenance danger) ())
!(test (signalProvenance failure) (quote ((SessionObservationRef "typed-signal-fixture" 0))))
!(fixturePutSignal failure (quote (BooleanFact True)))
!(test (signalTrue failure) True)
!(test (hasErrors) True)
!(test (size-atom (getSignals)) 1)
!(fixturePutSignal failure (quote (BooleanFact False)))
!(test (signalTrue failure) False)
!(test (size-atom (getSignals)) 1)
!(fixturePutSignal progress-made (quote (BooleanFact False)))
!(test (hasResults) False)
!(fixturePutSignal progress-made (quote (BooleanFact True)))
!(test (hasResults) True)
!(fixturePutSignal danger (quote (RatioFact 0.4 classifier-score)))
!(test (signalTrue danger) False)
!(test (signalRatioAtLeast danger 0.4) True)
!(test (signalRatioAtLeast danger 0.401) False)
!(test (signalRatioAtLeast danger -0.1) False)
!(test (signalRatioAtLeast danger 1.1) False)
!(test (signalRatioAtLeast danger "0.4") False)
!(test (signalRatioAtLeast failure 0) False)
!(test (signalRatioAtLeastIn (getSignals) danger count 0.4) False)
!(fixturePutSignal failure-streak (quote (QuantityFact 2 count)))
!(test (signalQuantityAtLeast failure-streak count 2) True)
!(test (signalQuantityAtLeast failure-streak count 3) False)
!(test (signalQuantityAtLeast failure-streak milliseconds 2) False)
!(test (signalQuantityAtLeast failure-streak count 1.5) False)
!(test (signalQuantityAtLeast failure-streak count -1) False)
!(test (signalQuantityAtLeast missing count 0) False)
!(test (signalQuantityAtLeast danger count 0) False)

;; Invalid or duplicate records never turn into a positive factual predicate.
!(bind! &r24-duplicate (new-state
   ((fixtureSignalFact failure (quote (BooleanFact True)))
    (fixtureSignalFact failure (quote (BooleanFact False))))))
!(test (signalFactIn (get-state &r24-duplicate) failure)
   (FactualSignalRejected DuplicateSignalKind))
!(test (signalTrueIn (get-state &r24-duplicate) failure) False)
!(test (signalProvenanceIn (get-state &r24-duplicate) failure) ())
!(test (signalTrueIn (quote ((signal failure 0.8))) failure) False)
!(test (signalTrueIn (quote ((FactualSignal (kind failure)
   (value (BooleanFact (change-state! &failure-streak 99)))
   (provenance ((SessionObservationRef "typed-signal-fixture" 0)))))) failure) False)
!(test (get-state &failure-streak) 0)
!(clearSignals)

;; R5 / 3.2: initialization uses the validated allowlist, never legacy defaults.
!(test (initializeSelfModel) SelfModelInitialized)

!(test (getSelfModel)
   ((self-metric energy 1.0) (self-metric fatigue 0.0) (self-metric urgency 0.5)))

!(replaceSelfMetric energy 0.7)
!(bind! &r32-initial (new-state (getSelfModel)))

;; Every retired field rejects through the actual writer without changing S.
!(test (filter-atom
   (collapse (match &self (LegacySelfMetricClass $name $_ $_) $name)) $name
   (!= (replaceSelfMetric $name 0.9) (SelfModelRejected InvalidMetric))) ())

!(test (replaceSelfMetric capabilities 0.9) (SelfModelRejected InvalidMetric))

!(test (replaceSelfMetric knowledge 0.9) (SelfModelRejected InvalidMetric))

!(test (replaceSelfMetric beliefs 0.9) (SelfModelRejected InvalidMetric))

!(test (replaceSelfMetric energy -0.1) (SelfModelRejected InvalidMetric))

!(test (replaceSelfMetric energy 1.1) (SelfModelRejected InvalidMetric))

!(test (replaceSelfMetric energy "0.5") (SelfModelRejected InvalidMetric))

!(test (replaceSelfMetric energy True) (SelfModelRejected InvalidMetric))

!(test (replaceSelfMetric energy
   (py-call (provider_helpers_fixture.numeric_anomaly "nan"))) (SelfModelRejected InvalidMetric))

!(test (replaceSelfMetric energy
   (py-call (provider_helpers_fixture.numeric_anomaly "inf"))) (SelfModelRejected InvalidMetric))

!(test (replaceSelfMetric energy (quote (change-state! &failure-streak 99)))
   (SelfModelRejected InvalidMetric))

!(test (replaceSelfMetric energy (quote $unknown)) (SelfModelRejected InvalidMetric))

!(test (getSelfModel) (get-state &r32-initial))

!(test (get-state &failure-streak) 0)

;; Invalid initialization preserves S and the other motivational spaces as well.
!(bind! &r32-goals (new-state (getGoals)))
!(bind! &r32-mods (new-state (getModulators)))
!(add-atom &self (SelfModelFieldSpec energy physiological normalized 0 1 0.5))

!(test (initializeSelfModel) (SelfModelRejected InvalidSchema))

!(test (initOmegaClawMotivation) (SelfModelRejected InvalidSchema))

!(test (motivatedOmegaclaw) (SelfModelRejected InvalidSchema))

!(test (getSelfModel) (get-state &r32-initial))

!(test (getGoals) (get-state &r32-goals))

!(test (getModulators) (get-state &r32-mods))
!(remove-atom &self (SelfModelFieldSpec energy physiological normalized 0 1 0.5))
!(add-atom &self (SelfModelFieldSpec capabilities cognitive normalized 0 1 0.5))

!(test (initializeSelfModel) (SelfModelRejected InvalidSchema))
!(remove-atom &self (SelfModelFieldSpec capabilities cognitive normalized 0 1 0.5))

;; Absence is not zero: old rule dependencies remain inactive pending 3.3.
!(test (selfMetricCondition memory_confidence below 0.2) False)

!(test (evalCondition () self-metric-below memory_confidence 0.45) False)

!(test (homeostaticRuleTriggered self-metric-below success_rate 0.15) False)

!(test (selfMetricCondition fatigue below 0.2) True)

!(runHomeostasis)
!(test (getGoals) (get-state &r32-goals))

!(test (getModulators) (get-state &r32-mods))

;; Both observed outcomes keep performance counts outside the persisted S schema.
!(bind! &r32-cycles (new-state (get-state &cycle-count)))
!(bind! &r32-successes (new-state (get-state &success-count)))
!(bind! &r32-failures (new-state (get-state &failure-count)))
!(updateSelfModel False True)
!(updateSelfModel True False)

!(test (get-state &cycle-count) (+ (get-state &r32-cycles) 2))

!(test (get-state &success-count) (+ (get-state &r32-successes) 1))

!(test (get-state &failure-count) (+ (get-state &r32-failures) 1))

!(test (selfModelMetricsValid (getSelfModel)) True)

!(test (fetchSelfMetricValue energy) 0.7)

!(test (fetchSelfMetricValue fatigue) 0.0)

!(test (fetchSelfMetricValue urgency) (extractModulatorValue urgency))

;; Invalid S rejects the whole snapshot before any otherwise valid G/AG/M write.
!(bind! &r32-before-restore (new-state (getSelfModel)))
!(bind! &r32-antigoals (new-state (getAntiGoals)))
!(change-state! &helper-memory
   "MOTIVOS_STATE_V1 time:today G:((goal progress 0.9)) AG:((anti-goal harm 0.1)) M:((modulator urgency 0.9)) S:((self-metric energy 0.2) (self-metric memory_confidence 0.9))")

!(test (restoreMotivationalState) (SelfModelRejected InvalidSnapshot))

!(test (getSelfModel) (get-state &r32-before-restore))

!(test (getGoals) (get-state &r32-goals))

!(test (getAntiGoals) (get-state &r32-antigoals))

!(test (getModulators) (get-state &r32-mods))

!(test (restoreParsedMotivationalState
   (quote ((goal progress 0.9) (self-metric energy 0.2) (self-metric energy 0.8))))
   (SelfModelRejected InvalidSnapshot))

!(test (restoreParsedMotivationalState
   (quote ((goal progress 0.9) (self-metric energy 0.2 extra))))
   (SelfModelRejected InvalidSnapshot))

!(test (restoreParsedMotivationalState
   (quote ((goal progress 0.9) (self-metric energy (change-state! &failure-streak 99)))))
   (SelfModelRejected InvalidSnapshot))

!(test (selfModelMetricsValid (quote ((self-metric energy 0.5) invalid))) False)

!(test (selfModelMetricsValid (quote ((self-metric energy $unknown)))) False)

!(test (get-state &failure-streak) 0)

!(test (getSelfModel) (get-state &r32-before-restore))

!(test (getGoals) (get-state &r32-goals))

;; Real parser and application restore accept declared fields; save round-trips S.
!(change-state! &helper-memory
   "MOTIVOS_STATE_V1 time:today G:((goal progress 0.6)) AG:((anti-goal harm 0.7)) M:((modulator urgency 0.4)) S:((self-metric energy 0.8) (self-metric fatigue 0.1) (self-metric urgency 0.3))")

!(test (restoreMotivationalState) MotivationalStateRestored)

!(test (fetchSelfMetricValue energy) 0.8)

!(test (fetchSelfMetricValue fatigue) 0.1)

!(test (fetchSelfMetricValue urgency) 0.3)

!(test (getGoals) ((goal progress 0.6)))

!(test (getAntiGoals) ((anti-goal harm 0.7)))

!(test (getModulators) ((modulator urgency 0.4)))
!(saveMotivationalState)
!(initializeSelfModel)
!(restoreMotivationalState)

!(test (selfModelMetricsValid (getSelfModel)) True)

!(test (fetchSelfMetricValue energy) 0.8)

;; The production initializer installs the same S schema alongside goals/modulators.
!(initOmegaClawMotivation)

!(test (getSelfModel)
   ((self-metric energy 1.0) (self-metric fatigue 0.0) (self-metric urgency 0.5)))

;; R5 / 3.3: live rules depend on facts or motivational preferences, never legacy S.
;; Example: volatile floating-point corrections are compared within 1e-9.
(= (r33Near $actual $expected)
   (and (> $actual (- $expected 0.000000001))
        (< $actual (+ $expected 0.000000001))))

!(bind! &r33-legacy (new-state
   (collapse (match &self (LegacySelfMetricClass $name $_ $_) $name))))

!(test (filter-atom (collapse (match &self
   (CandidateCondition $candidate $type $name $threshold) $name)) $name
   (fsContains (get-state &r33-legacy) $name)) ())

!(test (filter-atom (collapse (match &self
   (CandidateConditionAny $candidate $type $name $threshold) $name)) $name
   (fsContains (get-state &r33-legacy) $name)) ())

!(test (filter-atom (collapse (match &self
   (HomeostaticRule $type $name $threshold $action $target $delta) $name)) $name
   (fsContains (get-state &r33-legacy) $name)) ())

!(bind! &r33-self (new-state (getSelfModel)))
!(clearSignals)
!(clearSpace &appraisal-space)

!(test (homeostaticRuleTriggered signal-true repeated-failure IsTrue) False)

!(fixturePutSignal repeated-failure (quote (BooleanFact False)))

!(test (evalCondition () signal-true repeated-failure IsTrue) False)

!(test (homeostaticRuleTriggered signal-true repeated-failure IsTrue) False)

!(fixturePutSignal repeated-failure (quote (BooleanFact True)))
!(fixturePutSignal failure-streak (quote (QuantityFact 2 count)))

!(test (evalCondition () signal-true repeated-failure IsTrue) True)

!(test (registryCandidateAvailable () self-improve) True)

;; The ordinary repeated-failure appraisal still blocks reflection while risk is high.
!(computeAllDimensions)

!(test (registryCandidateAvailable () self-improve) False)
!(clearSpace &appraisal-space)

!(test (homeostaticRuleTriggered signal-true repeated-failure IsTrue) True)

!(test (homeostaticRuleTriggered signal-true repeated-failure 0.8) False)

;; Recovery corrections use current boolean truth; no success probability is inferred.
!(replaceModulator context_depth 0.5)
!(replaceModulator caution 0.2)
!(replaceModulator securing 0.3)
!(replaceGoal gTrans_over 0.4)
!(runHomeostasis)

!(test (extractModulatorValue caution) 0.4)

!(test (r33Near (extractGoalValue gTrans_over) 0.35) True)

;; Explicit False stops the correction; a duplicate record never supplies evidence.
!(fixturePutSignal repeated-failure (quote (BooleanFact False)))
!(runHomeostasis)

!(test (extractModulatorValue caution) 0.4)

!(add-atom &signal-space (fixtureSignalFact repeated-failure (quote (BooleanFact True))))

!(test (homeostaticRuleTriggered signal-true repeated-failure IsTrue) False)

!(test (evalCondition () signal-true repeated-failure IsTrue) False)
!(clearSignals)

;; The old identity proxy's threshold becomes an explicit count: 7 fails, 8 matches.
!(fixturePutSignal failure-streak (quote (QuantityFact 7 count)))

!(test (homeostaticRuleTriggered signal-count-at-least failure-streak 8) False)

!(fixturePutSignal failure-streak (quote (QuantityFact 8 count)))

!(test (homeostaticRuleTriggered signal-count-at-least failure-streak 8) True)

!(test (homeostaticRuleTriggered signal-count-at-least failure-streak 7.5) False)

!(replaceGoal gInd_over 0.7)
!(runHomeostasis)

!(test (extractGoalValue gInd_over) 0.75)

!(test (extractModulatorValue securing) 0.4)
!(clearSignals)
!(add-atom &signal-space (quote (FactualSignal (kind failure-streak)
   (value (QuantityFact 8 seconds))
   (provenance ((SessionObservationRef "typed-signal-fixture" 0))))))

!(test (homeostaticRuleTriggered signal-count-at-least failure-streak 8) False)
!(clearSpace &appraisal-space)

!(test (registryCandidateAvailable () self-improve) False)
!(clearSignals)

;; Recall follows demand for deeper context; planning follows focus, not memory trust.
!(bind! &r33-idle (new-state (quote (FrameStateBundle
   (root ()) (current ()) (index () ()) (relations ())
   (runtime (FrameStateRuntime (task-open False)))))))
!(replaceModulator context_depth 0.55)
!(replaceModulator focus 0.55)

!(test (registryCandidateAvailable (get-state &r33-idle) recall-goals) False)

!(test (registryCandidateAvailable (get-state &r33-idle) plan-goal) False)
!(replaceModulator context_depth 0.9)
!(replaceModulator focus 0.9)

!(test (registryCandidateAvailable (get-state &r33-idle) recall-goals) True)

!(test (registryCandidateAvailable (get-state &r33-idle) plan-goal) True)

!(replaceModulator threshold 0.4)
!(replaceModulator persistence 0.5)
!(runHomeostasis)

!(test (r33Near (extractModulatorValue threshold) 0.6) True)

!(test (r33Near (extractModulatorValue persistence) 0.35) True)

;; Invalid, missing or ambiguous motivational values cannot trigger preferences.
!(test (modulatorCondition absent below 0.5) False)

!(test (modulatorCondition context_depth above "0.5") False)
!(add-atom &motivation-space (modulator context_depth 0.1))

!(test (homeostaticRuleTriggered modulator-exceeds context_depth 0.8) False)

!(test (registryCandidateAvailable (get-state &r33-idle) recall-goals) False)
!(remove-atom &motivation-space (modulator context_depth 0.1))

!(test (getSelfModel) (get-state &r33-self))

!(test (replaceSelfMetric memory_confidence 0.9) (SelfModelRejected InvalidMetric))

!(test (homeostaticRuleTriggered unsupported memory_confidence 0.2) False)

!(test (getSelfModel) (get-state &r33-self))

;; R6 / 3.4: every existing rule resolves to one declared regulated variable/target.
!(test (size-atom (collapse (match &self
   (HomeostaticTarget $kind $name $unit $point) ($kind $name)))) 8)

!(test (filter-atom (collapse (match &self
   (HomeostaticRule $_ $_ $_ $action $name $_) ($action $name))) $row
   (let* (
      (($action $name) $row)
      ((HomeostaticAction $kind $_) (homeostaticActionSpec $action))
   ) (case (homeostaticTarget $kind $name) (
      ((HomeostaticTarget $_ $_ normalized (set-point $_)) False)
      ($_ True))))) ())

;; All four action kinds stop at their set-point and never pull back from beyond it.
!(replaceModulator caution 0.74)
!(applyHomeostaticAction raise-modulator caution 0.2)

!(test (extractModulatorValue caution) 0.75)

!(test (applyHomeostaticAction raise-modulator caution 0.2)
   (HomeostaticCorrection (variable modulator caution)
      (from 0.75) (to 0.75) (set-point 0.75)))
!(replaceModulator caution 0.9)
!(applyHomeostaticAction raise-modulator caution 0.2)

!(test (extractModulatorValue caution) 0.9)
!(replaceModulator arousal 0.31)
!(applyHomeostaticAction lower-modulator arousal 0.2)

!(test (extractModulatorValue arousal) 0.3)
!(replaceModulator arousal 0.1)
!(applyHomeostaticAction lower-modulator arousal 0.2)

!(test (extractModulatorValue arousal) 0.1)
!(replaceGoal gInd_over 0.84)
!(applyHomeostaticAction raise-goal gInd_over 0.05)

!(test (extractGoalValue gInd_over) 0.85)
!(replaceGoal gInd_over 0.9)
!(applyHomeostaticAction raise-goal gInd_over 0.05)

!(test (extractGoalValue gInd_over) 0.9)
!(replaceGoal gTrans_over 0.31)
!(applyHomeostaticAction lower-goal gTrans_over 0.05)

!(test (extractGoalValue gTrans_over) 0.3)
!(replaceGoal gTrans_over 0.2)
!(applyHomeostaticAction lower-goal gTrans_over 0.05)

!(test (extractGoalValue gTrans_over) 0.2)

;; Target edits are registry data; malformed or ambiguous declarations preserve values.
!(replaceModulator caution 0.6)
!(remove-atom &self (HomeostaticTarget modulator caution normalized (set-point 0.75)))

!(test (applyHomeostaticAction raise-modulator caution 0.2)
   (HomeostasisRejected UndeclaredTarget))

!(test (extractModulatorValue caution) 0.6)
!(add-atom &self (HomeostaticTarget modulator caution normalized (set-point 0.65)))
!(applyHomeostaticAction raise-modulator caution 0.2)

!(test (extractModulatorValue caution) 0.65)
!(add-atom &self (HomeostaticTarget modulator caution normalized (set-point 0.75)))

!(test (applyHomeostaticAction raise-modulator caution 0.2)
   (HomeostasisRejected InvalidTarget))
!(remove-atom &self (HomeostaticTarget modulator caution normalized (set-point 0.65)))
!(add-atom &self (ModulatorSpec caution 0.4))

!(test (homeostaticTarget modulator caution) (HomeostasisRejected InvalidTarget))
!(remove-atom &self (ModulatorSpec caution 0.4))

!(test (applyHomeostaticAction raise-goal caution 0.2)
   (HomeostasisRejected UndeclaredTarget))

!(test (applyHomeostaticAction raise-modulator capabilities 0.2)
   (HomeostasisRejected UndeclaredTarget))
!(add-atom &self (HomeostaticTarget modulator capabilities normalized (set-point 0.5)))

!(test (homeostaticTarget modulator capabilities) (HomeostasisRejected InvalidTarget))
!(remove-atom &self (HomeostaticTarget modulator capabilities normalized (set-point 0.5)))
!(add-atom &self (HomeostaticTarget goal help_user normalized (set-point 2)))

!(test (homeostaticTarget goal help_user) (HomeostasisRejected InvalidTarget))
!(remove-atom &self (HomeostaticTarget goal help_user normalized (set-point 2)))
!(add-atom &self (HomeostaticTarget goal help_user seconds (set-point 0.5)))

!(test (homeostaticTarget goal help_user) (HomeostasisRejected InvalidTarget))
!(remove-atom &self (HomeostaticTarget goal help_user seconds (set-point 0.5)))
!(add-atom &self (HomeostaticTarget goal help_user normalized
   (set-point (py-call (provider_helpers_fixture.numeric_anomaly "nan")))))

!(test (homeostaticTarget goal help_user) (HomeostasisRejected InvalidTarget))
!(collapse (let $row (match &self (HomeostaticTarget goal help_user $unit $point)
   (HomeostaticTarget goal help_user $unit $point)) (remove-atom &self $row)))

;; Reject invalid steps/current values; helpers cannot bypass the declared point.
!(test (applyHomeostaticAction raise-modulator caution -0.2) (HomeostasisRejected InvalidStep))

!(test (applyHomeostaticAction raise-modulator caution 0) (HomeostasisRejected InvalidStep))

!(test (applyHomeostaticAction raise-modulator caution "0.2") (HomeostasisRejected InvalidStep))

!(test (applyHomeostaticAction raise-modulator caution 2) (HomeostasisRejected InvalidStep))

!(test (applyHomeostaticAction raise-modulator caution
   (py-call (provider_helpers_fixture.numeric_anomaly "nan"))) (HomeostasisRejected InvalidStep))

!(test (applyHomeostaticAction raise-modulator caution
   (py-call (provider_helpers_fixture.numeric_anomaly "inf"))) (HomeostasisRejected InvalidStep))

!(test (applyHomeostaticAction unsupported caution 0.2) (HomeostasisRejected UnsupportedAction))

!(test (applyHomeostaticCorrection modulator raise caution 1 0.2)
   (HomeostasisRejected InvalidCorrection))

!(test (applyDeclaredHomeostaticAction raise-modulator caution -0.2)
   (HomeostasisRejected InvalidCorrection))

!(test (extractModulatorValue caution) 0.65)
!(add-atom &motivation-space (modulator caution 0.1))

!(test (applyHomeostaticAction raise-modulator caution 0.2)
   (HomeostasisRejected InvalidCurrentValue))
!(remove-atom &motivation-space (modulator caution 0.1))
!(remove-atom &motivation-space (modulator caution 0.65))

!(test (applyHomeostaticAction raise-modulator caution 0.2)
   (HomeostasisRejected InvalidCurrentValue))
!(replaceModulator caution 1.1)

!(test (applyHomeostaticAction raise-modulator caution 0.2)
   (HomeostasisRejected InvalidCurrentValue))

;; Colliding rules share the same destinations, even across repeated live sweeps.
!(initOmegaClawMotivation)
!(clearSignals)
!(fixturePutSignal repeated-failure (quote (BooleanFact True)))
!(fixturePutSignal failure-streak (quote (QuantityFact 8 count)))
!(replaceModulator securing 0.9)
!(replaceModulator context_depth 0.9)
!(bind! &r34-self (new-state (getSelfModel)))
!(map-atom (1 2 3 4 5 6 7 8 9 10) $cycle (runHomeostasis))

!(test (extractModulatorValue threshold) 0.75)

!(test (extractModulatorValue arousal) 0.3)

!(test (extractModulatorValue exploration_bias) 0.2)

!(test (extractModulatorValue persistence) 0.35)

!(test (extractModulatorValue caution) 0.75)

!(test (extractModulatorValue securing) 0.9)

!(test (extractGoalValue gTrans_over) 0.3)

!(test (extractGoalValue gInd_over) 0.85)

!(test (filter-atom (lastHomeostaticCorrections) $row
   (case $row (
      ((HomeostaticRuleResult $_ (HomeostaticCorrection
         (variable $kind $name) $_ $_ (set-point $point)))
         (!= (homeostaticTarget $kind $name)
             (HomeostaticTarget $kind $name normalized (set-point $point))))
      ($_ True)))) ())

!(test (getSelfModel) (get-state &r34-self))
!(initOmegaClawMotivation)

!(test (lastHomeostaticCorrections) ())
!(clearSignals)
