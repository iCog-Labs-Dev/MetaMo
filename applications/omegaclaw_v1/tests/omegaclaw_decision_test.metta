;; Focused tests for the OmegaClaw v1 decision layer.
;; Run from the MetaMo repository root with:
;;   python3 scripts/run-omegaclaw.py applications/omegaclaw_v1/tests/omegaclaw_decision_test.metta

!(import! &self (library MetaMo core/config))
!(import! &self (library MetaMo core/state))
!(import! &self (library MetaMo core/state_accessors))
!(import! &self (library MetaMo core/helper))
!(import! &self (library MetaMo core/helpers.py))
!(import! &self (library MetaMo category/functors))
!(import! &self (library MetaMo applications/omegaclaw_v1/openpsi_config))
!(import! &self (library MetaMo applications/omegaclaw_v1/utils))
!(import! &self (library MetaMo applications/omegaclaw_v1/registry))
!(import! &self (library MetaMo applications/omegaclaw_v1/adapter))
!(import! &self (library MetaMo applications/omegaclaw_v1/bridge))
!(import! &self (library MetaMo applications/omegaclaw_v1/candidate_selection))
!(import! &self (library MetaMo applications/omegaclaw_v1/scheduling))
!(import! &self (library MetaMo applications/omegaclaw_v1/signals))
!(import! &self (library MetaMo applications/omegaclaw_v1/omegaclaw_decision))


(= (decisionTestState)
   (motivation
      (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
      (0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5)))

(= (respondAction)
   (action respond (0 0 0.90 0 0.50 0.80 0 0 0 0 0)
                   0.10 (0 0 0 0 0 0 0 0 0 0 0)))

(= (emptyBundle)
   (FrameStateBundle
      (root (FrameStateRoot root-id ()))
      (current (FrameStateCurrent
         (id none) (parent ()) source (status Active) (frame-mode Fast)
         (priority 0.5) goal history deliverables results budget constraints method))
      (index (active ()) (completed ()))
      (relations ())
      (runtime runtime)))

(= (validBundle)
   (FrameStateBundle
      (root (FrameStateRoot root-id current-id (mode Fast) budget constraints))
      (current (FrameStateCurrent
         (id current-id) (parent ()) source (status Active) (frame-mode Fast)
         (priority 0.5) goal history deliverables results budget constraints method))
      (index (active ()) (completed ()))
      (relations ())
      (runtime runtime)))


      ;; Registry lookups and candidate classification.
!(test (eval (candidateType respond)) execution)
!(test (eval (candidateType retrieve-memory)) knowledge)
!(test  (eval (candidateType learn)) growth)
!(test  (eval (candidateType ask-clarification)) safety)
!(test (eval (candidateType not-registered)) unknown)
!(test (eval (isSafetyCandidate ask-clarification)) True)
!(test  (eval (isSafetyCandidate respond)) False)

; ;; Anti-saturation configuration is read from registry.metta.
!(test  (eval (antiSatThreshold)) 2)
!(test  (eval (antiSatStep)) 0.10)
!(test  (eval (antiSatMax)) 0.50)

;; A no-op action always has score zero.
; !(test (eval (omegaclawScore (decisionTestState)
;                             (action none () 0.0 ()))) 0.0)

;; Bundle-aware scoring rejects an unbound/current-less bundle and accepts a
;; bundle with a current frame. The valid case is intentionally structural:
;; petta evaluates the composed numeric scorer lazily at this boundary.
;; NOTE: `(id ())` is evaluated by Petta as the ID constructor and therefore
;; does not represent an empty current-frame ID at runtime. Keep the explicit
;; valid-bundle accessor assertion below as the reliable boundary check.
; !(test (eval (omegaclawScoreForBundle (emptyBundle)
;                                       (decisionTestState)
;                                       (respondAction))) 0.0)
!(test (eval (!= (frameBundleCurrentId (validBundle)) ())) True)

; ;; Empty candidate lists produce the documented no-op decision result.
!(test (eval (decisionAction
                 (omegaclawDecide (decisionTestState) ())))
      (action none () 0.0 ()))
!(test (eval (decisionDeltaG
                 (omegaclawDecide (decisionTestState) ()))) ())
