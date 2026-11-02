# MetaMo OmegaClaw Application

Start with [the current project state](CURRENT_PROJECT_STATE.md) for a plain-language
assessment dated 9 October 2026: component responsibilities, the execution flow,
terminology, implemented behavior, evidence limits, and remaining functional work.

The bounded [live mode scenario](LIVE_MODES.md) now verifies all six constitutional
transitions with real provider signals, native read failure/recovery, host
completion, and Threat/Sleep dispatch checks.

The parent application directory contains the MetaMo adapter and motivation logic
for OmegaClaw. This `omega_docs/` directory contains its documentation. Source paths
below are relative to `MetaMo/applications/omegaclaw_v1` unless stated otherwise.

## Boundary contracts

[CONTRACTS.md](CONTRACTS.md) specifies the proposed version 1 records shared by
ContextFrames, MetaMo, reasoner adapters, and the scheduler. Runtime records are
still unversioned; production migration remains pending. Shared wire tests and
trusted host identity/causal-link APIs are implemented; see [IDENTITY.md](IDENTITY.md).

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

Scheduling implements **Threat-remediation > Recovery > Interactive > Orienting >
Engaged > Rumination > Sleep** over admitted candidates. These priorities remain
separate from the four constitutional modes and ContextFrames Fast/Slow modes.
See [SCHEDULING.md](SCHEDULING.md) for candidate mappings, trigger handling, and tests.
Mode triggers, entry/exit thresholds, and cycle-based timing are registry data;
see [MODE_TRANSITIONS.md](MODE_TRANSITIONS.md) for wake and recovery behavior.
Commitments terminate only through explicit completed, abandoned-with-reason, or
superseded events; see [COMMITMENTS.md](COMMITMENTS.md) for host APIs and scope.
Blocked/deferred live frames resurface through a bounded MeTTa review queue;
see [RESURFACING.md](RESURFACING.md) for cycle bounds and multi-cycle tests.

## Declared self-model schema — integration item 3.1

`registry.metta` declares the R5 allowlist and runtime initialization defaults.
Each `SelfModelFieldSpec` names a field, its motivational/physiological
class, unit, inclusive numeric bounds and bootstrap default:

| Field | Class | Unit and bounds | Seed default | Meaning |
| --- | --- | --- | --- | --- |
| `energy` | physiological | normalized, 0–1 | 1.0 | Internal estimate of available activity capacity. |
| `fatigue` | physiological | normalized, 0–1 | 0.0 | Internal estimate of accumulated activity strain. |
| `urgency` | motivational | normalized, 0–1 | 0.5 | Internal pressure to attend to work. |

These defaults are declared seeds, not observed measurements. Item 3.2 mirrors
the existing urgency modulator after each motivational update; energy and fatigue
retain their current valid values. No resource meter or physiological update law
is invented. Numeric domains constrain representation; they are not
homeostatic correction targets (item 3.4). Fields absent from this allowlist,
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
Item 3.3 below replaces the dependent rules using existing facts with provenance
and motivational quantities, without recreating these retired heuristics.

`homeostasis.metta` supplies pure `selfModelFieldSpec`,
`selfModelFieldSpecValid`, and `selfModelMetricValid` checks. For example,
`(selfModelMetricValid (quote (self-metric energy 0.5)))` returns `True`;
unknown fields, invalid/duplicate declarations, nonnumeric or nonfinite values,
and values outside the declared bounds reject. These checks inspect data and
do not mutate state or evaluate supplied metric expressions.

## Self-model enforcement — integration item 3.2

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
parsed snapshot before any G/AG/M/S write. Invalid S, including forbidden legacy
fields or duplicate names, rejects the whole snapshot with
`(SelfModelRejected InvalidSnapshot)`. Old snapshots containing retired fields
are deliberately rejected, not silently filtered or promoted into claims.
Valid partial S snapshots update only their declared fields, leaving other
current/default values intact; an empty S section is allowed. Successful restore
returns `MotivationalStateRestored`. Numeric persistence remains floating point
until integration item 6.

Candidate/homeostatic self-metric predicates now require a unique valid observed
field. Missing or retired fields do not satisfy either comparison; absence cannot
become a low-value trigger via the legacy numeric getter's zero fallback.
Item 3.3 replaces the registry's retired dependencies as described below.
No adjudicated-store writer is added.

