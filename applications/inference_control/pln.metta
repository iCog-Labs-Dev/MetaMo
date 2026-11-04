;; Sentence: (Sentence (term (stv strength confidence)) evidence-ids).
;; Proposal: (PLN.Proposal rule first-sentence second-sentence).

(= (PLN.TruthStrength (stv $strength $confidence)) $strength)
(= (PLN.TruthConfidence (stv $strength $confidence)) $confidence)

(= (PLN.Clamp $v $lo $hi) (min $hi (max $lo $v)))

(= (PLN.SmallestIntersection $a $b)
   (PLN.Clamp (/ (- (+ $a $b) 1.0) $a) 0.0 1.0))

(= (PLN.LargestIntersection $a $b)
   (PLN.Clamp (/ $b $a) 0.0 1.0))

(= (PLN.ConditionalConsistent $a $b $conditional)
   (if (<= $a 0.0)
       False
       (and (<= (PLN.SmallestIntersection $a $b) $conditional)
            (<= $conditional (PLN.LargestIntersection $a $b)))))

;; Inconsistent term probabilities yield zero confidence.
(= (PLN.TruthDeduction (stv $as $ac)
                       (stv $bs $bc)
                       (stv $cs $cc)
                       (stv $abs $abc)
                       (stv $bcs $bcc))
   (if (and (PLN.ConditionalConsistent $as $bs $abs)
            (PLN.ConditionalConsistent $bs $cs $bcs))
       (stv (if (> $bs 0.9999)
                $cs
                (+ (* $abs $bcs)
                   (/ (* (- 1.0 $abs) (- $cs (* $bs $bcs)))
                      (- 1.0 $bs))))
            (min $ac (min $bc (min $cc (min $abc $bcc)))))
       (stv 1.0 0.0)))

(= (PLN.TruthModusPonens (stv $f1 $c1) (stv $f2 $c2))
   (stv (+ (* $f1 $f2) (* 0.02 (- 1.0 $f1)))
        (* $c1 $c2)))

