;; Constitutional MVP mode layer.
;;
;; These modes are distinct from ContextFrames' Fast/Slow frame execution mode
;; and from MetaMo's operation directives (orient/execute/verify/recover).

!(bind! &constitutional-mode (new-state Engaged))

(= (constitutionalModeSet)
   (cons Engaged (cons Threat (cons Rumination (cons Sleep ())))))

(= (constitutionalModeDefault)
   Engaged)

(= (constitutionalModePreemptionOrder)
   (cons Threat-remediation
      (cons Recovery
         (cons Interactive
            (cons Orienting
               (cons Engaged
                  (cons Rumination (cons Sleep ()))))))))

(= (constitutionalModePreemptionRank $mode)
   (case $mode
      ((Threat-remediation 7)
       (Recovery 6)
       (Interactive 5)
       (Orienting 4)
       (Engaged 3)
       (Rumination 2)
       (Sleep 1)
       ($_ 0))))

(= (constitutionalModePreempts $higher $lower)
   (> (constitutionalModePreemptionRank $higher)
      (constitutionalModePreemptionRank $lower)))

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
