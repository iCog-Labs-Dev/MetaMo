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

`host_dispatch_config.py` provisions a bounded set of real Core read and local/IRC send commands.
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

F1.1 initially supports Core's local test-channel stdout outbox. F1.10 below
extends metadata to IRC; executable IRC routing remains F1.11. Both fields are
required for local destinations; null, missing,
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

### IRC destination metadata and binding (F1.10)

Implemented 14 October 2026. The same version-1 configuration parser and send
catalog now accept this explicit destination:

```json
"destination": {
  "channel": "irc",
  "server": "irc.example.org",
  "port": 6667,
  "recipient": "#room"
}
```

The metadata includes normalized `server`, integer `port` and `recipient` fields,
permissions `channels.send` and `channels.send:irc:irc.example.org:6667:#room`,
and exact egress `irc:irc.example.org:6667:#room`. Both `respond` and explicit
`ask-clarification` reuse the existing exact `(send TEXT)` binding and prospective
cost of one `commands/units` per invocation. Declaring this destination does not
grant either scope any permission or egress; both scopes must explicitly allow
the generated requirements. Existing read bindings and local metadata retain
their previous representation.

The bounded server format is an ASCII DNS hostname or canonical IPv4 address;
DNS names are lowercased without resolving them. URLs, credentials, wildcards,
IPv6 literals and trailing dots are outside this slice. Port must be an integer
from 1 through 65535 (booleans and numeric strings are rejected). A missing `#`
prefix is added as in Core's `start_irc`; channel spelling/case is otherwise
preserved, without assuming a server's IRC casemapping. The initial channel
alphabet is ASCII letters, digits, `_`, `#`, `.`, and `-`, with a leading `#` and
at least one following character, at most 50 characters total. Private messages,
multiple recipients, whitespace and protocol control characters are unsupported.
Derived permission and egress identifiers must also fit the existing 256-character
limit. Configuration inputs are not mutated and invalid destinations fail before
policy installation or startup configuration replacement.

F1.10 alone adds metadata/binding support. F1.11 below adds authoritative routing;
F1.12–F1.13 below add observations and outcome handling; F1.14 supplies the
explicit startup profile. Comparing only `commchannel` or raw configuration is insufficient.

Verification: 28 host-configuration Python tests, 18 response-preparation tests
(provider mocked), 62 real local/typed-binding MeTTa assertions and 24 startup
assertions pass. IRC cases install typed bindings for both candidates, reject
missing exact permission/egress in either scope, and retain the routing block.
No IRC transport or live provider was invoked.

### Authoritative IRC routing and dispatch guard (F1.11)

Implemented 14 October 2026 across the v1 adapter and matching Core changes in
`src/dispatch.pl` and `channels/irc.py`. These Core sources must be deployed with
the adapter; an older Core lacks the required guard registration API.

Core IRC now owns a route snapshot containing its actual server, port, channel,
monotonic connection-state generation and availability. Socket publication,
registration, start, stop and disconnect are synchronized by its reentrant
socket lock. Restarting the same endpoint changes the generation; retiring
receiver threads cannot publish against or clear a newer connection. Old
protocol callbacks cannot send through a replacement socket.

`host_operations.irc_route_snapshot` applies F1.10's `destination_metadata`
normalization to that actual transport state. It returns bounded
`(IrcRoute EGRESS GENERATION Ready|Unavailable)` data, or `IrcRouteUnavailable`
for missing/incompatible/malformed transport state. It never starts or imports
a channel during policy checks. This is connection readiness, not confirmation
of channel membership or message delivery.

`mm_dispatch_snapshot` retains this route alongside the channel selector, frame
state and prepared command. Ticket comparison therefore rejects changed endpoints,
channels, disconnects and same-endpoint reconnects. Operation capture filters sends
whose destination is not currently available; the final `dispatchOperationGate`
independently requires exactly the current destination. Existing local/stdout
routing and both-scope feasibility checks remain in force.

Core's optional trusted `oc_dispatch_configure_guard(Enter, Leave)` hook runs
inside its existing dispatch mutex. The v1 adapter takes the IRC route lock
before the final snapshot, policy gate and handler invocation, releasing it with
`setup_call_cleanup` on success, rejection or exception. The lock order is always
**Core dispatch mutex → IRC route lock**. IRC receiver callbacks never acquire
Core's mutex or call its interpreter while holding the route lock. Guard
acquisition failure returns `Blocked MissingPolicyContext`; it cannot invoke a
handler. Reconfiguration clears the optional guard; other Core consumers retain
their existing four-hook configuration behavior.

