# OmegaClaw motivation and host integration

`omegaclaw_v1` connects MetaMo's motivation system to OmegaClaw-Core. Core owns
frames, tasks, permissions, and execution. MetaMo reads a limited snapshot of
that state, regulates its operating posture, filters candidates, and recommends
what deserves attention. The host checks the actual command again before it runs.

This folder explains how that connection works and how to run and test it.
Source paths are relative to `MetaMo/applications/omegaclaw_v1` unless a guide
says otherwise.

## Start here

| You want to… | Read |
| --- | --- |
| Understand the vocabulary and component roles | [Glossary](OMEGACLAW_GLOSSARY.md) |
| Set up matching repositories and launch the application | [Workspace setup](DEPENDENCIES.md) and [module loading](COMPOSITION.md) |
| Configure allowed commands and understand a blocked dispatch | [Command execution](DISPATCH.md) and [policy checks](TYPED_POLICY.md) |
| Understand spending and reservations | [Command budgets](BUDGET_ACCOUNTING.md) |
| Follow a task through completion, cancellation, or replacement | [Commitments](COMMITMENTS.md) |
| Handle a missing file, correction, retry, or uncertain read | [Continuation](CONTINUATION.md) |
| Understand observations, modes, and attention | [Signals and appraisal](FACTUAL_SIGNALS_R2.md), [mode transitions](MODE_TRANSITIONS.md), and [scheduling](SCHEDULING.md) |
| Inspect record formats and identity checks | [Contracts](CONTRACTS.md) and [identities](IDENTITY.md) |
| Run without external services | [Offline tests](OFFLINE_SERVICES.md) |
| See what was verified with real services | [Live setup](LIVE_SETUP.md), [execution run](LIVE_CYCLE.md), and [mode run](LIVE_MODES.md) |

## What happens during a cycle

1. The host admits input and updates its task records from observed outcomes.
2. It publishes one bounded frame-state snapshot for the motivational cycle.
3. MetaMo extracts typed observations, evaluates their motivational meaning,
   and chooses a constitutional mode.
4. Admission removes candidates that violate the applicable constraints.
   Scheduling precedence and scores choose among the survivors.
5. The host retains the exact selected command and ticket. Core rechecks current
   policy, routing, and budget before invoking its handler.
6. The next cycle reads the recorded outcome. A successful command or delivered
   reply does not by itself close a task; completion follows the host's criterion.

