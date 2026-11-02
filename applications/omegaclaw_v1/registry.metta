
;; R2: producer facts and classifier estimates have no motivational intensities.
;; Classifier scores report a model estimate, never execution or permission.
(FactualSignalSpec failure Boolean None observation)
(FactualSignalSpec repeated-failure Boolean None observation)
(FactualSignalSpec progress-made Boolean None observation)
(FactualSignalSpec stalled-progress Boolean None observation)
(FactualSignalSpec user-waiting Boolean None observation)
(FactualSignalSpec message-differs-from-task Boolean None observation)
(FactualSignalSpec new-input-without-outcome Boolean None observation)
(FactualSignalSpec verified-success Boolean None observation)
(FactualSignalSpec frame-blocked Boolean None observation)
(FactualSignalSpec failure-streak Quantity count observation)
(FactualSignalSpec danger Ratio classifier-score estimate)
(FactualSignalSpec user-angry Ratio classifier-score estimate)
(FactualSignalSpec execution-request Ratio classifier-score estimate)

;; Numeric domains are factual units/ranges, not motivational coefficients.
(FactualSignalRange failure-streak 0 9007199254740991)
(FactualSignalRange danger 0 1)
(FactualSignalRange user-angry 0 1)
(FactualSignalRange execution-request 0 1)


;; Semantic and confirmation classifiers support one request estimate per input.
(SignalReduction execution-request maximum)

(MotiveSpec clarity 0.45)
(MotiveSpec progress 0.55)
(MotiveSpec reliability 0.50)
(MotiveSpec adaptivity 0.40)
(MotiveSpec coherence 0.45)
(MotiveSpec responsiveness 0.45)

;; Constitutional MVP mode set. This is separate from ContextFrames Fast/Slow
;; frame mode and from operation directives such as execute or verify.
(ConstitutionalMode Engaged)
(ConstitutionalMode Threat)
(ConstitutionalMode Rumination)
(ConstitutionalMode Sleep)
(ConstitutionalModeDefault Engaged)

;; Boolean triggers read truth; ratio thresholds use classifier-score units.
;; Entry/exit comparisons are inclusive and independent of appraisal weights.
(ModeRatioTrigger threat danger classifier-score 0.0 0.0)
(ModeRatioTrigger threat user-angry classifier-score 0.0 0.0)
(ModeFactTrigger recovery failure IsTrue)
(ModeFactTrigger recovery repeated-failure IsTrue)
(ModeFactTrigger recovery stalled-progress IsTrue)
(ModeFactTrigger wake user-waiting IsTrue)
(ModeRatioTrigger wake execution-request classifier-score 0.0 0.0)
(ModeContextTrigger wake frame-present)
(ModeContextTrigger sleep frame-absent)

;; Constitutional transition collisions, distinct from SchedulingPriority.
;; Greater priority wins; declaration order breaks equal-priority ties.
(ModeTransitionRule threat Threat 40)
(ModeTransitionRule recovery Rumination 30)
(ModeTransitionRule wake Engaged 20)
(ModeTransitionRule sleep Sleep 10)

;; mode, consecutive entry evaluations, minimum held evaluations, cooldown.
;; These count motivation-cycle refreshes, not wall-clock time or Core wakes.
(ModeTransitionParameters Engaged 1 0 0)
(ModeTransitionParameters Threat 1 0 0)
(ModeTransitionParameters Rumination 1 0 0)
(ModeTransitionParameters Sleep 1 0 0)
;; More urgent targets can bypass hold/cooldown, but still require entry evidence.
(ModeTransitionOption urgent-bypass True)

;; Scheduling priority classes, highest first. These are neither
;; constitutional modes nor ContextFrames Fast/Slow execution modes.
(SchedulingPriority Threat-remediation 7)
(SchedulingPriority Recovery 6)
(SchedulingPriority Interactive 5)
(SchedulingPriority Orienting 4)
(SchedulingPriority Engaged 3)
(SchedulingPriority Rumination 2)
(SchedulingPriority Sleep 1)

