;; Generic utilities shared by the OmegaClaw MetaMo application.

(= (clamp01 $value)
   (if (< $value 0.0) 0.0 (if (> $value 1.0) 1.0 $value)))

(= (clearSpace $space)
   (collapse
      (let $atom (get-atoms $space)
         (remove-atom $space $atom))))
