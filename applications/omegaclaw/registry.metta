
(MotiveSpec clarity 0.45)
(MotiveSpec progress 0.55)
(MotiveSpec reliability 0.50)
(MotiveSpec adaptivity 0.40)
(MotiveSpec coherence 0.45)
(MotiveSpec responsiveness 0.45)


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
;; (SignalEffect <signal-kind> <target-type> <target-name> <scale>)
;;   target-type: motive | modulator
;;   scale > 0 → raises target; scale < 0 → lowers target

;; ambiguity
(SignalEffect ambiguity        motive    clarity         0.40)
(SignalEffect ambiguity        modulator caution         0.15)
(SignalEffect ambiguity        modulator context_depth   0.20)

;; failure
(SignalEffect failure          motive    reliability     0.35)
(SignalEffect failure          motive    adaptivity      0.25)
(SignalEffect failure          modulator caution         0.20)
(SignalEffect failure          modulator urgency         0.15)

;; repeated-failure
(SignalEffect repeated-failure motive    adaptivity      0.40)
(SignalEffect repeated-failure motive    reliability     0.15)
(SignalEffect repeated-failure modulator persistence    -0.30)
(SignalEffect repeated-failure modulator exploration_bias 0.30)

;; stalled-progress
(SignalEffect stalled-progress motive    progress        0.30)
(SignalEffect stalled-progress motive    adaptivity      0.20)
(SignalEffect stalled-progress modulator urgency         0.15)

;; verified-success
(SignalEffect verified-success motive    reliability    -0.30)
(SignalEffect verified-success motive    clarity        -0.20)
(SignalEffect verified-success modulator caution        -0.15)

;; progress-made
(SignalEffect progress-made    motive    progress       -0.25)
(SignalEffect progress-made    modulator persistence     0.10)

;; task-drift
(SignalEffect task-drift       motive    coherence       0.35)
(SignalEffect task-drift       modulator context_depth   0.10)
(SignalEffect task-drift       modulator human_deference 0.10)

;; user-waiting
(SignalEffect user-waiting     motive    responsiveness  0.35)
(SignalEffect user-waiting     modulator urgency         0.15)
(SignalEffect user-waiting     modulator human_deference 0.10)

;; user-angry
(SignalEffect user-angry       motive    reliability     0.20)
(SignalEffect user-angry       modulator human_deference 0.15)
(SignalEffect user-angry       modulator caution         0.20)
(SignalEffect user-angry       modulator urgency         0.10)

;; danger
(SignalEffect danger            modulator securing        0.40)
(SignalEffect danger            modulator caution         0.25)
(SignalEffect danger            modulator threshold       0.30)
(SignalEffect danger            modulator persistence    -0.25)
(SignalEffect danger            modulator arousal        -0.15)


;; SIGNAL MODE OVERRIDES
;; (SignalMode <signal-kind> <mode>)
(SignalMode ambiguity        orient)
(SignalMode failure          verify)
(SignalMode repeated-failure recover)
(SignalMode verified-success execute)
(SignalMode task-drift       orient)
(SignalMode user-angry       orient)
(SignalMode danger           verify)


;; SIGNAL STRENGTHS
;; (SignalStrength <signal-kind> <default-strength>)
(SignalStrength repeated-failure 0.85)
(SignalStrength failure          0.80)
(SignalStrength task-drift       0.45)
(SignalStrength ambiguity        0.60)
(SignalStrength stalled-progress 0.35)
(SignalStrength progress-made    0.40)
(SignalStrength user-waiting     0.30)


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
(CandidateDeltaG defer             gInd_over    0.03)
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