;; Candidate availability and policy admission run before scheduling.
(CandidateSchedulingPriority repair-failure Recovery)
(CandidateSchedulingPriority respond Interactive)
(CandidateSchedulingPriority ask-clarification Interactive)
(CandidateSchedulingPriority retrieve-memory Orienting)
(CandidateSchedulingPriority search-knowledge Orienting)
(CandidateSchedulingPriority verify-frame-state Orienting)
(CandidateSchedulingPriority recall-goals Orienting)
(CandidateSchedulingPriority execute-skill Engaged)
(CandidateSchedulingPriority learn Engaged)
(CandidateSchedulingPriority background-work Engaged)
(CandidateSchedulingPriority invent-goal Engaged)
(CandidateSchedulingPriority plan-goal Engaged)
(CandidateSchedulingPriority self-improve Rumination)
(CandidateSchedulingPriority defer Sleep)

;; Maximum tracked review frames, hints per cycle, initial/repeat delay.
(FrameResurfacingPolicy 128 2 3)
(CandidateSchedulingPriority none Sleep)

;; Elevate only explicit remediation work when existing threat signals fire.
;; Being safety-typed, or running in constitutional Threat, is not sufficient.
(SchedulingPromotion verify-frame-state threat Threat-remediation)
(SchedulingPromotion defer threat Threat-remediation)
(SchedulingPromotion ask-clarification threat Threat-remediation)
(SchedulingPromotion self-improve recovery Recovery)

(ModulatorSpec urgency 0.50)
(ModulatorSpec caution 0.50)
(ModulatorSpec persistence 0.55)
(ModulatorSpec exploration_bias 0.40)
(ModulatorSpec context_depth 0.50)
(ModulatorSpec human_deference 0.40)
(ModulatorSpec arousal 0.50)
(ModulatorSpec valence 0.50)
(ModulatorSpec threshold 0.40)
(ModulatorSpec securing 0.30)
(ModulatorSpec focus 0.55)


;; SCORE WEIGHTS
;; (ScoreWeight <motive> <modulator> <sign>)
;;   sign = 1.0  → modulator adds to motive score
;;   sign = -1.0 → modulator subtracts
(ScoreWeight clarity         context_depth     1.0)
(ScoreWeight clarity         caution           1.0)
(ScoreWeight progress        urgency           1.0)
(ScoreWeight progress        persistence       1.0)
(ScoreWeight reliability     caution           1.0)
(ScoreWeight reliability     human_deference   1.0)
(ScoreWeight adaptivity      exploration_bias  1.0)
(ScoreWeight adaptivity      persistence      -1.0)
(ScoreWeight coherence       context_depth     1.0)
(ScoreWeight coherence       human_deference   1.0)
(ScoreWeight responsiveness  urgency           1.0)
(ScoreWeight responsiveness  human_deference   1.0)


;; DECISION MAPPINGS
;; (DecisionMap <motive> <mode> <directive>)
(DecisionMap clarity         orient   inspect)
(DecisionMap progress        execute  execute)
(DecisionMap reliability     verify   verify)
(DecisionMap adaptivity      recover  recover)
(DecisionMap coherence       orient   inspect)
(DecisionMap responsiveness  execute  execute)


;; SIGNAL EFFECTS
;; Retired unused SignalEffect/SignalMode and compatibility SignalStrength rows.
;; Appraisal evaluation is declared solely through SignalAppraisalRule below.

;; DIRECTIVE GUIDANCE TEXT
;; (DirectiveText <directive> <guidance-string>)
(DirectiveText inspect  "Inspect first. Prefer reading, querying, and narrowing the problem before broader action.")
(DirectiveText verify   "Verify first. Check consistency and avoid making multiple changes before confidence improves.")
(DirectiveText recover  "FORMAT ERROR RECOVERY: Output a valid MeTTa s-expression list. Example: ((send \"Hello\")). Do not output conversational text outside the expression.")
(DirectiveText execute  "Execute normally. Advance the task directly while respecting current motivation state.")

;; GOAL VECTOR

;; (GoalSpec <name> <baseline>)
;; Core over-arching and domain goals
(GoalSpec gInd_over      0.70)
(GoalSpec gTrans_over    0.40)
(GoalSpec help_user      0.60)
(GoalSpec learn          0.45)
(GoalSpec cooperate      0.50)

