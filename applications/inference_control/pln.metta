;; Sentence: (Sentence (term (stv strength confidence)) evidence-ids).
;; Proposal: (plnProposal rule first-sentence second-sentence).

(: PlnProposal Type)
(: plnProposal (-> Symbol Expression Expression PlnProposal))

(: PlnStepResult Type)
(: plnStepResult (-> Expression Expression Expression PlnStepResult))

(= (plnTruthStrength (stv $strength $confidence)) $strength)
(= (plnTruthConfidence (stv $strength $confidence)) $confidence)

(= (plnClamp $v $lo $hi) (min $hi (max $lo $v)))

(= (plnSmallestIntersection $a $b)
   (plnClamp (/ (- (+ $a $b) 1.0) $a) 0.0 1.0))

(= (plnLargestIntersection $a $b)
   (plnClamp (/ $b $a) 0.0 1.0))

(= (plnConditionalConsistent $a $b $conditional)
   (if (<= $a 0.0)
       False
       (and (<= (plnSmallestIntersection $a $b) $conditional)
            (<= $conditional (plnLargestIntersection $a $b)))))

;; Inconsistent term probabilities yield zero confidence.
(= (plnTruthDeduction (stv $as $ac)
                       (stv $bs $bc)
                       (stv $cs $cc)
                       (stv $abs $abc)
                       (stv $bcs $bcc))
   (if (and (plnConditionalConsistent $as $bs $abs)
            (plnConditionalConsistent $bs $cs $bcs))
       (stv (if (> $bs 0.9999)
                $cs
                (+ (* $abs $bcs)
                   (/ (* (- 1.0 $abs) (- $cs (* $bs $bcs)))
                      (- 1.0 $bs))))
            (min $ac (min $bc (min $cc (min $abc $bcc)))))
       (stv 1.0 0.0)))

(= (plnTruthModusPonens (stv $f1 $c1) (stv $f2 $c2))
   (stv (+ (* $f1 $f2) (* 0.02 (- 1.0 $f1)))
        (* $c1 $c2)))

;; Exact-confidence premises avoid division by zero during revision.
(= (plnTruthRevision (stv $s1 $c1) (stv $s2 $c2))
   (if (>= $c1 1.0)
       (stv $s1 $c1)
       (if (>= $c2 1.0)
           (stv $s2 $c2)
           (let* (($w1 (/ $c1 (- 1.0 $c1)))
                  ($w2 (/ $c2 (- 1.0 $c2)))
                  ($w (+ $w1 $w2)))
                 (if (<= $w 0.0)
                     (stv 0.5 0.0)
                     (stv (/ (+ (* $w1 $s1) (* $w2 $s2)) $w)
                          (/ $w (+ $w 1.0))))))))

(= (plnStampDisjoint $left $right)
   (== ()
       (collapse (let* (($x (superpose $left))
                        ($y (superpose $right)))
                      (case (== $x $y) ((True True)))))))

(= (plnStampUnion $left $right)
   (msort (append $left $right)))

;; Match premises without computing truth values.
(= (plnProposePair $first $second)
   (case ($first $second)
     (
       (((Sentence ((Implication $a $b) $t1) $e1)
         (Sentence ((Implication $b $c) $t2) $e2))
        (if (plnStampDisjoint $e1 $e2)
            (plnProposal deduction $first $second)
            (empty)))
       (((Sentence ((Inheritance $a $b) $t1) $e1)
         (Sentence ((Inheritance $b $c) $t2) $e2))
        (if (plnStampDisjoint $e1 $e2)
            (plnProposal deduction $first $second)
            (empty)))
       (((Sentence ($term $t1) $e1)
         (Sentence ($term $t2) $e2))
        (if (plnStampDisjoint $e1 $e2)
            (plnProposal revision $first $second)
            (empty)))
       (((Sentence ($a $t1) $e1)
         (Sentence ((Implication $a $b) $t2) $e2))
        (if (plnStampDisjoint $e1 $e2)
            (plnProposal modus-ponens $first $second)
            (empty)))
       ($_ (empty)))))

(= (plnPropose $beliefs)
   (collapse (let* (($first (superpose $beliefs))
                    ($second (superpose $beliefs)))
                  (plnProposePair $first $second))))

(= (plnApplyOne
      (plnProposal deduction
        (Sentence ((Implication $a $b) $t1) $e1)
        (Sentence ((Implication $b $c) $t2) $e2)))
   (if (plnStampDisjoint $e1 $e2)
       (Sentence ((Implication $a $c)
                  (plnTruthDeduction (plnTermStv $a) (plnTermStv $b) (plnTermStv $c) $t1 $t2))
                 (plnStampUnion $e1 $e2))
       (empty)))

(= (plnApplyOne
      (plnProposal deduction
        (Sentence ((Inheritance $a $b) $t1) $e1)
        (Sentence ((Inheritance $b $c) $t2) $e2)))
   (if (plnStampDisjoint $e1 $e2)
       (Sentence ((Inheritance $a $c)
                  (plnTruthDeduction (plnTermStv $a) (plnTermStv $b) (plnTermStv $c) $t1 $t2))
                 (plnStampUnion $e1 $e2))
       (empty)))

(= (plnApplyOne
      (plnProposal modus-ponens
        (Sentence ($a $t1) $e1)
        (Sentence ((Implication $a $b) $t2) $e2)))
   (if (plnStampDisjoint $e1 $e2)
       (Sentence ($b (plnTruthModusPonens $t1 $t2))
                 (plnStampUnion $e1 $e2))
       (empty)))

