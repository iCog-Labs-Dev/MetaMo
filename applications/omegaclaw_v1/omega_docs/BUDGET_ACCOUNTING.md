# Host budget reservation and accounting contract

MetaMo checks prospective costs; Core owns balances, reservations, meters and
dispatch. The production adapter now publishes live session availability at
operation admission, continuation admission and final dispatch revalidation
(integration item 1.2). **Automatic dispatch reservation/settlement and usage
metering remain item 1.3.** Durable recovery is outside this integration item.

`budget_accounting.metta` now initializes accounts, publishes availability, and
reserves complete global/frame costs and settles actual usage with session replay
protection. It commits balances and the reservation/settlement record in one state
update under a serialized-caller contract. The production `dispatch.metta`
imports the component; the trusted adapter acquires Core's dispatch mutex around
provisioning, capture and revalidation. The component itself does not acquire
that mutex or authorize execution. See the
[integration plan](INTEGRATION_PLAN.md#budget-accounting-functions-to-implement)
for remaining work.

## Production availability and lifecycle

The supported catalog declares one `commands` / `units` cost per read,
frame inspection or send. No token, byte, monetary or general host-service
meter is implied. Per-provider output caps remain separate from these accounts.

On first trusted policy installation, `mm_budget_prepare` derives accounts in
namespace `"host"` from the configured global/frame budget rows, then
`mm_budget_install` calls `initBudgetAccounts`. Each configured `available`
amount seeds its account's limit, with zero spent/reserved and revision zero.
Account status starts Open; configured Closed/Exhausted status independently
denies operation through the policy projection.

Later provisioning adds only previously unseen account identities. Existing
limits, spent, reserved, account status, revisions and reservation/settlement
records are preserved. A new task gets its own frame accounts and shares the
existing global accounts. Returning to a previous frame, policy revocation,
changing the command catalog or reinitializing dispatch does not replenish
balances. Raising a configured ceiling does not raise an existing account limit;
there is no implicit recharge or reset API. Missing accounts block admission;
ordinary projection does not create them. Trusted provisioning allocates new
identities but rejects corrupt existing storage rather than resetting it.

`mm_dispatch_live_policies` captures the accounting store once while the host
holds the dispatch mutex. `budgetPolicyScopeForSnapshot` projects both scopes
from that store. For each configured resource it publishes
`min(configured ceiling, limit - spent - reserved)`; a Closed/Exhausted policy
or account remains restrictive. Missing, malformed or overcommitted accounting
returns a typed rejection in place of a policy scope. The existing concrete
gate consequently returns InvalidGlobalPolicy/InvalidFramePolicy; it cannot
fall back to a configured amount or an empty cost vector.

The live scopes feed normal pre-score operation admission and read-plan /
correction admission. Core's final snapshot includes those scopes and the host
accounting state, so changes invalidate an older ticket even when projected
availability happens to be unchanged. A fresh ticket must satisfy the current
availability. Host meter/accounting updates must use the existing Core mutex
and mutation epoch, including future reservation and settlement callers.

Accounts retain the component's 128-account session bound, including older
frames; adding accounts beyond it rejects provisioning without changing the
store. This implementation supplies session availability, not restart recovery.
Dispatch still does not automatically consume a command unit: item 1.3 must
connect reservation and observed settlement before cumulative execution cost
is enforced.

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

The session implementation accepts actual `AccountCost` rows for every reserved
account, with equal usage in global/frame scopes. It retains completed records
for replay protection. `Unknown` usage leaves pending capacity untouched. An
overrun retains the actual report and closes all accounts affected by that
operation, keeping spent/reserved unchanged until host reconciliation. It does
not automatically reconcile or reopen accounts; this is a pending overrun, not
final settlement. See the integration plan for the exact API and result records.

Restart-safe operation requires a durable atomic ledger and reconciliation of
in-flight reservations before new spending. Until that exists, session-only
implementations must explicitly exclude crash/restart guarantees; they must not
restore all reserved capacity as available on startup.

## Evidence and remaining host work

`tests/host_dispatch_config_test.metta` now checks the connected production
capture/admission and final Core dispatch paths with real account projections.
It covers both scopes, spent/reserved deductions, policy ceilings, closed
accounts, stale tickets, native frame identity, retained reservation records,
new-frame/reprovision/revocation lifecycle, missing accounts and corrupt or
uninitialized storage. Trusted fixture updates simulate the meter; these tests
do not claim automatic invocation charging.

Item 1.2 verification on 26 October 2026: all 82 existing MeTTa test files
passed, and the expanded `host_dispatch_config_test.metta` passed all 58
assertions after its final additions. Six relevant Python suites passed 118
tests; all four existing shell boundary guards and five Core dispatch-guard
tests passed. Providers/transports were doubled; no live external services were
called. Reproduce the MeTTa suite from the workspace root with:

```bash
python3 MetaMo/scripts/run-tests.py --root MetaMo/applications/omegaclaw_v1 --jobs 3 --timeout 90
```

`tests/budget_accounting_test.metta` checks accounting projection, overcommitment,
pending reservations reducing admission, both scopes, units, missing resources,
duplicate/malformed costs and settlement arithmetic examples through PeTTa.
These tests do not simulate a transactional ledger.
`tests/budget_reservation_test.metta` additionally covers session reservation,
all-or-nothing multi-account failure, cumulative exhaustion and replay without
duplicate charges. `tests/budget_settlement_test.metta` covers actual partial/full/
zero usage, preserved competing reservations, duplicate/conflicting reports,
unknown consumption, overrun blocking, revoked accounts and atomic failure.
Core still needs integrated tests for
concurrent reservations, all-or-nothing multi-account failure, revocation before
start, duplicate callbacks, partial execution costs and restart reconciliation.
