# Reasoner benchmark results — 2026-11-24

All three fresh-process comparisons completed. Each passed both independently checked
file reads, and all six observed policy checks passed. NARS and PLN preserved the
native operation sequence in shadow mode. No numerical prediction grade was available.

## What was run

- Scenario: `deterministic-three-way-v1`, one offline episode with two cycles per run.
- Configurations: native without a reasoner, NARS shadow, and PLN shadow; one run each.
- Seed: `37`; fresh memory, session, budgets and engine state for each process.
- Initial state: Fast frame, Active status, Engaged posture, registry-default motivation.
- Input: `Explain the project documentation`, followed by no new input.
- Available operation: `read-file`; fixture content: `deterministic documentation excerpt`.
- Global/frame command budgets: two each. Maximum elapsed time: 20,000 ms per run.
- Intake bounds: 128 facts, 16 proposals, 100 engine steps per invocation, queue 40,
  zero reasoner provider calls, and 1,000 ms timeout.
- Collection enabled only for NARS/PLN. Influence, runtime assessment and learning
  disabled throughout; influence cap zero. Post-run scoring reads retained evidence.

Core admission, selection, file dispatch, budget accounting and callback recording
use the normal loop. NARS/PLN derivation uses the local engines. Provider, classifier
and memory services are offline doubles; this did not contact IRC or live providers.

## Outcomes and prediction evidence

| Configuration | Mode | Verified read checks passed | Prediction grading coverage | Confirmed / refuted / ungraded | Mean grade |
| --- | --- | --- | --- | --- | --- |
| Native | native | 2/2 (100%) | N/A (0/0) | 0 / 0 / 0 | N/A (0 grades) |
| NARS | shadow | 2/2 (100%) | 0% (0/1) | 0 / 0 / 1 | N/A (0 grades) |
| PLN | shadow | 2/2 (100%) | 0% (0/1) | 0 / 0 / 1 | N/A (0 grades) |

The two checks in each run are repeated reads within one scenario, not two independent
tasks. All three runs selected `read-file` in both cycles and observed successful
completion with the expected content. No operation/outcome divergence was observed;
tickets, session/frame identities and receipts remain distinct in each original trace.

Each engine retained one proposal. The scorer reported `UnsupportedPrediction` for
both predictions: its exact-result comparator does not grade these candidate-outcome
predictions. Thus there are **zero refuted predictions, two ungraded predictions and
zero numerical grades** across the engine runs. Unsupported evidence is not a wrong
prediction. Native produced no proposals, so prediction coverage is undefined there.

Both engine runs recorded two coordinator observations. Reliability remained `0.8`
throughout. Their declared native-learning feedback capabilities are empty; these
observations do not establish engine training or learned improvement.

## Declared denominators

- Task success: passed independently verified checks / conclusive checks, **2/2 per
  configuration**. Task evidence coverage: conclusive / declared checks, also **2/2**.
- Prediction grading coverage: graded / unique retained proposal identities,
  **0/1 for NARS**, **0/1 for PLN**, and **0/0 for native**.
- Prediction accuracy: confirmed / (confirmed + refuted), **0/0 in every run**;
  reported as unavailable, rather than 0% or 100% accuracy.
- Mean grade and confidence error: numerical grades and supported graded comparisons
  respectively; both denominators are **zero**, so both values are unavailable.
- Policy compliance: passed / conclusive policy checks, **2/2 per configuration**;
  zero observed violations, zero ungraded policy checks.

All runs retained both expected trace cycles and readable reasoner snapshots. There
were no missing trace cycles, incomplete exports or failed configurations in this
comparison. A complete evidence window does not imply that every prediction is gradable.

## Timing and resource observations

| Configuration | Mean cycle latency (ms) | p95 cycle latency (ms) | Engine steps reserved | Engine reservations | Reasoner provider calls reserved |
| --- | --- | --- | --- | --- | --- |
| Native | 59.17 | 63.17 | 0 | 0 | 0 |
| NARS | 153.06 | 200.63 | 200 | 2 | 0 |
| PLN | 182.53 | 200.25 | 200 | 2 | 0 |