;; Derived domain goals referenced by CandidateGoalAlignment.
;; Without these entries fetchGoalOrMotiveValue returns 0.0, silently
;; zeroing out goal-alignment contributions for affected candidates.
(GoalSpec responsiveness 0.60) ;; timely, useful replies
(GoalSpec clarity        0.55) ;; accurate, unambiguous output
(GoalSpec coherence      0.50) ;; internal logical consistency
(GoalSpec reliability    0.60) ;; safe, predictable behaviour
(GoalSpec progress       0.50) ;; task-completion momentum
(GoalSpec adaptivity     0.45) ;; ability to self-adjust

;; Anti-goals: penalty weight applied to candidates that raise these risks.
;; (AntiGoalSpec <name> <penalty-weight>)
(AntiGoalSpec risk          0.10)
(AntiGoalSpec contradiction 0.10)
(AntiGoalSpec unsafe        0.05)

;;  GOAL FLOORS (MetaMo Identity Preservation) 
;; (GoalFloor <goal-name> <minimum-value>)
(GoalFloor gInd_over   0.55)
(GoalFloor gTrans_over 0.15)

;; GOAL EVOLUTION BOUNDS
(AlphaBound min 0.01)
(AlphaBound max 0.15)

;; GOAL DELTA WEIGHTS (Appraisal-Driven Goal Proposals)
;; (GoalDeltaWeight <goal-name> <appraisal-dim> <scale>)

(GoalDeltaWeight gInd_over    risk         0.12)
(GoalDeltaWeight gTrans_over  opportunity  0.10)
(GoalDeltaWeight gTrans_over  risk        -0.05)
(GoalDeltaWeight help_user    progress     0.06)
(GoalDeltaWeight help_user    risk        -0.03)
(GoalDeltaWeight learn        novelty      0.05)
(GoalDeltaWeight learn        uncertainty  0.05)
(GoalDeltaWeight cooperate    progress     0.04)

;; CANDIDATE DELTA-G (MetaMo Action-Driven Goal Updates)
;; (CandidateDeltaG <candidate> <goal-name> <delta>)
(CandidateDeltaG respond           help_user    0.04)
(CandidateDeltaG respond           cooperate    0.02)
(CandidateDeltaG retrieve-memory   learn        0.03)
(CandidateDeltaG search-knowledge  learn        0.03)
(CandidateDeltaG search-knowledge  gTrans_over  0.01)
(CandidateDeltaG execute-skill     help_user    0.05)
(CandidateDeltaG execute-skill     gTrans_over  0.02)
(CandidateDeltaG learn             learn        0.06)
(CandidateDeltaG learn             gTrans_over  0.04)
(CandidateDeltaG self-improve      gTrans_over  0.05)
(CandidateDeltaG self-improve      learn        0.04)
(CandidateDeltaG background-work   learn        0.02)
(CandidateDeltaG background-work   progress     0.02)
(CandidateDeltaG recall-goals      clarity      0.02)
(CandidateDeltaG recall-goals      coherence    0.02)
(CandidateDeltaG invent-goal       learn        0.04)
(CandidateDeltaG invent-goal       gTrans_over  0.03)
(CandidateDeltaG plan-goal         progress     0.04)
(CandidateDeltaG plan-goal         coherence    0.02)
(CandidateDeltaG repair-failure    reliability  0.04)
(CandidateDeltaG repair-failure    adaptivity   0.03)
(CandidateDeltaG defer             gInd_over    0.03)
(CandidateDeltaG verify-frame-state reliability 0.03)
(CandidateDeltaG ask-clarification gInd_over    0.02)
(CandidateDeltaG ask-clarification help_user    0.02)


;;  ANTI-SATURATION CONFIG
;; (AntiSaturation <key> <value>)
;; Replaces hardcoded constants in decision.metta.
(AntiSaturation threshold 2)    ;; consecutive safety wins before penalty kicks in
(AntiSaturation step      0.10) ;; penalty increment per extra win
(AntiSaturation max       0.50) ;; max penalty — enough to push score-1.0 safety below respond (~0.6)


