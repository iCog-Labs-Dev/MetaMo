;; Constitutional MVP mode layer.
;;
;; These modes are distinct from ContextFrames' Fast/Slow frame execution mode
;; and from MetaMo's operation directives (orient/execute/verify/recover).

!(bind! &constitutional-mode (new-state Engaged))

(= (constitutionalModeSet)
   (cons Engaged (cons Threat (cons Rumination (cons Sleep ())))))

(= (constitutionalModeDefault)
   Engaged)

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
