(: InferenceAnnotatedProposal Type)
(: inferenceAnnotatedProposal
   (-> PlnProposal Expression Expression Expression InferenceAnnotatedProposal))

(= (inferencePredictedTerm
      (plnProposal deduction
        (Sentence ((Implication $a $b) $t1) $e1)
        (Sentence ((Implication $b $c) $t2) $e2)))
   (Implication $a $c))

(= (inferencePredictedTerm
      (plnProposal deduction
        (Sentence ((Inheritance $a $b) $t1) $e1)
        (Sentence ((Inheritance $b $c) $t2) $e2)))
   (Inheritance $a $c))

(= (inferencePredictedTerm
      (plnProposal modus-ponens
        (Sentence ($a $t1) $e1)
        (Sentence ((Implication $a $b) $t2) $e2)))
   $b)

(= (inferencePredictedTerm
      (plnProposal revision
        (Sentence ($term $t1) $e1)
        (Sentence ($term $t2) $e2)))
   $term)

(= (inferenceIsBridge $predicted $query $belief)
   (case ($predicted $query $belief)
     (
       (((Implication $a $mid) (Implication $a $goal)
         (Sentence ((Implication $mid $goal) $truth) $evidence)) True)
       (((Inheritance $a $mid) (Inheritance $a $goal)
         (Sentence ((Inheritance $mid $goal) $truth) $evidence)) True)
       (($mid $goal
         (Sentence ((Implication $mid $goal) $truth) $evidence)) True)
       ($_ False))))

(= (inferenceBridgeBeliefs $predicted $query $beliefs)
   (collapse
     (let $belief (superpose $beliefs)
          (if (inferenceIsBridge $predicted $query $belief)
              $belief
              (empty)))))

(= (inferenceBridgePriority (Sentence ($term (stv $strength $confidence)) $evidence))
   $confidence)
(= (inferenceBridgePriority ()) -1.0)

(= (inferenceBestBridgeFrom $best $items)
   (if (== $items ())
       $best
       (let* (($head (car-atom $items))
              ($tail (cdr-atom $items)))
             (if (> (inferenceBridgePriority $head) (inferenceBridgePriority $best))
                 (inferenceBestBridgeFrom $head $tail)
                 (inferenceBestBridgeFrom $best $tail)))))

(= (inferenceBestBridge $predicted $query $beliefs)
   (inferenceBestBridgeFrom () (inferenceBridgeBeliefs $predicted $query $beliefs)))

(= (inferenceProposalContext
      (plnProposal $rule $first $second) $query $beliefs)
   (let* (($predicted (inferencePredictedTerm (plnProposal $rule $first $second)))
          ($bridge (inferenceBestBridge $predicted $query $beliefs)))
         (if (== $bridge ())
             ($first $second)
             (list_to_set (append ($first $second) ($bridge))))))

(= (inferenceQueryRelevance $predicted $query $bridge)
   (if (== $predicted $query)
       1.0
       (if (== $bridge ()) 0.0 0.75)))

(= (inferenceTermPresent $term $beliefs)
   (is-member True
     (collapse
       (let (Sentence ($existing $truth) $evidence) (superpose $beliefs)
            (if (== $term $existing) True (empty))))))

(= (inferenceNovelty $term $beliefs)
   (if (inferenceTermPresent $term $beliefs) 0.0 1.0))

(= (inferencePremiseConfidence
      (plnProposal $rule
        (Sentence ($term1 (stv $strength1 $confidence1)) $evidence1)
        (Sentence ($term2 (stv $strength2 $confidence2)) $evidence2)))
   (min $confidence1 $confidence2))

(= (inferenceEstimatedCost (plnProposal $type $first $second))
   (case $type (
     (deduction 0.5)
     (modus-ponens 0.25)
     (revision 0.25)
     ($_ 1.0))))

(= (inferenceProposalFeatures $proposal $query $beliefs)
   (let* (($predicted (inferencePredictedTerm $proposal))
          ($bridge (inferenceBestBridge $predicted $query $beliefs))
          ($confidence (inferencePremiseConfidence $proposal)))
         (stimulusFeatures
           ((query_relevance (inferenceQueryRelevance $predicted $query $bridge))
            (novelty (inferenceNovelty $predicted $beliefs))
            (premise_confidence $confidence)
            (estimated_cost (inferenceEstimatedCost $proposal))
            (estimated_risk (- 1.0 $confidence))))))

(= (inferenceAnnotateProposal $proposal $query $beliefs)
   (inferenceAnnotatedProposal
     $proposal
     (inferencePredictedTerm $proposal)
     (inferenceProposalContext $proposal $query $beliefs)
     (inferenceProposalFeatures $proposal $query $beliefs)))

(= (inferenceAnnotateProposals $proposals $query $beliefs)
   (collapse
     (let $proposal (superpose $proposals)
          (inferenceAnnotateProposal $proposal $query $beliefs))))

(= (inferenceAnnotationProposal (inferenceAnnotatedProposal $proposal $term $context $features))
   $proposal)
(= (inferenceAnnotationTerm (inferenceAnnotatedProposal $proposal $term $context $features))
   $term)
(= (inferenceAnnotationContext (inferenceAnnotatedProposal $proposal $term $context $features))
   $context)
(= (inferenceAnnotationFeatures (inferenceAnnotatedProposal $proposal $term $context $features))
   $features)