Preparation still calls the provider outside these locks. Its before/after
snapshot comparison now includes the route generation. The internal
`PreparedHostOperation` record appends `(PreparedRouting CHANNEL ROUTE)`; all
its v1 producers/consumers were updated together, while the public queue API
is unchanged. Resolution checks this captured route too, preventing a newly
captured ticket from adopting preparation published before a reconnect.
No policy grant, new execution path or automatic retry is introduced.

Verification uses real Core dispatch and IRC adapter code with socket/provider
doubles, without contacting IRC or a provider. `tests/irc_dispatch_test.metta`
covers exact destination matching, replay, route changes, reconnect during and
after preparation, and a writer attempting to disconnect between the final gate
and handler. The writer waits until invocation finishes. Seven Python routing
tests cover receiver lifecycle and socket ownership; five Prolog guard tests
cover cleanup, replay, acquisition failure and reconfiguration. The existing
Core dispatch suite (20 declared tests / 22 generated cases), all 58 focused
MeTTa files, 28 host-configuration and 18 mocked-provider preparation tests pass.
The complete MeTTa run includes the existing local/preparation regressions.

From the application directory, after installing matching Core sources:

```sh
python3 tests/irc_routing_test.py
swipl -q -s tests/dispatch_guard_test.pl
python3 ../../scripts/run-omegaclaw.py tests/irc_dispatch_test.metta
python3 ../../scripts/run-tests.py --root . --jobs 2 --timeout 60
```

F1.11 alone does not define a submission result. F1.12 below adds observations;
F1.13 below classifies confirmed submissions for the selected destination.
Automatic greeting preparation remains F2.9, and no live-channel acceptance is
claimed.

### Observable IRC submission (F1.12)

Implemented 14 October 2026 in Core `channels/irc.py` and `src/channels.metta`.
The existing `send` handler parses the IRC adapter's safely encoded observation
and returns it through normal dispatch. Its shape is:

```metta
(SendObservation "irc:irc.example.org:6667:#room"
  (TransportSubmission Submitted Complete 1 1))
```

The final two integers are the number of complete chunks whose socket write
returned normally and the total number of preflighted chunks. A failed chunk
may have written partial bytes; these counts do not estimate those bytes.
Only `Submitted Complete N N` confirms complete **socket submission**. It does
not confirm server acceptance, channel membership, recipient receipt or reading.

| Status | Reason | Meaning |
| --- | --- | --- |
| `Submitted` | `Complete` | Every chunk's `sendall` returned normally. |
| `NotSubmitted` | `Disconnected` | The adapter could establish before writing that the connection/socket was unavailable. |
| `NotSubmitted` | `InvalidDestination` | No supported, safely encoded endpoint/channel; destination is `()` and counts are zero. |
| `NotSubmitted` | `InvalidText` | Preflight rejected the text; counts are zero and no socket write occurred. |
| `NotSubmitted` | `SuppressedDuplicate` | The same wire text was already fully submitted on this destination and connection generation; this invocation wrote zero chunks. |
| `Uncertain` | `WriteUncertain` | A write raised, possibly after partial bytes, even when the completed count is zero. |
| `Uncertain` | `SubmissionInterrupted` | Pacing was interrupted after some chunks but before the whole message was submitted. |
| `Uncertain` | `Disconnected` | Some chunks completed but the low-level helper could not write a later chunk. |