;; CANDIDATE CONDITIONS
;; (CandidateCondition <candidate> <condition-type> <param> <threshold>)
;; Replaces hardcoded conditions in candidates.metta.
;;   condition-type: appraisal-above | modulator-above | self-metric-above | always | task-active
(CandidateCondition respond           task-active       _                _    )
(CandidateCondition retrieve-memory   always            _                _    )
(CandidateCondition search-knowledge  always            _                _    )
(CandidateCondition defer             always            _                _    )
(CandidateCondition ask-clarification always            _                _    )
(CandidateCondition execute-skill     task-active       _                _    )
;; learn uses OR semantics: either novelty > 0.50 OR exploration_bias > 0.50 is enough.
(CandidateConditionAny learn             appraisal-above   novelty          0.50 )
(CandidateConditionAny learn             modulator-above   exploration_bias 0.50 )
(CandidateCondition self-improve      self-metric-above failure_rate     0.35 )
(CandidateCondition self-improve      appraisal-below   risk             0.65 )


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
(CandidateSpec defer             safety)
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
(CandidateGoalAlignment execute-skill     progress        0.85)
(CandidateGoalAlignment execute-skill     help_user       0.70)
(CandidateGoalAlignment execute-skill     responsiveness  0.60)
(CandidateGoalAlignment learn             learn           0.90)
(CandidateGoalAlignment learn             gTrans_over     0.80)
(CandidateGoalAlignment learn             adaptivity      0.50)
(CandidateGoalAlignment self-improve      gTrans_over     0.85)
(CandidateGoalAlignment self-improve      adaptivity      0.70)
(CandidateGoalAlignment self-improve      learn           0.60)
(CandidateGoalAlignment defer             gInd_over       0.80)
(CandidateGoalAlignment defer             reliability     0.60)
(CandidateGoalAlignment ask-clarification clarity         0.85)
(CandidateGoalAlignment ask-clarification help_user       0.60)
(CandidateGoalAlignment ask-clarification coherence       0.50)

;; Candidate risk factors [0,1]
;; (CandidateRiskFactor <candidate> <risk>)
(CandidateRiskFactor respond           0.10)
(CandidateRiskFactor retrieve-memory   0.05)
(CandidateRiskFactor search-knowledge  0.05)
(CandidateRiskFactor execute-skill     0.40)
(CandidateRiskFactor learn             0.15)
(CandidateRiskFactor self-improve      0.65)
(CandidateRiskFactor defer             0.02)
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
(CandidateDecisionMap defer             verify   verify)
(CandidateDecisionMap ask-clarification orient   inspect)


;; APPRAISAL LAYER
;; (SignalAppraisal <signal-kind> <dimension> <weight>)
(SignalAppraisal failure           risk          0.70)
(SignalAppraisal failure           importance    0.50)
(SignalAppraisal failure           uncertainty   0.40)
(SignalAppraisal failure           progress     -0.30)
(SignalAppraisal repeated-failure  risk          0.85)
(SignalAppraisal repeated-failure  importance    0.70)
(SignalAppraisal repeated-failure  uncertainty   0.60)
(SignalAppraisal repeated-failure  progress     -0.50)
(SignalAppraisal ambiguity         uncertainty   0.60)
(SignalAppraisal ambiguity         importance    0.40)
(SignalAppraisal ambiguity         novelty       0.30)
(SignalAppraisal verified-success  progress      0.70)
(SignalAppraisal verified-success  opportunity   0.50)
(SignalAppraisal verified-success  risk         -0.30)
(SignalAppraisal progress-made     progress      0.45)
(SignalAppraisal progress-made     opportunity   0.30)
(SignalAppraisal stalled-progress  progress     -0.20)
(SignalAppraisal stalled-progress  importance    0.50)
(SignalAppraisal user-waiting      importance    0.60)
(SignalAppraisal task-drift        novelty       0.60)
(SignalAppraisal task-drift        uncertainty   0.40)
(SignalAppraisal user-angry        risk          0.60)
(SignalAppraisal user-angry        importance    0.50)
(SignalAppraisal danger            risk          0.80)
(SignalAppraisal danger            importance    0.70)
(SignalAppraisal danger            uncertainty   0.40)

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


;; SELF MODEL SPECS
;; (SelfModelSpec <name> <baseline>)
(SelfModelSpec success_rate        0.50)
(SelfModelSpec failure_rate        0.10)
(SelfModelSpec resource_usage      0.30)
(SelfModelSpec memory_confidence   0.70)
(SelfModelSpec identity_continuity 0.90)
