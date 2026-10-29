;; Pure typed policy checks on PeTTa. Operation metadata must be supplied by
;; trusted host handlers, not inferred from a candidate or reasoner claim.
;; These checks neither execute work nor reserve or mutate resource budgets.

(= (tpId $x)
   (if (== (get-type $x) String) (!= $x "") False)
)

;; Core generates symbolic frame IDs. Preserve their identity instead of
;; rewriting host state or coercing symbols and strings into the same target.
(= (tpFrameId $x)
   (or (tpId $x) (== (get-metatype $x) Symbol)))

(= (tpQuantity $x)
   (if (== (get-type $x) Number)
       ;; Host numeric anomalies must reject, never abort the admission path.
       (== (catch (if (< $x 0) False (<= $x 9007199254740991))) True) False)
)

(= (tpContains $items $x)
   (if (== $items ()) False
       (let ($head $tail) (decons-atom $items)
          (if (== $head $x) True (tpContains $tail $x)))))
;; Validate a flat list of already-safe boolean checks without nested logic.
(= (tpAllTrue $checks)
   (if (== $checks ()) True
       (let ($head $tail) (decons-atom $checks)
          (if (== $head True) (tpAllTrue $tail) False))))

(= (tpAccountingValid $resource $unit $limit $spent $reserved $status)
   (tpAllTrue ((tpId $resource) (tpId $unit)
      (tpQuantity $limit) (tpQuantity $spent) (tpQuantity $reserved)
      (tpContains (Open Closed Exhausted) $status))))

(= (tpAccountingBudget $resource $unit $limit $spent $reserved $status)
   (if (> $spent $limit)
       (BudgetAccountingRejected BudgetOvercommitted)
       (let $remaining (- $limit $spent)
          (if (> $reserved $remaining)
              (BudgetAccountingRejected BudgetOvercommitted)
              (ResourceBudget $resource $unit (- $remaining $reserved) $status)))))

;; Pure host-accounting projection. All values must come from one host revision.
;; Available excludes spent AND reserved amounts. No host state is mutated.
(= (resourceBudgetFromAccounting $resource $unit $limit $spent $reserved $status)
   (if (not (is-ground ($resource $unit $limit $spent $reserved $status)))
       (BudgetAccountingRejected InvalidBudgetAccounting)
       (if (tpAccountingValid $resource $unit $limit $spent $reserved $status)
           (tpAccountingBudget $resource $unit $limit $spent $reserved $status)
           (BudgetAccountingRejected InvalidBudgetAccounting))))

(= (tpKey $kind $entry)
   (if (== $kind ids) $entry (index-atom $entry 1)))
(= (tpEntryValid $kind $entry)
   (case $kind (
      (ids (tpId $entry))
      (costs (case $entry (
         ((ResourceCost $resource $unit $amount)
          (tpAllTrue ((tpId $resource) (tpId $unit) (tpQuantity $amount))))
         ($_ False))))
      (budgets (case $entry (
         ((ResourceBudget $resource $unit $amount $status)
          (tpAllTrue ((tpId $resource) (tpId $unit) (tpQuantity $amount)
             (tpContains (Open Closed Exhausted) $status))))
         ($_ False))))
      (constraints (case $entry (
         ((DenySkill $skill) (tpId $skill))
         ((RequirePermission $permission) (tpId $permission))
         ((DenyEgress $destination) (tpId $destination))
         ((MaxCost $resource $unit $amount)
          (tpAllTrue ((tpId $resource) (tpId $unit) (tpQuantity $amount))))
         ($_ False))))
      ($_ False))))


;; Validate shape before reading a key. Duplicate constraints remain permitted.
;; Example: (tpListEntryValid ids "files.read" ("files.read")) -> False.
(= (tpListEntryValid $kind $entry $seen)
   (if (tpEntryValid $kind $entry)
       (not (and (!= $kind constraints) (tpContains $seen (tpKey $kind $entry))))
       False))

;; Guard list shape and capacity before decomposing or validating its head.
;; Example: (tpListValid ids () 0 ()) -> True; a nonempty list at zero rejects.
(= (tpListValid $kind $items $remaining $seen)
   (case ((get-metatype $items) (== $items ())) (
      ((Expression True) True)
      ((Expression False)
       (if (<= $remaining 0) False
           (let ($head $tail) (decons-atom $items)
              (case (tpListEntryValid $kind $head $seen) (
                 (True (tpListValid $kind $tail (- $remaining 1)
                    (cons-atom (tpKey $kind $head) $seen)))
                 ($_ False))))))
      ($_ False))))


(= (tpList $kind $items) (tpListValid $kind $items 128 ()))


(= (tpOperationValid $operation)
   (case $operation (
      ((PolicyOperation (candidate $candidate) (target $target) (skill $skill)
          (permissions $permissions) (egress $egress) (costs $costs))
       (tpAllTrue ((== (get-metatype $candidate) Symbol)
          (tpFrameId $target) (tpId $skill) (tpList ids $permissions)
          (tpList ids $egress) (tpList costs $costs))))
      ($_ False))))

      
(= (tpScopeValid $scope $target)
   (case $scope (
      ((PolicyScope (target $actual) (skills $skills) (permissions $permissions)
          (egress $egress) (constraints $constraints) (budgets $budgets))
       (tpAllTrue ((== $actual $target) (tpList ids $skills)
          (tpList ids $permissions) (tpList ids $egress)
          (tpList constraints $constraints) (tpList budgets $budgets))))
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


;; Both scopes are already validated. A global denial precedes frame checks.
;; Example: a globally denied skill returns SkillNotAllowed immediately.
(= (tpOperationScopesReason $global $frame $operation)
   (let $reason (tpScopeReason $global $operation)
      (if (!= $reason Feasible) $reason (tpScopeReason $frame $operation))))

;; Validate each scope before evaluating its permissions, constraints or budgets.
;; Example: malformed global and frame scopes return InvalidGlobalPolicy first.
(= (tpOperationPolicyReason $global $frame $operation $target)
   (case (tpScopeValid $global Global) (
      (False InvalidGlobalPolicy)
      (True (case (tpScopeValid $frame (FrameTarget $target)) (
         (False InvalidFramePolicy)
         (True (tpOperationScopesReason $global $frame $operation))))))))

;; The operation shape is valid before its identity fields are inspected.
;; Example: candidate and target mismatches return OperationMismatch first.
(= (tpOperationBindingReason $global $frame $operation $candidate $target)
   (let (PolicyOperation (candidate $actual) (target $actualTarget) $_ $_ $_ $_) $operation
      (case ((== $actual $candidate) (== $actualTarget $target)) (
         ((False $_) OperationMismatch)
         ((True False) TargetMismatch)
         ((True True) (tpOperationPolicyReason $global $frame $operation $target))))))

;; Guard groundness and shape before dispatching to the ordered binding checks.
;; Example: non-ground input returns InvalidPolicy without inspecting the operation.
(= (tpOperationReason $global $frame $operation $candidate $target)
   (case (is-ground ($global $frame $operation $candidate $target)) (
      (False InvalidPolicy)
      (True (case (tpOperationValid $operation) (
         (False InvalidOperation)
         (True (tpOperationBindingReason $global $frame $operation $candidate $target))))))))


(= (typedOperationPolicyGate $global $frame $operation $candidate $target)
   (let $reason (tpOperationReason $global $frame $operation $candidate $target)
      (GateDecision (if (== $reason Feasible) Admitted Rejected) $reason)))