All message framing is validated before the first effect. UTF-8 code points are
kept intact, and each encoded `PRIVMSG` line is at most 512 bytes including its
command, channel and trailing CRLF, following the framing limit in
[RFC 2812 §2.3](https://www.rfc-editor.org/rfc/rfc2812.html#section-2.3).
Both actual LF and Core's existing literal `\\n` convention create separate
message bodies; an apparent command on a later line remains `PRIVMSG` text.
CR, NUL, other disallowed ASCII controls, DEL and lone surrogates fail preflight.
Tabs and ordinary text/whitespace within nonempty lines are preserved. Blank-only
messages are rejected and empty newline segments produce no empty wire message.

F1.11's route lock covers the complete attempt, including all chunks. The first
uncertain write stops the attempt; no remaining chunks, reconnect, or automatic
whole-message retry are attempted. Core's existing ticket ledger replays the
same recorded observation without reinvoking the socket. Exceptions are reduced
to fixed reasons rather than logged with potentially sensitive message/details.
The existing one-second pacing is retained after successful chunks. A pacing
exception after the final completed write cannot erase the known complete
submission; an exception before remaining chunks yields uncertainty.

For IRC only, `send` no longer uses the shared pre-invocation `&lastsend` marker.
The IRC adapter keeps one last-confirmed-submission marker under the route lock,
keyed by destination, connection generation and actual wire commands. Failed,
invalid, disconnected and uncertain attempts never become delivered duplicates.
Reconnecting or changing destination cannot inherit an old connection's marker.
Local/stdout and other channel paths keep their existing behavior. This is the
channel's consecutive-text guard, not task completion or a new retry ledger;
F1.9's task/input/evidence answer suppression remains separate.

Verification: 14 Python submission tests, seven routing tests and 29 MeTTa
submission assertions use socket doubles with the real handler and dispatcher.
They cover both send candidates, successful/uncertain replay, failed first and
later chunks, definite non-submission, marker ownership, UTF-8 framing and input
injection. Local behavior and the F1.11 concurrent-routing tests remain covered
by the focused suite; all 59 MeTTa test files pass. No live IRC messages or
provider requests are made.

F1.12 supplies transport evidence; F1.13 below consumes it. Neither step
completes a commitment or automatically queues a reply.

### Consume IRC observations (F1.13)

Implemented 14 October 2026 in `channel_outcomes.metta` and
`host_operations.py`, delegated from `operationOutcomeStatus`. The shared
`sendOutcomeStatus` entry point resolves the channel from the recorded destination
and calls `channelOutcomeStatus CHANNEL COMMAND DESTINATION OBSERVATION`. Explicit
`local` and `irc` branches own their observation contracts; other channels return
`Unobserved` until a handler is added. Selection matching and submission-count
validation are separate helpers. No live channel is consulted for classification.
The IRC handler recognizes an exact
`DispatchResult Executed Feasible` containing `SendObservation DESTINATION
(TransportSubmission Submitted Complete N N)` as `Success` only when N is a
positive bounded integer and the observation matches the retained selected send
operation's sole canonical IRC destination. The command, candidate (`respond`
or `ask-clarification`), ticket and current operation context must also match
the retained decision. Classification uses that selection, not the current
socket: a later disconnect cannot erase an already observed complete submission.

This profile defines send-operation success as transport submission, not server
or recipient acknowledgement. Partial/uncertain writes, definite non-submission,
suppressed duplicates, malformed counts, unknown shapes and mismatched destinations
remain `Unobserved`; no retry is queued. Explicit dispatch rejection remains
`Blocked` and handler `Error` retains the existing `Failure` classification.
Local/stdout classification is unchanged.

Existing `ingestOperationOutcome` correlation, duplicate/conflicting replay
checks and one-shot consumption remain the only feedback path. A successful
prepared `respond` publishes the F1.9 answer key when consumed; a clarification
never publishes that marker. IRC answer identity includes the canonical server,
port and channel, so equivalent destination spellings share suppression while
different destinations do not. A reconnect to the same destination does not
change task/input/evidence identity. Uncertainty cannot overwrite a prior accepted
answer marker. Send success leaves the task and commitment open.

Verification: 46 outcome assertions cover exact classification, both candidates,
callback validation, replay and one-shot feedback. Another 21 assertions exercise
real preparation, capture, dispatch and socket-double submission, including a
disconnect after submission, answer suppression, uncertainty and no automatic
retry. Twenty-one Python preparation tests include canonical IRC answer identity,
channel routing and supported observation destinations. All 61 MeTTa test files, 14 Python submission
tests and seven routing tests pass. No live IRC or provider calls are used.
Automatic greeting preparation remains F2.9; F1.14 below supplies the explicit
IRC startup profile.

### Explicit IRC startup profile (F1.14)

Copy `host_dispatch.irc.example.json` to an operator-owned absolute path. It uses
the existing version-1 schema and `frame_id: current-frame`, with exact `respond`
and `ask-clarification` send bindings. The example contains placeholder endpoint
`irc.example.org:6667/#room` and fixed example text, not generated answers. Replace
the destination, both scopes' exact permission/egress identifiers and command
text together. Both scopes explicitly grant `send`, `channels.send`,
`channels.send:irc:SERVER:PORT:#CHANNEL` and `irc:SERVER:PORT:#CHANNEL`.
No permissions or destination values are derived from incoming messages.

From the PeTTa workspace root, the existing launcher accepts Core runtime
arguments after its options:

```bash
python3 MetaMo/scripts/run-omegaclaw.py \
  MetaMo/applications/omegaclaw_v1/run.metta \
  --host-config /absolute/path/host-irc.json \
  commchannel=irc IRC_server=irc.example.org IRC_port=6667 'IRC_channel=#room' IRC_user=omegaclaw
```

