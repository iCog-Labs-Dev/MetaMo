;; Core framework constants — NOT tied to any specific cognitive system

(= (C_CONTRACT) 0.9)
(= (EPSILON) 0.05)
(= (ETA_BOUNDARY) 0.1)

(= (ALPHA_0) 0.1)
(= (BETA_0) 0.15)

(= (LAX_DISTRIBUTIVE_DELTA) 1e-3)

;; Core config intentionally contains only framework constants.
;; Applications now provide schema, profiles, policies, and callbacks through
;; ApplicationBundle records instead of global constructor atoms.

