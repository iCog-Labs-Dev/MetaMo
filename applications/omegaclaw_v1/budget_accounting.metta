;; Host budget accounting interfaces for the OmegaClaw v1 integration.
;; Initialization, availability and reservation are implemented; settlement
;; remains an explicit stub. Load contexts/typed_policy before this module.
;; Keep this module out of runtime composition until implementation and wiring
;; are complete. See omega_docs/INTEGRATION_PLAN.md for acceptance criteria.
;;
;; These are trusted host operations, not model-callable skills. Core dispatch
;; owns invocation and synchronization; MetaMo reads budget projections only.

;; Account shape (identity includes namespace, scope, resource and unit):
;; (BudgetAccount (BudgetAccountId "host" Global "commands" "units")
;;                LIMIT SPENT RESERVED STATUS REVISION)
;; Scope is Global or (FrameTarget FRAME-ID); native frame symbols stay symbols.
;; Amounts and revisions are integers in [0, 9007199254740991]. A nonzero reserved
;; amount remains unavailable; initialization alone provides no recovery ledger.
;; One state distinguishes an empty initialized account set from no initialization.
!(bind! &budget-account-state (new-state BudgetAccountsUninitialized))

(= (baInteger $value)
   (if (tpQuantity $value)
       (== $value (floor-math $value)) False))

(= (baScopeValid $scope)
   (case $scope (
      (Global True)
      ((FrameTarget $frame) (tpFrameId $frame))
      ($_ False))))

(= (baAccountReason $account)
   (case $account (
      ((BudgetAccount (BudgetAccountId $namespace $scope $resource $unit)
          $limit $spent $reserved $status $revision)
       (if (tpAllTrue ((tpId $namespace) (baScopeValid $scope)
              (baInteger $limit) (baInteger $spent) (baInteger $reserved)
              (baInteger $revision)))
           (case (resourceBudgetFromAccounting
                     $resource $unit $limit $spent $reserved $status) (
              ((ResourceBudget $_ $_ $_ $_) Valid)
              ((BudgetAccountingRejected $reason) $reason)))
           InvalidBudgetAccount))
      ($_ InvalidBudgetAccount))))

;; Validate without writes; cap startup input at 128 accounts like typed policy
;; lists. Duplicate identity is invalid even when the two balances are identical.
(= (baAccountsReason $accounts $remaining $seen)
   (case ((get-metatype $accounts) (== $accounts ()) (<= $remaining 0)) (
      ((Expression True $_) Valid)
      ((Expression False True) TooManyBudgetAccounts)
      ((Expression False False)
       (let ($head $tail) (decons-atom $accounts)
          (case (baAccountReason $head) (
             (Valid (baUniqueAccountReason $head $tail $remaining $seen))
             ($reason $reason)))))
      ($_ InvalidBudgetAccounts))))

(= (baUniqueAccountReason $head $tail $remaining $seen)
   (let $id (index-atom $head 1)
      (if (tpContains $seen $id) DuplicateBudgetAccount
          (let* (($nextSeen (cons-atom $id $seen)))
             (baAccountsReason $tail (- $remaining 1) $nextSeen)))))

(= (baInitializationReason $accounts)
   (case ((get-state &budget-account-state) (is-ground $accounts)) (
      ((BudgetAccountsUninitialized True) (baAccountsReason $accounts 128 ()))
      ((BudgetAccountsUninitialized False) InvalidBudgetAccounts)
      ($_ AlreadyInitialized))))

;; Trusted serialized startup only. Validate all rows before a single state write;
;; rejected input leaves the original state untouched. No public reset API.
(= (initBudgetAccounts $accounts)
   (case (baInitializationReason $accounts) (
      (Valid
       (progn
          (change-state! &budget-account-state (BudgetAccounts $accounts ()))
          (BudgetAccountsInitialized (size-atom $accounts))))
      ($reason (BudgetAccountingRejected $reason)))))

(= (baAccountIdValid $id)
   (case $id (
      ((BudgetAccountId $namespace $scope $resource $unit)
       (tpAllTrue ((tpId $namespace) (baScopeValid $scope)
          (tpId $resource) (tpId $unit))))
      ($_ False))))