Replace the example route with the intended route in both places. Provider and
memory configuration remain the existing Core setup. Keep authentication in the
existing Core secret mechanism (`OMEGACLAW_AUTH_SECRET`); no credentials belong
in policy JSON or diagnostics. The JSON grants authority but does not configure
or connect the transport. The launcher flag overrides `OMEGACLAW_HOST_CONFIG`.
An import-only `--audit` checks source resolution, not live route consistency.

Startup validates the JSON before the loop starts. Core initializes its channel
later, so route validation occurs at the first active frame, before installing
policies or selecting an operation. It compares `commchannel` and the IRC
adapter's actual normalized server/port/channel with the host destination.
`StartupChannelMismatch`, `StartupIrcDestinationMismatch` or
`StartupIrcRouteUnavailable` raises a fixed diagnostic and prevents installation;
an already installed configuration is not replaced. No endpoint, message or
credential value is included in those diagnostics. A disconnected but configured
matching route can install policy; F1.11 still blocks dispatch until ready.

Missing configuration prints `MissingReplyPolicy` once and keeps dispatch closed.
A read-only profile without a destination prints `MissingReplyDestination` and
remains usable. Missing required send grants are reported by scope as
`MissingReplyPolicy`; missing `respond` bindings produce `MissingReplyBinding`,
with instructions to supply an exact command or queue trusted preparation.
These diagnostics never add grants, relax denials, create bindings, or claim that
the final gate will admit a command. Constraints, budgets, freshness and connection
availability are still enforced by the existing gate. A preparation-only profile
can intentionally omit static send bindings and receive that diagnostic.

Repeated cycles neither reprint diagnostics nor reinstall the same owner's policy.
F2.8 now installs the operator template separately for each admitted commitment;
arbitrary frame switches do not inherit grants.
F1.14 does not queue a generated greeting or complete a task: automatic replies
still require F2.9's response preparation after F2.1/F2.8 admission and provisioning.
An explicitly authorized fixed binding is not
the automatic conversational preparation path.

Verification: 12 Python startup tests and 28 real startup/dispatch assertions
cover the shipped example, both candidates, normalized and mismatched routes,
missing policy/bindings, read-only operation, credential-free diagnostics,
first-frame installation, ticket replay and later-frame isolation. All 62 MeTTa
test files pass, as do the existing 28 configuration, 21 preparation, seven
routing and 14 submission Python tests. All sockets/providers are doubled;
no live IRC messages are sent.

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
provides classification of send observations, and F1.9 suppresses repeated
accepted answers. An explicit new queue prepares another reply only when its
task, input, request, destination or read evidence has changed.
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

For a local `send` command, `operationOutcomeStatus` recognizes exactly
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
below; F1.9 adds task-level suppression for prepared answers.

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
F1.9 below suppresses repeated accepted answers on subsequent queues.

Verification covers multi-read coverage, missing requirements, readiness without
fresh result feedback, actual local dispatch, cycle expiry, provider invalidation
and policy denial. The 17 Python preparation tests, all 56 MeTTa test files, and
dispatch/commitment boundary guards pass.

### Suppress repeated answers (F1.9)

Prepared read-based answers now carry a host-generated answer key. It identifies
the session, native frame, commitment snapshot, task, most recently admitted input
identity, request, destination, and read paths/content. Evidence order, duplicate
content, new read tickets and alternative provider wording do not make unchanged
evidence a new answer. The key is a SHA-256 digest; no additional evidence history
or dispatch ledger is introduced.

Selection retains the prepared key alongside its existing decision. Only the
existing validated, once-consumed `respond` outcome with status `Success` records
that key as accepted. Clarification, rejection, suppression and uncertain delivery
do not mark an answer accepted. Duplicate callbacks cannot apply it again.

The next capture checks the accepted key before invoking the provider. A matching
queue publishes `(ResponseNoAction AlreadyAnswered)` and exposes no send binding.
Binding resolution also excludes an already-accepted key. The existing final
dispatch snapshot includes the marker, so a marker change invalidates an earlier
ticket. This supplements Core's protection against replaying the same ticket:
new tickets cannot make an unchanged prepared answer eligible again.

Changed evidence, a new admitted input, a changed request/destination or different
task/commitment ownership permits fresh preparation. Session reset clears the
marker. One last-accepted marker is maintained for the bounded active-task flow;
it is not durable delivery history across restarts or a ledger of every past
answer. Fixed host-configured sends without prepared read evidence retain their
existing explicit-command and ticket replay behavior.

No automatic retry is added. Unknown delivery remains unknown; only a fresh
explicit host queue can prepare another attempt. Acceptance still means local
stdout write/flush, and it never completes a task. The host remains responsible
for admitted observation authenticity and task membership.

