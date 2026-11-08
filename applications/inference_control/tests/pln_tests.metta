!(import! &self ../pln)

(= (plnTermStv A) (stv 0.5 0.9))
(= (plnTermStv B) (stv 0.25 0.9))
(= (plnTermStv C) (stv 0.25 0.9))
(= (plnTermStv D) (stv 0.5 0.9))

(= (plnTestKb)
   ((Sentence ((Inheritance A B) (stv 0.25 0.9)) (1))
    (Sentence ((Inheritance A C) (stv 0.25 0.9)) (2))
    (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3))
    (Sentence ((Inheritance C D) (stv 0.5 0.9)) (4))))

!(test (plnTruthModusPonens (stv 0.8 0.9) (stv 0.7 0.8))
       (stv 0.564 0.7200000000000001))
(= (plnTestDeduction)
   (plnTruthDeduction
     (stv 0.2 0.9) (stv 0.3 0.9) (stv 0.4 0.9)
     (stv 0.8 0.9) (stv 0.7 0.8)))
!(test (and (> (plnTruthStrength (plnTestDeduction)) 0.61428)
            (< (plnTruthStrength (plnTestDeduction)) 0.61429))
       True)
!(test (plnTruthConfidence (plnTestDeduction)) 0.8)
!(test (plnTruthDeduction
         (stv 0.2 0.9) (stv 0.1 0.9) (stv 0.4 0.9)
         (stv 0.8 0.9) (stv 0.7 0.8))
       (stv 1.0 0.0))

!(test (plnProposePair
         (Sentence ((Inheritance A B) (stv 0.25 0.9)) (1))
         (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3)))
       (plnProposal deduction
         (Sentence ((Inheritance A B) (stv 0.25 0.9)) (1))
         (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3))))

!(test (plnApplyOne
         (plnProposal deduction
           (Sentence ((Inheritance A B) (stv 0.25 0.9)) (1))
           (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3))))
       (Sentence ((Inheritance A D) (stv 0.5 0.9)) (1 3)))

(= (plnTestTask)
   (Sentence ((Inheritance A B) (stv 0.25 0.9)) (1)))
(= (plnTestProposal)
   (plnProposal deduction
     (plnTestTask)
     (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3))))
(= (plnTestStep)
   (plnStep (plnTestKb) (plnTestKb) (plnTestTask)
             (plnTestProposal) 10 100))

!(test (length (plnPropose (plnTestKb))) 2)
!(test (length (plnProposeTask (plnTestTask) (plnTestKb))) 1)
!(test (plnStepDerived (plnTestStep))
       (Sentence ((Inheritance A D) (stv 0.5 0.9)) (1 3)))
!(test (length (plnStepTasks (plnTestStep))) 4)
!(test (length (plnStepBeliefs (plnTestStep))) 5)

!(test (plnStampDisjoint (1 2) (2 3)) False)
!(test (plnStampDisjoint (1 2) (3 4)) True)
!(test (collapse (plnProposePair (plnTestTask) (plnTestTask))) ())
!(test (collapse (plnStep (plnTestKb) (plnTestKb) (plnTestTask)
                            (plnProposal deduction (plnTestTask) (plnTestTask))
                            10 100)) ())

!(test (plnTruthRevision (stv 0.5 0.9) (stv 0.5 0.9))
       (stv 0.5 0.9473684210526316))
!(test (plnQuery (plnTestKb) (Inheritance A D))
       ((stv 0.5 0.9473684210526316) (1 2 3 4)))
!(test (plnQuery (plnTestKb) (Inheritance A D) 0) ())
!(test (plnQuery (plnTestKb) (Inheritance A D) 1)
       ((stv 0.5 0.9) (1 3)))

!(test (plnApplyOne
         (plnProposal modus-ponens
           (Sentence (A (stv 0.8 0.9)) (5))
           (Sentence ((Implication A E) (stv 0.7 0.8)) (6))))
       (Sentence (E (stv 0.564 0.7200000000000001)) (5 6)))

!(test (length (plnLimitSize (plnTestKb) 2)) 2)
!(test (length (plnLimitSize (plnTestKb) 4)) 4)
