
(GoalIndex gInd   0)
(GoalIndex gTrans 1)

(= (NUM_GOALS) 11)

(GoalIndex gInd_over       0)
(GoalIndex gTrans_over     1)
(GoalIndex help_user       2)
(GoalIndex learn           3)
(GoalIndex cooperate       4)
(GoalIndex responsiveness  5)
(GoalIndex clarity         6)
(GoalIndex coherence       7)
(GoalIndex reliability     8)
(GoalIndex progress        9)
(GoalIndex adaptivity     10)

(= (NUM_MODULATORS) 11)

(ModulatorIndex urgency           0)
(ModulatorIndex caution           1)
(ModulatorIndex persistence       2)
(ModulatorIndex exploration_bias  3)
(ModulatorIndex context_depth     4)
(ModulatorIndex human_deference   5)
(ModulatorIndex arousal           6)
(ModulatorIndex valence           7)
(ModulatorIndex threshold         8)
(ModulatorIndex securing          9)
(ModulatorIndex focus            10)

(= (NUM_STIMULUS) 6)

(StimulusIndex novelty      0)
(StimulusIndex risk         1)
(StimulusIndex importance   2)
(StimulusIndex uncertainty  3)
(StimulusIndex opportunity  4)
(StimulusIndex progress     5)

(= (THETA_SAFE) 0.55)  ;; GoalFloor for gInd_over
(= (G_MAX)      3.5)   ;; Scaled for 11 goals
(= (LAMBDA_IND)   0.5)
(= (LAMBDA_TRANS) 0.5)


(= (OPENPSI_GOAL_WEIGHT_IDX)     0)         ;; gInd_over
(= (OPENPSI_SAFETY_GOAL_IDX)     (0 8))     ;; gInd_over, reliability
(= (OPENPSI_EXPLORATORY_GOAL_IDX)(1 3 10))  ;; gTrans_over, learn, adaptivity
(= (OPENPSI_SOCIAL_GOAL_IDX)     (2 4 5))   ;; help_user, cooperate, responsiveness

(= (OPENPSI_CAUTION_MOD_IDX)      (1 8 9))  ;; caution, threshold, securing
(= (OPENPSI_EXPLORATORY_MOD_IDX)  (3 6))    ;; exploration_bias, arousal
(= (OPENPSI_SHARED_MOD_IDX)       (7 4))    ;; valence, context_depth

(goalMetaDrive gInd_over      individuation)
(goalMetaDrive gTrans_over    transcendence)
(goalMetaDrive help_user      individuation)
(goalMetaDrive learn          transcendence)
(goalMetaDrive cooperate      dual)
(goalMetaDrive responsiveness individuation)
(goalMetaDrive clarity        individuation)
(goalMetaDrive coherence      individuation)
(goalMetaDrive reliability    individuation)
(goalMetaDrive progress       dual)
(goalMetaDrive adaptivity     transcendence)


(goalModulatorRelevance help_user      (urgency human_deference))
(goalModulatorRelevance learn          (exploration_bias arousal))
(goalModulatorRelevance cooperate      (human_deference valence))
(goalModulatorRelevance responsiveness (urgency human_deference))
(goalModulatorRelevance clarity        (context_depth caution))
(goalModulatorRelevance coherence      (context_depth human_deference))
(goalModulatorRelevance reliability    (caution securing))
(goalModulatorRelevance progress       (urgency persistence))
(goalModulatorRelevance adaptivity     (exploration_bias arousal))


(= (createInitialState)
    (motivation
        (0.70 0.40 0.60 0.45 0.50 0.60 0.55 0.50 0.60 0.50 0.45)  ;; Goals
        (0.50 0.50 0.55 0.40 0.50 0.40 0.50 0.50 0.40 0.30 0.55)   ;; Modulators
    )
)
