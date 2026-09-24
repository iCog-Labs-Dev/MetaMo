# Task 5 local regression results — 24 September 2026

All **18 commands passed on their first invocation**, with no timeouts or
retries. This records the final Task 5 regression checklist item for the bounded,
session-only offline integration.

## Environment and sources

- Working directory: `/Users/nahomsenay/Hyperclaw-Metamo-Fork`.
- Run: `2026-09-24 14:34:34–14:34:54 UTC`.
- Shell Python: `3.9.6`; SWI-Prolog: `9.2.9`, `x86_64-darwin`.
- PeTTa: `0576ffb6ec05c5bca04b668afe2c8085ad3dc420`.
- MetaMo: `ff4d9d0d3aa60dd6a66dcd1eca7ab824c6fd900f`.
- OmegaClaw-Core: `8cabe49da4010dd981150dec1b6b3f25b3153035`.
- ChromaDB adapter: `456385457e4e99ee049c2c0966988a6cd7ff3705`.

These are working-tree results: revisions alone do not reproduce the tested
sources. The retained summary includes source SHA-256 fingerprints and pre-run
MetaMo/Core Git status, including the launcher and Core overlays. The harness
records fingerprints for its resolved imports as well. See `../DEPENDENCIES.md`
for the required workspace layout and the limits of its older pinned baseline.

## Results

| Check | Result |
| --- | --- |
| Focused MeTTa suite | 46/46 files; 1,704 assertion-success records, including seven shared-core wrappers |
| Full-loop scenarios | 377/377 assertions: scoring 59, modes 180, callbacks 46, invalidation 92 |
| Runner hardening | 15 Python tests passed |
| Offline harness | 6 Python tests passed, including intentional assertion-failure trace retention |
| Offline service boundaries | 6 Python tests passed |
| Host dispatch provisioning | 10 Python tests passed |
| Identity store | 12 Python tests passed |
| Optional reasoner boundary | 2 Python tests passed |
| Import/launcher regression | 8 Python tests passed, including native-runner checks |
| Core lifecycle helpers | 5 Python tests passed |
| Core dispatch | 20 declared tests / 22 generated cases passed |
| Shared v1 contracts | 38 declared tests / 102 generated cases passed |
| Host commitments | 20 declared tests / 25 generated cases passed |
| Shell boundary guards | All four passed: adapter, source, commitment, dispatch |
| Production startup import audit | Exit 0; 74 resolved import edges; application not started |

The Python suites total **64 tests**. The full-loop assertions are also exercised
inside the focused MeTTa suite; the counts above describe separate invocations
and must not be added as unique coverage. Prolog generated-case counts include
the `forall` fixture expansions.

## Commands

Run from the workspace root. The following are the commands actually executed;
artifact arguments identify this local run. For another run, choose a new output
directory to preserve these results. Each command's exit code and separate
stdout/stderr log paths are in `summary.json`.

```sh
python3 MetaMo/scripts/run-tests.py --root MetaMo/applications/omegaclaw_v1 --petta-runner ./run.sh --jobs 2 --timeout 60 --import-report-dir /private/tmp/omegaclaw-task5-regressions-gyt7jghy/imports
python3 MetaMo/scripts/run-omegaclaw-offline.py --output /private/tmp/omegaclaw-task5-regressions-gyt7jghy/full-loop
python3 MetaMo/applications/omegaclaw_v1/tests/runner_hardening_test.py
python3 MetaMo/applications/omegaclaw_v1/tests/offline_harness_test.py
python3 MetaMo/applications/omegaclaw_v1/tests/offline_services_test.py
python3 MetaMo/applications/omegaclaw_v1/tests/host_dispatch_config_test.py
python3 MetaMo/applications/omegaclaw_v1/tests/identity_store_test.py
python3 MetaMo/applications/omegaclaw_v1/tests/reasoner_boundary_test.py
python3 MetaMo/scripts/import-resolution-test.py
python3 repos/OmegaClaw-Core/Autotests/test_helper_lifecycle.py
swipl -q -s repos/OmegaClaw-Core/Autotests/dispatch/dispatch_test.pl
swipl -q -s MetaMo/applications/omegaclaw_v1/tests/contracts_v1_test.pl -g run_tests -t halt
swipl -q -s MetaMo/applications/omegaclaw_v1/tests/commitments_test.pl -g run_tests -t halt
bash MetaMo/applications/omegaclaw_v1/tests/adapter_boundary_test.sh
bash MetaMo/applications/omegaclaw_v1/tests/boundary_source_test.sh
bash MetaMo/applications/omegaclaw_v1/tests/commitment_boundary_test.sh
bash MetaMo/applications/omegaclaw_v1/tests/dispatch_boundary_test.sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/run.metta --audit --report /private/tmp/omegaclaw-task5-regressions-gyt7jghy/startup-imports.json
```

## Retained local artifacts

- Root: `/private/tmp/omegaclaw-task5-regressions-gyt7jghy/`.
- `summary.json`: all commands, exit codes, timings, versions, source revisions,
  pre-run status and source fingerprints; aggregate `passed: true`.
- `*.stdout.log`, `*.stderr.log`: complete output for each regression command.
- `imports/`: per-test import-resolution reports from the MeTTa suite.
- `startup-imports.json`: production startup import audit.
- `full-loop/omegaclaw-offline-e5dz8f1g/summary.json`: scenario assertions,
  commands, source fingerprints and paths to full cycle/dispatch/callback traces.
- `run.py`: the local orchestration script used to capture these results.

These artifacts are local temporary files, not a published CI artifact archive.
The source-controlled record preserves the commands and results if they expire.

## Scope

This closes Task 5's local offline regression gate. It is not a full-repository
or clean-installation baseline. Shared-core checks here use the documented
application wrappers. No live provider, channel, memory service, durable restart
recovery, or CI execution was exercised. Optional reasoner tests remain offline;
live reasoner integration and CI changes remain deferred. Task 6 live acceptance
and the broader Phase 1–7 gates remain open.