;; Called only with a validated snapshot. Match full identity without coercion
;; or fallback to another namespace, scope, resource, or unit.
(= (baAvailabilityIn $accounts $accountId)
   (case $accounts (
      (() (BudgetAccountingRejected MissingBudgetAccount))
      ($_ (let* (
          (($head $tail) (decons-atom $accounts))
          ((BudgetAccount $id $limit $spent $reserved $status $_revision) $head))
          (if (== $id $accountId)
              (let (BudgetAccountId $_namespace $_scope $resource $unit) $id
                 (resourceBudgetFromAccounting
                    $resource $unit $limit $spent $reserved $status))
              (baAvailabilityIn $tail $accountId)))))))

;; Read the store once, then validate/project that same snapshot without writes.
;; Invalid or ambiguous stored data fails closed rather than yielding capacity.
;; Closed/Exhausted status is preserved for the existing policy gate to reject.
(= (budgetAvailability $accountId)
   (case (baAvailabilityRequestReason $accountId) (
      (Valid
       (case (baValidatedSnapshot (get-state &budget-account-state)) (
          ((BudgetAccounts $accounts $_reservations)
           (baAvailabilityIn $accounts $accountId))
          ($rejection $rejection))))
      ($reason (BudgetAccountingRejected $reason)))))

(= (baAvailabilityRequestReason $accountId)
   (case (is-ground $accountId) (
      (True (if (baAccountIdValid $accountId) Valid InvalidBudgetAccountId))
      (False InvalidBudgetAccountId))))

;; Shared account validation reads the supplied snapshot, never live state again.
(= (baValidatedSnapshot $snapshot)
   (if (not (is-ground $snapshot))
       (BudgetAccountingRejected InvalidBudgetAccounts)
       (case $snapshot (
          (BudgetAccountsUninitialized
           (BudgetAccountingRejected AccountsNotInitialized))
          ((BudgetAccounts $accounts $_reservations)
           (case (baAccountsReason $accounts 128 ()) (
              (Valid $snapshot)
              ($reason (BudgetAccountingRejected $reason)))))
          ($_ (BudgetAccountingRejected InvalidBudgetAccounts))))))

;; Reservation input:
;;   (DispatchTicket "id")
;;   (BudgetOperation COMMAND POLICY-OPERATION)
;;   ((AccountCost ACCOUNT-ID INTEGER-AMOUNT) ...)
;; COMMAND retains exact arguments as inert data; the trusted caller quotes it.
;; POLICY-OPERATION is the existing typed record supplied by the handler.
;; Each declared cost needs one Global and one target FrameTarget account in
;; the same namespace. Repeated identical account references are charged once;
;; conflicting amounts, missing scopes and undeclared charges are rejected.
(= (baTicketValid $ticket)
   (case $ticket (((DispatchTicket $id) (tpId $id)) ($_ False))))

(= (baIntegerCosts $costs)
   (case $costs (
      (() True)
      ($_ (let* ((($head $tail) (decons-atom $costs))
              ((ResourceCost $_ $_ $amount) $head))
          (if (baInteger $amount) (baIntegerCosts $tail) False))))))

(= (baOperationValid $operation)
   (case $operation (
      ((BudgetOperation $command $policy)
       (case ((tpOperationValid $policy) (get-metatype $command) (== $command ())) (
          ((True Expression False)
           (let (PolicyOperation $_ $_ (skill $skill) $_ $_ (costs $costs)) $policy
              (and (== (repr (car-atom $command)) $skill)
                   (baIntegerCosts $costs))))
          ($_ False))))
      ($_ False))))

;; Canonical scope ordering makes an identical set of account references replay
;; identically, even if a caller changes row order or repeats an identical row.
(= (baExpectedCosts $namespace $target $costs)
   (if (== $costs ()) ()
       (let* ((($head $tail) (decons-atom $costs))
              ((ResourceCost $resource $unit $amount) $head)
              ($globalCost (AccountCost
                 (BudgetAccountId $namespace Global $resource $unit) $amount))
              ($frameCost (AccountCost
                 (BudgetAccountId $namespace (FrameTarget $target) $resource $unit) $amount))
              ($remainingCosts (baExpectedCosts $namespace $target $tail))
              ($withFrame (cons-atom $frameCost $remainingCosts))
              ($withGlobal (cons-atom $globalCost $withFrame)))
          $withGlobal)))

