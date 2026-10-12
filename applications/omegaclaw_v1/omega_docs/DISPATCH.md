# Session dispatch revalidation

The v1 entry point initializes Core's session dispatcher before starting the
loop. Model commands and the loop's idle mode-switch request go through
`coreLoopDispatchCommand`, whose v1 hook checks the selected exact command before
calling `coreDispatchCommand`; v1 never falls back to arbitrary `eval` on missing policy
or unsupported work. Standalone Core without this explicitly enabled integration
retains its legacy behavior.

**Startup is closed by default.** There are no implicit command grants or typed
policy defaults. A trusted host must provision policies and exact command bindings
before useful execution. Use the explicit startup configuration option below to provide these grants. Neither model output nor compacted constraint
summaries may provision it. This is a single-frame, serialized, session-only
implementation, not the durable v1 dispatch ledger in `CONTRACTS.md`.

## Trusted host configuration

`host_dispatch_config.py` provisions a bounded set of real Core read and local send commands.
Copy `host_dispatch.example.json` into host-owned configuration, replace its
absolute file paths, and explicitly set both policy scopes. The
example is a template; importing the module installs nothing.

| Exact command | Candidate | Required permissions | Egress | Prospective cost |
| --- | --- | --- | --- | --- |
| `(read-file "/canonical/allowed/file")` | `execute-skill` | `files.read` and `files.read:/canonical/allowed/file` | None | 1 `commands` / `units` |
| `(show-current-frame)` | `search-knowledge` | `frames.read` | None | 1 `commands` / `units` |
| `(send "fixed text")` | `respond` | `channels.send` and `channels.send:local:stdout` | `local:stdout` | 1 `commands` / `units` |
| `(send "fixed question")` with explicit candidate | `ask-clarification` | `channels.send` and `channels.send:local:stdout` | `local:stdout` | 1 `commands` / `units` |

The host supplies actual arguments, while the supported-handler catalog derives
the default candidate, target, permissions, egress, and costs. An optional
`candidate` selects only a supported catalog mapping (see F1.3 below); command
entries cannot override handler requirements. File arguments must exactly match an explicitly
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
host API, not a model skill. The startup adapter below invokes the same installer.

The manual `provision` API retains explicit string frame targets. Startup resolves
the configured target to the actual Core ID, preserving its symbol/string type. The host must keep allowlisted paths under its control throughout the
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

## Startup configuration

### Destination metadata (F1.1)

Read-only configuration remains valid without a `destination` field. To declare
the destination for the send binding, add this optional top-level
field to the existing version-1 JSON configuration:

```json
"destination": {"channel": "local", "recipient": "stdout"}
```

Only Core's existing local test-channel stdout outbox is supported in this
increment. Both fields are required when `destination` is present; null, missing,
unknown, extra or unsupported values are rejected before policy installation.
There is no environment-derived destination or fallback to a network channel.

`host_dispatch_config.destination_metadata` resolves that object into:

```metta
(HostDestination (channel "local") (recipient "stdout")
  (permissions ("channels.send" "channels.send:local:stdout"))
  (egress ("local:stdout")))
```

These are handler requirements, not grants. `local:stdout` names the exact
output destination for policy matching even though this channel has no network
transport. The declaration does not change either scope's allowlists, initialize
a channel, or enable `send`. Existing read-only dispatch records remain unchanged.
The existing read-only example intentionally omits this optional field.

### Send binding (F1.2)

With the destination above, append an exact command to `commands`:

```json
{"skill": "send", "arguments": ["Your requested result is ready."]}
```

The catalog derives one `respond` binding for this exact text. Text must be a
nonblank string of at most 1200 characters; control characters below U+0020 are
rejected except newline and tab. Candidate selection is restricted to the catalog
mappings below; permissions, destination and cost cannot be overridden. Missing destination metadata rejects the
configuration before installation.

Both global and frame policies must explicitly allow skill `send`, permissions
`channels.send` and `channels.send:local:stdout`, and egress `local:stdout`.
Their constraints and budgets must admit one `commands` / `units` invocation.
This is a prospective command count, not token usage or settled consumption.

The dispatch adapter reuses the existing feasibility gate, then checks Core's
actual `commchannel` under the dispatch lock. A send requires `local` routing
and exactly `local:stdout` operation egress; otherwise it is blocked with
`DestinationMismatch`. The existing exact-command and replay checks apply.
The host must initialize Core's local channel separately.

