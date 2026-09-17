# Typed operation checks on PeTTa

`typed_policy.metta` implements pure MeTTa admission checks. It has no Prolog
helper, service dependency, execution authority, or mutable policy registry.

Call `typedOperationPolicyGate global frame operation candidate target` for
typed policy checks, or `feasibilityGateForOperation bundle candidate operation
global frame` to additionally apply the existing frame and constitutional-mode
gates. Both return one `GateDecision Admitted Feasible` or `GateDecision Rejected
REASON`. Rejection is never overridden by a mode or motivational score.

Base policy rejection keeps its original reason in every constitutional mode,
including Threat. Sleep may additionally reject otherwise admitted operational
work; leaving Sleep does not remove host restrictions. Risk/stability penalties
and the scorer's `safety` candidate category express preferences only. A raw
numeric score is not an admission result, and zero score is not a typed denial.
Callers must retain the gate decision separately and score only admitted work.
`tests/mode_monotonicity_test.metta` covers all four modes, rejection precedence,
denied maximum-confidence proposals skipping scoring, and real risk penalties.

The global and frame values are **resolved host-owned policy**, not strings
extracted from compacted bundle summaries. The frame scope must identify the
operation's target. `feasibilityGateForOperation` supports the bundle's current
frame. The common request API below also accepts a separate authoritative target
snapshot for cross-frame requests; it never uses origin-frame policy as a substitute.

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

Use `resourceBudgetFromAccounting resource unit limit spent reserved status`
to derive validated availability after both consumption and pending reservations.
The host atomic reservation, settlement, replay and uncertain-outcome rules are
defined in [BUDGET_ACCOUNTING.md](BUDGET_ACCOUNTING.md). This pure helper does not
implement or mutate a host ledger.

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

### Candidate pruning and diagnostics

`pruneActionsForBundle bundle actions` returns
`(CandidatePruning (admitted (...)) (rejected ((CandidateRejection candidate reason) ...)))`.
It applies the preliminary frame/mode gate individually, preserves action order
and payloads, and never scores rejected actions. The bridge passes the admitted
list into the motivational cycle; `omegaclawDecideForBundle` also prunes before
scoring. Empty or entirely rejected lists yield the existing no-action decision.
These local records do not extend the versioned wire contracts.

`generateCandidates` records policy rejection for available native candidates;
`generateCandidatesForOperations` records concrete gate rejection for supplied
operation rows. Read `(candidateRejections)` after generation for typed reasons.
Both generators clear previous diagnostics, including on empty input. Candidates
omitted by availability heuristics are not reported as policy rejections. The
bridge appends any additional rejection from its pre-cycle action check.

The concrete generator retains the full host-resolved policy gate; preliminary
list pruning is not a substitute for permission/egress/budget enforcement at
dispatch. Low risk or a high score cannot restore a removed candidate, and an
admitted zero-score candidate remains eligible. Tests in
`tests/candidate_pruning_test.metta` cover mixed lists, ordering, typed reasons,
scorer exclusion, diagnostic reset, and no-action behavior.

### Common request admission

`feasibilityGateForRequest origin target request operation global frame` is the
shared concrete gate for native candidates, proposals, attention and transitions.
Requests have the shape `(AdmissionRequest kind requested-target candidate)`.
Kinds are `propose-candidate`, `request-attention`, `request-frame-switch`, and
`request-mode-change`. The candidate must be known, the operation's candidate and
frame must match, and both snapshots must provide valid frame identity/status/mode.
Every concrete path requires an active/focused target, including attention and
operations whose legacy candidate-name checks did not require a frame.

| Entry point | Use of the common gate |
| --- | --- |
| `candidateAdmissionForOperation`, `feasibilityGateForOperation` | Same-frame native operation with explicit host metadata. |
| `generateCandidatesForOperations bundle rows` | Applies existing availability rules and the common gate before adding candidates. Rows are `(CandidateOperation candidate operation global frame)` supplied by the host, with one resolved operation per candidate. Empty rows yield no candidates; there is no legacy fallback. |
| `reasonerProposalAdmissionForOperation origin target proposal operation global frame` | Validates proposal shape, then checks its actual kind, target and candidate against the host operation. |
| `reasonerProposalToActionForOperation`, `reasonerProposalScoreForOperation` | Rejected proposals become no-action/zero score; the scorer is not invoked. Accepted proposals use the target bundle for scoring. |
| `attentionDirectiveForRequest origin target request operation global frame score` | Uses the common gate and destination frame. Rejection produces `task none`, no slice/target, priority zero and the typed reason, regardless of score. |

For native work and attention, `current-frame` must resolve to the origin frame;
`(FrameTarget id)` must match the supplied target snapshot. The target's frame
mode must match the origin's root mode. A frame switch additionally requires
the `switch-frame` handler and explicit `frames.switch-frame` permission metadata.
It cannot be admitted by using an unrelated handler with candidate `defer`.

A mode request uses `(ModeTarget Fast)` or `(ModeTarget Slow)` and requires
`(ModeOperation mode policy-operation)` with the identical requested mode. The
inner operation must identify the actual target frame, handler `switch-mode`,
and permission `frames.switch-mode`. The destination frame must be active and
compatible with the requested mode. Both transition types are operational work
under Sleep, even when their motivational candidate is `defer`. Transition
handlers cannot be hidden inside ordinary candidate or attention requests.

The host must retain the admitted request and operation alongside the advisory
directive; a legacy directive alone does not encode the transition mode or
concrete command. MetaMo performs no frame mutation. Host policy resolution,
snapshot consistency, revision checks and final dispatch remain host duties.

### Production wiring still required

The legacy `feasibilityGate bundle candidate` still performs preliminary checks
only. Legacy reasoner admission now rejects attention, cross-frame and transition
requests with `MissingOperationContext`; only current-frame candidate suggestions
remain on its preliminary path. Production candidates lack trusted handler metadata,
and the legacy projection still compacts policy summaries. This change therefore
does **not** claim that production dispatch enforces the new checks. Core must
resolve policy and derive metadata from the actual handler/arguments, wire the
concrete request APIs into scheduling, revalidate current policy, and reserve
and account for resources before execution. These are separate Phase 3 items.

`tests/fixtures/typed_policy.metta` provides reusable policy/operation examples.
`tests/typed_policy_test.metta` exercises the pure gate through PeTTa; the focused
context policy suite exercises composition with the existing frame/mode gate.
`tests/request_admission_test.metta` checks all concrete entry paths, cross-frame
targets, blocked destinations, mode/handler mismatches, transition permissions,
Sleep, maximum-confidence proposals and no-action output at maximum priority.

```sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/typed_policy_test.metta
python3 MetaMo/scripts/run-tests.py --root MetaMo/applications/omegaclaw_v1 --petta-runner ./run.sh
```
