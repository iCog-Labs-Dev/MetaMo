!(import! &self ../helper)
!(import! &self "../helpers.py")

!(test (listDifference (7 6 13) (4 5 6)) (3.0 1.0 7.0))
!(test (listDifference () ()) ())

!(test (norm (3 4)) 5.0)
!(test (norm ()) 0.0)

!(test (calculateNormDifference (1 2 3) (4 5 6)) 27.0)
!(test (calculateNormDifference () ()) 0.0)



!(test (normalizeVector (3 4)) (0.6 0.8))
(test (normalizeVector ()) ())

!(test (softmax (1 2 3)) (0.09003057317038046 0.24472847105479764 0.6652409557748218))

!(test (roundNum 2.67777 2) 2.68)
!(test (roundNum 0.0 2) 0.0)

!(test (split (1 2 3 4) 2) ((1 2) (3 4)))
!(test (split (1 2 3 4 5 7) 3) ((1 2) (3 4) (5 7)))
!(test (split (1 2 3 4) 4) ((1) (2) (3) (4)))
 
!(test (sum (1 2 3 4)) 10.0)
!(test (sum ()) 0.0)
!(test (sum (1)) 1.0)

!(test (product (1 2 3 4)) 24.0)
!(test (product ()) 1.0)

!(test (mean (1 2 3 4)) 2.5)
  
!(test (std (1 2 3 4)) 1.12)
 
!(test (variance (1 2 3 4)) 1.25)
!(test (variance (10)) 0.0)
!(test (variance (2 2 2)) 0.0)
!(test (variance (1.0 2.0)) 0.25)

!(test (dotProduct (1 2 3) (4 5 6)) 32.0)
!(test (dotProduct (1 0) (0 1)) 0.0)
!(test (dotProduct () ()) 0.0)

!(test (min-atom (2 6 7 4 9 3)) 2)
!(test (max-atom (2 6 7 4 9 3)) 9)
!(test (unique-atom (1 2 3 3)) (1 2 3))
!(test (union-atom (1 2 2 3) (2 3 3 4)) (1 2 2 3 2 3 3 4))
!(test (intersection-atom (1 2 3 3) (2 3 3 3 4)) (2 3 3))
!(test (sort-atom (2 6 7 4 9 3)) (2 3 4 6 7 9))
!(test (filter-atom (1 2 3 4 5) $x (> $x 3)) (4 5))
!(test (subtraction-atom (1 2 3 3) (2 3 4)) (1 3))
!(test (size-atom (1 2 3 4)) 4)