;; Exact-confidence premises avoid division by zero during revision.
(= (PLN.TruthRevision (stv $s1 $c1) (stv $s2 $c2))
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

(= (PLN.StampDisjoint $left $right)
   (== ()
       (collapse (let* (($x (superpose $left))
                        ($y (superpose $right)))
                      (case (== $x $y) ((True True)))))))

(= (PLN.StampUnion $left $right)
   (msort (append $left $right)))

;; Match premises without computing truth values.
(= (PLN.ProposePair $first $second)
   (case ($first $second)
     (
       (((Sentence ((Implication $a $b) $t1) $e1)
         (Sentence ((Implication $b $c) $t2) $e2))
        (if (PLN.StampDisjoint $e1 $e2)
            (PLN.Proposal deduction $first $second)
            (empty)))
       (((Sentence ((Inheritance $a $b) $t1) $e1)
         (Sentence ((Inheritance $b $c) $t2) $e2))
        (if (PLN.StampDisjoint $e1 $e2)
            (PLN.Proposal deduction $first $second)
            (empty)))
       (((Sentence ($term $t1) $e1)
         (Sentence ($term $t2) $e2))
        (if (PLN.StampDisjoint $e1 $e2)
            (PLN.Proposal revision $first $second)
            (empty)))
       (((Sentence ($a $t1) $e1)
         (Sentence ((Implication $a $b) $t2) $e2))
        (if (PLN.StampDisjoint $e1 $e2)
            (PLN.Proposal modus-ponens $first $second)
            (empty)))
       ($_ (empty)))))

(= (PLN.Propose $beliefs)
   (collapse (let* (($first (superpose $beliefs))
                    ($second (superpose $beliefs)))
                  (PLN.ProposePair $first $second))))

(= (PLN.ApplyOne
      (PLN.Proposal deduction
        (Sentence ((Implication $a $b) $t1) $e1)
        (Sentence ((Implication $b $c) $t2) $e2)))
   (if (PLN.StampDisjoint $e1 $e2)
       (Sentence ((Implication $a $c)
                  (PLN.TruthDeduction (STV $a) (STV $b) (STV $c) $t1 $t2))
                 (PLN.StampUnion $e1 $e2))
       (empty)))

(= (PLN.ApplyOne
      (PLN.Proposal deduction
        (Sentence ((Inheritance $a $b) $t1) $e1)
        (Sentence ((Inheritance $b $c) $t2) $e2)))
   (if (PLN.StampDisjoint $e1 $e2)
       (Sentence ((Inheritance $a $c)
                  (PLN.TruthDeduction (STV $a) (STV $b) (STV $c) $t1 $t2))
                 (PLN.StampUnion $e1 $e2))
       (empty)))

(= (PLN.ApplyOne
      (PLN.Proposal modus-ponens
        (Sentence ($a $t1) $e1)
        (Sentence ((Implication $a $b) $t2) $e2)))
   (if (PLN.StampDisjoint $e1 $e2)
       (Sentence ($b (PLN.TruthModusPonens $t1 $t2))
                 (PLN.StampUnion $e1 $e2))
       (empty)))

(= (PLN.ApplyOne
      (PLN.Proposal revision
        (Sentence ($term $t1) $e1)
        (Sentence ($term $t2) $e2)))
   (if (PLN.StampDisjoint $e1 $e2)
       (Sentence ($term (PLN.TruthRevision $t1 $t2))
                 (PLN.StampUnion $e1 $e2))
       (empty)))

;; Consider both premise orders for a selected task.
(= (PLN.ProposeTask $task $beliefs)
   (collapse (let $belief (superpose $beliefs)
                  (superpose ((PLN.ProposePair $task $belief)
                              (PLN.ProposePair $belief $task))))))

;; Keep exactly the requested queue limit.
(= (PLN.PriorityRank (Sentence ($term (stv $s $c)) $evidence)) $c)
(= (PLN.PriorityRank ()) -99999.0)
(= (PLN.NegPriorityRank (Sentence ($term (stv $s $c)) $evidence)) (- 0.0 $c))
(= (PLN.NegPriorityRank ()) -99999.0)

(= (PLN.BestCandidate $rank $best $items)
   (if (== $items ())
       $best
       (let* (($head (car-atom $items))
              ($tail (cdr-atom $items)))
             (if (> ($rank $head) ($rank $best))
                 (PLN.BestCandidate $rank $head $tail)
                 (PLN.BestCandidate $rank $best $tail)))))

(= (PLN.LimitSize $items $limit)
   (if (<= (length $items) $limit)
       $items
       (let $lowest (PLN.BestCandidate PLN.NegPriorityRank () $items)
            (PLN.LimitSize (exclude-item $lowest $items) $limit))))

(= (PLN.CommitOne $tasks $beliefs $selectedTask $derived $taskLimit $beliefLimit)
   (let* (($remaining (exclude-item $selectedTask $tasks))
          ($nextTasks (PLN.LimitSize
                        (list_to_set (append $remaining ($derived))) $taskLimit))
          ($nextBeliefs (PLN.LimitSize
                          (list_to_set (append $beliefs ($derived))) $beliefLimit)))
         ($nextTasks $nextBeliefs)))

(= (PLN.Step $tasks $beliefs $selectedTask $proposal $taskLimit $beliefLimit)
   (let $eligible (PLN.ProposeTask $selectedTask $beliefs)
        (if (is-member $proposal $eligible)
            (let $derived (PLN.ApplyOne $proposal)
                 (let ($nextTasks $nextBeliefs)
                      (PLN.CommitOne $tasks $beliefs $selectedTask $derived $taskLimit $beliefLimit)
                      (PLN.StepResult $derived $nextTasks $nextBeliefs)))
            (empty))))

(= (PLN.StepDerived (PLN.StepResult $derived $tasks $beliefs)) $derived)
(= (PLN.StepTasks (PLN.StepResult $derived $tasks $beliefs)) $tasks)
(= (PLN.StepBeliefs (PLN.StepResult $derived $tasks $beliefs)) $beliefs)

(= (PLN.Config.MaxSteps) 100)
(= (PLN.Config.TaskQueueSize) 10)
(= (PLN.Config.BeliefQueueSize) 100)

(= (PLN.ExpandTask $task $beliefs)
   (let $proposals (PLN.ProposeTask $task $beliefs)
        (collapse (let $proposal (superpose $proposals)
                       (PLN.ApplyOne $proposal)))))

(= (PLN.Derive $tasks $beliefs $steps $maxSteps $taskLimit $beliefLimit)
   (if (or (>= $steps $maxSteps) (== $tasks ()))
       ($tasks $beliefs)
       (let* (($selected (PLN.BestCandidate PLN.PriorityRank () $tasks))
              ($derivations (PLN.ExpandTask $selected $beliefs))
              ($remaining (exclude-item $selected $tasks))
              ($nextTasks (PLN.LimitSize
                            (list_to_set (append $remaining $derivations)) $taskLimit))
              ($nextBeliefs (PLN.LimitSize
                              (list_to_set (append $beliefs $derivations)) $beliefLimit)))
             (PLN.Derive $nextTasks $nextBeliefs (+ $steps 1)
                         $maxSteps $taskLimit $beliefLimit))))

(= (PLN.Answer $beliefs $term)
   (let* (($matches
            (collapse (let (Sentence ($candidate $truth) $evidence)
                           (superpose $beliefs)
                           (if (== $candidate $term)
                               (Sentence ($candidate $truth) $evidence)
                               (empty)))))
          ($best (PLN.BestCandidate PLN.PriorityRank () $matches)))
         (case $best
           (((Sentence ($candidate $truth) $evidence) ($truth $evidence))
            ($_ ())))))

(= (PLN.Query $tasks $beliefs $term $maxSteps $taskLimit $beliefLimit)
   (let ($tasksOut $beliefsOut)
        (PLN.Derive $tasks $beliefs 0 $maxSteps $taskLimit $beliefLimit)
        (PLN.Answer $beliefsOut $term)))

(= (PLN.Query $beliefs $term $maxSteps $taskLimit $beliefLimit)
   (PLN.Query $beliefs $beliefs $term $maxSteps $taskLimit $beliefLimit))

(= (PLN.Query $beliefs $term $maxSteps)
   (PLN.Query $beliefs $term $maxSteps
              (PLN.Config.TaskQueueSize) (PLN.Config.BeliefQueueSize)))

(= (PLN.Query $beliefs $term)
   (PLN.Query $beliefs $term (PLN.Config.MaxSteps)))
