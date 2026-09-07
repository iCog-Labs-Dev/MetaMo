;; ContextFrames integration boundary for the v1 MetaMo application.
;;
;; MetaMo does not mutate ContextFrames. It receives a small policy result and
;; emits an AttentionDirective for the scheduler/reasoner. The existing
;; candidate scorer remains the transitional S3 selector.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Bounded FrameStateBundle
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This is the sole ContextFrames -> MetaMo state boundary. The bundle contains
;; compact projections, not the raw RootFrame/current-frame cache, transcript,
;; command log, or vector-store records.
;;
;; PUBLIC API AND USAGE GUIDE
;; --------------------------
;; The main public flow is:
;;
;;   (frameStateForMetaMo)
;;       -> (frameStateForSlice <slice> $bundle)
;;       -> (contextPolicyGate $bundle <candidate>)
;;       -> (attentionDirectiveForDecision $bundle <candidate> <score>)
;;
;; Example:
;;
;;   (= (demoBundle) (frameStateForMetaMo))
;;   (frameBundleCurrentId (demoBundle))
;;   (frameStateForSlice CurrentFrameSummary (demoBundle))
;;   (contextPolicyGate (demoBundle) respond)
;;   (attentionDirectiveForDecision (demoBundle) respond 0.80)
;;
;; The predicates in this file are divided into four responsibilities:
;;
;;   1. Projection: build bounded Root/Current/Index/Runtime values.
;;   2. Access: read fields from a FrameStateBundle without raw state access.
;;   3. Policy: check frame, mode, and budget constraints for a candidate.
;;   4. Output: create an AttentionDirective for the scheduler/reasoner.
;;
;; Constructors use tagged fields deliberately. For example, a budget is
;; represented as `(ResourceBudget 10 7 units (status Open))`, and a resulting
;; directive can be inspected with `(directiveSlice $directive)` or by matching
;; its `(admission ...)` and `(reason ...)` fields.
;;
;; Exact chronological data remains in the audit substrates owned by
;; OmegaClaw/ContextFrames: history.metta, frame notes, command-batch records,
;; STM/LTM memory, and runtime logs. Those substrates are deliberately not
;; fields of FrameStateBundle.

;; Relation projection and verification evidence live in a focused submodule;
;; this file remains the compatibility façade for the complete boundary.
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_relations)
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_accessors)
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_slices)
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_policy)
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_directives)
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_projection)

