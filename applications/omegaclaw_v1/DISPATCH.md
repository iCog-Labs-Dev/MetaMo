# Session dispatch revalidation

The v1 entry point initializes Core's session dispatcher before starting the
loop. Model commands and the loop's idle mode-switch request go through
`coreLoopDispatchCommand`, whose v1 hook checks the selected exact command before
calling `coreDispatchCommand`; v1 never falls back to arbitrary `eval` on missing policy
or unsupported work. Standalone Core without this explicitly enabled integration
retains its legacy behavior.

**Startup is closed by default.** There are no implicit command grants or typed
policy defaults. A trusted host must provision policies and exact command bindings
before useful execution. The previously documented live invocation alone does
not provide this configuration. Neither model output nor compacted constraint
summaries may provision it. This is a single-frame, serialized, session-only
implementation, not the durable v1 dispatch ledger in `CONTRACTS.md`.

## Trusted host configuration

`host_dispatch_config.py` provisions a bounded set of real Core read commands.
Copy `host_dispatch.example.json` into host-owned configuration, replace its
frame ID and absolute file paths, and explicitly set both policy scopes. The
example is a template; importing the module installs nothing.

| Exact command | Candidate | Required permissions | Egress | Prospective cost |
| --- | --- | --- | --- | --- |
| `(read-file "/canonical/allowed/file")` | `execute-skill` | `files.read` and `files.read:/canonical/allowed/file` | None | 1 `commands` / `units` |
| `(show-current-frame)` | `search-knowledge` | `frames.read` | None | 1 `commands` / `units` |

The host supplies actual arguments, while the supported-handler catalog derives
the candidate, target, permissions, egress, and costs. Command entries cannot
override these requirements. File arguments must exactly match an explicitly
allowlisted canonical regular file. Other skills, arities, nested expressions,
and unregistered paths receive no binding.

Each global/frame scope must explicitly include `skills`, `permissions`,
`egress`, `constraints`, and `budgets`. Constraints support `DenySkill`,
`RequirePermission`, `DenyEgress`, and `MaxCost`; unknown constraints are rejected.
Budgets declare resource, unit, available amount, and `Open`, `Closed`, or
`Exhausted` status. Empty grants stay empty. The gate checks both scopes;
registration alone does not make an operation feasible.

In trusted startup/admission code, after loading composition and dispatch and
establishing the current frame, initialize dispatch and provision before starting
the loop:

```metta
!(import! &self (library MetaMo applications/omegaclaw_v1/host_dispatch_config.py))
!(initMetaMoDispatch)
!(sread (py-call (host_dispatch_config.provision "/absolute/path/host.json")))
```

Provisioning validates the complete configuration and typed records, then
atomically replaces policies and exact bindings under the existing dispatch
mutex. Successful replacement invalidates outstanding tickets. Invalid
configuration preserves the previous policies and bindings. This is an explicit
host API, not a model skill or automatic configuration in `run.metta`.

The frame ID must match the typed snapshot target. The integration fixture uses
an explicit string ID; mapping native Core symbol IDs to this contract remains
pending. The host must keep allowlisted paths under its control throughout the
session: provisioning-time path validation is not a filesystem sandbox.
Costs currently account for command units only, not file bytes, memory, or time;
budgets are checked prospectively without reservation or consumption settlement.

`dispatch.pl` supplies these Prolog host APIs (not exported as model skills):

| API | Responsibility |
| --- | --- |
| `mm_dispatch_set_policies(Global, Frame)` | Install complete authoritative `PolicyScope` records for the global and current-frame scopes. Missing or malformed scopes cannot grant permission. |
| `mm_dispatch_register(Command, Request, Operation)` | Register one exact ground command with the existing `AdmissionRequest` and `PolicyOperation` metadata derived by its trusted handler. |
| `mm_dispatch_revoke(Command)` | Remove a command binding and invalidate outstanding decisions. |
| `oc_dispatch_mutate(Goal)` | Serialize an external host mutation with final checks/invocation and advance the in-memory revision, including after failure. |

Configure these from trusted startup code, after loading the adapter and before
starting the loop. A command is MeTTa's parsed Prolog data, for example
`['read-file', "/workspace/input.txt"]`; it is not a shell command string.
The host must derive required permissions, egress and conservative costs from
the actual arguments, preserve applicable constraints in typed policy, and use
consistent resource units. Registering a command is not itself admission: every
invocation reruns `feasibilityGateForRequest` against fresh context and policies.

The current live intent adapter binds the selected candidate to a same-frame
`propose-candidate` request. Cross-frame and mode-transition instructions are
unsupported on this live path and produce no action. The Core dispatcher can
wrap mutation handlers supplied by another trusted adapter, but there is no
automatic transition authorization or fallback through a `defer` candidate.

## Final check and outcomes

