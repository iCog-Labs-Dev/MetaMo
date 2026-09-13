;; Deterministic vertical-slice demo for the OmegaClaw v1 MetaMo loop.
;;
;; This is intentionally not the production OmegaClaw entry point. It uses a
;; fixed FrameStateBundle so the adapter -> signal -> mode -> candidate ->
;; decision path can be demonstrated without a channel, LLM, or ChromaDB.
;;
;; PURPOSE
;; -------
;; This file is a presentation and smoke-test harness for the smallest useful
;; end-to-end loop. It proves that a bounded ContextFrames-style input can be
;; accepted at the MetaMo boundary, associated with a constitutional mode, and
;; turned into an admitted attention directive.
;;
;; DEMONSTRATED LOOP
;; -----------------
;;
;;   synthetic input bundle
;;       -> deterministic signal facts
;;       -> constitutional mode refresh
;;       -> one available candidate: respond
;;       -> bundle feasibility gate
;;       -> AttentionDirective
;;
;; The production bridge contains the full motivational cycle. This demo keeps
;; the response path deterministic so it can run offline and remain easy to
;; explain. The production candidate generator, scorer, and broader lifecycle
;; behavior continue to be tested by the other v1 test files.
;;
;; INTENTIONAL NON-GOALS
;; --------------------
;; This file does not connect to a chat channel, call an LLM, query ChromaDB,
;; persist state, execute a skill, or model every candidate and failure path.
;; It is therefore evidence of a working vertical slice, not a claim that the
;; complete OmegaClaw runtime requirements have been implemented.
;;
;; EXPECTED RESULT
;; ---------------
;; The demo prints Engaged mode, the respond candidate, an admitted action, and
;; a feasible AttentionDirective targeting demo-frame. The score is deliberately
;; fixed at 0.50 in minimalLoop so repeated runs produce identical output.

;; Explicit host sources also resolve under the workspace-local run.sh.
!(import! &self "../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../repos/OmegaClaw-Core/src/context)
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/minimal_loop))
!(initMinimalLoopFixture)

!(println! "MINIMAL-LOOP")
!(println! (Input new-message-active-task))
!(println! (Mode (constitutionalMode)))
!(println! (Candidates (car-atom (cdr-atom (demoResult)))))
!(println! (AllActionsFeasible (car-atom (cdr-atom (cdr-atom (demoResult))))))
!(println! (SelectedCandidate
   (car-atom (cdr-atom (cdr-atom (cdr-atom (demoResult)))))))
!(println! (Directive
   (car-atom (cdr-atom (cdr-atom (cdr-atom (cdr-atom (cdr-atom (demoResult)))))))))

;; ---------------------------------------------------------------------------
;; 6. Minimal contract assertions
;; ---------------------------------------------------------------------------
;; These assertions intentionally verify only the promises made by this file:
;; a valid default mode, an admitted response candidate, a non-empty result,
;; and a non-empty directive. They do not stand in for the full v1 test suite.
!(test (constitutionalMode) Engaged)
!(test (eval (feasibilityGate (minimalDemoBundle) respond))
      (GateDecision Admitted Feasible))
!(test (!= (car-atom (cdr-atom (demoResult))) ()) True)
!(test (car-atom (cdr-atom (cdr-atom (demoResult)))) True)
!(test (!= (car-atom (cdr-atom (cdr-atom (cdr-atom (demoResult))))) none) True)
!(test (!= (car-atom
         (cdr-atom (cdr-atom (cdr-atom (cdr-atom (cdr-atom (demoResult)))))))
         ()) True)
