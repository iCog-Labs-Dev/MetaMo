;; Host budget accounting interfaces for the OmegaClaw v1 integration.
;; Initialization is implemented; availability, reservation and settlement remain
;; explicit stubs. Load contexts/typed_policy before this module.
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
   (if (!= (get-metatype $accounts) Expression) InvalidBudgetAccounts
       (if (== $accounts ()) Valid
           (if (<= $remaining 0) TooManyBudgetAccounts
               (let* (
                  (($head $tail) (decons-atom $accounts))
                  ($reason (baAccountReason $head)))
                  (if (!= $reason Valid) $reason
                      (let $id (index-atom $head 1)
                         (if (tpContains $seen $id) DuplicateBudgetAccount
                             (baAccountsReason $tail (- $remaining 1)
                                (cons-atom $id $seen))))))))))

;; Trusted serialized startup only. Validate all rows before a single state write;
;; rejected input leaves the original state untouched. No public reset API.
(= (initBudgetAccounts $accounts)
   (if (!= (get-state &budget-account-state) BudgetAccountsUninitialized)
       (BudgetAccountingRejected AlreadyInitialized)
       (if (not (is-ground $accounts))
           (BudgetAccountingRejected InvalidBudgetAccounts)
           (let $reason (baAccountsReason $accounts 128 ())
              (if (!= $reason Valid) (BudgetAccountingRejected $reason)
                  (progn
                     (change-state! &budget-account-state (BudgetAccounts $accounts))
                     (BudgetAccountsInitialized (size-atom $accounts))))))))

;; Publish current availability using resourceBudgetFromAccounting from
;; contexts/typed_policy.metta, loaded by the application composition.
;; TODO: read one consistent account revision; reject missing/invalid accounts.
(= (budgetAvailability $accountId)
   (Error budgetAvailability NotImplemented))

;; Reserve all global/frame costs under Core's dispatch lock before execution.
;; TODO: check current balances, update all accounts or none, retain the exact
;; operation under the dispatch ID, and reject conflicting identity reuse.
(= (reserveOperationBudget $dispatchId $operation $accountCosts)
   (Error reserveOperationBudget NotImplemented))

;; Settle trusted actual costs against the retained reservation exactly once.
;; TODO: charge usage, release unused capacity, and reject conflicting repeats.
;; Proven non-start permits explicit zero usage; uncertainty stays reserved.
(= (settleOperationBudget $dispatchId $actualCosts)
   (Error settleOperationBudget NotImplemented))
