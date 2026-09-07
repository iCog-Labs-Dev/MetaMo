# MetaMo OmegaClaw Application

This directory contains the MetaMo adapter and motivation logic for OmegaClaw.

## Pluggable Module Structure

| File | Responsibility |
| --- | --- |
| `config.metta` | Application scales, feature names, signal names, cognitive modes, and capability envelopes. |
| `schema.metta` | OmegaClaw goal schema, modulator schema, and named vector builders. |
| `state.metta` | Default schema-aware MetaMo motivation state. |
| `signals.metta` | Immutable observation, outcome, signal, and perception records plus signal weights. |
| `stimulus.metta` | Pure conversion from OmegaClaw signals to named MetaMo stimulus features. |
| `actions.metta` | Representative candidate policies, correlations, metadata, and candidate builder. |
| `appraisal_profile.metta` | OpenPsi-compatible stimulus-to-modulator and outcome-to-goal conversions. |
| `decision_profile.metta` | MAGUS-compatible additive decision profile for OmegaClaw candidates. |
| `policies.metta` | Configured stability, coherence, and merge policies. |
| `bundle.metta` | OmegaClaw `applicationBundle`, validation helper, bimonad helper, and diagnosed step helper. |
| `adapters/omegaclaw_host.metta` | Application-local, host-policy-first lifecycle boundary with immutable turn state and duplicate/stale commit protection. |
| `tests/host_contract_tests.metta` | Phase 1 host adapter contract tests. |
| `tests/schema_bundle_tests.metta` | Phase 2 schema/profile/bundle vertical-slice tests. |

The older files such as `bridge.metta`, `adapter.metta`, `omegaclaw_appraisal.metta`,
`candidate_selection.metta`, and `run.metta` are still present as legacy material.
They are not the canonical pluggable path until the later wiring phases replace
their obsolete imports and runtime assumptions.

## Motivation Model

Goals:

```text
gInd_over, gTrans_over,
help_user, learn, cooperate, responsiveness, clarity, coherence,
reliability, progress, adaptivity,
risk, contradiction, unsafe
```

Primary goals are `help_user`, `learn`, `cooperate`, `responsiveness`,
`clarity`, `coherence`, `reliability`, `progress`, and `adaptivity`.
Anti-goals are `risk`, `contradiction`, and `unsafe`. The overgoals are
`gInd_over` and `gTrans_over`.

Modulators:

```text
valence, arousal, approach, resolution, threshold, securing,
urgency, persistence, context_depth, human_deference, focus
```

The first six modulators are the reusable MetaMo/OpenPsi core. The remaining
five are OmegaClaw-owned application modulators.

Stimulus features:

```text
novelty, risk, importance, uncertainty, opportunity, progress
```

Signals currently supported by the vertical slice are `failure`,
`repeated-failure`, `ambiguity`, `verified-success`, `progress-made`,
`stalled-progress`, `user-waiting`, `task-drift`, `danger`, and
`execution-request`.


## Installation

To set up and run this application, clone the necessary repositories and copy the run file:

```bash
git clone https://github.com/trueagi-io/PeTTa
cd PeTTa
mkdir -p repos
git clone https://github.com/asi-alliance/OmegaClaw-Core.git repos/OmegaClaw-Core
git clone https://github.com/patham9/petta_lib_chromadb.git repos/petta_lib_chromadb
git clone https://github.com/iCog-Labs-Dev/MetaMo.git MetaMo
cp MetaMo/usecase/omegaclaw_v1/run.metta ./run_omega.metta
```

## Usage

After copying the file, you can run the system from the root folder:

```bash
OMEGACLAW_AUTH_SECRET=<channel-secret> sh run.sh run_omega.metta IRC_channel="<irc-channel>" -s
```

*(Note: Replace `<channel-secret>` and `<irc-channel>` with your own values, similarly to the default OmegaClaw setup).*
