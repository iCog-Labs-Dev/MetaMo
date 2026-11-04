!(import! &self ../pln)

(= (STV A) (stv 0.5 0.9))
(= (STV B) (stv 0.25 0.9))
(= (STV C) (stv 0.25 0.9))
(= (STV D) (stv 0.5 0.9))

(= (pln-test-kb)
   ((Sentence ((Inheritance A B) (stv 0.25 0.9)) (1))
    (Sentence ((Inheritance A C) (stv 0.25 0.9)) (2))
    (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3))
    (Sentence ((Inheritance C D) (stv 0.5 0.9)) (4))))

!(test (PLN.TruthModusPonens (stv 0.8 0.9) (stv 0.7 0.8))
       (stv 0.564 0.7200000000000001))
(= (pln-test-deduction)
   (PLN.TruthDeduction
     (stv 0.2 0.9) (stv 0.3 0.9) (stv 0.4 0.9)
     (stv 0.8 0.9) (stv 0.7 0.8)))
!(test (and (> (PLN.TruthStrength (pln-test-deduction)) 0.61428)
            (< (PLN.TruthStrength (pln-test-deduction)) 0.61429))
       True)
!(test (PLN.TruthConfidence (pln-test-deduction)) 0.8)
!(test (PLN.TruthDeduction
         (stv 0.2 0.9) (stv 0.1 0.9) (stv 0.4 0.9)
         (stv 0.8 0.9) (stv 0.7 0.8))
       (stv 1.0 0.0))

!(test (PLN.ProposePair
         (Sentence ((Inheritance A B) (stv 0.25 0.9)) (1))
         (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3)))
       (PLN.Proposal deduction
         (Sentence ((Inheritance A B) (stv 0.25 0.9)) (1))
         (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3))))

!(test (PLN.ApplyOne
         (PLN.Proposal deduction
           (Sentence ((Inheritance A B) (stv 0.25 0.9)) (1))
           (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3))))
       (Sentence ((Inheritance A D) (stv 0.5 0.9)) (1 3)))

(= (pln-test-task)
   (Sentence ((Inheritance A B) (stv 0.25 0.9)) (1)))
(= (pln-test-proposal)
   (PLN.Proposal deduction
     (pln-test-task)
     (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3))))
(= (pln-test-step)
   (PLN.Step (pln-test-kb) (pln-test-kb) (pln-test-task)
             (pln-test-proposal) 10 100))

!(test (length (PLN.Propose (pln-test-kb))) 2)
!(test (length (PLN.ProposeTask (pln-test-task) (pln-test-kb))) 1)
!(test (PLN.StepDerived (pln-test-step))
       (Sentence ((Inheritance A D) (stv 0.5 0.9)) (1 3)))
!(test (length (PLN.StepTasks (pln-test-step))) 4)
!(test (length (PLN.StepBeliefs (pln-test-step))) 5)

!(test (PLN.StampDisjoint (1 2) (2 3)) False)
!(test (PLN.StampDisjoint (1 2) (3 4)) True)
!(test (collapse (PLN.ProposePair (pln-test-task) (pln-test-task))) ())
!(test (collapse (PLN.Step (pln-test-kb) (pln-test-kb) (pln-test-task)
                            (PLN.Proposal deduction (pln-test-task) (pln-test-task))
                            10 100)) ())

!(test (PLN.TruthRevision (stv 0.5 0.9) (stv 0.5 0.9))
       (stv 0.5 0.9473684210526316))
!(test (PLN.Query (pln-test-kb) (Inheritance A D))
       ((stv 0.5 0.9473684210526316) (1 2 3 4)))
!(test (PLN.Query (pln-test-kb) (Inheritance A D) 0) ())
!(test (PLN.Query (pln-test-kb) (Inheritance A D) 1)
       ((stv 0.5 0.9) (1 3)))

!(test (PLN.ApplyOne
         (PLN.Proposal modus-ponens
           (Sentence (A (stv 0.8 0.9)) (5))
           (Sentence ((Implication A E) (stv 0.7 0.8)) (6))))
       (Sentence (E (stv 0.564 0.7200000000000001)) (5 6)))

!(test (length (PLN.LimitSize (pln-test-kb) 2)) 2)
!(test (length (PLN.LimitSize (pln-test-kb) 4)) 4)
