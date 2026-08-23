
; Bridges Qwestor's space and MetaMo's (motivation goals modulators) state type.
;
; PROJECTION (Qwestor → MetaMo)

; MetaMo's OpenPSI motivation state has:
;   8 goals:      gInd gTrans gHelp gCurio gNovel gSelf gEthic gSoc
;   6 modulators: valence arousal approach resolution threshold securing
;
; These are derived from Qwestor's running modulators and goal weights;

; Goal mapping (Qwestor → OpenPSI):
;    gInd   = C(over_safety)
;
;    gTrans = C(success_breakthrough)
;
;    gHelp  = C((help_short + help_long + over_beneficial) / 3)
;
;    gCurio = C((knowledge + coherence) / 2)
;
;    gNovel = C((novelty + originality) / 2)
;
;    gSelf  = C((efficiency + accuracy + success_moderate) / 3)
;
;    gEthic = C(over_honesty)
;
;    gSoc   = C(social)
 
;
; Modulator mapping (Qwestor → OpenPSI):
 
; 
;   valence converts the Qwestor range [-1, 1] to the OpenPSI range [0, 1]
;   before applying the clamp.
;
; valence   = C((m_valence + 1.0) / 2)
;
; arousal   = C((m_arousal + m_urgency) / 2)
;
; approach  = C((m_approach + m_creativity) / 2)
;
; resolution = C((m_resolution + m_topic_familiarity + m_user_expertise) / 3)
;
; threshold = C((m_threshold + m_error_tolerance) / 2)
;
; securing  = C((m_securing + m_failure_wariness + m_risk_aversion) / 3)


; projectToMotivation: reads the current Qwestor space and returns a MetaMo motivation state.
; Example:
;   (projectToMotivation &space)
;   → (motivation (0.65 0.44 0.55 0.52 0.46 0.62 0.65 0.58)
;                 (0.00 0.40 0.40 0.40 0.30 0.10))

(: projectToMotivation (-> Expression Expression))
(= (projectToMotivation $space)
  (let*
    (
      ; Read 14 goal weights from Qwestor space 
      ($efficiency_g      (getGoalQwestor $space efficiency))
      ($accuracy_g        (getGoalQwestor $space accuracy))
      ($success_mod_g     (getGoalQwestor $space success_moderate))
      ($knowledge_g       (getGoalQwestor $space knowledge))
      ($novelty_g         (getGoalQwestor $space novelty))
      ($success_brk_g     (getGoalQwestor $space success_breakthrough))
      ($coherence_g       (getGoalQwestor $space coherence))
      ($originality_g     (getGoalQwestor $space originality))
      ($social_g          (getGoalQwestor $space social))
      ($help_short_g      (getGoalQwestor $space help_short))
      ($help_long_g       (getGoalQwestor $space help_long))
      ($over_beneficial_g (getGoalQwestor $space over_beneficial))
      ($over_safety_g     (getGoalQwestor $space over_safety))
      ($over_honesty_g    (getGoalQwestor $space over_honesty))

      ; Read 13 modulators from Qwestor space 
      ($m_urg      (getMod $space m_urgency))
      ($m_res      (getMod $space m_resolution))
      ($m_usr_exp  (getMod $space m_user_expertise))
      ($m_thr      (getMod $space m_threshold))
      ($m_top_fam  (getMod $space m_topic_familiarity))
      ($m_fail_war (getMod $space m_failure_wariness))
      ($m_sec      (getMod $space m_securing))
      ($m_app      (getMod $space m_approach))
      ($m_ar       (getMod $space m_arousal))
      ($m_risk_av  (getMod $space m_risk_aversion))
      ($m_err_tol  (getMod $space m_error_tolerance))
      ($m_creat    (getMod $space m_creativity))
      ($m_val      (getMod $space m_valence))

      ; Build OpenPSI goal vector (8) 
      ($gInd   (eval (clampToUnitInterval $over_safety_g)))
      ($gTrans (eval (clampToUnitInterval $success_brk_g)))
      ($gHelp  (eval (clampToUnitInterval (/ (+ (+ $help_short_g $help_long_g) $over_beneficial_g) 3.0))))
      ($gCurio (eval (clampToUnitInterval (/ (+ $knowledge_g $coherence_g) 2.0))))
      ($gNovel (eval (clampToUnitInterval (/ (+ $novelty_g $originality_g) 2.0))))
      ($gSelf  (eval (clampToUnitInterval (/ (+ (+ $efficiency_g $accuracy_g) $success_mod_g) 3.0))))
      ($gEthic (eval (clampToUnitInterval $over_honesty_g)))
      ($gSoc   (eval (clampToUnitInterval $social_g)))

      ; Build OpenPSI modulator vector (6) 
      ; valence: map Qwestor's [-1,1] to OpenPSI's [0,1]
      ($val_openpsi (eval (clampToUnitInterval (* (+ $m_val 1.0) 0.5))))
      
      ; arousal: average of arousal and urgency
      ($ar_openpsi  (eval (clampToUnitInterval (/ (+ $m_ar $m_urg) 2.0))))
      
      ; approach: average of approach and creativity
      ($app_openpsi (eval (clampToUnitInterval (/ (+ $m_app $m_creat) 2.0))))
      
      ; resolution: average of resolution, topic familiarity, and user expertise
      ($res_openpsi (eval (clampToUnitInterval (/ (+ (+ $m_res $m_top_fam) $m_usr_exp) 3.0))))
      
      ; threshold: average of threshold and error tolerance
      ($thr_openpsi (eval (clampToUnitInterval (/ (+ $m_thr $m_err_tol) 2.0))))
      
      ; securing: average of securing, failure wariness, and risk aversion
      ($sec_openpsi (eval (clampToUnitInterval (/ (+ (+ $m_sec $m_fail_war) $m_risk_av) 3.0))))
    )
    (motivation
      ($gInd $gTrans $gHelp $gCurio $gNovel $gSelf $gEthic $gSoc)
      ($val_openpsi $ar_openpsi $app_openpsi $res_openpsi $thr_openpsi $sec_openpsi)
    )
  )
)

; motivationSummary  
; Returns a human-readable pair-list of the MetaMo motivation state for logging

(= (motivationSummary (motivation $goals $mods))
  (let*
    (
      ($gInd   (index-atom $goals 0))
      ($gTrans (index-atom $goals 1))
      ($gHelp  (index-atom $goals 2))
      ($gCurio (index-atom $goals 3))
      ($gNovel (index-atom $goals 4))
      ($gSelf  (index-atom $goals 5))
      ($gEthic (index-atom $goals 6))
      ($gSoc   (index-atom $goals 7))
      ($val    (index-atom $mods 0))
      ($ar     (index-atom $mods 1))
      ($app    (index-atom $mods 2))
      ($res    (index-atom $mods 3))
      ($thr    (index-atom $mods 4))
      ($sec    (index-atom $mods 5))
    )

    (
      (gInd $gInd) (gTrans $gTrans) (gHelp $gHelp) (gCurio $gCurio)
      (gNovel $gNovel) (gSelf $gSelf) (gEthic $gEthic) (gSoc $gSoc)
      (valence $val) (arousal $ar) (approach $app) (resolution $res)
      (threshold $thr) (securing $sec)
    )
    
  )
)