This increment accepts fixed host-supplied text. F1.4 now provides a separate
preparation helper; F1.5 connects explicitly queued preparation to normal capture.
F1.6 exposes local stdout acceptance; F1.7 classifies that exact observation as
operation `Success`. Unknown delivery and suppressed duplicates remain `Unobserved`.

Verification: 20 Python host-config tests and all 55 MeTTa test files pass,
including 24 assertions in `tests/host_send_binding_test.metta` exercising real
local stdout output, preserved reads, policy denials, changed routing, exact
arguments and replay protection. The dispatch boundary guard also passes.

### Clarification binding (F1.3)

To bind a fixed question through the same local send handler, add an explicit
candidate to its command entry:

```json
{"skill": "send", "arguments": ["Which file should I inspect?"], "candidate": "ask-clarification"}
```

`send` accepts `respond` or `ask-clarification`; omission still selects `respond`.
`read-file` accepts only its existing `execute-skill` mapping and
`show-current-frame` only `search-knowledge`. These mappings may also be stated
explicitly. Null, malformed, unknown or mismatched candidates reject the complete
configuration before installation. No candidate changes handler requirements or
adds policy grants.

Configure distinct exact text for a response and a question if both are present.
The existing duplicate-command check rejects identical commands even when their
candidate labels differ. Configure one command per candidate to avoid the existing
`AmbiguousOperation` rejection. A ticket captured for `respond` cannot invoke the
question bound to `ask-clarification`, or vice versa.

The question uses the same text bounds, destination metadata, policy gate, final
local-routing check and replay protection as a response. This task adds a trusted
binding; automatic question preparation, recovery routing and acknowledged
delivery remain subsequent work. Its handler result remains `Unobserved` in the
operation outcome classifier.

Verification on 11 October 2026: 23 Python host-config tests, all 55 MeTTa test
files and the dispatch boundary guard pass. The extended local-send regression
has 43 assertions checking coexistence, candidate isolation, a real question
send, replay, unchanged reads/responses, policy denials and routing changes.

### Response preparation (F1.4)

`host_operations.prepare_response(provider, request, context, observations)` is a
trusted Python host API. It calls the existing `lib_llm_ext.callProvider` interface
to prepare text from successful read observations. It does not register commands,
capture tickets, invoke a channel, consume feedback or complete a task. Startup
does not automatically gather evidence or queue it; F1.5 provides that trusted
queue interface and calls preparation during the normal pre-scoring capture.

The host supplies list representations of the existing `OperationContext` and
`OperationOutcome` records. For example, after the corresponding read outcome has
been accepted by `ingestOperationOutcome`, a trusted caller can use:

```python
context = ["OperationContext", "session-id", 2, "frame-id"]
command = ["read-file", "/allowed/input.txt"]
outcome = [
    "OperationOutcome",
    ["OperationDecision", ["OperationContext", "session-id", 1, "frame-id"],
     "execute-skill", command, ["DispatchTicket", "ticket-id"]],
    ["attempted-command", command],
    "Success",
    ["DispatchResult", "Executed", "Feasible", "Observed file contents"],
]
prepared = host_operations.prepare_response(
    "ASICloud", "Summarize the file", context, [outcome])
```

The sample IDs and observation illustrate the API; constructing such a list is
not evidence of admission. The caller must obtain outcomes from the validated
host path and retain only evidence belonging to the current task. This helper
checks shape and correlation, not caller authority, dispatch-ledger authenticity
or commitment ownership. Model-supplied records and compacted history are not
valid sources. Gathering retained observations is subsequent host integration.

Input bounds and checks:

- Nonblank request of at most 1200 characters, using the send-text control rules.
- One to sixteen successful `read-file` outcomes for the supplied session/frame.
  Observed cycles must be positive and no later than the supplied current cycle;
  cycles and ticket IDs must be unique. Earlier read cycles may support a later answer.
- Each attempted command must match its recorded decision, candidate must be
  `execute-skill`, and result must be `Executed / Feasible` with string content.
  Failed, blocked, unknown, malformed or mismatched evidence rejects the batch.
- Each read content is at most 8192 characters; the complete serialized request
  and evidence payload is at most 32768 UTF-8 bytes. Oversized data is rejected,
  never silently truncated. Empty file content remains a valid observation.

The provider receives separate instructions and a JSON data payload containing
the request and exact read paths/contents. It is asked to use only those
observations and avoid invented execution, delivery and task-completion claims.
One provider call requests at most 1024 output tokens. The helper adds no retry;
transport timeouts/retries remain the existing provider's behavior.

