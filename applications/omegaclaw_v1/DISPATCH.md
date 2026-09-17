# Session dispatch revalidation

The v1 entry point initializes Core's session dispatcher before starting the
loop. Model commands and the loop's idle mode-switch request go through
`coreDispatchCommand`; v1 never falls back to arbitrary `eval` on missing policy
or unsupported work. Standalone Core without this explicitly enabled integration
retains its legacy behavior.

**Startup is closed by default.** There are no implicit command grants or typed
policy defaults. A trusted host must provision policies and exact command bindings
before useful execution. The previously documented live invocation alone does
not provide this configuration. Neither model output nor compacted constraint
summaries may provision it. This is a single-frame, serialized, session-only
implementation, not the durable v1 dispatch ledger in `CONTRACTS.md`.

## Trusted host configuration

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

After prompt/decision construction, Core captures an opaque ticket containing
intent, the session revision and current context. The v1 context includes a
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
bash MetaMo/applications/omegaclaw_v1/tests/dispatch_boundary_test.sh
```

Core tests cover stale/revoked work, mutation handlers, unknown commands, replay,
reinitialization, partial failure, malformed gate output, missing configuration,
and policy-writer serialization. MeTTa tests use the real typed gate and an
observable fixture handler to cover permission, budget and mode denial without
effects. External services and live channels are not exercised.

Durable identity/claims, resource reservations and settlement, automatic trusted
handler metadata derivation, multi-frame transition dispatch, and restart
reconciliation remain separate integration work. Host ingestion, bookkeeping and
frame audit updates are host lifecycle operations, not model-selected commands;
this boundary does not turn them into MetaMo-owned mutations.