;; DYNAMICS CONFIG
;; (DynamicsConfig <key> <value>)
;; Replaces hardcoded decay and EMA constants.
(DynamicsConfig decay_rate        0.15)
(DynamicsConfig self_model_alpha  0.20)
(DynamicsConfig persistence_interval 10)
(DynamicsConfig autonomy_actions_before_refresh 2)

;; Seed thresholds: initial trigger values are registry data, not algorithm
;; constants. Runtime adaptation may change the effective values later.
(SeedThreshold execution_opportunity_threshold 0.75)
(SeedThreshold execution_intent_threshold      0.50)
(SeedThreshold execution_risk_limit           0.45)
(SeedThreshold execution_uncertainty_limit    0.65)
(SeedThreshold execution_caution_limit        0.75)


;; CANDIDATE CONDITIONS
;; (CandidateCondition <candidate> <condition-type> <param> <threshold>)

(CandidateCondition respond           task-active       _                _    )
(CandidateCondition respond           appraisal-below   opportunity     0.50 )
(CandidateCondition retrieve-memory   task-active       _                _    )
(CandidateCondition search-knowledge  task-active       _                _    )
(CandidateCondition defer             task-active       _                _    )
(CandidateCondition ask-clarification task-active       _                _    )
(CandidateCondition ask-clarification appraisal-below   opportunity     0.50 )
(CandidateCondition execute-skill     task-active       _                _    )
(CandidateCondition execute-skill     appraisal-above   opportunity     0.50 )
(CandidateCondition execute-skill     appraisal-below   risk            0.45 )
(CandidateCondition execute-skill     appraisal-below   uncertainty     0.65 )
;; learn uses OR semantics: either novelty > 0.50 OR exploration_bias > 0.50 is enough.
(CandidateCondition learn             task-active       _                _    )
(CandidateConditionAny learn             appraisal-above   novelty          0.50 )
(CandidateConditionAny learn             modulator-above   exploration_bias 0.50 )
(CandidateCondition self-improve      self-metric-above failure_rate     0.35 )
(CandidateCondition self-improve      appraisal-below   risk             0.65 )
(CandidateCondition background-work   task-inactive     _                _    )
(CandidateCondition recall-goals      task-inactive     _                _    )
(CandidateConditionAny recall-goals   self-metric-below memory_confidence 0.45 )
(CandidateCondition invent-goal       task-inactive     _                _    )
(CandidateCondition plan-goal         task-inactive     _                _    )
(CandidateCondition plan-goal         self-metric-above memory_confidence 0.80 )
(CandidateCondition repair-failure    task-active       _                _    )
(CandidateCondition repair-failure    appraisal-above   risk             0.30 )


;; SIGNAL THRESHOLDS
;; (SignalThreshold <signal-check> <threshold>)
;; Replaces hardcoded comparison values in signals.metta.
(SignalThreshold failure-streak-repeat    1   ) ;; streak > this → repeated-failure
(SignalThreshold progress-made-maxlen     20  ) ;; results shorter than this → progress-made
(SignalThreshold ambiguity-uncertainty    0.55) ;; uncertainty above → uncertaintyHigh
(SignalThreshold explore-novelty          0.50) ;; novelty above → explorationCondition
(SignalThreshold explore-exploration_bias 0.50) ;; exploration_bias above → explorationCondition
(SignalThreshold self-improve-failure     0.35) ;; failure_rate above → selfImproveCondition
(SignalThreshold self-improve-risk        0.65) ;; risk below → selfImproveCondition


;; ADDITIONAL CANDIDATE SPECS
;; (CandidateSpec <name> <type>)
;;   type ∈ { execution | knowledge | growth | safety }
(CandidateSpec respond           execution)
(CandidateSpec retrieve-memory   knowledge)
(CandidateSpec search-knowledge  knowledge)
(CandidateSpec execute-skill     execution)
(CandidateSpec learn             growth)
(CandidateSpec self-improve      growth)
(CandidateSpec background-work   knowledge)
(CandidateSpec recall-goals      knowledge)
(CandidateSpec invent-goal       growth)
(CandidateSpec plan-goal         knowledge)
(CandidateSpec repair-failure    safety)
(CandidateSpec defer             safety)
(CandidateSpec verify-frame-state safety)
(CandidateSpec ask-clarification safety)