Verification: 18 Python preparation tests and all 57 MeTTa files pass. Real local
handler regressions cover repeated idle queues without provider calls or sends,
changed evidence, new input/task ownership, duplicate feedback, suppression,
uncertain-send replay and session reset. Dispatch, commitment, adapter and source
boundary guards pass.

### Startup invocation

```bash
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/run.metta --host-config /absolute/path/host.json
```

`OMEGACLAW_HOST_CONFIG` is the equivalent trusted host environment setting; the
launcher option takes precedence. Startup reads and validates the configuration
before starting the loop/services. Missing configuration leaves dispatch closed;
an explicitly supplied unreadable or malformed configuration stops startup.
No secrets belong in this policy file.

Use `"frame_id": "current-frame"` as a template for each admitted open task, or a
concrete ID to require an exact match. Core's initial context has no active frame:
`coreLoopPrepare` runs after message ingestion/frame maintenance, before
`getContext` performs motivational selection. Until a frame exists no bindings
are installed. Native frame IDs are preserved, never renamed. Installation
rechecks the admitted commitment and target under the dispatch mutex and atomically replaces the policies
and exact bindings using the existing host installer.

Repeated cycles for one owner do not reload the file or restore revoked grants.
Later admitted commitments receive fresh bindings from the same operator template;
arbitrary frame switches and mismatched fixed targets remain denied. Outstanding
or unresolved invocations hold task handoff. See
`COMMITMENTS.md#per-task-provisioning-f28` for ownership and diagnostics.
Changing configuration requires explicit trusted reprovisioning or a new process.
Only `read-file`, `show-current-frame` and local/IRC `send` are supported. Candidate
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


## Increment 1 acceptance

Verified 14 October 2026 after the candidate-availability refactor. F1.A1–F1.A11
pass in the bounded offline scope: one active frame, serialized dispatch,
explicit host preparation and policy, real Core read/send handlers, with only
providers and IRC sockets doubled. This does not establish live recipient receipt,
automatic greeting preparation, generated clarification, or task completion.

| Checks | Evidence |
| --- | --- |
| F1.A1–F1.A8 | `tests/increment1_local_acceptance_test.metta`: 48 assertions. |
| F1.A9: repeat A1–A8 on IRC | `tests/increment1_irc_acceptance_test.metta`: the same 48 assertions. |
| F1.A10: route/connection changes | `tests/irc_dispatch_test.metta`: 56 assertions; seven Python routing tests; five Prolog guard tests. |
| F1.A11: truthful failure/uncertainty and framing | `tests/irc_submission_test.metta`: 29 assertions; `tests/irc_outcome_test.metta`: 46 assertions; 14 Python submission tests; shared uncertainty scenarios. |

The shared fixture reads a real temporary file, supplies its accepted observation
to bounded preparation, and checks that `File says: observed local file content`
is actually emitted to stdout or PRIVMSG. The offline provider constructs text
from that observation, rather than returning an unrelated canned answer. The
explicit clarification is host-supplied; both commands traverse selected dispatch.
Substituted commands and changed routes cause no send. Denying egress in either
scope prevents reply selection. Clearing channel duplicate markers demonstrates
that ticket replay alone prevents a second invocation. After successful delivery,
the idle decision is actually dispatched and both send effects and executed-read
ledger counts remain unchanged.

Uncertain attempts retain `Unobserved`, preserve the previous accepted-answer key,
and replay without another effect. The following cycle cannot resend the uncertain
answer or invoke preparation again. A separately configured clarification can
remain eligible; the test distinguishes it from an automatic resend.

From `MetaMo/applications/omegaclaw_v1`, reproduce the acceptance scenarios:

```bash
python3 ../../scripts/run-omegaclaw.py tests/increment1_local_acceptance_test.metta
python3 ../../scripts/run-omegaclaw.py tests/increment1_irc_acceptance_test.metta
python3 ../../scripts/run-omegaclaw.py tests/irc_dispatch_test.metta
python3 ../../scripts/run-omegaclaw.py tests/irc_submission_test.metta
python3 ../../scripts/run-omegaclaw.py tests/irc_outcome_test.metta
python3 tests/irc_submission_test.py
python3 tests/irc_routing_test.py
swipl -q -s tests/dispatch_guard_test.pl
```

The complete regression run passed all 64 MeTTa files, 82 Python tests and both
boundary checks. Reproduce it with:

```bash
python3 ../../scripts/run-tests.py --root . --jobs 2 --timeout 60
python3 tests/host_dispatch_config_test.py
python3 tests/response_preparation_test.py
python3 tests/irc_startup_test.py
python3 tests/irc_routing_test.py
python3 tests/irc_submission_test.py
bash tests/dispatch_boundary_test.sh
bash tests/commitment_boundary_test.sh
```

Current-run full-suite output is `/tmp/increment1-acceptance-suite.log`; per-channel
logs are `/tmp/f1-acceptance-local.log` and `/tmp/f1-acceptance-irc.log`. These are
local temporary evidence, not portable release artifacts. The fixture
sources and commands above are the reproducible acceptance record.


## Automatic conversational preparation (F2.9)

### IRC input normalization (F2.9a)

The v1 ingress callback reads the configured `commchannel`. For IRC only,
`Nahom: hello` becomes body `hello` before routing, frame/commitment admission
and response preparation. Only the first transport prefix is removed; colons
inside the body and all non-IRC message text remain intact. Invalid envelopes
return `HostInput Held InvalidIrcEnvelope` (invalid/empty bodies use
`InvalidInput`). Core's receiver authentication remains unchanged and precedes
normalization; sender metadata is not a new authentication mechanism.

Core joins pending IRC messages with unescaped ` | `, so their original
boundaries cannot be recovered reliably. V1 holds the **entire** input as
`HostInput Held AmbiguousIrcBatch` with no partial routing, frame creation or
commitment changes. Single messages containing that delimiter are also held.
Resend held input as separate messages without that delimiter. Supporting
lossless batches requires a structured transport interface in a future change.

Accepted input retains host-owned provenance:
`(HostTransportInput SESSION FRAME (TransportInput CHANNEL SENDER ORIGINAL) BODY)`.
This state joins the preparation owner alongside the current commitment and
admitted input, so provider results cannot outlive their captured ownership.
Session reset clears it. An open IRC owner's sender is checked before routing
follow-up, cancel or replacement input; a different sender returns `SenderMismatch`
without mutation. Nickname comparison follows Core's lowercase authentication
convention while the original spelling is preserved. Trusted internal `ingest`
calls accept body text directly; only the channel callback unwraps envelopes.

Reproduce the offline checks from the application directory:

```bash
python3 tests/host_ingress_test.py
python3 ../../scripts/run-omegaclaw.py tests/irc_ingress_test.metta
python3 ../../scripts/run-omegaclaw.py tests/conversational_response_loop_test.metta
```

The focused fixture exercises real authentication and the real IRC receive
queue, including same/different-sender batches, sender isolation, follow-up,
replacement, native identity preservation, non-IRC colons and session reset.
Conversational polling fixtures now feed transport-prefixed messages through
Core's queue; providers and sockets remain doubled. No live channel is started.

### Host-owned conversational requirements (F2.9b)

Before automatic response preparation, v1 establishes requirements for the
admitted request under the provisioned open commitment. This runs during
operation capture when an operator-configured reply destination exists; a
read-only profile does not start conversational classification. No classification
installs permissions, bindings, a read plan, answer readiness or completion.

`host_requirements.py` validates bounded proposals and returns one of:

| Assessment | Meaning |
| --- | --- |
| `Conversational` | Eligible for the host-owned no-tool preparation contract described in F2.9c below. |
| `RequiresTools` | Retained work includes `Files`, `Browsing`, `CurrentData`, `PrivateData`, `Execution` or `ExternalAction`. No automatic conversational answer is queued. |
| `NoAction` | Classification is uncertain, unavailable or invalid. No answer is queued and the task stays open. |

Existing host work always takes precedence. An installed continuation and a
successfully queued read-backed response retain `Files`; read queuing requires
the same validated observed outcomes as before. Requirements accumulate across
follow-ups for the same commitment. Replacement uses its new commitment identity;
session reset clears the assessment. A follow-up is assessed with the host task
summary, so a short new message cannot discard the original task.

The exact greeting check needs no classifier call. For other requests with no
known external work, the provider classifies the meaning of the request rather
than applying keyword vetoes. For example, explaining search engines or asking
“How are you today?” can be conversational, while requesting a web search or
current weather requires external work. The provider may propose `Conversation`, `External` or `Uncertain` plus a bounded `needs` list.
The host validates the exact JSON shape, enums, size, duplicates and consistency,
and unions requirements rather than allowing a proposal to remove them. Output
containing commands, permissions, observations, answer text or completion fields
is rejected. Ambiguous context must produce `Uncertain` or explicit no-action.