(= (baCostRowsMatch $rows $expected $remaining)
   (case ((== $rows ()) (<= $remaining 0)) (
      ((True $_) True)
      ((False True) False)
      ((False False)
       (let ($head $tail) (decons-atom $rows)
          (if (tpContains $expected $head)
              (baCostRowsMatch $tail $expected (- $remaining 1)) False))))))

(= (baNormalizeCosts $operation $rows)
   (if (!= (get-metatype $rows) Expression)
       (BudgetAccountingRejected InvalidAccountCosts)
       (let (BudgetOperation $_
                (PolicyOperation $_ (target $target) $_ $_ $_ (costs $costs))) $operation
          (case ((== $costs ()) (== $rows ())) (
             ((True True) (BudgetAccountCosts ()))
             ((False False) (baNormalizeScopedCosts $target $costs $rows))
             ($_ (BudgetAccountingRejected InvalidAccountCosts)))))))

(= (baNormalizeScopedCosts $target $costs $rows)
   (case (car-atom $rows) (
      ((AccountCost (BudgetAccountId $namespace $_ $_ $_) $_)
       (case (tpId $namespace) (
          (True
           (let $expected (baExpectedCosts $namespace $target $costs)
              (if (and (baCostRowsMatch $rows $expected 256)
                       (tpSubset $expected $rows))
                  (BudgetAccountCosts $expected)
                  (BudgetAccountingRejected InvalidAccountCosts))))
          (False (BudgetAccountingRejected InvalidAccountCosts)))))
      ($_ (BudgetAccountingRejected InvalidAccountCosts)))))

;; Pure update of one account; returned rows are not yet written to host state.
(= (baReservationAccountReason $account $amount)
   (let (BudgetAccount $_ $limit $spent $reserved $status $revision) $account
      (case ((or (!= $status Open) (> $amount (- (- $limit $spent) $reserved)))
             (>= $revision 9007199254740991)) (
         ((True $_) BudgetExhausted)
         ((False True) BudgetRevisionExhausted)
         ((False False) Valid)))))

(= (baPrepareAccountReservation $account $tail $amount)
   (case (baReservationAccountReason $account $amount) (
      (Valid
       (let* (
          ((BudgetAccount $id $limit $spent $reserved $status $revision) $account)
          ($updatedAccount (BudgetAccount $id $limit $spent
             (+ $reserved $amount) $status (+ $revision 1)))
          ($updatedAccounts (cons-atom $updatedAccount $tail)))
          (BudgetAccountUpdate $updatedAccounts $account)))
      ($reason (BudgetAccountingRejected $reason)))))

(= (baReserveOne $accounts $id $amount)
   (case $accounts (
      (() (BudgetAccountingRejected MissingBudgetAccount))
      ($_
       (let* ((($head $tail) (decons-atom $accounts))
              ((BudgetAccount $actual $_ $_ $_ $_ $_) $head))
          (if (== $actual $id)
              (baPrepareAccountReservation $head $tail $amount)
              (case (baReserveOne $tail $id $amount) (
                 ((BudgetAccountUpdate $updated $before)
                  (let* (($updatedAccounts (cons-atom $head $updated)))
                     (BudgetAccountUpdate $updatedAccounts $before)))
                 ($rejection $rejection)))))))))

(= (baReserveCosts $costs $accounts $before)
   (if (== $costs ()) (BudgetAccountUpdates $accounts $before)
       (let* ((($head $tail) (decons-atom $costs))
              ((AccountCost $id $amount) $head))
          (case (baReserveOne $accounts $id $amount) (
             ((BudgetAccountUpdate $updated $prior)
              (let* (($nextBefore (cons-atom $prior $before)))
                 (baReserveCosts $tail $updated $nextBefore)))
             ($rejection $rejection))))))