;; Candidate → Goal/Motive alignment weights
;; (CandidateGoalAlignment <candidate> <goal-or-motive> <weight>)
(CandidateGoalAlignment respond           help_user       0.90)
(CandidateGoalAlignment respond           responsiveness  0.80)
(CandidateGoalAlignment respond           cooperate       0.50)
(CandidateGoalAlignment retrieve-memory   clarity         0.80)
(CandidateGoalAlignment retrieve-memory   coherence       0.60)
(CandidateGoalAlignment retrieve-memory   learn           0.40)
(CandidateGoalAlignment search-knowledge  clarity         0.70)
(CandidateGoalAlignment search-knowledge  learn           0.70)
(CandidateGoalAlignment search-knowledge  gTrans_over     0.40)
(CandidateGoalAlignment execute-skill     progress        1.00)
(CandidateGoalAlignment execute-skill     help_user       0.90)
(CandidateGoalAlignment execute-skill     responsiveness  0.80)
(CandidateGoalAlignment learn             learn           0.90)
(CandidateGoalAlignment learn             gTrans_over     0.80)
(CandidateGoalAlignment learn             adaptivity      0.50)
(CandidateGoalAlignment self-improve      gTrans_over     0.85)
(CandidateGoalAlignment self-improve      adaptivity      0.70)
(CandidateGoalAlignment self-improve      learn           0.60)
(CandidateGoalAlignment background-work   progress        0.35)
(CandidateGoalAlignment background-work   adaptivity      0.35)
(CandidateGoalAlignment background-work   reliability     0.25)
(CandidateGoalAlignment background-work   coherence       0.20)
(CandidateGoalAlignment background-work   learn           0.20)
(CandidateGoalAlignment recall-goals      clarity         0.70)
(CandidateGoalAlignment recall-goals      coherence       0.50)
(CandidateGoalAlignment recall-goals      learn           0.30)
(CandidateGoalAlignment invent-goal       learn           0.65)
(CandidateGoalAlignment invent-goal       gTrans_over     0.50)
(CandidateGoalAlignment invent-goal       adaptivity      0.30)
(CandidateGoalAlignment invent-goal       progress        0.20)
(CandidateGoalAlignment plan-goal         progress        0.60)
(CandidateGoalAlignment plan-goal         coherence       0.50)
(CandidateGoalAlignment plan-goal         help_user       0.35)
(CandidateGoalAlignment plan-goal         learn           0.30)
(CandidateGoalAlignment repair-failure    reliability     0.85)
(CandidateGoalAlignment repair-failure    adaptivity      0.55)
(CandidateGoalAlignment repair-failure    clarity         0.50)
(CandidateGoalAlignment defer             gInd_over       0.80)
(CandidateGoalAlignment defer             reliability     0.60)
(CandidateGoalAlignment verify-frame-state reliability  0.90)
(CandidateGoalAlignment verify-frame-state clarity      0.70)
(CandidateGoalAlignment ask-clarification clarity         0.85)
(CandidateGoalAlignment ask-clarification help_user       0.60)
(CandidateGoalAlignment ask-clarification coherence       0.50)

;; Candidate risk factors [0,1]
;; (CandidateRiskFactor <candidate> <risk>)
(CandidateRiskFactor respond           0.10)
(CandidateRiskFactor retrieve-memory   0.05)
(CandidateRiskFactor search-knowledge  0.05)
(CandidateRiskFactor execute-skill     0.20)
(CandidateRiskFactor learn             0.15)
(CandidateRiskFactor self-improve      0.65)
(CandidateRiskFactor background-work   0.02)
(CandidateRiskFactor recall-goals      0.05)
(CandidateRiskFactor invent-goal       0.10)
(CandidateRiskFactor plan-goal         0.05)
(CandidateRiskFactor repair-failure    0.03)
(CandidateRiskFactor defer             0.02)
(CandidateRiskFactor verify-frame-state 0.01)
(CandidateRiskFactor ask-clarification 0.02)

