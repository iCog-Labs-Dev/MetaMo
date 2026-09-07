;; AttentionDirective construction and scheduler-facing policy output.
;;
;; This module converts an admitted policy result into typed advisory output;
;; it does not execute operations or mutate ContextFrames.

!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_accessors)
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_policy)


!(bind! &last-attention-directive
   (new-state
      (AttentionDirective
         (target ())
         (slice None)
         (task none)
         (admission Rejected)
         (priority 0)
         (source MetaMo))))

(= (directiveSlice $candidate)
   (case $candidate
      ((retrieve-memory CurrentFrameAndRelations)
       (search-knowledge CurrentFrameAndRelations)
       (verify-frame-state CurrentFrameAndRelations)
       (background-work CurrentFrameTask)
       (execute-skill CurrentFrameTask)
       (learn CurrentFrameSummary)
       (self-improve CurrentFrameSummary)
       ($_ CurrentFrameSummary))))

;; Explicit scheduler operation for relation evidence that could imply a
;; same-frame judgment. Verification must publish evidence before any merge,
;; rewrite, switch, or action is allowed to rely on the relation.
(= (frameStateVerificationOperation) verify-frame-state)

;; Directive priority is deliberately separate from frame priority and
;; candidate score. It is a bounded scheduler hint derived from both inputs;
;; neither source value is overwritten.
(= (directivePriority $bundle $score)
   (let $framePriority (bundle-current-priority $bundle)
      (clampValue (+ (* 0.70 $score) (* 0.30 $framePriority)))))

(= (makeAttentionDirective $bundle $candidate $score)
   ;; Example:
   ;;   `(makeAttentionDirective $bundle respond 0.80)` returns a typed
   ;;   AttentionDirective containing target, slice, task, admission, reason,
   ;;   bounded priority, and source fields.
   (let* (
      ($gate (feasibilityGate $bundle $candidate))
      ((GateDecision $admission $reason) $gate)
      ($target (if (!= (frameBundleCurrentId $bundle) ())
                   (frameBundleCurrentId $bundle)
                   ()))
      ($priority (if (== $admission Admitted)
                     (directivePriority $bundle $score)
                     0))
   )
      (AttentionDirective
         (target $target)
         (slice (directiveSlice $candidate))
         (task $candidate)
         (admission $admission)
         (reason $reason)
         (priority $priority)
         (source MetaMo))))

(= (attentionDirectiveForDecision $bundle $candidate $score)
   ;; Public facade used by the bridge after candidate selection:
   ;;   `(attentionDirectiveForDecision $bundle $candidate $score)`.
   ;; Prefer this name at call sites so the decision-to-scheduler contract is
   ;; clear even if directive construction changes internally.
   (makeAttentionDirective $bundle $candidate $score))

;; Public MetaMo -> scheduler contract. Internal decision/action structures
;; remain available to the motivational dynamics, but this is the only policy
;; result exposed across the integration boundary.
(= (metaMoPolicyOutput $bundle $candidate $score)
   (let* (
      ($directive (attentionDirectiveForDecision $bundle $candidate $score))
      ((AttentionDirective $_ $_ $_ (admission $admission) $_
          (priority $priority) $_) $directive))
      (MetaMoPolicyOutput
         (mode (constitutionalMode))
         (operation-class $candidate)
         (feasibility $admission)
         (priority $priority))))

(= (policyOutputOperation
      (MetaMoPolicyOutput $_ (operation-class $operation) $_ $_))
   $operation)
(= (policyOutputMode
      (MetaMoPolicyOutput (mode $mode) $_ $_ $_))
   $mode)
(= (policyOutputFeasibility
      (MetaMoPolicyOutput $_ $_ (feasibility $feasibility) $_))
   $feasibility)
(= (policyOutputPriority
      (MetaMoPolicyOutput $_ $_ $_ (priority $priority)))
   $priority)

;; Scheduler-facing adapter. MetaMo supplies policy fields; the scheduler
;; receives a typed AttentionDirective and remains responsible for resolving
;; the operation class into a concrete handler.
(= (schedulerAttentionDirective
      $bundle
      (MetaMoPolicyOutput $_ (operation-class $operation)
         (feasibility $feasibility) (priority $priority)))
   (AttentionDirective
      (target (frameBundleCurrentId $bundle))
      (slice (directiveSlice $operation))
      (task $operation)
      (admission $feasibility)
      (reason (if (== $feasibility Admitted) Feasible PolicyRejected))
      (priority $priority)
      (source MetaMo)))

(= (lastAttentionDirective)
   ;; Example: `(lastAttentionDirective)` reads the most recently published
   ;; directive. It is initialized to a rejected `none` directive at startup.
   (get-state &last-attention-directive))