This fences the supported application APIs, not arbitrary code with access to
the interpreter's mutable spaces. Regression coverage extends the existing
`tests/provider_helpers_test.metta`, including the real parser/save/restore
fixture. Homeostatic target declarations remain item 3.4 work.

Validation on 2 November 2026: all 82 v1 MeTTa test files passed; the final
provider-helper run passed 198 assertions (59 added for 3.2). All four boundary
guards and eight import/launcher regressions passed. External services were
doubled; no live-service verification was performed.

## Factual and motivational rule inputs — integration item 3.3

Every candidate and homeostatic rule that referenced a retired S field now reads
an existing typed factual signal or motivational modulator:

| Retired dependency | Replacement | Behavior |
| --- | --- | --- |
| `failure_rate` in `self-improve` | `failure-streak >= 2 count` | Recorded consecutive failures make reflection eligible through the registry fallback when its existing appraisal-risk guard (`risk < 0.65`) allows it. |
| `memory_confidence` in `recall-goals` | `context_depth > 0.55` | A stronger preference for deeper context favors recalling goals. |
| `memory_confidence` in `plan-goal` | `focus > 0.55` | Stronger motivational focus favors planning. |
| Low `memory_confidence` homeostasis | `context_depth > 0.80` | Demand for deeper context raises deliberation threshold by 0.20 and lowers persistence by 0.15. |
| Low `success_rate` homeostasis | `repeated-failure` is True | The current repeated-failure observation raises caution by 0.20 and lowers the growth goal by 0.05. An idle/no-outcome cycle is not low-success evidence. |
| Low `identity_continuity` homeostasis | `failure-streak >= 8 count` | A recorded long failure streak raises the stability goal by 0.05 and securing by 0.10. This is the count boundary of the old `0.90 - streak * 0.08 < 0.30` proxy, without an identity claim. |

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
homeostatic targets and correction bounds remain the separate item 3.4.

Coverage extends the existing provider-helper and host-mode suites. The latter
dispatches two correlated failing commands, resolves their factual provenance,
checks the actual corrections and unchanged S/commitment, and verifies that the
next no-outcome cycle clears the fresh failure fact while retaining the count.
Providers, memory and the failing handler are test doubles; Core ingestion,
policy, dispatch, outcome consumption, projection and MetaMo are real.

Validation on 2 November 2026: all 82 v1 MeTTa test files passed, including
235 provider-helper and 206 host-mode assertions (37 and 26 added respectively).
All four boundary guards and 20 import/harness/service Python checks passed.
No live-service verification was performed.

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
The offline baseline is not yet a verified full live-runtime installation.

## Usage

After configuring dependencies and credentials, run from the PeTTa workspace root:

The v1 runtime also requires trusted host command bindings and typed policies
for the session dispatch boundary described in [DISPATCH.md](DISPATCH.md).
Without them, commands return explicit no-action results. Stale or revoked
decisions cannot fall back to direct evaluation. The invocation below does not
provision policy; configure it in trusted host startup code first.
The [host configuration template](../host_dispatch.example.json) and
[provisioning instructions](DISPATCH.md#trusted-host-configuration) cover exact
`read-file` and `show-current-frame` commands with explicit global/frame policies.

```bash
OMEGACLAW_AUTH_SECRET=<channel-secret> python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/run.metta IRC_channel="<irc-channel>"
```

*(Note: Replace `<channel-secret>` and `<irc-channel>` with your own values, similarly to the default OmegaClaw setup).*

## Minimal loop demo

The full motivational bridge has a separate offline regression:
`tests/bridge_cycle_test.metta` uses real Core ingestion/projection and calls
`motivationContextBlock`, including state updates and persistence scheduling,
with external provider/memory doubles. It covers fresh messages and idle no-action;
execution continuation and the complete feedback loop remain pending. See
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

Live reasoner integration is deferred. The default `composition.metta` and
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
not a calibrated probability of success. The positive-value cutoff is an MVP
seed rule. `reasonerInferDirective` additionally takes a frame bundle and MetaMo
state and calls the existing validation, feasibility, scoring, and audit path.
It returns an advisory scheduler directive; it does not execute anything.

Automatic frame-to-fact extraction, proposal collection in the live bridge,
and scheduler outcome callbacks remain deferred host integration work. Shared
wire contracts may still represent proposals without loading an adapter or engine.

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

They pass all 6 and 18 assertions respectively without import caching. Native
compiler regression checks run both with a 64 MiB stack limit as well.
