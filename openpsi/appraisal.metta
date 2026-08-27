(: OpenPsiAppraisal Type)
(: openPsiAppraisal (-> AppraisalProfile OpenPsiAppraisal))

;; Return the profile from a canonical OpenPsi appraisal wrapper.
;; Example: (openPsiAppraisalProfile (openPsiAppraisal profile)) -> profile
(= (openPsiAppraisalProfile (openPsiAppraisal $profile))
    $profile
)

;; Construct a canonical OpenPsi appraisal wrapper.
;; Example: (openPsiAppraisalWithProfile profile) -> (openPsiAppraisal profile)
(= (openPsiAppraisalWithProfile $profile)
    (openPsiAppraisal $profile)
)

;; Extract the current schema-aware state.
;; Example: (openPsiExtract (openPsiAppraisal profile) state) -> state
(= (openPsiExtract (openPsiAppraisal $profile) $state)
    $state
)

;; Appraise a state with an explicit profile.
;; Example: (openPsiAppraiseWithProfile profile state stimulus) -> updated-state
(= (openPsiAppraiseWithProfile $profile $state $stimulus)
    (appraisalProfileAppraise $profile $state $stimulus)
)

;; Appraise a state through the canonical wrapper.
;; Example: (openPsiAppraise (openPsiAppraisal profile) state stimulus) -> updated-state
(= (openPsiAppraise (openPsiAppraisal $profile) $state $stimulus)
    (openPsiAppraiseWithProfile $profile $state $stimulus)
)

;; Produce goal-change feedback with an explicit profile.
;; Example: (openPsiGoalChangeFeedbackWithProfile profile state stimulus) -> (goalChangeFeedback ())
(= (openPsiGoalChangeFeedbackWithProfile $profile $state $stimulus)
    (let* (
        ($features (appraisalProfileStimulusFeatures $profile $state $stimulus))
    )
        (appraisalProfileGoalChangeFeedback $profile $state $stimulus $features)
    )
)

;; Produce goal-change feedback through the canonical wrapper.
;; Example: (openPsiGoalChangeFeedback appraisal state stimulus) -> (goalChangeFeedback ())
(= (openPsiGoalChangeFeedback (openPsiAppraisal $profile) $state $stimulus)
    (openPsiGoalChangeFeedbackWithProfile $profile $state $stimulus)
)