;; Candidate type → modulator weight links
;; (CandidateTypeModulator <type> <modulator> <sign>)
(CandidateTypeModulator execution  urgency           1.0)
(CandidateTypeModulator execution  persistence       0.5)
(CandidateTypeModulator execution  threshold        -0.5)
(CandidateTypeModulator knowledge  context_depth     1.0)
(CandidateTypeModulator knowledge  caution           0.5)
(CandidateTypeModulator knowledge  urgency          -0.3)
(CandidateTypeModulator growth     exploration_bias  1.0)
(CandidateTypeModulator growth     arousal           0.5)
(CandidateTypeModulator growth     persistence      -0.5)
(CandidateTypeModulator safety     securing          1.0)
(CandidateTypeModulator safety     threshold         0.5)
(CandidateTypeModulator safety     caution           0.5)

;; Candidate → Decision output map
;; (CandidateDecisionMap <candidate> <mode> <directive>)
(CandidateDecisionMap respond           execute  execute)
(CandidateDecisionMap retrieve-memory   orient   inspect)
(CandidateDecisionMap search-knowledge  orient   inspect)
(CandidateDecisionMap execute-skill     execute  execute)
(CandidateDecisionMap learn             orient   inspect)
(CandidateDecisionMap self-improve      recover  recover)
(CandidateDecisionMap background-work   orient   inspect)
(CandidateDecisionMap recall-goals      orient   inspect)
(CandidateDecisionMap invent-goal       orient   inspect)
(CandidateDecisionMap plan-goal         orient   inspect)
(CandidateDecisionMap repair-failure    recover  recover)
(CandidateDecisionMap defer             verify   verify)
(CandidateDecisionMap verify-frame-state verify verify)
(CandidateDecisionMap ask-clarification orient   inspect)


;; APPRAISAL LAYER
;; Effective appraisal coefficients; BooleanIndicator is applied only here.
;; (SignalAppraisalRule <factual-kind> <dimension> <transform> <coefficient>)
(SignalAppraisalRule failure risk BooleanIndicator 0.5600)
(SignalAppraisalRule failure importance BooleanIndicator 0.4000)
(SignalAppraisalRule failure uncertainty BooleanIndicator 0.3200)
(SignalAppraisalRule failure progress BooleanIndicator -0.2400)
(SignalAppraisalRule repeated-failure risk BooleanIndicator 0.7225)
(SignalAppraisalRule repeated-failure importance BooleanIndicator 0.5950)
(SignalAppraisalRule repeated-failure uncertainty BooleanIndicator 0.5100)
(SignalAppraisalRule repeated-failure progress BooleanIndicator -0.4250)
(SignalAppraisalRule new-input-without-outcome uncertainty BooleanIndicator 0.3600)
(SignalAppraisalRule new-input-without-outcome importance BooleanIndicator 0.2400)
(SignalAppraisalRule new-input-without-outcome novelty BooleanIndicator 0.1800)
(SignalAppraisalRule verified-success progress BooleanIndicator 0.70)
(SignalAppraisalRule verified-success opportunity BooleanIndicator 0.50)
(SignalAppraisalRule verified-success risk BooleanIndicator -0.30)
(SignalAppraisalRule progress-made progress BooleanIndicator 0.1800)
(SignalAppraisalRule progress-made opportunity BooleanIndicator 0.1200)
(SignalAppraisalRule stalled-progress progress BooleanIndicator -0.0700)
(SignalAppraisalRule stalled-progress importance BooleanIndicator 0.1750)
(SignalAppraisalRule user-waiting importance BooleanIndicator 0.1800)
(SignalAppraisalRule message-differs-from-task novelty BooleanIndicator 0.2700)
(SignalAppraisalRule message-differs-from-task uncertainty BooleanIndicator 0.1800)
(SignalAppraisalRule user-angry risk IdentityRatio 0.60)
(SignalAppraisalRule user-angry importance IdentityRatio 0.50)
(SignalAppraisalRule danger risk IdentityRatio 0.80)
(SignalAppraisalRule danger importance IdentityRatio 0.70)
(SignalAppraisalRule danger uncertainty IdentityRatio 0.40)
(SignalAppraisalRule execution-request opportunity IdentityRatio 0.90)
(SignalAppraisalRule execution-request importance IdentityRatio 0.70)
(SignalAppraisalRule execution-request progress IdentityRatio 0.60)

