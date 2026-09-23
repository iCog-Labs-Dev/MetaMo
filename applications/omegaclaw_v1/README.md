# MetaMo OmegaClaw Application

This directory contains the MetaMo adapter and motivation logic for OmegaClaw.

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
| `task_lifecycle.metta` | User-task state, execution continuation, and autonomy phases. |
| `commitments.pl`, `commitments.metta` | Host-owned commitment events and a read-only adapter; motivation cannot implicitly terminate work. |
| `candidate_selection.metta` | Candidate-condition evaluation and availability. |
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

## Installation

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
[offline service tests](tests/OFFLINE_SERVICES.md) for commands and limitations.

For real message ingestion without ChromaDB or LLM services, see
[offline service tests](tests/OFFLINE_SERVICES.md). These use test-only provider
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
