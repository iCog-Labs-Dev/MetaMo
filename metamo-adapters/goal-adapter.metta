;; Standalone goal adapter for frame atomspaces.
;; This file intentionally does not import any project modules.

(= (goalScoreFromStatus $status)
   (if (== $status Focused) 1.0
      (if (== $status Active) 0.9
         (if (== $status Suspended) 0.5
            (if (== $status Blocked) 0.2
               0.0)))))

(= (frameToScore
      (Frame
         (frameID $frameID)
         (parent-frameID $parentFrameID)
         (source $source)
         (priority $priority)
         (goal-namespace $goalNamespace)
         (status $status)
         (frame-mode $frameMode)
         (hypotheses $hypotheses)
         (method $method)
         (history-summary $historySummary)
         (modules $modules)
         (budget $budget)
         (constraints $constraints)
         (deliverables $deliverables)
         (sub-frame-namespace $subFrameNamespace)
         (results $results)
         (created-at $createdAt)
         (updated-at $updatedAt)
         (completed-timestamp $completedTimestamp)
         (completed-summary $completedSummary)))
   (goalScoreFromStatus $status))

;; Remove frame IDs after sorting while preserving the resulting score order.
(= (frameScorePairsToScores ())
   ())

(= (frameScorePairsToScores $pairs)
   (let* (
      (($head $rest) (decons $pairs))
      ((FrameScore $_frameID $score) $head))
      (cons $score (frameScorePairsToScores $rest))))

;; Query Frame atoms, sort by frameID, and return the ordered score vector.
;; Non-Frame atoms in the same space do not match and are ignored.
(= (atomspaceToScores $atomspace)
   (frameScorePairsToScores
      (msort (collapse
      (match $atomspace
         (Frame
            (frameID $frameID)
            (parent-frameID $parentFrameID)
            (source $source)
            (priority $priority)
            (goal-namespace $goalNamespace)
            (status $status)
            (frame-mode $frameMode)
            (hypotheses $hypotheses)
            (method $method)
            (history-summary $historySummary)
            (modules $modules)
            (budget $budget)
            (constraints $constraints)
            (deliverables $deliverables)
            (sub-frame-namespace $subFrameNamespace)
            (results $results)
            (created-at $createdAt)
            (updated-at $updatedAt)
            (completed-timestamp $completedTimestamp)
            (completed-summary $completedSummary))
         (FrameScore $frameID
            (frameToScore
               (Frame
                  (frameID $frameID)
                  (parent-frameID $parentFrameID)
                  (source $source)
                  (priority $priority)
                  (goal-namespace $goalNamespace)
                  (status $status)
                  (frame-mode $frameMode)
                  (hypotheses $hypotheses)
                  (method $method)
                  (history-summary $historySummary)
                  (modules $modules)
                  (budget $budget)
                  (constraints $constraints)
                  (deliverables $deliverables)
                  (sub-frame-namespace $subFrameNamespace)
                  (results $results)
                  (created-at $createdAt)
                  (updated-at $updatedAt)
                  (completed-timestamp $completedTimestamp)
                  (completed-summary $completedSummary)))))))))

(= (goalAdapter $atomspace)
   (atomspaceToScores $atomspace))

;; Self-checks for petta.

!(bind! &goalAdapterTestSpace (new-space))
!(add-atom &goalAdapterTestSpace
   (Frame
      (frameID Frame-2)
      (parent-frameID Parent)
      (source UserDirective)
      (priority 0.8)
      (goal-namespace Goals)
      (status Completed)
      (frame-mode Fast)
      (hypotheses ())
      (method Method)
      (history-summary Summary)
      (modules Modules)
      (budget Budget)
      (constraints Constraints)
      (deliverables Deliverables)
      (sub-frame-namespace SubFrames)
      (results Results)
      (created-at Created)
      (updated-at Updated)
      (completed-timestamp ())
      (completed-summary ())))
!(add-atom &goalAdapterTestSpace
   (Frame
      (frameID Frame-1)
      (parent-frameID Parent)
      (source AgentDirective)
      (priority 0.3)
      (goal-namespace Goals)
      (status Active)
      (frame-mode Slow)
      (hypotheses ())
      (method Method)
      (history-summary Summary)
      (modules Modules)
      (budget Budget)
      (constraints Constraints)
      (deliverables Deliverables)
      (sub-frame-namespace SubFrames)
      (results Results)
      (created-at Created)
      (updated-at Updated)
      (completed-timestamp ())
      (completed-summary ())))
!(add-atom &goalAdapterTestSpace (Metadata ignored))