Classification is heuristic: a valid model proposal is not proof of semantic
correctness. New external requirements depend on the model assessment; existing
host requirements remain binding regardless of the wording of a follow-up. This assessment grants no execution authority. It cannot
replace the existing answer validation, policy checks or evidence requirements.
F2.9c below supplies answer readiness from the exact current assessment.

The provider receives only bounded request/summary text and requirement
categories, with at most 512 output tokens; proposals exceeding 2048 UTF-8 bytes
are rejected. Requests are limited to 4096 characters/16384 UTF-8 bytes. Provider
errors return `NoAction ProviderUnavailable` without exception details or retries.

`host_operations.py` publishes the host record:

```metta
(HostTaskRequirements OWNER CONTINUATION
    (RequiredWork (Files))
    (RequirementAssessment RequiresTools RequiredWork)
    (AssessedRequest "Explain recursion and read /tmp/a"))
```

`OWNER` is the existing native session/frame/commitment/task/admitted-input/
transport-provenance tuple. Publication rechecks that owner, the previous
requirements, continuation, dispatch epoch and complete dispatch snapshot after
inference. Stale results are discarded. Unchanged input reuses its assessment,
including failures and uncertainty, without repeated classification calls.
The conversational queue also rejects retained external work. Read-backed
preparation remains available through its existing evidence path.

Offline reproduction from the application directory:

```bash
python3 tests/host_requirements_test.py
python3 tests/response_preparation_test.py
python3 ../../scripts/run-tests.py --root . --jobs 2 --timeout 60
```

`tests/task_requirements_test.metta` runs isolated scenarios using the real Core polling loop, ingress,
provisioning and capture with provider/socket doubles. They cover classification,
mixed/external work, uncertainty, malformed proposals, provider failure and
follow-up/replacement/session/policy/route invalidation. Classification alone
grants no tool/send/completion authority; the F2.9c scenarios also exercise preparation and sending. The read-capture regression verifies that
actual observed read work is retained in the requirements record.
Each scenario launches the shared loop fixture in a fresh interpreter and
requires all six original checks to pass. The single entry point replaces the
eleven separate wrappers without sharing mutable state between scenarios.

Historical F2.9b verification on 16 October 2026: all 92 MeTTa files, 108 relevant Python tests
and four boundary guards passed. The focused read-capture fixture was rerun
with an additional real-state greeting-shortcut rejection. No live services
were called. Local suite output is `/tmp/omegaclaw-f29b-suite.log`; the commands
and fixtures above are the reproducible evidence.

### General conversational preparation (F2.9c)

After host ingress admits input and F2.8 provisions its open commitment,
operation capture prepares an answer when F2.9b's exact current requirements
record says `Conversational`, has no required external work and no continuation.
This includes greetings, explanations, stable general knowledge, casual
conversation, and writing or rewriting supplied text. The greeting fast path
only avoids a classifier call; it no longer restricts answer preparation.
Automatic file planning and read-backed answers remain F3.1–F3.7; generated
recovery questions remain F4.2.

Configure an explicit local/IRC `destination` and grant the required send skill,
permissions, egress and command budget in both scopes. For automatic replies,
omit fixed `respond`/`send` entries from `commands` (an empty list is valid).
Multiple commands for the same candidate still fail as ambiguous; automatic
preparation does not override the configured command catalog or grants.

The trusted queue accepts `requirements="ConversationNoTools"` with no
observations. It resolves this selector to the live host record through
`mm_response_conversation_source`, checking its owner and exact `AssessedRequest`.
A string token alone, another request's assessment, a stale owner, an unprovisioned
commitment or retained external requirements cannot establish readiness.
`GreetingNoTools` is no longer accepted. `required_reads=[]` remains invalid,
and no-tool preparation cannot be combined with read observations or required reads.

The configured provider receives only bounded conversational request text and
`{"kind":"Conversation","tools":"None"}`. It may answer from that text and
stable model knowledge or return explicit no-action for missing/unsupported
context. Requests retain the classification limit of 4096 characters/16384 UTF-8
bytes; output remains JSON containing only `text` (nonblank, at most 1200
characters) or `no_action: true`, with a 1024-token provider limit and an 8192-byte
raw response bound. Provider failure, malformed output and uncertain answers
produce no-action. No provider text is evaluated as a command or treated as
read, execution, delivery or completion evidence.

Validated text is wrapped by the existing send catalog and publishes
`(NoToolEvidenceReady Conversation TASK)` on the cycle-owned operation. It
passes through ordinary operation admission, selection and Core dispatch.
This marker establishes response readiness only; F2.10 still owns task completion.