The provider must return exactly `{"text":"..."}` or `{"no_action":true}`.
The parser rejects duplicate keys, extra fields, markdown-wrapped JSON, malformed
responses and output above 8192 UTF-8 bytes. Text uses the same nonblank,
1200-character/control-character checks as the send catalog and is safely quoted
as data in the returned MeTTa record:

```metta
(ResponsePrepared "Validated answer text")
(ResponseNoAction InvalidInput)
(ResponseNoAction InputTooLarge)
(ResponseNoAction ProviderUnavailable)
(ResponseNoAction InvalidResponse)
(ResponseNoAction InsufficientEvidence)
```

Structural validation is not proof of the answer's semantic accuracy. Prepared
text remains a proposal, not an authorized command or observed delivery. F1.5
binds/captures it through the existing gate, and F1.8 must determine whether
the task has enough observations to answer. This slice handles read-based answers;
it does not automatically generate clarification questions or enable IRC sending.

`tests/response_preparation_test.py` checks the provider contract, exact evidence,
input/output bounds, invalid correlation, uncertainty, duplicates, escaping,
no-action handling, failure without helper retries, and absence of channel or
dispatch calls. A transport-mocked test also exercises the real ASICloud provider
registry. Run it with:

```bash
python3 MetaMo/applications/omegaclaw_v1/tests/response_preparation_test.py
```

### Capture prepared commands (F1.5)

After admission and a successful observed read, trusted host code can queue
preparation using the F1.4 observation representation:

```python
host_operations.queue_response_preparation(
    "ASICloud", "Summarize the file", [outcome],
    {"channel": "local", "recipient": "stdout"})
```

This returns `(ResponsePreparationQueued)` or an explicit `ResponseNoAction`.
The queue copies and validates its inputs and captures the host's session, native
frame identity, commitment snapshot and active task. It does not call the provider
or grant policy. One pending request is supported; a new explicit queue replaces
the previous input. Invalid input clears pending preparation.

On the next normal `captureCandidateOperations` call, before admission and
scoring, the existing `host_operations.capture` consumes that request once:

1. Under Core's existing mutex, clear any previous prepared command and verify
   ownership and the published bundle. Capture current context, snapshot and epoch.
2. Release the mutex and call F1.4's bounded provider helper.
3. Reacquire the mutex. If owner, context, snapshot or epoch changed during the
   call, discard the result. Otherwise publish one `PreparedHostOperation` using
   the fixed send catalog's requirements and Core's exact native frame identity.
4. Enumerate it together with existing configured bindings and capture ordinary
   Core tickets. The concrete gate, scheduler and scorer operate on the usual
   `HostOperation` rows. Existing selection retains the winning command and its
   original pre-scoring ticket through Core's loop hooks.

The new slot is cycle/commitment-owned data, not another ticket ledger. It expires
for resolution on a later operation cycle and is cleared on session reset, policy
replacement or explicit revocation of its command. No-action output exposes no
binding. Static read and clarification bindings remain available. If a static
`respond` binding is also present, the existing ambiguity checks reject that
candidate rather than silently replacing the configured command. For generated
replies, configure send permissions/egress but omit a fixed `respond` command.

Both policy scopes must still allow send. Denied generated replies are pruned
before scoring; preparation never makes them admissible. Substituting selected
text is rejected, and replaying the same ticket returns its recorded result
without another handler invocation.

Dispatch snapshots now include the actual `commchannel` and prepared-command
state. A channel change after capture causes `StaleSnapshot`; a fresh decision
captured while routing to an unsupported channel still fails the final
`DestinationMismatch` gate. Only local/stdout is supported in this increment.
Relevant host mutations must still use the existing serialized mutation API;
arbitrary concurrent writes or unsanctioned change-and-restore sequences are
outside this session contract.

The trusted caller remains responsible for admitted evidence and deciding when
to queue it. Ordinary startup does not automatically gather a task's observations
or generate an answer on every message. F1.8 adds host-declared answer readiness; F1.7
provides classification of send observations, and F1.9 owns task-level duplicate-answer
suppression. An explicit new queue can prepare another reply in a later cycle.
There is no new IRC support, autonomous task planning or durable recovery here.

