# MetaMo OmegaClaw Application

This directory contains the MetaMo adapter and motivation logic for OmegaClaw.

## Module Structure

| File | Responsibility |
| --- | --- |
| `openpsi_config.metta` | Goal, modulator, and stimulus indices used by MetaMo. |
| `registry.metta` | Declarative goals, signals, candidates, weights, thresholds, and dynamics. |
| `utils.metta` | Generic utilities shared across application modules. |
| `adapter.metta` | OmegaClaw motivation spaces and conversion to and from MetaMo state/actions. |
| `signals.metta` | Runtime signal extraction and signal-to-appraisal aggregation. |
| `omegaclaw_appraisal.metta` | Appraisal-driven updates to the modulator vector. |
| `homeostasis.metta` | Self-model updates and homeostatic rules. |
| `task_lifecycle.metta` | User-task state, execution continuation, and autonomy phases. |
| `candidate_selection.metta` | Candidate-condition evaluation and availability. |
| `omegaclaw_decision.metta` | Candidate scoring and winner selection. |
| `persistence.metta` | Save, restore, and persistence scheduling. |
| `bridge.metta` | MetaMo-cycle orchestration, prompt construction, and startup. |
| `composition.metta` | Shared application imports in dependency order; no channel startup. |
| `run.metta` | Host imports and explicit application startup. |
| `tests/` | Isolated integration and scoring diagnostics. |

## Installation

Use the exact source revisions and workspace structure recorded in
[DEPENDENCIES.md](DEPENDENCIES.md). Keep `MetaMo/`, `repos/OmegaClaw-Core/`,
and `repos/petta_lib_chromadb/` inside the same PeTTa workspace. Use the common
launcher below for canonical import resolution and one-time module loading.
See [COMPOSITION.md](COMPOSITION.md) for dependency and initialization rules.
The offline baseline is not yet a verified full live-runtime installation.

## Usage

After configuring dependencies and credentials, run from the PeTTa workspace root:

```bash
OMEGACLAW_AUTH_SECRET=<channel-secret> python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/run.metta IRC_channel="<irc-channel>"
```

*(Note: Replace `<channel-secret>` and `<irc-channel>` with your own values, similarly to the default OmegaClaw setup).*

## Minimal loop demo

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

`reasoner_integration.metta` loads PeTTa's local `lib_nars` and `lib_pln`
through `reasoner_engines.pl`. The loader prefixes all library-defined function
names because PeTTa compiles functions globally even across imported spaces.
It uses the local PeTTa parser/compiler and rejects runnable library forms.
The original libraries are not modified or copied. These are distinct from
OmegaClaw-Core's `lib_nal` and `lib_pln` rule libraries.

Load the application composition once, then its inference extension.
`composition.metta` owns the proposal definitions and import helpers; the
extension must not reload them under native PeTTa. If the host has already
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
and scheduler outcome callbacks remain host integration work.

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
