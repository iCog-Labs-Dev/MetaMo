# Offline ContextFrames service boundaries

Run from the PeTTa workspace root:

```bash
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/offline_ingestion_test.metta
python3 MetaMo/applications/omegaclaw_v1/tests/offline_services_test.py
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/bridge_cycle_test.metta
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/bridge_snapshot_test.metta
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/multiple_candidates_test.metta
```

The MeTTa test is also discovered by `scripts/run-tests.py`. It loads the actual
Core context/helper/utils modules and application composition. It ingests two
messages through `ctx-ingest-user-message`, stores and loads real frames, checks
the resulting relation endpoints and advisory evidence status, projects the
bounded bundle, and exercises real signal extraction, appraisal, numeric scoring,
and policy admission/rejection. The appraisal changes the real `respond` score
from the same neutral initial state; there is no fixed scorer or synthetic
`FrameStateBundle` replacing projection.

## Doubled boundaries

| Test-only Python module | Replaced external behavior |
| --- | --- |
| `fixtures/offline_services/frame_relation.py` | ChromaDB/vector retrieval and model relation classification. An in-memory list of previously supplied frame IDs replaces retrieval. The first frame has no relations; later frames receive at most five deterministic `RelatedButSeparate` relations in the production provider's wire format. |
| `fixtures/offline_services/lib_llm_ext.py` | Execution-intent confirmation and semantic extraction calls. Explicit `Offline` configuration returns zero confirmation and an empty semantic list, leaving ordinary host-derived signals and registry appraisal intact. |
| `fixtures/offline_services/offline_guard.py` | Test-process guard: forbids imports of optional service packages and socket connections, so installed packages/credentials cannot accidentally satisfy the test. |

Provider doubles validate their expected inputs and expose reset/call-count APIs.
Python tests cover relation direction, quoted IDs, deterministic replay/reset,
retrieval bounds, invalid inputs, and service/network blocking in a child process.
Host-generated IDs and timestamps remain real; determinism means reproducible
relations for the same IDs, not byte-identical wall-clock traces.

All replacements are explicitly imported by this test only. Production `run.metta`
keeps the real providers. Use a fresh launcher process; these modules intentionally
have the provider module names and must not share a Python interpreter with live
providers. The guard likewise lasts for the test process lifetime. There is no
fallback to these doubles when a production service is unavailable.

The fixture supplies bounded host configuration (`provider`, `embeddingprovider`,
token/wake settings and a compact skill listing), but does not override projection,
appraisal, scoring, candidate conversion, or feasibility functions. The composition
loads bundle accessors before signals because PeTTa needs those definitions when
compiling signal extraction.

## Scope and known limits

This closes optional-service dependencies for the tested ContextFrames loading
and message-ingestion path. It does not load all channel integrations or exercise
embeddings, real semantic classification, memory persistence, execution dispatch,
relation verification write-back, or the complete bridge execution-feedback loop.
The ingestion test uses an explicit observed host failure for appraisal.

## Full bridge regression — 23 September 2026

`bridge_cycle_test.metta` calls the production `motivationContextBlock` after
real Core message ingestion. It uses the same provider doubles and network guard,
plus test-only `query`/`remember` functions for the external memory boundary.
Persistence restoration and save scheduling remain real; the test does not
restore a previously serialized payload or exercise a storage backend.

The earlier empty-result failure had two causes: `idleAutonomyActive` was compiled
before its bundle accessor and needed explicit runtime evaluation, and relation
projection converted a structural list into a display string, leaving candidate
generation without a result. Projection now retains bounded typed relations and
preserves empty runtime text before adding any digest. Empty errors/results no
longer produce false failure/progress signals.

The regression passes 49 assertions across fresh-message cycles with empty and
nonempty relation lists, an observed error accompanying a fresh message, and idle
no-action. Each bridge call returns exactly one policy result. Checks cover the
published directive, real motivational state updates, self-model counters,
persistence scheduling and final signal cleanup. The focused suite passes 36
MeTTa files, alongside 32 Python tests, eight import regressions and four shell
boundary checks.

This does not establish execution dispatch or the complete feedback loop. A
separate probe of an active-task continuation without a fresh message reaches
`helper.is_result_status_question`, which is absent from the pinned Core helper;
`helper.task_needs_more_execution` is also referenced by lifecycle code but absent
there. Those host continuation interfaces still need implementation/integration
before claiming the successive execution-feedback scenarios. Live providers,
channels and restart recovery remain unverified. CI is unchanged.

## Snapshot consistency regression

`bridge_snapshot_test.metta` uses real ingestion and the existing trusted host
commitment test APIs. It verifies that `prepareTaskStateForMetaMo` refreshes
execution observations and commitment state before publishing the bundle.
The production entry point then passes that one value to
`motivationContextBlockForBundle`; decision/scoring callbacks retain it through
`omegaclawDecisionForBundle`, and autonomy bookkeeping receives it explicitly.

After capture, the test changes host frame/task/error/result state and replaces
the active-bundle cache. The original snapshot still determines appraisal,
candidate admission, numeric scoring, selection and the directive target. A later
publication sees the updated observations and an explicit commitment completion,
without changing the earlier snapshot. No motivational functions are doubled.

All 34 assertions pass, alongside 37 focused MeTTa files, 32 Python tests, eight
import regressions and four shell guards. These deliberately adversarial mutations
test snapshot isolation within the serialized motivational calculation; they do
not authorize execution against stale host state. The dispatcher must still
revalidate current state and policy before invoking a handler.

## Multiple feasible candidates

`multiple_candidates_test.metta` ingests a real Core task and exercises its open,
awaiting-first-execution state: the message has been ingested, no fresh message is
pending, and there are no execution observations. Existing registry rules generate
five feasible candidates. Scheduling retains `respond` and `ask-clarification`
in the Interactive class, so both reach the unchanged numeric scorer.

The first full bridge call selects `respond` under the default 1.0 score tie.
The test then lowers responsiveness and cooperation goals through `replaceGoal`;
it does not change registry rules, inject candidates, or replace scoring functions.
The resulting decision-context scores are approximately 0.567 for `respond` and
0.967 for `ask-clarification`. A second full bridge call selects the latter while
the host snapshot and generated candidates remain unchanged. Printed candidate,
score, and policy traces make the comparison inspectable.

Lifecycle bookkeeping now skips merging absent results, preserving the empty
observation. Status-question classification only runs for a waiting user, and
continuation classification requires an open task, no new message, and an actual
execution observation. Lazy guards prevent irrelevant eager Python calls. The
missing host classifiers documented above still need integration for scenarios
that require them; this test supplies no replacements for those functions.

All 30 assertions pass. The focused suite now passes 38 MeTTa files, with 32 Python
tests, eight import regressions and four shell boundary checks. The goal change is
a controlled motivational input, not an observed execution outcome; this verifies
Task 1's candidate competition requirement, not the execution-feedback MVP.