;; Records retain the exact operation, canonical costs and pre-reservation account
;; revisions/balances. Validate shape/identity before looking up a replay.
(= (baReservationRecordValid $record $seen)
   (case $record (
      ((BudgetReservation $ticket $operation $costs $before)
       (case ((baTicketValid $ticket) (baOperationValid $operation)
              (tpContains $seen $ticket)) (
          ((True True False)
           (and (== (baNormalizeCosts $operation $costs) (BudgetAccountCosts $costs))
                (== (baAccountsReason $before 128 ()) Valid)))
          ($_ False))))
      ($_ False))))

(= (baReservationsValid $records $seen)
   (case ((get-metatype $records) (== $records ())) (
      ((Expression True) True)
      ((Expression False)
       (let ($head $tail) (decons-atom $records)
          (case (baReservationRecordValid $head $seen) (
             (True
              (let* (
                 ((BudgetReservation $ticket $_ $_ $_) $head)
                 ($nextSeen (cons-atom $ticket $seen)))
                 (baReservationsValid $tail $nextSeen)))
             (False False)))))
      ($_ False))))

(= (baFindReservation $records $ticket)
   (case $records (
      (() NoBudgetReservation)
      ($_ (let* ((($head $tail) (decons-atom $records))
              ((BudgetReservation $id $_ $_ $_) $head))
          (if (== $id $ticket) $head (baFindReservation $tail $ticket)))))))

(= (baReserveIn $accounts $records $ticket $operation $costs)
   (case (baFindReservation $records $ticket) (
      ((BudgetReservation $_ $priorOperation $priorCosts $_)
       (if (and (== $operation $priorOperation) (== $costs $priorCosts))
           (BudgetReserved $ticket $costs)
           (BudgetAccountingRejected ConflictingReplay)))
      (NoBudgetReservation
       (case (baReserveCosts $costs $accounts ()) (
          ((BudgetAccountUpdates $updated $before)
           (let* (
              ($reservation (BudgetReservation $ticket $operation $costs $before))
              ($nextRecords (cons-atom $reservation $records))
              ($_ (change-state! &budget-account-state
                 (BudgetAccounts $updated $nextRecords))))
              (BudgetReserved $ticket $costs)))
          ($rejection $rejection)))))))

(= (baReserveSnapshot $snapshot $ticket $operation $costs)
   (case (baValidatedSnapshot $snapshot) (
      ((BudgetAccounts $accounts $records)
       (if (baReservationsValid $records ())
           (baReserveIn $accounts $records $ticket $operation $costs)
           (BudgetAccountingRejected InvalidBudgetReservations)))
      ($rejection $rejection))))

(= (baReservationRequestReason $dispatchId $operation $accountCosts)
   (case (is-ground ($dispatchId $operation $accountCosts)) (
      (False InvalidBudgetReservation)
      (True
       (case ((baTicketValid $dispatchId) (baOperationValid $operation)) (
          ((False $_) InvalidDispatchId)
          ((True False) InvalidOperation)
          ((True True) Valid)))))))

;; Trusted serialized caller only: final policy authorization and the shared Core
;; mutex remain the caller's responsibility. This function never executes work.
;; Compute all changes first, then publish balances AND replay record in one write.
(= (reserveOperationBudget $dispatchId $operation $accountCosts)
   (case (baReservationRequestReason $dispatchId $operation $accountCosts) (
      (Valid
       (case (baNormalizeCosts $operation $accountCosts) (
          ((BudgetAccountCosts $costs)
           (baReserveSnapshot (get-state &budget-account-state)
              $dispatchId $operation $costs))
          ($rejection $rejection))))
      ($reason (BudgetAccountingRejected $reason)))))

;; Settle trusted actual costs against the retained reservation exactly once.
;; TODO: charge usage, release unused capacity, and reject conflicting repeats.
;; Proven non-start permits explicit zero usage; uncertainty stays reserved.
(= (settleOperationBudget $dispatchId $actualCosts)
   (Error settleOperationBudget NotImplemented))