The offline `tests/prepared_response_capture_test.metta` uses a real read,
native symbol frame identity, normal bridge/scoring, real local send and existing
dispatch. It checks provider-time invalidation, final stale tickets, exact text,
replay, policy denials, no-action output, revocation and task/session ownership.
Only external providers and memory are doubled.

### Send observation (F1.6)

The real local channel now returns a constant observation only after its JSON
output has been written and stdout has flushed. Core's existing `send` handler
parses that observation and dispatch preserves it in the normal result:

```metta
(DispatchResult Executed Feasible (SendObservation "local:stdout" Accepted))
```

`Accepted` means local stdout accepted the write and flush. It is not evidence
that a person read the message, that a remote channel delivered it, or that the
task is complete. No message text is interpolated into the parsed observation.
Other channel adapters retain their existing return values and receive no new
acknowledgement or authorization.

If Core's existing last-message guard suppresses a local send, the result is
`(SendObservation "local:stdout" SuppressedDuplicate)`. No output occurred for
that invocation. If writing or flushing raises, partial output may already
exist: the existing dispatcher records `Unobserved ExecutionUncertain`, never
`Accepted`. Ticket replay returns the recorded result without another write,
including after an uncertain send. This does not add retries or task-level
duplicate suppression.

F1.7 classifies this observation through `operationOutcomeStatus` below.
Tests cover actual stdout output,
write/flush exceptions, suppression, acceptance replay and uncertain replay.

### Send outcome classification (F1.7)

For a `send` command, `operationOutcomeStatus` now recognizes exactly
`(DispatchResult Executed Feasible (SendObservation "local:stdout" Accepted))`
as `Success`. This means the local output operation succeeded, with only the
write-and-flush guarantee described above. It does not assert remote delivery.

Suppressed duplicates, legacy integer returns, missing or malformed observations,
unsupported destinations and uncertain dispatch results remain `Unobserved`.
Existing explicit dispatch rejections stay `Blocked`; handler `Error` results
retain the existing `Failure` classification.

Both `respond` and `ask-clarification` use the existing correlated outcome
ingestion and one-shot feedback consumption. The raw dispatch result is retained;
duplicate callbacks cannot apply feedback twice, and a callback cannot label an
uncertain send as success. Successful consumption resets the existing operation
failure streak, as it does for other successful operations.

No task-completion rule changes: delivery success alone does not close a task or
commitment. The real prepared-response regression verifies that a local reply
produces success feedback while the task stays open. F1.8 adds answer availability
below; F1.9 task-level suppression remains separate work.

The existing signal projection now sees that success on the next cycle, rather
than treating the send as an unknown result. In the prepared-response fixture,
that changes the next selection from `search-knowledge` to `none`: the previous
cycle's reply binding has expired and no new answer has been prepared.

Verification: all 56 MeTTa test files pass, including 69 outcome-ingestion and
51 prepared-response assertions. Dispatch and commitment boundary guards pass.

### Answer availability (F1.8)

The trusted host can now state which reads its answer requires when queuing
preparation. For example, after retaining admitted successful outcomes for both
files:

```python
host_operations.queue_response_preparation(
    "ASICloud", "Compare the two files", admitted_read_outcomes,
    {"channel": "local", "recipient": "stdout"},
    required_reads=["/allowed/first.txt", "/allowed/second.txt"])
```

`required_reads` contains 1–16 unique, bounded path strings. Matching uses the
exact paths in the successful read commands. Every required path must be covered
by the supplied session/frame-correlated observations. Missing coverage returns
`(ResponseNoAction MissingRequiredReads)` without calling the provider; malformed
requirements return `InvalidInput`. Both clear pending preparation. The host
still owns outcome authenticity and task membership, and must supply the complete
requirements for this answer. This is not an automatic task planner or a new
evidence store.

When coverage is complete and the provider produces a valid answer, the existing
`PreparedHostOperation` carries `(ReadEvidenceReady TASK)`. The existing
`taskResultReadyForBundle` rule accepts that evidence alongside its earlier result
signal. Thus a task can offer `respond` even after fresh read feedback has been
consumed. Readiness requires a current prepared binding, matching frame and task
summary, and the existing open-task, no-new-input, clarification and error checks.
Existing continuation precedence still selects a pending execution step first.

Readiness expires with the command's operation cycle and commitment ownership.
Revocation, policy replacement and session reset clear the same command slot;
provider no-action or invalid output does not publish readiness. Concrete policy
admission and exact-ticket dispatch remain mandatory. Readiness grants no send
permission and does not complete a task.

