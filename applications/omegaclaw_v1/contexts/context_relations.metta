;; Advisory ContextFrames relation projection and verification evidence.
;;
;; Relations cross the ContextFrames -> MetaMo boundary as bounded evidence,
;; never as frame topology or permission to mutate a frame.

;; Accept the two relation shapes used by ContextFrames relation providers.
(= (frameStateRelationEvidence $source $target $type $evidence)
   (case $type
      ((SameFrame VerificationRequired)
       (PossibleSameFrame VerificationRequired)
       ($_ $evidence))))

(= (frameStateProjectRelation
      (FrameRelation $source $target $type $reason $confidence $evidence))
   (let $status (eval (frameStateRelationEvidence
                        $source $target $type $evidence))
      (FrameStateRelation
         (source-frame $source)
         (target-frame $target)
         (relation-type $type)
         (reason (cfv2-compact-limited $reason 240))
         (confidence $confidence)
         (evidence-status $status))))

(= (frameStateProjectRelation
      (Relation (FrameID-1 $source) (FrameID-2 $target)
                (Class $type) (Reason $reason) (Confidence $confidence)))
   (frameStateProjectRelation
      (FrameRelation $source $target $type $reason $confidence Unverified)))

(= (frameStateProjectRelation
      (Relation $source $target $type $reason $confidence $evidence))
   (frameStateProjectRelation
      (FrameRelation $source $target $type $reason $confidence $evidence)))

;; Unknown relation shapes are intentionally dropped by the projection rules;
;; no raw relation atom is allowed to cross the boundary.
(= (frameStateBoundRelations ()) ())
(= (frameStateBoundRelations $relations)
   (let* (
      (($head $tail) (decons-atom $relations))
      ($projected (frameStateProjectRelation $head)))
      (cons $projected
            (frameStateBoundRelations
               (frameStateTake (- (frameStateMaxRelations) 1) $tail)))))

;; A same-frame relation is evidence requiring verification, never permission
;; to merge or rewrite either frame.
;; Keep this as one structural rule. A broad fallback rule would overlap the
;; VerificationRequired pattern in MeTTa and produce both True and False,
;; allowing an unsafe same-frame branch to survive nondeterministic matching.
(= (relationNeedsVerification
      (FrameStateRelation $_ $_ $_ $_ $_ (evidence-status $status)))
   (== $status VerificationRequired))
(= (relationsNeedVerification ()) False)
(= (relationsNeedVerification $relations)
   (let* ((($head $tail) (decons-atom $relations)))
      (if (relationNeedsVerification $head)
          True
          (relationsNeedVerification $tail))))
(= (bundleNeedsRelationVerification $bundle)
   (relationsNeedVerification (frameBundleRelations $bundle)))

;; ---------------------------------------------------------------------------
;; Frame-state verification evidence
;; ---------------------------------------------------------------------------
;; The scheduler/ContextFrames layer supplies the result of the explicit
;; verify-frame-state operation. Unknown results are conservative and remain
;; unresolved; they can never be mistaken for confirmation.
(= (verificationEvidenceStatus $result)
   (case $result
      ((Confirmed Confirmed)
       (Refuted Refuted)
       (Unresolved Unresolved)
       ($_ Unresolved))))

(= (makeFrameVerificationEvidence
      (FrameStateRelation
         (source-frame $source)
         (target-frame $target)
         (relation-type $type)
         (reason $reason)
         (confidence $confidence)
         (evidence-status $_))
      $result)
   (FrameVerificationEvidence
      (source-frame $source)
      (target-frame $target)
      (relation-type $type)
      (reason $reason)
      (prior-confidence $confidence)
      (evidence-status (verificationEvidenceStatus $result))))

(= (frameVerificationStatus
      (FrameVerificationEvidence $_ $_ $_ $_ $_ (evidence-status $status)))
   $status)

;; Capture a typed observation without mutating the input relation. The
;; returned evidence is suitable for a scheduler audit event and is also
;; stored for later relation write-back.
!(bind! &frame-verification-evidence (new-space))
(= (captureFrameVerificationOutcome $relation $result)
   (let $evidence (makeFrameVerificationEvidence $relation $result)
      (let $_ (add-atom &frame-verification-evidence $evidence)
         $evidence)))

(= (frameVerificationEvidence)
   (collapse (match &frame-verification-evidence
      (FrameVerificationEvidence
         (source-frame $source)
         (target-frame $target)
         (relation-type $type)
         (reason $reason)
         (prior-confidence $confidence)
         (evidence-status $status))
      (FrameVerificationEvidence
         (source-frame $source)
         (target-frame $target)
         (relation-type $type)
         (reason $reason)
         (prior-confidence $confidence)
         (evidence-status $status)))))
