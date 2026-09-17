;; Constitutional MVP mode layer.
;;
;; These modes are distinct from ContextFrames' Fast/Slow frame execution mode
;; and from MetaMo's operation directives (orient/execute/verify/recover).

!(import! &self (library MetaMo applications/omegaclaw_v1/scheduling))

!(bind! &constitutional-mode (new-state Engaged))

(= (constitutionalModeSet)
   (cons Engaged (cons Threat (cons Rumination (cons Sleep ())))))

(= (constitutionalModeDefault)
   Engaged)

;; Historical API aliases. These describe scheduling classes, NOT members of
;; constitutionalModeSet. New callers should use schedulingPriority* names.
(= (constitutionalModePreemptionOrder) (schedulingPriorityOrder))
(= (constitutionalModePreemptionRank $class) (schedulingPriorityRank $class))
(= (constitutionalModePreempts $higher $lower)
   (schedulingPriorityPreempts $higher $lower))

;; MVP mode selection consumes the existing typed signal substrate. It does
;; not create a second salience or scoring space.
(= (constitutionalModeFromSignalFacts True $_ $_ $_)
   Threat)
(= (constitutionalModeFromSignalFacts False True $_ $_)
   Rumination)
(= (constitutionalModeFromSignalFacts False False True $_)
   Sleep)
(= (constitutionalModeFromSignalFacts False False False $_)
   Engaged)

(= (constitutionalModeFromSignals $bundle)
   (constitutionalModeFromSignalFacts
      (eval (or (hasSignal danger) (hasSignal user-angry)))
      (eval (or (hasSignal failure)
                 (hasSignal repeated-failure)
                 (hasSignal stalled-progress)))
      (eval (== (frameBundleCurrentId $bundle) ()))
      True))

(= (refreshConstitutionalMode $bundle)
   (setConstitutionalMode (constitutionalModeFromSignals $bundle)))

(= (constitutionalModeValid $mode)
   (case $mode
      ((Engaged True)
       (Threat True)
       (Rumination True)
       (Sleep True)
       ($_ False))))

(= (constitutionalMode)
   (get-state &constitutional-mode))

(= (setConstitutionalMode $mode)
   (if (constitutionalModeValid $mode)
       (change-state! &constitutional-mode $mode)
       (ModeRejected $mode)))
