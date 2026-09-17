;; Common concrete request gate. Import after context_policy/accessors.
;; Origin/target bundles and resolved policies are supplied by the host for
;; one revision. This module never switches frames or changes host modes.

(= (requestOperation $operation)
   (case $operation (
      ((ModeOperation $_ $inner) $inner)
      ($_ $operation))))

(= (requestCandidateValid $candidate)
   (tpContains (respond retrieve-memory search-knowledge execute-skill learn
      self-improve background-work recall-goals invent-goal plan-goal
      repair-failure defer verify-frame-state ask-clarification) $candidate))

(= (requestBundleShapeValid $bundle)
   (case $bundle (
      ((FrameStateBundle (root (FrameStateRoot $_ $_ (mode $rootMode) $_ $_))
          (current (FrameStateCurrent (id $id) (parent $_) $_ (status $status)
             (frame-mode $mode) (priority $_) $_ $_ $_ $_ $_ $_ $_))
          $_ (relations $_) (runtime $_))
       (tpAllTrue ((tpId $id) (tpContains (Fast Slow) $rootMode)
          (tpContains (Fast Slow) $mode)
          (tpContains (Active Focused Completed Blocked Abandoned Superseded) $status))))
      ($_ False))))

(= (requestFrameReason $origin $target $requested)
   (case $requested (
      (current-frame
       (if (== (frameBundleCurrentId $origin) (frameBundleCurrentId $target))
           Feasible TargetMismatch))
      ((FrameTarget $id)
       (if (== $id (frameBundleCurrentId $target)) Feasible TargetMismatch))
      ($_ InvalidTarget))))

(= (requestTargetReason $origin $target $kind $requested $operation)
   (case $kind (
      (propose-candidate (requestFrameReason $origin $target $requested))
      (request-attention (requestFrameReason $origin $target $requested))
      (request-frame-switch (case $requested (
         ((FrameTarget $id)
          (if (== $id (frameBundleCurrentId $target)) Feasible TargetMismatch))
         ($_ InvalidTarget))))
      (request-mode-change (case $requested (
         ((ModeTarget $mode)
          (if (tpContains (Fast Slow) $mode)
              (case $operation (
                 ((ModeOperation $actual $_)
                  (if (== $actual $mode) Feasible ModeMismatch))
                 ($_ MissingModeOperation)))
              InvalidTarget))
         ($_ InvalidTarget))))
      ($_ UnsupportedRequest))))

(= (requestHandlerReason $kind $operation)
   (let (PolicyOperation $_ $_ (skill $skill) (permissions $permissions) $_ $_)
           (requestOperation $operation)
      (case $kind (
         (request-frame-switch
          (case $operation (
             ((ModeOperation $_ $_) OperationMismatch)
             ($_ (if (!= $skill "switch-frame") OperationMismatch
                    (if (tpContains $permissions "frames.switch-frame") Feasible PermissionDenied))))))
         (request-mode-change
          (if (!= $skill "switch-mode") OperationMismatch
              (if (tpContains $permissions "frames.switch-mode") Feasible PermissionDenied)))
         ($_ (case $operation (
            ((ModeOperation $_ $_) OperationMismatch)
            ($_ (if (tpContains ("switch-frame" "switch-mode") $skill)
                    OperationMismatch Feasible)))))))))

(= (requestFrameStateReason $origin $target $kind $requested)
   (if (not (frameBundleHasCurrent $target)) NoActiveFrame
       (if (not (frameBundleActive $target)) InactiveFrame
           (let $requiredMode
                   (if (== $kind request-mode-change)
                       (index-atom $requested 1) (frameBundleRootMode $origin))
              (if (== (frameBundleCurrentMode $target) $requiredMode)
                  Feasible FrameModeMismatch)))))

(= (requestPolicyReason $origin $target $kind $requested $candidate $operation $global $frame)
   (let* (
      ((GateDecision $admission $reason)
         (typedOperationPolicyGate $global $frame (requestOperation $operation)
            $candidate (frameBundleCurrentId $target)))
      ($targetReason (requestTargetReason $origin $target $kind $requested $operation)))
      (if (== $admission Rejected) $reason
          (if (!= $targetReason Feasible) $targetReason
              (let $handlerReason (requestHandlerReason $kind $operation)
                 (if (!= $handlerReason Feasible) $handlerReason
                     (requestFrameStateReason $origin $target $kind $requested)))))))

(= (requestAdmissionValidated $origin $target $request $operation $global $frame)
   (case $request (
      ((AdmissionRequest $kind $requested $candidate)
       (let $reason (requestPolicyReason $origin $target $kind $requested
                      $candidate $operation $global $frame)
          (if (!= $reason Feasible)
              (GateDecision Rejected $reason)
              ;; Transitions cannot inherit defer's exemption from Sleep.
              (if (tpContains (request-frame-switch request-mode-change) $kind)
                  (constitutionalModeGate execute-skill)
                  (constitutionalModeGate $candidate)))))
      ($_ (GateDecision Rejected InvalidRequest)))))

(= (requestAdmissionForCandidate $origin $target $request $operation $global $frame)
   (case $request (
      ((AdmissionRequest $_ $_ $candidate)
       (if (requestCandidateValid $candidate)
           (requestAdmissionValidated $origin $target $request $operation $global $frame)
           (GateDecision Rejected InvalidCandidate)))
      ($_ (GateDecision Rejected InvalidRequest)))))

(= (feasibilityGateForRequest $origin $target $request $operation $global $frame)
   (if (not (is-ground ($origin $target $request $operation $global $frame)))
       (GateDecision Rejected InvalidRequest)
       (if (not (requestBundleShapeValid $origin))
           (GateDecision Rejected InvalidOriginSnapshot)
           (if (not (requestBundleShapeValid $target))
               (GateDecision Rejected InvalidTargetSnapshot)
               (requestAdmissionForCandidate $origin $target $request $operation $global $frame)))))
