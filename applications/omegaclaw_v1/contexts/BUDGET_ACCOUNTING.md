# Host budget reservation and accounting contract

MetaMo checks prospective costs; Core owns balances, reservations, meters and
dispatch. This document defines the required host behavior. The current code
implements numeric admission and a pure accounting projection, **not a live
reservation ledger or transactional dispatcher**.

## Values and publication

Each resource account is identified by host namespace, scope (global or frame),
resource name and unit. The host tracks `limit`, `spent`, and `reserved` at an
account revision. All quantities are nonnegative, finite and at most
9007199254740991. Require `spent <= limit` and `reserved <= limit - spent`.
Publish `available = limit - spent - reserved`, never the original limit.

`resourceBudgetFromAccounting resource unit limit spent reserved status` validates
those invariants and emits the existing `(ResourceBudget resource unit available
status)` or `(BudgetAccountingRejected reason)`. Inputs must come from one
consistent host revision. The helper reads no host state and reserves nothing.
Invalid accounting must block publication/admission, not be clamped to zero or
converted to an empty cost list. An overdrawn account requires host reconciliation.

Use integer smallest units for host accounting (for example microcredits) and
conservative upward rounding for prospective costs. The generic admission API
also accepts bounded fractional quantities; it does not choose a unit, perform
conversions, or supply an accounting precision policy. Never mix units implicitly.
Closed or exhausted accounts cannot admit declared costs, even costs of zero.

## Prospective operation cost

The trusted handler derives a cost vector from the actual operation and its
arguments. Every consumed resource must appear exactly once, with a known unit
and an enforceable upper bound. Unknown, unbounded, negative, malformed or
duplicate costs block dispatch. Explicit empty costs are valid only for a
handler the host knows consumes no regulated resources. Missing metadata is not
equivalent to zero cost.

Every cost must fit both global and target-frame accounts, as well as applicable
`MaxCost` constraints. A permissive frame budget cannot override the global
budget. Long-running or variable-cost handlers must enforce the reserved upper
bound; reserve an additional increment atomically before exceeding it, or stop.

## Atomic dispatch protocol

1. Resolve the actual handler, arguments, target, destinations and bounded cost
   vector. Revalidate current permissions, constraints, modes and revisions.
2. Under the same host lock/transaction used for relevant policy/account
   mutations, claim a unique dispatch ID and reserve the complete vector across
   all affected accounts. Check current available balances, not the balances in
   MetaMo's earlier snapshot. Either all claims/reservations commit, or none do.
3. Record the binding from dispatch ID to operation/argument identity, target,
   policy/account revisions and reserved amounts. Advance account revisions.
4. Start execution only after a successful claim. If policy changes before start,
   revalidate or block and release the unstarted reservation. No score is an
   authorization token. A stale decision must be recomputed.

Global and frame limits represent two scopes restricting the same consumption.
Both balances are debited, but the external usage/billing event is recorded once.
If two references resolve to the same account identity, reserve that account once.
Concurrent dispatches must not both spend the same available balance. Even in a
serialized loop, asynchronous in-flight work needs reservations. For synchronous
work a committed pre-execution debit can serve the same purpose.

## Settlement and replay

| Observation | Required accounting |
| --- | --- |
| Denied before reservation | No account mutation and no execution. |
| Cancelled, revoked, or failed to start, with proof of no consumption | Release the reservation exactly once; spent stays unchanged. |
| Completed, failed, or cancelled after starting, with measured usage | Atomically remove this reservation and add measured actual consumption to spent in each affected scope. Release unused capacity. Failure does not imply zero cost. |
| Outcome/usage uncertain, timeout, lost callback or crash | Keep the reservation pending reconciliation. Do not refund based on silence or elapsed time alone. |
| Actual usage exceeds reservation | Record actual usage without hiding the overrun; block affected accounts and reconcile. Do not permit negative availability or continue spending. The handler must normally prevent this via its execution limit. |

For reservation `q` and measured use `a <= q`, settlement is
`reserved' = reserved - q`, `spent' = spent + a`; unused `q - a` becomes available.
Settlement requires matching dispatch/execution identity, account, resource and
unit. Reject mismatched observations without releasing funds. Repeated identical
claims/outcomes return the stored result without another debit, refund, or start;
conflicting replays are rejected. A retry is a new dispatch with a new reservation.

Restart-safe operation requires a durable atomic ledger and reconciliation of
in-flight reservations before new spending. Until that exists, session-only
implementations must explicitly exclude crash/restart guarantees; they must not
restore all reserved capacity as available on startup.

## Evidence and remaining host work

`tests/budget_accounting_test.metta` checks accounting projection, overcommitment,
pending reservations reducing admission, both scopes, units, missing resources,
duplicate/malformed costs and settlement arithmetic examples through PeTTa.
These tests do not simulate a transactional ledger. Core still needs tests for
concurrent reservations, all-or-nothing multi-account failure, revocation before
start, duplicate callbacks, partial execution costs and restart reconciliation.
