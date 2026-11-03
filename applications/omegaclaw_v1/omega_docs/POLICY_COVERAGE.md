# Which execution paths enforce policy

This audit follows each supported command from admission to final dispatch and
asks where its budget, permissions, egress, skill, and safety restrictions are
checked. It was recorded on 26 October 2026 using the local MetaMo (`1622d9b`
base) and OmegaClaw-Core (`8cabe49` base) working trees.

Follow-up work connected live budget availability to admission and final
revalidation. G1 below records the original audit finding;
its availability wiring is resolved as described in
[the budget lifecycle documentation](BUDGET_ACCOUNTING.md#available-budget-and-account-lifetime).
Reservation and settlement also resolve G2 for command invocations through
[production reservation and settlement](BUDGET_ACCOUNTING.md#reserving-and-spending-command-units).
The dispatcher now checks raw native constraints, current host justification, native
budget closure, continuation-mode regression coverage and command-batch limits;
see [native constraint enforcement](DISPATCH.md#native-constraints-and-justification).
G3–G4 are closed for the supported catalog. For G5, the command-batch limit is
now enforced. Provider, transport, and memory setup remain a trusted host-service
boundary with existing per-call caps, not a new command-budget resource. No
additional host-service meter or rollout is introduced. The tables below
preserve the original audit baseline.

## Production boundary

[`run.metta`](../run.metta) loads Core and the v1 composition, initializes
`initMetaMoDispatch`, installs host startup, and starts `motivatedOmegaclaw`.
[`dispatch.metta`](../dispatch.metta) installs `captureHostOperations` and the
`selectedHostTicket` / `dispatchSelectedHostCommand` Core loop hooks. This is
the enabled v1 path covered below. Pure composition has no execution provider.
Standalone Core intentionally retains legacy evaluation when dispatch has not
been enabled; that separate entry point does not provide these guarantees.

The supported production handler catalog is defined by
[`host_dispatch_config.py`](../host_dispatch_config.py), `binding`:
`read-file`, `show-current-frame`, and `send`. Send maps only to `respond` or
`ask-clarification`. The host derives metadata from the actual command; JSON
cannot substitute permissions, egress, target or costs. Other Core skills being
listed in a prompt does not make them executable through this catalog.

The common path is:

1. Trusted startup provisions exact command bindings and explicit global/frame
   `PolicyScope` records. Missing policy supplies no executable grants.
2. `prepareTaskStateForMetaMo` finishes host bookkeeping and publishes one
   bundle. `host_operations.capture` requires the current bundle to match,
   resolves host bindings, checks send routing, and captures Core tickets before
   scoring.
3. `pruneActionsForBundle` applies preliminary frame/budget-status and posture
   checks. `admitCapturedOperations` / `hostOperationGate` require exactly one
   concrete operation per candidate and call `candidateAdmissionForOperation`.
   Rejections are removed before scheduling and scoring in `bridge.metta`.
4. `dispatchSelectedHostCommand` accepts only the selected command and ticket.
   Core's `coreDispatch` reacquires its mutex and transport guard, checks epoch
   and full snapshot equality, resolves the operation again, and calls
   `mm_dispatch_gate` → `dispatchOperationGate` → `feasibilityGateForRequest`.
   Only `GateDecision Admitted Feasible` reaches `mm_dispatch_execute`.
5. Core claims the ticket before invocation. Identical replay returns its stored
   result; conflicting replay is denied. Exceptions/failure retain
   `Unobserved ExecutionUncertain`. This prevents duplicate invocation for the
   same ticket, but does not reserve any resource balance.

Source: [`bridge.metta`](../bridge.metta),
[`operation_selection.metta`](../operation_selection.metta),
[`host_operations.py`](../host_operations.py),
[`dispatch.pl`](../dispatch.pl), and
[Core dispatch](../../../../repos/OmegaClaw-Core/src/dispatch.pl).

## Supported paths and applicable policy

Every executable row below requires both global and target-frame scopes to
allow the skill, required permissions and declared egress, satisfy typed
constraints, and provide an open `commands` / `units` budget of at least 1.
Each command declares a prospective cost of 1 command unit. These are static
availability comparisons, not accounting (G1–G2 below).

| Production path | Skill, permission and egress requirements | Admission | Final dispatch and remaining limits |
| --- | --- | --- | --- |
| Configured file read | `read-file`; `files.read` and `files.read:/canonical/path`; no egress | Catalog requires one explicitly allowlisted canonical regular file. Common gate checks target, active status, frame/root mode equality and both policy scopes. | Exact arguments and catalog binding are resolved again through the common gate. Core's read handler reports definite unavailable-file failure; other invocation uncertainty is retained. Host ownership of configured paths is assumed; there is no byte/I/O budget or file-content confinement beyond the trusted path. G1–G2 apply. |
| Frame inspection | `show-current-frame`; `frames.read`; no egress | Common concrete gate, despite `search-knowledge` not requiring a frame in the preliminary candidate-only gate. | Common revalidation and exact no-argument command. G1–G2 apply. |
| Fixed local answer or clarification | `send`; `channels.send` and `channels.send:local:stdout`; egress `local:stdout` | Nonblank bounded text, catalog-approved candidate, both scopes, active/mode-compatible frame; actual channel must be local. | Routing is checked again; only local stdout is allowed for that metadata. Outcome/deduplication checks do not consume a balance. G1–G3 apply. |
| Fixed IRC answer or clarification | `send`; `channels.send` and destination-specific `channels.send:irc:SERVER:PORT:#CHANNEL`; matching egress | Same checks plus normalized exact server, port and channel, with a ready authenticated transport route. | Core holds the route guard from final snapshot through handler invocation; route changes invalidate the operation. Partial/uncertain submission is not inferred as delivery. G1–G3 apply. |
| Prepared conversational or read-backed answer | Same send catalog and destination requirements as fixed sends | Prepared data must match native session/frame/commitment/input and current routing. Conversational readiness uses the retained no-tool assessment; read readiness uses actual retained successful Core outcomes. Publication rechecks snapshot/epoch. Ordinary concrete admission and scoring follow. | Exact selected prepared text only; `preparedHostBinding` and `mm_dispatch_resolve` recheck owner and routing, then common final gate. Provider generation precedes this admission; its costs/egress are outside this command gate (G5). G1–G3 also apply. |
| Installed read continuation, including corrected/resumed reads | Same exact file-read requirements; each step costs 1 command unit | `hostAdmitContinuation` → `continuationAdmitReads` checks every proposed read against the installed catalog and common gate. Installation revalidates ownership and policy under the dispatch lock. Capture exposes only the expected Ready read; correction/retry uses the same admission. | Every selected step uses ordinary Core revalidation. Held plans and outstanding uncertain reads cannot silently retry; retry count is bounded. Frame/root mode mismatch is rejected by the common request gate. Whole-plan admission does not reserve aggregate cost. G1–G2 apply; production continuation mode-mismatch regression remains to be demonstrated (G4). |

Sources: `binding`, `allowed_file`, `destination_metadata`, `scope` and `_INSTALL`
in [`host_dispatch_config.py`](../host_dispatch_config.py);
`preparedHostBinding`, `continuationOperationRows`, `hostOperationGate` and
`dispatchSelectedHostCommand` in
[`operation_selection.metta`](../operation_selection.metta);
`continuationReadGate`, `continuationAdmitReads` and `dispatchOperationGate` in
[`dispatch.metta`](../dispatch.metta); `mm_dispatch_resolve`,
`mm_dispatch_gate`, `dispatchRoutingAllowed` and the response-proof predicates
in [`dispatch.pl`](../dispatch.pl).

## Constraint and mode coverage

| Rule | Effective enforcement | Coverage limit |
| --- | --- | --- |
| Skill allowlist, required permissions, egress allowlist | `tpScopeReason` checks both scopes at concrete admission and final dispatch. | Only declared host metadata is checked; trusted registration must describe the real handler. |
| `DenySkill`, `RequirePermission`, `DenyEgress`, `MaxCost` | `tpConstraints` / `tpConstraint` enforce these as hard feasibility checks in both scopes. | `MaxCost` caps each declared operation cost, not cumulative spending. |
| Unsupported typed constraints | Config parser rejects them. `tpScopeValid` also rejects malformed/unknown constraints as invalid global/frame policy before execution. | Core's prose `Constraint` records are separate from typed `PolicyScope` constraints; they are not translated into these checks (G3). |
| Active frame and Fast/Slow mode matching | `requestFrameStateReason` requires Active/Focused status and frame mode equal to origin root mode for ordinary operations. The check is shared by read-plan admission, corrected-read admission and final dispatch. | Continuation ownership/Ready state alone does not prove mode compatibility. Existing pure request tests cover mismatch; see G4 for the remaining production-path check. |
| Constitutional posture | `constitutionalModeGate` can only tighten admission. Sleep rejects candidates classified by `candidateRequiresFrame`; explicit transition requests are tested as operational work even if named `defer`. | `respond`, `ask-clarification` and `search-knowledge` are not in that operational set; they still need ordinary concrete policy. Dedicated bounded Sleep work classes still need to be connected. |
| Core frame budget/status | Preliminary candidate gating checks the current frame budget status for frame-requiring candidates. Provider calls receive output caps. | Core's `max-output-tokens`, `max-command-lines` and `wake-interval` record is not a live accounting vector. The command loop does not enforce the recorded five-command maximum as a parser/batch limit. G1–G2/G5 apply. |
| `NoUnjustifiedAutonomousSideEffects` | Core declares it; concrete gating supplies partial protection via active target, mode matching and typed policy. | No dedicated semantic check or typed representation; declaration alone is not enforcement (G3). |
| Autonomous frame creation only in Slow mode | No production v1 catalog binding exists for `new-autonomous-frame`, so model attempts are denied. | Core's public helper and `cfv2-create-autonomous-frame` do not check the current root mode or applicable constraints (G4). Creating a frame whose stored mode is Slow is not a check that creation happened in Slow mode. |

Sources: [`typed_policy.metta`](../contexts/typed_policy.metta),
[`request_admission.metta`](../contexts/request_admission.metta),
[`context_policy.metta`](../contexts/context_policy.metta),
[Core context](../../../../repos/OmegaClaw-Core/src/context.metta), and
[Core loop](../../../../repos/OmegaClaw-Core/src/loop.metta).

## Unsupported routes and host work outside command dispatch

- `shell`, file writes, memory/query/search skills, arbitrary `metta`/state
  mutation, model frame creation and frame/mode switching have no bindings in
  the supported config catalog. V1 rejects unselected commands before handler
  invocation; Core also rejects unresolved operations. The loop's idle
  `switch-mode` attempt uses this same boundary and cannot bypass it.
- Pure request APIs can validate `request-frame-switch` and
  `request-mode-change`, but the default host catalog and resolver do not
  install those executable routes. Optional reasoner proposal code is not
  loaded by production composition. Tests of those APIs do not establish a
  production transition handler.
- Trusted ingress creates user-directed frames and handles follow-up,
  replacement, cancellation and correction outside model dispatch. Startup
  provisions policies; host completion updates commitments/frames from
  validated outcomes. These are host control-plane paths, not autonomous
  frame creation or model skill grants.
- Provider calls (classification, plan extraction, response preparation and
  Core command generation), channel startup/polling/authentication, memory
  initialization and runtime history/persistence writes happen outside
  `coreDispatch`. Send egress grants do not cover all network traffic or these
  host resource costs. See G5; no live services were exercised for this audit.
- Trusted Prolog registration/`eval` APIs are not a sandbox for host code. The
  guarantees require trusted metadata/configuration, serialized interpreter
  access, and policy/state mutations through Core's mutation/epoch boundary.
  Standalone Core's legacy `eval` path must not be presented as enabled v1.

## Findings from the original audit

| ID | Finding and source evidence | Follow-up |
| --- | --- | --- |
| G1 | `scope` copies configured `available` directly into `ResourceBudget`; `mm_dispatch_snapshot` reads those installed policies. Production composition does not import `budget_accounting.metta`; production callers do not call `initBudgetAccounts` or `budgetAvailability`. A fresh ticket can therefore see the same availability after prior execution. | **1.2:** publish live available balances from the existing component in both scopes. Define resource coverage for the supported handlers; do not claim token/byte/monetary accounting from the current command count. |
| G2 | Core claims/replays dispatch identities, but `oc_dispatch_locked` and `mm_dispatch_execute` neither reserve nor settle resources. No production caller uses `reserveOperationBudget` or `settleOperationBudget`. Read-plan admission checks each step against the same prospective availability. Uncertainty holds protect continuation from retries but hold no resource balance. | **1.3:** connect atomic reservation and outcome settlement for applicable resources; preserve pending consumption, replay behavior and revocation checks. No durable restart subsystem is required by this item. |
| G3 | `NoUnjustifiedAutonomousSideEffects` appears in `cfv2-default-constraints` as descriptive text. `frameStateRootProjection` / `frameStateCurrentProjection` compact Core constraints for display. Gates enforce only the four supported typed constraints from separately installed scopes; they do not evaluate those Core declarations. An unknown constraint explicitly supplied to a typed scope does fail closed, but an unsupported Core declaration is not automatically made such a scope constraint. | **1.4:** identify the applicable safety declarations, supply authoritative structured enforcement, and reject applicable unsupported constraints at admission and final dispatch. Active-frame and budget predicates alone must not be credited as the complete named constraint. |
| G4 | Normal continuation reads share `requestFrameStateReason`, so the mode check exists. Existing request tests demonstrate mismatch, but the audited continuation suite does not explicitly demonstrate a real continuation mismatch at admission and final invocation. Separately, `new-autonomous-frame` stores a Slow frame without checking root mode, and `cfv2-create-autonomous-frame` calls the generic creator unconditionally. V1's unsupported catalog prevents current model access but is not enforcement inside those helpers. | **1.4:** demonstrate continuation mode denial through production adapters, including a change after selection; guard any supported autonomous-creation route with Slow mode and applicable policy. Do not add a new executable route merely to satisfy this audit. |
| G5 | Catalog metadata models only command-count cost. Core generation and host preparation call providers before/outside command admission; they have per-call output caps but no shared policy-budget reservation. The recorded five-command limit is prompt guidance rather than enforced batch truncation/rejection. Channel and memory setup also run outside the command gate. | **1.2–1.4:** determine which declared budgets/constraints apply to this host work and wire the necessary enforcement. Preserve the distinction between command egress and host-service egress; this audit does not authorize new services or live rollout. |

The existing accounting implementation and its boundaries are described in
[`BUDGET_ACCOUNTING.md`](BUDGET_ACCOUNTING.md). G4 is partly an evidence gap;
it does not claim that the shared continuation mode predicate is missing.

## Verification

The following existing offline checks were rerun for this audit. Provider and
transport integration fixtures use doubles; this is not a live-channel claim.
No new test files or runtime changes were introduced.

| Existing check | Result | Evidence scope |
| --- | --- | --- |
| `tests/host_dispatch_config_test.py` | 29 tests passed | Closed catalog, derived metadata and config validation. |
| `tests/dispatch_guard_test.pl` | 5 tests passed | Guard held through gate/invocation, release on rejection/error, replay and uncertainty. |
| `tests/dispatch_boundary_test.sh` | Passed | Static startup/hook order and admission-before-scoring guards. |
| `tests/typed_policy_test.metta` | 45 assertions passed | Both scopes, permissions, egress, costs, units, unknown constraints and target identity. |
| `tests/request_admission_test.metta` | 36 assertions passed | Shared request gate, frame status/mode, transition metadata and pruning. |
| `tests/dispatch_test.metta` | 18 assertions passed | Core revalidation, stale tickets, replay, budget/posture denial and unsupported commands. |
| `tests/host_dispatch_config_test.metta` | 20 assertions passed | Real provisioning and exact Core handler bindings. |
| `tests/operation_selection_test.metta` | 134 assertions passed | Concrete pre-score admission, retained selection and execution-feedback correlation. |
| `tests/task_continuation_test.metta` | 496 assertions passed | Real read admission/installation, corrections, policy denials, retry and uncertainty holds. |
| `tests/irc_dispatch_test.metta` | 56 assertions passed | Exact IRC routing, final transport checks and submission outcomes with doubles. |

From the PeTTa workspace root, reproduce the Python, Prolog and shell checks:

```bash
python3 MetaMo/applications/omegaclaw_v1/tests/host_dispatch_config_test.py
swipl -q -s MetaMo/applications/omegaclaw_v1/tests/dispatch_guard_test.pl
bash MetaMo/applications/omegaclaw_v1/tests/dispatch_boundary_test.sh
```

For each MeTTa file listed above, use the canonical launcher, for example:

```bash
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/typed_policy_test.metta
```

These results describe the original audit baseline. The follow-up links at the
top describe the connected accounting, native constraints, and frame-creation
checks. The supported budget meter still counts commands only, and this audit
does not establish durable recovery or enforcement for every possible host service.
