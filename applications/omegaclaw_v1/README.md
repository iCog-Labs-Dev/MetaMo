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
| `run.metta` | Dependency composition and application entry point. |
| `tests/` | Isolated integration and scoring diagnostics. |

## Installation

To set up and run this application, clone the necessary repositories and copy the run file:

```bash
git clone https://github.com/trueagi-io/PeTTa
cd PeTTa
mkdir -p repos
git clone https://github.com/asi-alliance/OmegaClaw-Core.git repos/OmegaClaw-Core
git clone https://github.com/patham9/petta_lib_chromadb.git repos/petta_lib_chromadb
git clone https://github.com/iCog-Labs-Dev/MetaMo.git MetaMo
cp MetaMo/applications/omegaclaw_v1/run.metta ./run_omega.metta
```

## Usage

After copying the file, you can run the system from the root folder:

```bash
OMEGACLAW_AUTH_SECRET=<channel-secret> sh run.sh run_omega.metta IRC_channel="<irc-channel>" -s
```

*(Note: Replace `<channel-secret>` and `<irc-channel>` with your own values, similarly to the default OmegaClaw setup).*