Before scheduling or scoring, `host_operations.py` reads the installed policies
and exact bindings under Core's dispatch mutex and captures the existing Core
tickets. It verifies the published bundle still equals current host state;
the raw bundle stays inside the host instead of being round-tripped through text.
`operation_selection.metta` applies `candidateAdmissionForOperation` to each
available candidate using this captured metadata. Missing bindings reject with
`UnsupportedOperation`; more than one binding for a candidate rejects with
`AmbiguousOperation`. The current candidate scorer cannot select between multiple
argument sets, so configure one exact command per candidate for this slice.
Denied candidates never enter scheduling or numeric comparison.

Selection retains the exact command and its original ticket. Core's MeTTa loop
hooks return that ticket after prompting, without recapturing or refreshing it.
Only the selected command and arguments reach the existing Core dispatcher;
substitutions receive `UnselectedOperation`. The prompt requests one exact command.
The default Core hooks continue to use its existing dispatcher when v1 is absent.
V1 refuses startup with a Core revision lacking these hooks.

The captured ticket contains intent, session revision and current context. The v1 context includes a
fresh frame bundle, complete installed policies, constitutional mode and raw
`&cfv2-*` state values. The raw values are retained by the host dispatcher, not
exposed to motivational scoring. Namespace mutations and external policy/state
writers must also use `oc_dispatch_mutate`; comparing snapshots alone cannot
detect a change-and-restore or synchronize an unsanctioned concurrent writer.

Under one host mutex, dispatch resolves the ticket, compares current revision
and context, resolves exact command metadata, reruns the typed gate, records an
invocation claim, and invokes the handler. The current serialized interpreter
holds the mutex through synchronous completion. Relevant external writers must
use the same mutation API; arbitrary concurrent `change-state!` is unsupported.

| Situation | Result |
| --- | --- |
| Changed context/revision, including revocation through the host API | `(DispatchResult Blocked StaleSnapshot none)` |
| Fresh context but current policy denies work | `(DispatchResult Blocked REASON none)`, retaining the typed gate reason |
| Unknown ticket, unsupported command, missing/invalid policy or failed validation | Typed `Blocked` result with `none`; handler never invoked |
| Handler returns | `(DispatchResult Executed Feasible RESULT)`; this reports invocation, not adjudicated task success |
| Handler throws/fails after invocation begins | `(DispatchResult Unobserved ExecutionUncertain none)`; effects may have occurred |

`none` on a blocked result is the explicit no-action fallback. Core records
blocked/uncertain results in `&error` so lifecycle bookkeeping cannot mistake
them for successful completion. Stale decisions are never refreshed in place:
recompute from current state and issue a new ticket on a subsequent cycle.

Each ticket permits at most one invocation. Identical redelivery returns the
recorded result without repeating effects; a changed command returns
`ConflictingReplay`. Remaining commands in a model batch cannot reuse the ticket
to start additional work. Every invocation advances the session revision, making
other outstanding tickets stale. Reinitialization invalidates all old tickets.
An uncertain attempt is not automatically retried.

## Verification and limits

Run from the workspace root:

```sh
swipl -q -s repos/OmegaClaw-Core/Autotests/dispatch/dispatch_test.pl
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/dispatch_test.metta
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/host_dispatch_config_test.metta
python3 MetaMo/applications/omegaclaw_v1/tests/host_dispatch_config_test.py
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/operation_selection_test.metta
bash MetaMo/applications/omegaclaw_v1/tests/dispatch_boundary_test.sh
```

Core tests cover stale/revoked work, mutation handlers, unknown commands, replay,
reinitialization, partial failure, malformed gate output, missing configuration,
and policy-writer serialization. Provisioning tests invoke real Core file and
frame readers and cover exact arguments, permission/skill denial, budget and
maximum-cost denial, policy replacement, invalid configuration, and replay.
Other MeTTa tests use the real typed gate and an
observable fixture handler to cover permission, budget and mode denial without
effects. External services and live channels are not exercised.

The operation-selection regression exercises the real bridge/scorer with trusted
configuration and a typed current frame, followed by real Core frame inspection.
It also checks the real file reader, missing configuration, permission/budget/cost
rejection before scoring, exact-command enforcement, inert command expressions,
replay, ambiguous bindings, and policy replacement between selection and dispatch.
External providers and memory are doubled. Production startup provisioning and
native symbol-to-typed-frame mapping remain pending; this is not live acceptance
or execution-outcome feedback.

Verified locally on 23 September 2026: all 40 focused MeTTa files pass, including
32 operation-selection assertions; eight import regressions, ten provisioning
Python tests, 17 Core dispatch tests, and four shell boundary guards pass.
The host checkout requires the updated `src/dispatch.metta` loop hooks and the
three corresponding `src/loop.metta` call sites alongside the MetaMo changes.

Durable identity/claims, resource reservations and settlement, additional trusted
handler catalogs, native frame-ID mapping,
multi-frame transition dispatch, and restart
reconciliation remain separate integration work. Host ingestion, bookkeeping and
frame audit updates are host lifecycle operations, not model-selected commands;
this boundary does not turn them into MetaMo-owned mutations.
