;; Focused tests for the ContextFrames relation boundary.

!(import! &self (library lib_import))
!(import! &self "../../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../../repos/OmegaClaw-Core/src/context)
!(import! &self (library MetaMo core/state))
!(import! &self (library MetaMo core/state_accessors))
!(import! &self (library MetaMo core/helper))
!(import! &self (library MetaMo core/helpers.py))
!(import! &self (library MetaMo applications/omegaclaw_v1/utils))
!(import! &self (library MetaMo applications/omegaclaw_v1/context_integration))

!(test (!= (frameStateProjectRelation
               (FrameRelation frame-a frame-a SameFrame "same" 0.90 Proposed))
           ()) True)
!(test (eval (eval (frameStateRelationEvidence frame-a frame-a SameFrame Proposed)))
      VerificationRequired)

(= (relationTestBundle)
   (FrameStateBundle
      (root (FrameStateRoot root-id frame-a (mode Fast)
             (ResourceBudget 10 10 units (status Open)) root-constraints))
      (current (FrameStateCurrent
         (id frame-a) (parent ()) UserDirective (status Active) (frame-mode Fast)
         (priority 0.8) (goal-summary goal) (history-summary history)
         (deliverable-summary deliverable) (results-summary results)
         (budget (ResourceBudget 10 10 units (status Open)))
         (constraints constraints) (certified-method method)))
      (index (active ()) (completed ()))
(relations
         ((FrameStateRelation
            (source-frame frame-a) (target-frame frame-a)
            (relation-type SameFrame) (reason same-frame) (confidence 0.90)
            (evidence-status VerificationRequired))))
      (runtime ())))


!(test (eval (bundleNeedsRelationVerification (relationTestBundle))) True)
!(test  (eval (frameVerificationStatus
               (captureFrameVerificationOutcome
                  (car-atom (frameBundleRelations (relationTestBundle)))
                  Confirmed))) Confirmed)
!(captureFrameVerificationOutcome
                  (relationTestBundle)
                  Confirmed)
!(eval (frameBundleRelations (eval (relationTestBundle))))
!(test (eval (frameVerificationStatus
               (captureFrameVerificationOutcome
                  (car-atom (frameBundleRelations (relationTestBundle)))
                  Refuted))) Refuted)
!(let $interimVariable (frameBundleRelations (relationTestBundle))
      (test  (eval (frameVerificationStatus
               (eval (captureFrameVerificationOutcome
                  (car-atom $$interimVariable)
                  ;(car-atom $interimVariable)
                  UnknownVerificationResult)))) Unresolved))

!(eval (frameVerificationStatus
               (captureFrameVerificationOutcome
                  (car-atom (frameBundleRelations (relationTestBundle)))
                  Confirmed)))