;; Appraisal dimension → Modulator update effects
;; (AppraisalEffect <dimension> <modulator> <delta-scale>)
(AppraisalEffect novelty      arousal           0.30)
(AppraisalEffect novelty      exploration_bias  0.20)
(AppraisalEffect novelty      focus            -0.10)
(AppraisalEffect risk         securing          0.40)
(AppraisalEffect risk         threshold         0.35)
(AppraisalEffect risk         arousal          -0.20)
(AppraisalEffect importance   urgency           0.30)
(AppraisalEffect importance   focus             0.25)
(AppraisalEffect uncertainty  threshold         0.25)
(AppraisalEffect uncertainty  caution           0.20)
(AppraisalEffect uncertainty  arousal          -0.10)
(AppraisalEffect opportunity  arousal           0.25)
(AppraisalEffect opportunity  valence           0.30)
(AppraisalEffect opportunity  exploration_bias  0.15)
(AppraisalEffect progress     valence           0.35)
(AppraisalEffect progress     persistence       0.15)
(AppraisalEffect progress     urgency          -0.10)


;; HOMEOSTATIC GOVERNANCE RULES

;; (HomeostaticRule <condition-type> <metric-name> <threshold>
;;                  <action-type> <target> <delta>)
;;   condition-type: modulator-exceeds | self-metric-below
;;   action-type:    raise-modulator | lower-modulator | raise-goal | lower-goal

;; Excessive securing → raise threshold, dampen exploration and arousal
(HomeostaticRule modulator-exceeds  securing            0.75 raise-modulator threshold         0.25)
(HomeostaticRule modulator-exceeds  securing            0.75 lower-modulator arousal           0.20)
(HomeostaticRule modulator-exceeds  securing            0.75 lower-modulator exploration_bias  0.20)

;; Excessive caution → dampen exploration
(HomeostaticRule modulator-exceeds  caution             0.80 lower-modulator exploration_bias  0.15)

;; Low memory confidence → raise threshold, lower persistence
(HomeostaticRule self-metric-below  memory_confidence   0.20 raise-modulator threshold         0.20)
(HomeostaticRule self-metric-below  memory_confidence   0.20 lower-modulator persistence       0.15)

;; Low success rate → raise caution, dampen growth goal
(HomeostaticRule self-metric-below  success_rate        0.15 raise-modulator caution           0.20)
(HomeostaticRule self-metric-below  success_rate        0.15 lower-goal      gTrans_over       0.05)

;; Low identity continuity → strengthen stability goal and securing
(HomeostaticRule self-metric-below  identity_continuity 0.30 raise-goal      gInd_over         0.05)
(HomeostaticRule self-metric-below  identity_continuity 0.30 raise-modulator securing          0.10)


;; R5 / 3.1–3.2: S allowlist and runtime initialization defaults.
;; (SelfModelFieldSpec <name> <class> <unit> <minimum> <maximum> <seed-default>)
;; These are internal condition estimates, not measured resources or capabilities.
;; Initialization, writes and restore enforce this schema; rule migration is 3.3.
(SelfModelFieldSpec energy  physiological normalized 0 1 1.00)
(SelfModelFieldSpec fatigue physiological normalized 0 1 0.00)
(SelfModelFieldSpec urgency motivational  normalized 0 1 0.50)

;; Exhaustive classification of retired legacy fields. No row permits S writes.
;; (LegacySelfMetricClass <name> <destination> <interpretation>)
;; An adjudicated claim requires host evidence; the current heuristic cannot supply it.
(LegacySelfMetricClass success_rate        observation      execution-success-estimate)
(LegacySelfMetricClass failure_rate        observation      execution-failure-estimate)
(LegacySelfMetricClass resource_usage      observation      cycle-count-proxy)
(LegacySelfMetricClass memory_confidence   adjudicated-claim memory-reliability)
(LegacySelfMetricClass identity_continuity observation      failure-streak-proxy)

;; Trusted policy captured at plan installation; zero disables correction retries.
(ContinuationRetryPolicy 2)
