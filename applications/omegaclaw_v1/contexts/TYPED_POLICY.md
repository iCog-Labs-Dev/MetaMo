# Typed operation checks on PeTTa

`typed_policy.metta` implements pure MeTTa admission checks. It has no Prolog
helper, service dependency, execution authority, or mutable policy registry.

Call `typedOperationPolicyGate global frame operation candidate target` for
typed policy checks, or `feasibilityGateForOperation bundle candidate operation
global frame` to additionally apply the existing frame and constitutional-mode
gates. Both return one `GateDecision Admitted Feasible` or `GateDecision Rejected
REASON`. Rejection is never overridden by a mode or motivational score.

The global and frame values are **resolved host-owned policy**, not strings
extracted from compacted bundle summaries. The frame scope must identify the
operation's target. The combined gate currently supports the bundle's current
frame; it rejects a different operation target. Cross-frame admission requires
the host to supply that target's authoritative snapshot in a later integration.

```metta
(PolicyScope
  (target Global) ; frame scope uses (FrameTarget "frame-1")
  (skills ("read-file"))
  (permissions ("files.read"))
  (egress ())
  (constraints ((RequirePermission "files.read")))
  (budgets ((ResourceBudget "commands" "units" 10 Open))))

(PolicyOperation
  (candidate execute-skill)
  (target "frame-1")
  (skill "read-file")
  (permissions ("files.read"))
  (egress ())
  (costs ((ResourceCost "commands" "units" 1))))
```

These are local adapter inputs, not additional v1 `IntegrationRecord` schemas.
Exact field order and shapes are required. IDs, permissions, resource names,
units, and destinations are nonempty strings. Collections contain at most 128
entries. Duplicate allowlist entries or duplicate resource names are malformed.
Budgets and costs must be numbers in `[0, 9007199254740991]`; booleans and numeric
strings are rejected. A budget status is exactly `Open`, `Closed`, or `Exhausted`.

Both scopes must allow the skill, every required permission and every actual
egress destination. Matching is exact; there are no wildcards, URL-prefix
inference, or grants inferred from prose. Empty allowlists grant nothing.
Explicit empty egress/cost lists mean no egress/resource consumption only when
the **trusted host handler** establishes that fact. Neither a model nor a client
request may omit requirements to obtain admission.

Supported constraints in either scope:

| Constraint | Check |
| --- | --- |
| `(DenySkill "skill")` | Reject that skill regardless of allowlists. |
| `(RequirePermission "permission")` | Require that permission in this scope. |
| `(DenyEgress "destination")` | Reject an operation using that destination. |
| `(MaxCost "resource" "unit" amount)` | If the operation consumes the resource, require matching units and cost within the limit. |

Missing, malformed, unknown or legacy prose constraints reject the scope as
`InvalidGlobalPolicy` or `InvalidFramePolicy`. No constraint is silently dropped.
Every consumed resource needs a matching budget in **both** scopes. Unit
mismatch, a closed/exhausted budget, or cost exceeding availability rejects the
operation, including zero-cost entries against a closed budget. Explicitly
cost-free operations can use empty budget lists.

The gate validates data; it does not authenticate its source. MeTTa callers must
quote untrusted literal terms before evaluation, as with the v1 wire APIs.

## Integration limits

The legacy `feasibilityGate bundle candidate` still performs preliminary checks
only. Production candidates currently lack trusted concrete handler metadata,
and the legacy projection still compacts policy summaries. This change therefore
does **not** claim that production dispatch enforces the new checks. Core must
resolve policy and derive metadata from the actual handler/arguments, wire the
concrete-operation gate into scheduling, revalidate current policy, and reserve
and account for resources before execution. These are separate Phase 3 items.

`tests/fixtures/typed_policy.metta` provides reusable policy/operation examples.
`tests/typed_policy_test.metta` exercises the pure gate through PeTTa; the focused
context policy suite exercises composition with the existing frame/mode gate.

```sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/typed_policy_test.metta
python3 MetaMo/scripts/run-tests.py --root MetaMo/applications/omegaclaw_v1 --petta-runner ./run.sh
```