The optional argument preserves existing four-argument callers: they can still
prepare commands, but do not assert this new required-read readiness. Normal
startup still needs trusted host code to collect observations and queue an answer.
Task-level repeated-answer suppression remains F1.9.

Verification covers multi-read coverage, missing requirements, readiness without
fresh result feedback, actual local dispatch, cycle expiry, provider invalidation
and policy denial. The 17 Python preparation tests, all 56 MeTTa test files, and
dispatch/commitment boundary guards pass.

### Startup invocation

```bash
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/run.metta --host-config /absolute/path/host.json
```

`OMEGACLAW_HOST_CONFIG` is the equivalent trusted host environment setting; the
launcher option takes precedence. Startup reads and validates the configuration
before starting the loop/services. Missing configuration leaves dispatch closed;
an explicitly supplied unreadable or malformed configuration stops startup.
No secrets belong in this policy file.

Use `"frame_id": "current-frame"` to bind once to the first active frame, or a
concrete ID to require an exact match. Core's initial context has no active frame:
`coreLoopPrepare` runs after message ingestion/frame maintenance, before
`getContext` performs motivational selection. Until a frame exists no bindings
are installed. Native frame IDs are preserved, never renamed. Installation
rechecks the target under the dispatch mutex and atomically replaces the policies
and exact bindings using the existing host installer.

Repeated cycles do not reload the file or restore revoked grants. Later frames
do not inherit the first frame's permissions; mismatched targets remain denied.
Changing configuration requires explicit trusted reprovisioning or a new process.
Only `read-file`, `show-current-frame` and local `send` are supported. Candidate
generation and policy still determine which operation can be selected on a given cycle.
The default Core preparation hook does nothing when the v1 startup adapter is
absent. Preserve the updated Core `src/dispatch.metta` and `src/loop.metta` with
`host_startup.metta`, `run.metta`, the host configuration module and launcher.

`tests/host_startup_test.metta` checks delayed provisioning, native identity,
bridge admission, real read/frame handlers, once-only installation, target mismatch,
permission denial and isolation across frame changes. These are local integration
checks with external services doubled, not a live provider/channel run.

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

The native reader now returns `(Error read-file FileUnavailable)` when its
pre-open file check fails. This is a definite `Failure`; empty file contents
remain `Success`, and later read exceptions remain `Unobserved`. Preserve Core's
updated `src/skills.metta`; [LIVE_MODES.md](LIVE_MODES.md) records the live
failure/recovery and mode-transition evidence.

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

Core ticket UUID serialization was repaired on 24 September 2026. Previously,
bare UUID atoms with numeric exponent-like prefixes (for example `18e99999-...`)
could raise `float_overflow` in PeTTa's text parser. Core now converts the UUID
to a string before storing or returning the ticket, so serialization quotes it
and parsing preserves the ledger key's type. Deterministic Core regressions
cover exponent-like, numeric-leading and alphabetic-leading IDs, round-trip
identity, replay/conflicting replay, and stale-ticket rejection. Use the updated
Core `src/dispatch.pl` overlay; older copies retain the failure. The generic
PeTTa parser is unchanged.


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

### Startup wiring verification — 24 September 2026

Commands from the workspace root:

```bash
python3 MetaMo/scripts/run-tests.py --root MetaMo/applications/omegaclaw_v1 --petta-runner ./run.sh --jobs 2 --timeout 60
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/host_startup_test.metta
python3 MetaMo/applications/omegaclaw_v1/tests/host_dispatch_config_test.py
python3 MetaMo/scripts/import-resolution-test.py
swipl -q -s repos/OmegaClaw-Core/Autotests/dispatch/dispatch_test.pl
bash MetaMo/applications/omegaclaw_v1/tests/dispatch_boundary_test.sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/run.metta --audit --report /tmp/omegaclaw-startup-imports.json
```

Results: all 48 MeTTa files pass; the final standalone startup scenario passes
20 assertions, including registration through `initializeHostStartup`. All 12
configuration Python tests, eight import regressions, 20 named Core dispatch
tests (22 generated cases), the dispatch boundary guard and startup audit pass.
Logs: `/tmp/omegaclaw-startup-regressions.log` and
`/tmp/omegaclaw-host-startup-test.log`. An initial new-test failure reflected a
fixture without an open task; it was corrected to load the admitted native frame
and establish the task before checking candidate admission. No live services or
external channel messages were used.
