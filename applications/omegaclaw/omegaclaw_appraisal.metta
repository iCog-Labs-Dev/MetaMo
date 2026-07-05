

(= (mapAppraisalIdx $dim)
    (case $dim (
        (novelty      0)
        (risk         1)
        (importance   2)
        (uncertainty  3)
        (opportunity  4)
        (progress     5)
    ))
)

(= (mapModulatorIdx $mod)
    (case $mod (
        (urgency           0)
        (caution           1)
        (persistence       2)
        (exploration_bias  3)
        (context_depth     4)
        (human_deference   5)
        (arousal           6)
        (valence           7)
        (threshold         8)
        (securing          9)
        (focus            10)
    ))
)


;; Identity extract: returns the state unchanged.
(= (omegaclawExtract $state) $state)


;; Apply a single (AppraisalEffect dim mod scale) atom by boosting the target
;; modulator at the appropriate index.
(= (applyAppraisalEffect $effect $dimVal $modulators)
    (case $effect (
        ((AppraisalEffect $dim $mod $scale)
            (let $modIdx (eval (mapModulatorIdx $mod))
                (eval (boostAtIndices $modulators ($modIdx) (* $scale $dimVal) 2.0))
            )
        )
    ))
)

;; Iteratively apply a list of AppraisalEffect atoms to the modulator vector.
(= (applyDimEffects $dim $dimVal $effects $modulators)
    (if (== $effects ())
        $modulators
        (let* (
            (($head $tail) (decons-atom $effects))
            ($newMods (eval (applyAppraisalEffect $head $dimVal $modulators)))
        )
            (eval (applyDimEffects $dim $dimVal $tail $newMods))
        )
    )
)


;; omegaclawAppraise: the appraisal function for the AppraisalComonad.
(= (omegaclawAppraise $state $stimulus)
    (let* (
        ($goals (motivationGoals $state))
        ($mods  (motivationModulators $state))

        ;; Extract each of the 6 stimulus dimension values by position
        ($sVals        (eval (stimulusValues $stimulus)))
        ($sNovelty     (index-atom $sVals 0))
        ($sRisk        (index-atom $sVals 1))
        ($sImportance  (index-atom $sVals 2))
        ($sUncertainty (index-atom $sVals 3))
        ($sOpportunity (index-atom $sVals 4))
        ($sProgress    (index-atom $sVals 5))

        ;; Fetch all AppraisalEffect atoms from &self (populated by registry.metta)
        ($noveltyEffects (collapse (match &self (AppraisalEffect novelty     $m $s) (AppraisalEffect novelty     $m $s))))
        ($riskEffects    (collapse (match &self (AppraisalEffect risk        $m $s) (AppraisalEffect risk        $m $s))))
        ($impEffects     (collapse (match &self (AppraisalEffect importance  $m $s) (AppraisalEffect importance  $m $s))))
        ($uncEffects     (collapse (match &self (AppraisalEffect uncertainty $m $s) (AppraisalEffect uncertainty $m $s))))
        ($oppEffects     (collapse (match &self (AppraisalEffect opportunity $m $s) (AppraisalEffect opportunity $m $s))))
        ($progEffects    (collapse (match &self (AppraisalEffect progress    $m $s) (AppraisalEffect progress    $m $s))))

        ;; Accumulate modulator changes from each stimulus dimension in sequence
        ($mods1 (eval (applyDimEffects novelty     $sNovelty     $noveltyEffects $mods)))
        ($mods2 (eval (applyDimEffects risk        $sRisk        $riskEffects    $mods1)))
        ($mods3 (eval (applyDimEffects importance  $sImportance  $impEffects     $mods2)))
        ($mods4 (eval (applyDimEffects uncertainty $sUncertainty $uncEffects     $mods3)))
        ($mods5 (eval (applyDimEffects opportunity $sOpportunity $oppEffects     $mods4)))
        ($finalMods (eval (applyDimEffects progress $sProgress   $progEffects    $mods5)))
    )
        (motivation $goals (eval (clipVector $finalMods 0.0 1.0)))
    )
)


(= (omegaclawAppraisal)
    (appraisalComonad omegaclawExtract omegaclawAppraise)
)