(= (plnApplyOne
      (plnProposal revision
        (Sentence ($term $t1) $e1)
        (Sentence ($term $t2) $e2)))
   (if (plnStampDisjoint $e1 $e2)
       (Sentence ($term (plnTruthRevision $t1 $t2))
                 (plnStampUnion $e1 $e2))
       (empty)))

;; Consider both premise orders for a selected task.
(= (plnProposeTask $task $beliefs)
   (collapse (let $belief (superpose $beliefs)
                  (superpose ((plnProposePair $task $belief)
                              (plnProposePair $belief $task))))))

;; Keep exactly the requested queue limit.
(= (plnPriorityRank (Sentence ($term (stv $s $c)) $evidence)) $c)
(= (plnPriorityRank ()) -99999.0)
(= (plnNegPriorityRank (Sentence ($term (stv $s $c)) $evidence)) (- 0.0 $c))
(= (plnNegPriorityRank ()) -99999.0)

(= (plnBestCandidate $rank $best $items)
   (if (== $items ())
       $best
       (let* (($head (car-atom $items))
              ($tail (cdr-atom $items)))
             (if (> ($rank $head) ($rank $best))
                 (plnBestCandidate $rank $head $tail)
                 (plnBestCandidate $rank $best $tail)))))

(= (plnLimitSize $items $limit)
   (if (<= (length $items) $limit)
       $items
       (let $lowest (plnBestCandidate plnNegPriorityRank () $items)
            (plnLimitSize (exclude-item $lowest $items) $limit))))

(= (plnCommitOne $tasks $beliefs $selectedTask $derived $taskLimit $beliefLimit)
   (let* (($remaining (exclude-item $selectedTask $tasks))
          ($nextTasks (plnLimitSize
                        (list_to_set (append $remaining ($derived))) $taskLimit))
          ($nextBeliefs (plnLimitSize
                          (list_to_set (append $beliefs ($derived))) $beliefLimit)))
         ($nextTasks $nextBeliefs)))

(= (plnStep $tasks $beliefs $selectedTask $proposal $taskLimit $beliefLimit)
   (let $eligible (plnProposeTask $selectedTask $beliefs)
        (if (is-member $proposal $eligible)
            (let $derived (plnApplyOne $proposal)
                 (let ($nextTasks $nextBeliefs)
                      (plnCommitOne $tasks $beliefs $selectedTask $derived $taskLimit $beliefLimit)
                      (plnStepResult $derived $nextTasks $nextBeliefs)))
            (empty))))

(= (plnStepDerived (plnStepResult $derived $tasks $beliefs)) $derived)
(= (plnStepTasks (plnStepResult $derived $tasks $beliefs)) $tasks)
(= (plnStepBeliefs (plnStepResult $derived $tasks $beliefs)) $beliefs)

(= (PLN_MAX_STEPS) 100)
(= (PLN_TASK_QUEUE_SIZE) 10)
(= (PLN_BELIEF_QUEUE_SIZE) 100)

(= (plnExpandTask $task $beliefs)
   (let $proposals (plnProposeTask $task $beliefs)
        (collapse (let $proposal (superpose $proposals)
                       (plnApplyOne $proposal)))))

(= (plnDerive $tasks $beliefs $steps $maxSteps $taskLimit $beliefLimit)
   (if (or (>= $steps $maxSteps) (== $tasks ()))
       ($tasks $beliefs)
       (let* (($selected (plnBestCandidate plnPriorityRank () $tasks))
              ($derivations (plnExpandTask $selected $beliefs))
              ($remaining (exclude-item $selected $tasks))
              ($nextTasks (plnLimitSize
                            (list_to_set (append $remaining $derivations)) $taskLimit))
              ($nextBeliefs (plnLimitSize
                              (list_to_set (append $beliefs $derivations)) $beliefLimit)))
             (plnDerive $nextTasks $nextBeliefs (+ $steps 1)
                         $maxSteps $taskLimit $beliefLimit))))

(= (plnAnswer $beliefs $term)
   (let* (($matches
            (collapse (let (Sentence ($candidate $truth) $evidence)
                           (superpose $beliefs)
                           (if (== $candidate $term)
                               (Sentence ($candidate $truth) $evidence)
                               (empty)))))
          ($best (plnBestCandidate plnPriorityRank () $matches)))
         (case $best
           (((Sentence ($candidate $truth) $evidence) ($truth $evidence))
            ($_ ())))))

(= (plnQuery $tasks $beliefs $term $maxSteps $taskLimit $beliefLimit)
   (let ($tasksOut $beliefsOut)
        (plnDerive $tasks $beliefs 0 $maxSteps $taskLimit $beliefLimit)
        (plnAnswer $beliefsOut $term)))

(= (plnQuery $beliefs $term $maxSteps $taskLimit $beliefLimit)
   (plnQuery $beliefs $beliefs $term $maxSteps $taskLimit $beliefLimit))

(= (plnQuery $beliefs $term $maxSteps)
   (plnQuery $beliefs $term $maxSteps
              (PLN_TASK_QUEUE_SIZE) (PLN_BELIEF_QUEUE_SIZE)))

(= (plnQuery $beliefs $term)
   (plnQuery $beliefs $term (PLN_MAX_STEPS)))