Response capture and publication are named predicates in the existing
`dispatch.pl`: `mm_response_capture` and `mm_response_publish`. Python calls
them through Janus with data. They hold Core's dispatch mutex only around state
capture or publication, never across provider inference. They recheck native
session/frame/commitment/input ownership, the exact retained requirements,
continuation, dispatch epoch, policy and route. The dispatch snapshot also
retains requirements and continuation, so changes before invocation invalidate
the selected command. Stale generation cannot overwrite newer input or work.

There is one automatic attempt per unchanged owned input/destination, including
no-action, provider failure or denied attempts. F1.9's accepted-answer key
suppresses reuse. Uncertain transport submission does not cause automatic
regeneration or resend. Core's separate command-generation provider may still
be called while its polling loop is active.

The existing `tests/task_requirements_test.metta` now includes 27 isolated
classification/preparation scenarios with six underlying checks each. These
exercise permitted explanation/factual/casual/writing/rewriting replies, mixed
requests, malformed/no-action/failed providers, denied send policy, uncertain
submission and changes during generation or before dispatch. Existing
`tests/conversational_*_test.metta` retain the greeting regressions, and
`tests/response_preparation_test.py` covers exact contracts, bounds and inert
command-like output. No new test files were added for F2.9c.

All scenarios use the actual Core loop and host boundary with provider/socket
doubles. Successful conversational submissions leave commitments open pending
F2.10; this is not a live-channel or task-completion acceptance claim.

F2.9c verification on 16 October 2026: all 82 MeTTa test files (including the
27 consolidated scenarios), 112 relevant Python tests and four boundary guards
passed. The reduced file count reflects the earlier consolidation of eleven
requirement wrappers into one entry point. Local suite output is
`/tmp/omegaclaw-f29c-suite.log`. No live provider or IRC calls were made.


### Conversational completion configuration (F2.10)

To close eligible IRC conversational tasks after complete socket submission, add
`"completion_criterion": "TransportSubmission"` to the trusted host JSON profile.
The IRC example includes this setting. Omission defaults to `Disabled`, preserving
existing profiles. `LocalAccepted` is available for local stdout;
`RecipientAcknowledged` keeps a task open because submission does not establish
recipient acknowledgement. See [explicit conversational completion](COMMITMENTS.md#explicit-conversational-completion-f210)
for evidence and lifecycle checks. Read requirements and clarification remain
nonterminal under this no-tool rule.


## Completed read-plan answers (F3.7)

An installed read continuation retains its original steps and accepted successful
outcomes in `ContinuationEvidence`, owned by its session, commitment and plan.
The cursor still advances only through consumed feedback. New installations and
session resets clear the retained evidence; Held plans cannot supply an answer.

At ordinary operation capture, the host collects evidence only for a complete
`AwaitingCompletion` plan. The read-specific collector verifies ordered coverage
and each immutable Core result, then the existing response queue prepares an
answer using the actual contents. Collection is separate from preparation so
future skill-specific evidence adapters need not replace the provider/send path.
This implementation still accepts only read steps.

The retained proof is rechecked before and after inference. Policy, route,
input, ownership or evidence changes invalidate publication. No-action and stale
results do not send or complete work; unchanged idle cycles do not retry the same
automatic preparation. An explicit configured destination and send permissions
remain necessary.

After a separately admitted answer is accepted at `local:stdout`, the existing
completion hook checks the exact read decisions and answer through F2.5/F2.6.
It requires the explicit `LocalAccepted` completion policy. F2.7 retains frame
reconciliation; read completion does not reinterpret IRC submission as recipient
acknowledgement. Automatic user-request extraction/installation uses the separate F3.A1
host cycle hook described below.


## Automatic admitted read plans (F3.A1)

At the normal cycle boundary, `prepareAutomaticReadPlan` runs after previous
feedback is consumed and selection is cleared, before the one published frame
snapshot. The trusted Python adapter reuses requirements classification, extracts
only Files-only requests, and constructs the existing bounded ExecutionStep data.
It does not grant permissions, choose a command for scoring, or run a handler.

The existing dispatch mutex protects context capture and final installation.
Owner, input, operation context, full native snapshot and epoch must still match
after provider inference. The final transaction reuses normal admission and
safe-point installation. Active continuations cannot be overwritten. Idle cycles
do not retry unchanged extraction attempts; a sleeping host waits to wake first.
A task requiring files without an admitted plan does not offer arbitrary catalog
reads for execution. Completed plans then use the F3.7 evidence/answer path.

The Core-loop regression supplies one plain-path request and model responses;
it never installs a plan itself. File handlers, local sends, task completion and
normal ingress are real. Core's pre-existing quote-escaping behavior is unchanged.