Each latency estimate has only two samples. These measurements include the selected
cycle path and are insufficient for engine speed rankings. Engine steps are reserved
allowances, not measured internal instruction counts. Every run made two offline
classifier calls. Internal instructions, provider tokens and monetary costs were
not instrumented and remain unavailable, rather than being inferred as zero.

## Reproduce

From the `MetaMo` repository root, use a new output directory for a separate cohort:

```bash
python3 applications/omegaclaw_v1/tools/benchmark_reasoners.py \
  applications/omegaclaw_v1/tests/fixtures/reasoner_benchmark/deterministic.scenario.json \
  --matrix applications/omegaclaw_v1/tests/fixtures/reasoner_benchmark/deterministic.matrix.json \
  --output /tmp/omegaclaw-reasoner-report-20261124-repeat
```

Observed source revisions:

- MetaMo/v1: `eb9bd79353b7f9a9aa2ac0809163ea1054e87433` plus the current uncommitted benchmark export changes.
- OmegaClaw-Core: `8cabe49da4010dd981150dec1b6b3f25b3153035`.
- PeTTa: `0576ffb6ec05c5bca04b668afe2c8085ad3dc420`.
- Scorer SHA-256: `59762ece578c02cd700a7db9f32bdc67616265dcd6d1e44c389ad588fc5bf447`.

The fixture's declared v1 revision is older than the observed checkout. The result
files retain both declared and observed versions, plus loaded-source fingerprints;
the commit alone does not identify the uncommitted export changes.

## Retained artifacts

- [Aggregate summary](/private/tmp/omegaclaw-reasoner-report-20261124/summary.json).
- [Portable export](/private/tmp/omegaclaw-reasoner-report-20261124/benchmark-export.zip).
- Archive SHA-256: `e01bd22251a88811a38a7e03dd41e4a09ca054323ae39ac90cf6a4ffadebc9e3`.
- **disabled** — `reasoner-6a723d7bc7f44a1099dbeab1ad120f26-_dlcvd6v`: [result](/private/tmp/omegaclaw-reasoner-report-20261124/reasoner-6a723d7bc7f44a1099dbeab1ad120f26-_dlcvd6v/result.json), [trace](/private/tmp/omegaclaw-reasoner-report-20261124/reasoner-6a723d7bc7f44a1099dbeab1ad120f26-_dlcvd6v/output/trajectory.jsonl), [reasoner evidence](/private/tmp/omegaclaw-reasoner-report-20261124/reasoner-6a723d7bc7f44a1099dbeab1ad120f26-_dlcvd6v/output/reasoner-evidence.json).
- **nars** — `reasoner-a53a07e58ed2467fb66462b0dc86d96c-_47idspv`: [result](/private/tmp/omegaclaw-reasoner-report-20261124/reasoner-a53a07e58ed2467fb66462b0dc86d96c-_47idspv/result.json), [trace](/private/tmp/omegaclaw-reasoner-report-20261124/reasoner-a53a07e58ed2467fb66462b0dc86d96c-_47idspv/output/trajectory.jsonl), [reasoner evidence](/private/tmp/omegaclaw-reasoner-report-20261124/reasoner-a53a07e58ed2467fb66462b0dc86d96c-_47idspv/output/reasoner-evidence.json).
- **pln** — `reasoner-af7f98561db445e6bf4011f44e1bef98-_bwdosb0`: [result](/private/tmp/omegaclaw-reasoner-report-20261124/reasoner-af7f98561db445e6bf4011f44e1bef98-_bwdosb0/result.json), [trace](/private/tmp/omegaclaw-reasoner-report-20261124/reasoner-af7f98561db445e6bf4011f44e1bef98-_bwdosb0/output/trajectory.jsonl), [reasoner evidence](/private/tmp/omegaclaw-reasoner-report-20261124/reasoner-af7f98561db445e6bf4011f44e1bef98-_bwdosb0/output/reasoner-evidence.json).

The archive was checked against all three original trace files byte for byte.
Artifacts are currently under `/private/tmp/omegaclaw-reasoner-report-20261124`; preserve the archive elsewhere before
clearing temporary storage. This Markdown report is retained in the repository.

This small comparison establishes successful integration and unchanged native
behavior under shadow collection. It does not measure broad task competence,
advisory benefit, prediction calibration or learning effectiveness. Those require
additional tasks, supported prediction comparators and separate evaluation episodes.
