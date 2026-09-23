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
Reading the published bundle also occurs inside that mutex during capture.
The selected-path regression now passes 43 assertions, including host
change-and-restore, explicit revocation followed by restored grants, and file
replay returning the original observation. Core's 17 dispatcher tests also pass,
including concurrent policy-writer serialization; the existing ledger is reused.

| Situation | Result |
| --- | --- |
| No command selected, including all candidates denied or no configured bindings | `(DispatchResult Blocked MissingDecision none)`; policy/directive report `none`, `Rejected`, zero priority, and directive reason `NoAction` |
| Command or ticket differs from the retained selection | `(DispatchResult Blocked UnselectedOperation none)` |
| Changed context/revision, including revocation through the host API | `(DispatchResult Blocked StaleSnapshot none)` |
| Fresh context but current policy denies work | `(DispatchResult Blocked REASON none)`, retaining the typed gate reason |
| Unknown ticket, unsupported command, missing/invalid policy or failed validation | Typed `Blocked` result with `none`; handler never invoked |
| Handler returns | `(DispatchResult Executed Feasible RESULT)`; this reports invocation, not adjudicated task success |
| Handler throws/fails after invocation begins | `(DispatchResult Unobserved ExecutionUncertain none)`; effects may have occurred |

`none` on a blocked result is the explicit no-action fallback. Core records
blocked/uncertain results in `&error` so lifecycle bookkeeping cannot mistake
them for successful completion. Stale decisions are never refreshed in place:
recompute from current state and issue a new ticket on a subsequent cycle.
Candidate diagnostics retain the individual permission, budget, constraint, or
unsupported-operation reasons when admission produces no selected command.
The selected-path regression passes 58 assertions, including observable checks
that denied, unsupported, and unconfigured work never invokes a fallback handler.

Each ticket permits at most one invocation. Identical redelivery returns the
recorded result without repeating effects; a changed command returns
`ConflictingReplay`. Remaining commands in a model batch cannot reuse the ticket
to start additional work. Every invocation advances the session revision, making
other outstanding tickets stale. Reinitialization invalidates all old tickets.
An uncertain attempt is not automatically retried.

## Session outcome correlation

The existing host adapter publishes `&operation-context` alongside each snapshot
after lifecycle bookkeeping: `(OperationContext SESSION CYCLE FRAME)`. Startup
allocates a UUID session; publication increments the cycle. Native frame IDs and
the existing bundle shape are unchanged. Pure motivational fixtures do not need
this host context.

Selection freezes `(OperationDecision CONTEXT ACTION COMMAND TICKET)` in
`&selected-operation-decision`. The dispatch hook records the typed observation
in `&last-operation-outcome` before Core formats result text:

```metta
(OperationOutcome
  (OperationDecision (OperationContext "session-id" 3 "frame-id")
    execute-skill (read-file "/allowed/file") (DispatchTicket ticket-id))
  (attempted-command (read-file "/allowed/file"))
  Success
  (DispatchResult Executed Feasible "observed content"))
```

`Success` means an observed string from `read-file` or a frame from
`show-current-frame`; it does not mean task completion. An explicit returned
`Error` is `Failure`, a denied invocation is `Blocked`, and uncertain execution
or an unrecognized handler result is `Unobserved`. The raw result is preserved.
Outcome context comes from the retained decision, never the current frame.
Mismatched commands/tickets remain blocked and do not overwrite the selected
action's observation. Repeated delivery retains the same correlation identity.

Before each new snapshot, `prepareTaskStateForMetaMo` consumes the preceding
cycle's observation only when session, cycle, and current frame match. It retains
an applied-decision marker and projects `(OperationFeedback STATUS FAILURE-STREAK)`
through the runtime's `operation-feedback` field. A cycle without a new matching
observation publishes `NoOutcome`. Frame changes exclude the old observation;
returning to that frame later does not apply stale feedback.

Concrete-dispatch signals use this typed projection: `Success` produces progress,
`Failure` advances the failure streak, and `Blocked`/`Unobserved` produce neither
progress nor an observed-failure signal. Success resets the streak; other statuses
preserve it. Re-reading a snapshot cannot increment the streak. Formatted results
and errors remain display data and do not populate legacy execution bookkeeping.
Offline bundles without concrete dispatch retain their existing text-based path.

Operation success does not complete a task. Only the existing trusted host
commitment adjudication/event path can close it, and that state is mirrored before
the next snapshot. New messages do not discard matching operation feedback.

### Validated session callbacks

`ingestOperationOutcome` is the trusted MeTTa host entry point for an
`OperationOutcome`. Dispatch routes observations through it; host callers must
pass literal records as quoted data. It is not a model skill or an authenticated
network endpoint. Call it in the existing serialized host loop, before the next
snapshot publication; concurrent callback threads must hand off to that loop.

Validation requires the current session/cycle/frame context and the exact retained
selected decision, including action, command arguments and ticket. The attempted
command must equal the selected command. The dispatch result must have the
recognized shape/status, and the reported outcome status must match
`operationOutcomeStatus`. Unknown or malformed records are rejected. For no-action
selections, dispatch records a canonical empty attempted command with
`Blocked MissingDecision none`; arbitrary rejected model commands cannot replace
that observation.

| Result | Meaning |
| --- | --- |
| `OutcomeAccepted` | First valid observation for this decision stored; feedback is applied only during pre-snapshot bookkeeping. |
| `OutcomeDuplicate` | Identical current-decision redelivery; no state changes, before or after consumption. |
| `(OutcomeRejected ConflictingReplay)` | A different valid observation for the same decision; the first observation remains unchanged. |
| `(OutcomeRejected WrongSession)` | Callback belongs to another session, including one that ended before reset. |
| `(OutcomeRejected StaleCycle)` | Callback cycle differs from the current cycle, including future cycles. |
| `(OutcomeRejected MismatchedDecision)` | Frame, action, selected command or ticket does not match the retained decision/context. |
| `(OutcomeRejected MismatchedCommand)` | Attempted command differs from the decision's exact command. |
| `(OutcomeRejected MalformedOutcome)` / `(OutcomeRejected InconsistentStatus)` | Invalid record/result shape or status inconsistent with the observation. |
| `(OutcomeRejected MissingSession)` | No initialized operation context. |

All rejections leave the pending observation, consumption marker, failure streak,
feedback and motivation unchanged. `applyOperationOutcome` revalidates before
consuming and retains the applied-decision marker, so repeated application cannot
increment the streak twice. New decisions returning identical result text still
count separately. After the cycle advances, even identical old callbacks are
rejected as stale rather than reopening feedback. A frame change before consumption
excludes the old feedback. Unknown execution remains `Unobserved`; later amendments
to an accepted observation are outside this MVP.

This remains one in-memory latest-observation slot for the serialized selected
invocation, not a durable ledger or asynchronous callback queue. Session reset
clears its feedback and consumption marker. This completes session callback
validation/deduplication; active multi-step continuation remains separate Task 3
work. No Core or Prolog source changes are required.

`tests/outcome_ingestion_test.metta` covers mismatched identity fields, malformed
and inconsistent records, duplicates before/after consumption, conflicting replay,
late cycles, reset, inert callback expressions and identical results from distinct
decisions. Run it through the common launcher:

```sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/outcome_ingestion_test.metta
```

## Verification and limits

PeTTa's existing text parser can intermittently raise `float_overflow` when a
Core ticket UUID begins with a numeric exponent-like prefix (for example,
`18e99999-...`). This affects the existing ticket text round-trip, independently
of feedback processing; an interrupted run is not a failed feedback assertion.


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
