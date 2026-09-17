;; Pure typed policy checks on PeTTa. Operation metadata must be supplied by
;; trusted host handlers, not inferred from a candidate or reasoner claim.
;; These checks neither execute work nor reserve or mutate resource budgets.

(= (tpId $x)
   (if (== (get-type $x) String) (!= $x "") False))
(= (tpQuantity $x)
   (if (== (get-type $x) Number)
       (and (>= $x 0) (<= $x 9007199254740991)) False))
(= (tpContains $items $x)
   (if (== $items ()) False
       (let ($head $tail) (decons-atom $items)
          (if (== $head $x) True (tpContains $tail $x)))))
(= (tpKey $kind $entry)
   (if (== $kind ids) $entry (index-atom $entry 1)))
(= (tpEntryValid $kind $entry)
   (case $kind (
      (ids (tpId $entry))
      (costs (case $entry (
         ((ResourceCost $resource $unit $amount)
          (and (tpId $resource) (and (tpId $unit) (tpQuantity $amount))))
         ($_ False))))
      (budgets (case $entry (
         ((ResourceBudget $resource $unit $amount $status)
          (and (tpId $resource)
             (and (tpId $unit)
                (and (tpQuantity $amount)
                     (tpContains (Open Closed Exhausted) $status)))))
         ($_ False))))
      (constraints (case $entry (
         ((DenySkill $skill) (tpId $skill))
         ((RequirePermission $permission) (tpId $permission))
         ((DenyEgress $destination) (tpId $destination))
         ((MaxCost $resource $unit $amount)
          (and (tpId $resource) (and (tpId $unit) (tpQuantity $amount))))
         ($_ False))))
      ($_ False))))


(= (tpListValid $kind $items $remaining $seen)
   (if (== (get-metatype $items) Expression)
       (if (== $items ()) True
           (if (<= $remaining 0) False
               (let ($head $tail) (decons-atom $items)
                  (if (tpEntryValid $kind $head)
                      (let $key (tpKey $kind $head)
                         (if (and (!= $kind constraints) (tpContains $seen $key))
                             False
                             (tpListValid $kind $tail (- $remaining 1)
                                (cons-atom $key $seen))))
                      False)))) False))
(= (tpList $kind $items) (tpListValid $kind $items 128 ()))
(= (tpOperationValid $operation)
   (case $operation (
      ((PolicyOperation (candidate $candidate) (target $target) (skill $skill)
          (permissions $permissions) (egress $egress) (costs $costs))
       (and (== (get-metatype $candidate) Symbol)
          (and (tpId $target)
             (and (tpId $skill)
                (and (tpList ids $permissions)
                   (and (tpList ids $egress) (tpList costs $costs)))))))
      ($_ False))))

      
(= (tpScopeValid $scope $target)
   (case $scope (
      ((PolicyScope (target $actual) (skills $skills) (permissions $permissions)
          (egress $egress) (constraints $constraints) (budgets $budgets))
       (and (== $actual $target)
          (and (tpList ids $skills)
             (and (tpList ids $permissions)
                (and (tpList ids $egress)
                   (and (tpList constraints $constraints) (tpList budgets $budgets)))))))
      ($_ False))))
(= (tpSubset $required $allowed)
   (if (== $required ()) True
       (let ($head $tail) (decons-atom $required)
          (if (tpContains $allowed $head) (tpSubset $tail $allowed) False))))
(= (tpResource $entries $resource)
   (if (== $entries ()) None
       (let ($head $tail) (decons-atom $entries)
          (if (== (index-atom $head 1) $resource) $head
              (tpResource $tail $resource)))))
(= (tpConstraint $constraint $permissions $skill $egress $costs)
   (case $constraint (
      ((DenySkill $denied) (if (== $skill $denied) ConstraintDenied Feasible))
      ((RequirePermission $required)
       (if (tpContains $permissions $required) Feasible PermissionDenied))
      ((DenyEgress $denied)
       (if (tpContains $egress $denied) EgressDenied Feasible))
      ((MaxCost $resource $unit $limit)
       (case (tpResource $costs $resource) (
          (None Feasible)
          ((ResourceCost $_ $actual $amount)
           (if (!= $unit $actual) ResourceUnitMismatch
               (if (> $amount $limit) ConstraintDenied Feasible))))))
      ($_ UnsupportedConstraint))))


(= (tpConstraints $constraints $permissions $skill $egress $costs)
   (if (== $constraints ()) Feasible
       (let* ((($head $tail) (decons-atom $constraints))
              ($reason (tpConstraint $head $permissions $skill $egress $costs)))
          (if (!= $reason Feasible) $reason
              (tpConstraints $tail $permissions $skill $egress $costs)))))


(= (tpBudgets $costs $budgets)
   (if (== $costs ()) Feasible
       (let* ((($head $tail) (decons-atom $costs))
              ((ResourceCost $resource $unit $amount) $head)
              ($reason (case (tpResource $budgets $resource) (
                 (None MissingResourceBudget)
                 ((ResourceBudget $_ $actual $available $status)
                  (if (!= $unit $actual) ResourceUnitMismatch
                      (if (or (!= $status Open) (> $amount $available))
                          BudgetExhausted Feasible)))))))
          (if (!= $reason Feasible) $reason (tpBudgets $tail $budgets)))))


(= (tpScopeReason $scope $operation)
   (let* (
      ((PolicyScope $_ (skills $skills) (permissions $allowed) (egress $destinations)
          (constraints $constraints) (budgets $budgets)) $scope)
      ((PolicyOperation $_ $_ (skill $skill) (permissions $required)
          (egress $egress) (costs $costs)) $operation))
      (if (not (tpContains $skills $skill)) SkillNotAllowed
          (if (not (tpSubset $required $allowed)) PermissionDenied
              (if (not (tpSubset $egress $destinations)) EgressDenied
                  (let $reason (tpConstraints $constraints $allowed $skill $egress $costs)
                     (if (!= $reason Feasible) $reason (tpBudgets $costs $budgets))))))))


(= (tpOperationReason $global $frame $operation $candidate $target)
   (if (not (is-ground ($global $frame $operation $candidate $target))) InvalidPolicy
       (if (not (tpOperationValid $operation)) InvalidOperation
           (let (PolicyOperation (candidate $actual) (target $actualTarget) $_ $_ $_ $_) $operation
              (if (!= $actual $candidate) 
                  OperationMismatch
                  (if (!= $actualTarget $target) 
                     TargetMismatch
                      (if (not (tpScopeValid $global Global)) 
                           InvalidGlobalPolicy
                           (if (not (tpScopeValid $frame (FrameTarget $target))) 
                              InvalidFramePolicy
                              (let $reason (tpScopeReason $global $operation)
                                 (if (!= $reason Feasible) 
                                       $reason
                                     (tpScopeReason $frame $operation)))))))))))


(= (typedOperationPolicyGate $global $frame $operation $candidate $target)
   (let $reason (tpOperationReason $global $frame $operation $candidate $target)
      (GateDecision (if (== $reason Feasible) Admitted Rejected) $reason)))