The selected command now enters Core as data. There is no extra model call to
repeat command syntax, and no command-generation call on an empty selection.
Reply preparation, classification, and relation analysis still use their own
provider calls. See [direct host command input](DISPATCH.md#direct-host-command-input).

## Three different kinds of mode

Scheduling precedence is **Threat-remediation > Recovery > Interactive >
Orienting > Engaged > Rumination > Sleep**. Only allowed candidates enter this
comparison. These scheduling classes are separate from the four constitutional
postures (**Engaged, Threat, Rumination, Sleep**) and Core's **Fast/Slow** frame
execution modes. None of them grants permission to run a command.

The bridge also publishes [review hints](RESURFACING.md) for waiting frames.
A hint keeps work visible; it does not unblock it or switch frames.

## Installation

For the verified ASICloud, local-memory and local-test-channel profile, see
[LIVE_SETUP.md](LIVE_SETUP.md). Run `python3 tools/verify_live_setup.py` from the application directory (`MetaMo/applications/omegaclaw_v1`) to reproduce setup verification with isolated artifacts and real services.

[LIVE_CYCLE.md](LIVE_CYCLE.md) records the subsequent seven-cycle real-bridge
success, controlled read-failure/recovery and policy-denial demonstration, with
the required Core budget fix and explicit limits of its serialized host driver.

Use the exact source revisions and workspace structure recorded in
[DEPENDENCIES.md](DEPENDENCIES.md). Keep `MetaMo/`, `repos/OmegaClaw-Core/`,
and `repos/petta_lib_chromadb/` inside the same PeTTa workspace. Use the common
launcher below for canonical import resolution and one-time module loading.
See [COMPOSITION.md](COMPOSITION.md) for dependency and initialization rules.
The setup reports verify the profiles they describe, not every machine, provider,
or runtime configuration.

## Usage

Configure dependencies, credentials, and trusted host policy before starting the
application. The launcher does not grant permission to run commands. Missing
policy produces no action, and stale or revoked decisions cannot fall back to
direct evaluation. See [command execution](DISPATCH.md) for the complete setup.

Use matching MetaMo/Core sources so the selected command enters the checked
dispatcher directly. See [direct host command input](DISPATCH.md#direct-host-command-input).
The [host configuration template](../host_dispatch.example.json) and
[provisioning instructions](DISPATCH.md#trusted-host-configuration) cover exact
`read-file` and `show-current-frame` commands with explicit global/frame policies.

```bash
OMEGACLAW_AUTH_SECRET=<channel-secret> python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/run.metta IRC_channel="<irc-channel>"
```

Run from the PeTTa workspace root and replace the channel and secret placeholders.

## Minimal loop demo

The full motivational bridge has a separate offline regression:
`tests/bridge_cycle_test.metta` uses real Core ingestion/projection and calls
`motivationContextBlock`, including state updates and persistence scheduling,
with external provider/memory doubles. That test covers fresh messages and idle
no-action. Other suites cover continuation and observed execution feedback. See
[offline service tests](OFFLINE_SERVICES.md) for commands and limitations.

For real message ingestion without ChromaDB or LLM services, see
[offline service tests](OFFLINE_SERVICES.md). These use test-only provider
doubles while retaining Core frame creation and MetaMo projection, signal
extraction, appraisal, scoring, and policy. They are separate from the fixed-score
demo below and do not establish a complete execution-feedback loop.

The deterministic vertical-slice demo exercises the v1 path from one bounded
`FrameStateBundle` through adapter projection, signal refresh, constitutional
mode selection, candidate generation, feasibility checking, and action/directive
selection. It does not require a live channel, LLM, persistence backend, or
ChromaDB:

```bash
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/minimal_loop_test.metta
```

Run this command from the PeTTa workspace root. The
`tests/run_minimal_loop.sh` convenience wrapper uses the same launcher.
Pass `--workspace` to select a compiler workspace explicitly; the default is
the parent of this MetaMo checkout. Native `petta` and `run.sh` do not enforce
one-time module loading.

The demo is intentionally narrower than the production loop and is suitable
for showing the core integration before the remaining runtime requirements are
implemented. The first slice uses one deterministic `respond` candidate and a
fixed score; the real bundle feasibility gate is still exercised and asserted.

## NARS / PLN proposal integration

Live proposal intake is not connected yet. The default `composition.metta` and
`run.metta` do not import the MetaMo proposal adapter or inference extension.
Native candidates, scoring, policy and dispatch operate independently. Existing
reasoner code/tests are retained as an explicit optional extension.

`reasoner_integration.metta` loads PeTTa's local `lib_nars` and `lib_pln`
through `reasoner_engines.pl`. The loader prefixes all library-defined function
names because PeTTa compiles functions globally even across imported spaces.
It uses the local PeTTa parser/compiler and rejects runnable library forms.
The original libraries are not modified or copied. These are distinct from
OmegaClaw-Core's `lib_nal` and `lib_pln` rule libraries.

For offline extension development, load the application composition once, then
its inference extension. `reasoner_integration.metta` owns the proposal adapter
and engine imports. Do not import `reasoner_proposals` separately when loading
that extension under native PeTTa. If the host has already
loaded the composition, add only the second import:

```metta
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_integration))
```

The caller supplies bounded `Sentence` facts and stable evidence stamps from an
admitted frame slice. A positive conclusion `(Recommend FRAME CANDIDATE)` must
be supported by inference; querying it does not assert it. NARS uses `==>` for
implication and PLN uses `Implication`. For example:

```metta
(reasonerInferProposal nars proposal-1 frame-A
   ((Sentence ((Failed frame-A) (stv 1.0 0.9)) (observation-1))
    (Sentence ((==> (Failed frame-A) (Recommend frame-A repair-failure))
       (stv 1.0 0.9)) (rule-1)))
   repair-failure (Expected recovered) (InferenceLimits 8 10 40))
```

The return is a `ReasonerMotivationalProposal` or `()` for no supported positive
recommendation. The full truth value is retained in support and the evidence
stamps are retained in evidence references. Confidence is the engine's confidence,
not a calibrated probability of success. The positive-value cutoff is an initial
seed rule. `reasonerInferDirective` additionally takes a frame bundle and MetaMo
state and calls the existing validation, feasibility, scoring, and audit path.
It returns an advisory scheduler directive; it does not execute anything.

Automatic frame-to-fact extraction, proposal collection in the live bridge,
and scheduler outcome callbacks remain deferred host integration work. Shared
wire contracts may still represent proposals without loading an adapter or engine.

Legacy proposal accessors require a ground `ReasonerMotivationalProposal` with
exactly ten fields. Malformed input returns
`(ReasonerAccessorRejected InvalidProposal)`. `getProposalEventProposal` requires
the exact `ReasonerProposalEvent` constructor and ordered `proposal`, `decision`,
and `disposition` fields, each containing one value, plus a matching proposal
shape. Malformed events return `(ReasonerAccessorRejected InvalidProposalEvent)`.
Quote literal record inputs; the accessors inspect and return contents as data.
These shape checks do not validate evidence authority or grade outcomes.

### Legacy proposal value contract

`reasonerProposalValid` checks the following representation contract after the
exact, ground proposal shape has matched. It returns one boolean and does not
allocate identities, resolve evidence, change ownership, or update reliability.

| Field | Accepted representation |
| --- | --- |
| ID | A nonblank symbol or string of 1–256 Unicode characters, without control characters. Boolean and symbolic `None`/`none` values are rejected. Symbols and strings retain their distinct identities. |
| Target | `current-frame` or `(FrameTarget ID)` for candidate/attention requests; `(FrameTarget ID)` for frame switches; exactly `(ModeTarget Fast)` or `(ModeTarget Slow)` for mode changes. Frame IDs use the same scalar bounds as proposal IDs. |
| Confidence | A finite number in `[0,1]`; numeric strings and booleans are rejected rather than coerced. |
| Claim, support, prediction | Ground, nonempty opaque data. Top-level `()`, `None`, empty strings and whitespace-only strings are rejected. Each field has depth at most 16, at most 1024 nodes, at most 256 children per list, and at most 1200 characters per text/symbol scalar. Embedded numbers must be finite and within ±9007199254740991. |
| Evidence | Exactly `(EvidenceReferences REFS)`, where REFS is a proper list of at most 32 distinct references. NARS and PLN proposals require at least one reference; other sources may use an empty list. |

References may be bounded legacy symbol/string stamps, `(ObservationRef HOST ID)`
with string host/ID, or `(SessionObservationRef SESSION SEQUENCE)` with a string
session and integer sequence in `0–9007199254740991`. Identifier text rules apply
to these names. Duplicate checks preserve exact types. Multiline payload text
is allowed; expression contents are inspected as data and never executed.
The depth count starts at one, and every list or scalar counts as one node.

Proposal builders accept raw reference lists or an existing `EvidenceReferences`
wrapper and produce the canonical wrapper. Malformed proposals receive
`Malformed / InvalidProposal` at admission and cannot reach scoring. Inference
conversion emits no proposal when the completed record fails value validation.

A valid reference shape does not establish that an observation exists, belongs
to this snapshot/task, or supports the claim. Those checks remain the trusted
host's responsibility before live proposal intake. Nonempty support data is
likewise not proof of a derivation. This contract leaves engine reasoning,
evidence resolution, authorization, and outcome grading separate.

### Execution-backed proposal evidence

`recordReasonerProposalOutcome` now requires evidence from an explicitly installed
trusted host adapter. Without one it returns
`(ReasonerOutcomeRejected MissingHostEvidence)` and changes neither outcomes nor
source reliability. Status labels or arbitrary evidence text cannot create a grade.

The optional `reasoner_host_evidence.metta` adapter uses Core's existing ticket
and immutable result ledger. Load it once after composition, proposal support,
and Core/v1 dispatch. It does not load inference engines or start a service.

| Trusted host API | Required timing and result |
| --- | --- |
| `retainReasonerProposalSelection EVENT` | Before invocation, explicitly attribute the exact selected operation to a retained Accepted event. Checks the event's original operation context, published bundle, open commitment, candidate/target and current Core ticket/snapshot. Returns `(ReasonerProposalLinked OPERATION-DECISION)` or a rejection. |
| `observeReasonerProposalExecution EVENT` | After normal dispatch, while its owner and selection remain current, validate the correlated callback against Core's exact retained command/result. Returns `(ReasonerExecutionEvidence TICKET)` or a rejection. The opaque reference exposes no file contents. |
| `recordReasonerProposalOutcome EVENT STATUS EVIDENCE Unresolved ()` | Resolve the captured evidence for this exact event and recheck Core's receipt before recording an execution-backed grade. Observed `Success` corresponds to execution status `Completed`; observed `Failure` corresponds to `Failed`. |

The retained chain is proposal event and publication → selected operation/ticket
→ Core's single execution attempt → validated observation. A matching candidate
alone is insufficient. Attribution must precede execution; a later proposal
cannot adopt an earlier result. Receipts from another command, frame, cycle,
commitment or session cannot replace the linked observation. Captured evidence
can be validated on later cycles within its session without relabelling it as
evidence for a successor task.

The adapter supports current-frame candidate work and at most 128 links per
session. It requires an open matching commitment. Observation capture must occur
before the selected callback slot is displaced. Blocked and uncertain execution
cannot supply an execution-backed grade. Dispatch reset or session loss does not
provide durable evidence recovery. These are host APIs, not model skills or
authorization for execution.

Here `Completed` describes the observed operation, not the user's task. No
commitment is completed by this recorder. `Confirmed`/`Refuted` frame evidence
is rejected until an authoritative verification adapter is connected; empty
evidence returns `MissingVerificationEvidence`, and arbitrary nonempty text
returns `UnsupportedVerificationEvidence`. An executed read cannot establish a
frame claim merely by returning successfully.

The existing status-based grade table remains provisional. Prediction comparison
and grade/outcome deduplication are separate unfinished work; retaining a causal
receipt does not by itself implement either. Tests extend the real Core
operation-selection suite with successful and failed reads, missing/forged
observations, mismatched receipts/statuses, stale/revoked selections, ownership
changes and session isolation. External services remain doubled.

From the PeTTa workspace root, run the offline integration checks:

```bash
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/reasoner_integration_test.metta
```

The test reuses the minimal-loop fixture and additionally checks real derivation
in both engines, evidence and target preservation, missing-premise behavior,
engine isolation, negative evidence, policy rejection, malformed input, and
cumulative reliability updates. No LLM, network, or persistence is needed.

Both offline tests also run with the workspace-local native runner:

```bash
sh run.sh MetaMo/applications/omegaclaw_v1/tests/minimal_loop_test.metta -s
sh run.sh MetaMo/applications/omegaclaw_v1/tests/reasoner_integration_test.metta -s
```

They pass all 6 and 112 assertions respectively without import caching. Native
compiler regression checks run both with a 64 MiB stack limit as well.

## Module Structure

| File | Responsibility |
| --- | --- |
| `openpsi_config.metta` | Goal, modulator, and stimulus indices used by MetaMo. |
| `registry.metta` | Declarative goals, signals, candidates, weights, thresholds, and dynamics. |
| `utils.metta` | Generic utilities shared across application modules. |
| `adapter.metta` | OmegaClaw motivation spaces and conversion to and from MetaMo state/actions. |
| `host_identity.metta`, `identity_store.py` | Trusted host identity/publication and causal checks in MeTTa; UUIDs and durable opaque storage in Python. |
| `signals.metta` | Runtime signal extraction and signal-to-appraisal aggregation. |
| `omegaclaw_appraisal.metta` | Appraisal-driven updates to the modulator vector. |
| `homeostasis.metta` | Self-model updates and homeostatic rules. |
| `host_continuation.metta` | Trusted session-bound read plans and observed step progression; see [CONTINUATION.md](CONTINUATION.md). |
| `task_lifecycle.metta` | User-task state, execution continuation, and autonomy phases. |
| `commitments.pl`, `commitments.metta` | Host-owned commitment events and a read-only adapter; motivation cannot implicitly terminate work. |
| `candidate_selection.metta` | Candidate-condition evaluation and availability. |
| `operation_selection.metta`, `host_operations.py` | Concrete-operation admission before scoring, retaining the exact selected command and Core dispatch ticket; explicitly queued bounded response preparation from admitted reads joins normal capture through a cycle-owned binding. |
| `scheduling.metta` | Fixed preemption between admitted scheduling classes, before numeric scoring. |
| `resurfacing.metta` | Bounded, periodic review hints for blocked and deferred live frames, without execution authority. |
| `mode_triggers.metta` | Shared registry-driven trigger evaluation over existing signals and snapshot conditions. |
| `mode_layer.metta` | Four constitutional modes with registry-driven wake, recovery, collision, and transition timing rules. |
| `omegaclaw_decision.metta` | Candidate scoring and winner selection. |
| `persistence.metta` | Save, restore, and persistence scheduling. |
| `bridge.metta` | MetaMo-cycle orchestration, prompt construction, and startup. |
| `composition.metta` | Shared application imports in dependency order; no channel startup. |
| `run.metta` | Host imports and explicit application startup. |
| `tests/` | Isolated integration and scoring diagnostics. |

## Self-model and defaults

The self-model, written as S, holds internal motivational/physiological condition.
`registry.metta` declares its allowed fields and initialization defaults.
Each `SelfModelFieldSpec` names a field, its motivational/physiological
class, unit, inclusive numeric bounds and bootstrap default:

| Field | Class | Unit and bounds | Seed default | Meaning |
| --- | --- | --- | --- | --- |
| `energy` | physiological | normalized, 0–1 | 1.0 | Internal estimate of available activity capacity. |
| `fatigue` | physiological | normalized, 0–1 | 0.0 | Internal estimate of accumulated activity strain. |
| `urgency` | motivational | normalized, 0–1 | 0.5 | Internal pressure to attend to work. |

These defaults are declared seeds, not observed measurements. The cycle updater mirrors
the existing urgency modulator after each motivational update; energy and fatigue
retain their current valid values. No resource meter or physiological update law
is inferred. The 0–1 domains say which values are valid; homeostatic targets say
where a correction should move. Fields absent from this allowlist,
including capability, knowledge and belief fields, are outside the declared S
schema.

The five retired runtime fields are exhaustively classified by
`LegacySelfMetricClass`:

| Legacy field | Destination | Retired calculation and interpretation |
| --- | --- | --- |
| `success_rate` | Observation | Smoothed cumulative successful-result cycles / all cycles; not a capability claim or calibrated success probability. |
| `failure_rate` | Observation | Smoothed cumulative error cycles / all cycles; not a capability claim. |
| `resource_usage` | Observation | `cycles / (cycles + 50)`; a cycle-count proxy, not measured resource consumption. |
| `memory_confidence` | Adjudicated claim | Previously `clamp(success_rate * 1.4)`; that heuristic cannot establish memory reliability. Any retained reliability claim requires host adjudication and evidence. |
| `identity_continuity` | Observation | `clamp(0.90 - failure_streak * 0.08)`; a failure-streak proxy, not evidence about identity or beliefs. |

Classification does not publish observations, migrate values, or write claims
to the adjudicated store. In particular, an old saved `memory_confidence` value
must not be promoted into an authoritative claim by copying or renaming it.
The rules described below replace the dependent rules using existing facts with provenance
and motivational quantities, without recreating these retired heuristics.

`homeostasis.metta` supplies pure `selfModelFieldSpec`,
`selfModelFieldSpecValid`, and `selfModelMetricValid` checks. For example,
`(selfModelMetricValid (quote (self-metric energy 0.5)))` returns `True`;
unknown fields, invalid/duplicate declarations, nonnumeric or nonfinite values,
and values outside the declared bounds reject. These checks inspect data and
do not mutate state or evaluate supplied metric expressions.

## Validating self-model changes

`initializeSelfModel` validates the complete nonempty registry schema before
replacing S with its defaults. Duplicate/invalid declarations reject without
clearing current state. `initOmegaClawMotivation` and `motivatedOmegaclaw` check
the schema before changing motivational spaces or entering the Core loop.
The retired `SelfModelSpec` defaults are removed.

`replaceSelfMetric` validates before removal/insertion. Unknown fields, non-ground
values, nonnumeric/nonfinite values, or values outside the declared domain return
`(SelfModelRejected InvalidMetric)` and preserve existing S. `updateSelfModel`
keeps cycle/success/failure counters outside S and no longer writes any retired
metric. It updates urgency only through this validated writer.

Restoration keeps Core's existing text/parser checks, then validates the complete
parsed snapshot before changing goals (G), anti-goals (AG), modulators (M), or
the self-model (S). Invalid S, including forbidden legacy
fields or duplicate names, rejects the whole snapshot with
`(SelfModelRejected InvalidSnapshot)`. Old snapshots containing retired fields
are deliberately rejected, not silently filtered or promoted into claims.
Valid partial S snapshots update only their declared fields, leaving other
current/default values intact; an empty S section is allowed. Successful restore
returns `MotivationalStateRestored`. Numeric persistence remains floating point
until integer-scaled persistence is implemented.

Candidate/homeostatic self-metric predicates now require a unique valid observed
field. Missing or retired fields do not satisfy either comparison; absence cannot
become a low-value trigger via the legacy numeric getter's zero fallback.
The rule inputs below replace the registry's retired dependencies.
No adjudicated-store writer is added.

This fences the supported application APIs, not arbitrary code with access to
the interpreter's mutable spaces. Regression coverage extends the existing
`tests/provider_helpers_test.metta`, including the real parser/save/restore
fixture. The homeostatic target section below explains how corrections stop at a declared destination.

## Inputs used by candidate and homeostatic rules

Every candidate and homeostatic rule that referenced a retired S field now reads
an existing typed factual signal or motivational modulator:

| Retired dependency | Replacement | Behavior |
| --- | --- | --- |
| `failure_rate` in `self-improve` | `failure-streak >= 2 count` | Recorded consecutive failures make reflection eligible through the registry fallback when its existing appraisal-risk guard (`risk < 0.65`) allows it. |
| `memory_confidence` in `recall-goals` | `context_depth > 0.55` | A stronger preference for deeper context favors recalling goals. |
| `memory_confidence` in `plan-goal` | `focus > 0.55` | Stronger motivational focus favors planning. |
| Low `memory_confidence` homeostasis | `context_depth > 0.80` | Demand for deeper context raises deliberation threshold by up to 0.20 and lowers persistence by up to 0.15. |
| Low `success_rate` homeostasis | `repeated-failure` is True | The current repeated-failure observation raises caution by up to 0.20 and lowers the growth goal by up to 0.05. An idle/no-outcome cycle is not low-success evidence. |
| Low `identity_continuity` homeostasis | `failure-streak >= 8 count` | A recorded long failure streak raises the stability goal by up to 0.05 and securing by up to 0.10. This is the count boundary of the old `0.90 - streak * 0.08 < 0.30` proxy, without an identity claim. |

The context-depth/focus policies and failure-trigger changes are explicit seed
policy choices, not calibrated equivalents of memory reliability or cumulative
success/failure rates. No capability/knowledge claim is inferred from execution
success. Existing task routing, idle autonomy phase precedence, scoring, policy
gates and dispatch remain in place; these registry rows do not override them.

Candidate and homeostatic condition readers share the existing `signalTrue` and
unit-aware `signalQuantityAtLeast` interfaces. Facts come from the same bounded
publication as appraisal and selection; homeostasis runs before signal cleanup.
Provenance and one-shot outcome consumption remain in the existing producer path.
No new signal kind, rate accumulator, or detached observation store is introduced.
Absent, malformed or duplicate facts do not match, False is not True, and a
quantity with the wrong unit cannot satisfy a count condition.

`modulatorCondition` requires one finite normalized value and a finite normalized
threshold; missing, duplicate or invalid values cannot drive either comparison.
Unknown condition types return False. The unused legacy EMA and failure-rate
threshold declarations are removed. `resource_usage` has no remaining rule
consumer and is not replaced with a pretend resource meter.

No adjudicated-store integration is necessary for these replacements: MetaMo
neither constructs nor writes a memory-reliability claim. Any future claim reader
must consume host-adjudicated evidence. S remains limited to its declared schema;
homeostasis stops these corrections at their declared destinations.

Coverage extends the existing provider-helper and host-mode suites. The latter
dispatches two correlated failing commands, resolves their factual provenance,
checks the actual corrections and unchanged S/commitment, and verifies that the
next no-outcome cycle clears the fresh failure fact while retaining the count.
Providers, memory and the failing handler are test doubles; Core ingestion,
policy, dispatch, outcome consumption, projection and MetaMo are real.

## Homeostatic targets

`registry.metta` enumerates all eight variables corrected by homeostasis as
`(HomeostaticTarget kind name normalized (set-point value))` records. Each
variable must also have exactly one valid `ModulatorSpec` or `GoalSpec`. The
current action types address only motivational modulators/goals, never host
tasks, frames, adjudicated claims, or self-model fields.

| Kind | Variable | Current correction direction | Seed set-point |
| --- | --- | --- | --- |
| modulator | `threshold` | raise | 0.75 |
| modulator | `arousal` | lower | 0.30 |
| modulator | `exploration_bias` | lower | 0.20 |
| modulator | `persistence` | lower | 0.35 |
| modulator | `caution` | raise | 0.75 |
| modulator | `securing` | raise | 0.70 |
| goal | `gTrans_over` | lower | 0.30 |
| goal | `gInd_over` | raise | 0.85 |

These are explicit bootstrap policy choices, not outcome-earned parameters.
Caution and securing destinations remain below their respective excess triggers
(0.80 and 0.75), so their own homeostatic increases do not keep escalating those
triggers. Deliberation and stability retain reserves under pressure; dampening
keeps nonzero arousal, exploration, persistence and growth preferences. They are
not resource estimates or changes to execution policy. Energy/fatigue have no
homeostatic correction mechanism here, so no fictitious targets are added for
them.

Existing rule triggers and step sizes remain registry data. A raising correction
uses `min(set-point, current + step)` only while current is below the point; a
lowering correction uses `max(set-point, current - step)` only while above it.
Values already at or beyond the point in that direction remain unchanged.
For example, raising caution from 0.74 by 0.20 stops at 0.75, while caution at
0.90 stays 0.90. These are destinations for homeostatic corrections, not global
limits on appraisal or other motivational updates. Shared-variable rules use
one destination, so repeated/colliding corrections cannot overshoot it.

`homeostaticTarget` requires one exact declaration with normalized units, a finite
0–1 point, and one valid corresponding variable declaration. Before any write,
the correction also requires one finite 0–1 current value and a positive finite
step no greater than 1. Unknown actions, missing/duplicate targets, wrong units,
unsupported variables, malformed/nonfinite numbers, duplicate/missing current
values and invalid steps return a typed `HomeostasisRejected` result. The affected
variable is unchanged; valid corrections for other triggered rules can still run.
Internal correction entry points recheck the declared destination and step.

Each triggered rule returns a `HomeostaticRuleResult` containing the copied rule
and its correction or rejection. A successful `HomeostaticCorrection` records
the variable kind/name, actual before/after values and set-point, including no-op
corrections already at/beyond the destination. `runHomeostasis` returns this trace
and retains it in `lastHomeostaticCorrections`; normal motivational initialization
clears it. These are latest-cycle, non-persisted diagnostics, not execution
receipts or a new grading/learning loop.

Existing provider-helper tests cover all rule-to-target links, four directions,
overshoot, repeated sweeps, shared destinations, registry edits, rejected inputs,
and unchanged S. The host-mode test consumes two actual correlated dispatch
failures through the real bridge and checks the retained correction, then verifies
the 0.75 caution and 0.30 growth destinations against that same bounded
publication. Provider, memory and failing-handler doubles retain their existing
scope; host policy, commitments and dispatch remain authoritative.

## Checks and evidence

The recorded 2 November 2026 offline run passed all 82 v1 MeTTa files. The
self-model/homeostasis coverage included 281 provider-helper and 211 host-mode
assertions. The direct-command follow-up also passed Core's 20-case dispatch
suite, four boundary guards, and 20 Python import/harness/service checks.
[Dispatch](DISPATCH.md) describes that path and its test scope.

These runs used provider, memory, and transport doubles. They did not make live
provider requests or send to a real IRC server. The September [live setup](LIVE_SETUP.md),
[execution](LIVE_CYCLE.md), and [mode](LIVE_MODES.md) reports describe their own
real-service runs; those were controlled drivers rather than broad deployment
or performance tests.

## Current limits

Versioned record constructors and identity checks are available, but the live
runtime still uses unversioned records. The supported command budget counts
invocations rather than tokens, money, or elapsed time. Session accounting and
execution state do not establish recovery across a process restart.

The scored operation-class selector is still a temporary mechanism. Production
reasoner proposals, prediction/outcome grading, earned parameter updates,
authoritative relation-verification write-back, integer-scaled persistence, and
bounded Sleep/Rumination work classes need further integration. Learning and
memory restructuring belong to the reasoner and host mechanisms, not MetaMo.

Dated test reports describe the exact scenarios they ran. Offline success does
not establish live-service readiness or performance at a larger workload.
