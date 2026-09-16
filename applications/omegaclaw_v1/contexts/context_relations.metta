;; Advisory ContextFrames relation projection and verification evidence.
;;
;; Relations cross the ContextFrames -> MetaMo boundary as bounded evidence,
;; never as frame topology or permission to mutate a frame.

(= (frameStateMaxRelations) 10)
;; Stop on either bound without overlapping base clauses. Empty and short
;; input lists must return one prefix rather than fail during deconstruction.
(= (frameStateTake $n $items)
   (if (or (<= $n 0) (== $items ()))
       ()
       (let* (
          (($head $tail) (decons-atom $items))
          ($rest (frameStateTake (- $n 1) $tail)))
          (cons-atom $head $rest))))

;; Choose the evidence status exposed to MetaMo. SameFrame and
;; PossibleSameFrame always become VerificationRequired; this currently
;; overrides even supplied Confirmed/Refuted evidence. Other relation types
;; retain their supplied status. The source/target arguments are not inspected.
(= (frameStateRelationEvidence $source $target $type $evidence)
   (case $type
      ((SameFrame VerificationRequired)
       (PossibleSameFrame VerificationRequired)
       ($_ $evidence))))

;; Project a positional FrameRelation into the named fields of
;; FrameStateRelation used by MetaMo. Preserve source/target IDs, relation type,
;; and confidence; compact the reason to a 240-character excerpt with a digest
;; and original-length prefix (the full field can exceed 240 characters). Derive
;; the evidence status using frameStateRelationEvidence above. This conversion
;; neither verifies the relation nor mutates either frame.
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

;; Core's relation provider emits this named-field Relation shape without an
;; evidence status. Supply Unverified, then use the common projection above
;; (which changes it to VerificationRequired for the two same-frame types).
(= (frameStateProjectRelation
      (Relation (FrameID-1 $source) (FrameID-2 $target)
                (Class $type) (Reason $reason) (Confidence $confidence)))
   (frameStateProjectRelation
      (FrameRelation $source $target $type $reason $confidence Unverified)))

;; Also accept the positional Relation spelling, forwarding its explicit
;; evidence status through the same projection and status-selection rule.
(= (frameStateProjectRelation
      (Relation $source $target $type $reason $confidence $evidence))
   (frameStateProjectRelation
      (FrameRelation $source $target $type $reason $confidence $evidence)))

;; Only the three shapes above have projection rules. There is no explicit
;; fallback returning () for unknown shapes, nor an explicit filter here;
;; unsupported input therefore must not be assumed to be safely dropped.
(= (frameStateBoundRelations ()) ())
(= (frameStateBoundRelations $relations)
   (let* (
      (($head $tail) (decons-atom $relations))
      ($projected (frameStateProjectRelation $head)))
      (cons-atom $projected
            (frameStateBoundRelations
               (eval (frameStateTake (- (frameStateMaxRelations) 1) $tail))))))

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
      (if (eval (relationNeedsVerification $head))
          True
          (eval (relationsNeedVerification $tail)))))
(= (bundleNeedsRelationVerification $bundle)
   (let (FrameStateBundle $_ $_ $_ (relations $relations) $_)
        (eval $bundle)
      (eval (relationsNeedVerification $relations))))

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

(= (frameVerificationStatus $evidence)
   (let (FrameVerificationEvidence $_ $_ $_ $_ $_ (evidence-status $status))
        $evidence
      $status))

;; Capture a typed observation without mutating the input relation. The
;; returned evidence is suitable for a scheduler audit event and is also
;; stored for later relation write-back.
!(bind! &frame-verification-evidence (new-space))
(= (captureFrameVerificationOutcome $relation $result)
   (let $evidence
         (makeFrameVerificationEvidence (eval $relation) $result)
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
