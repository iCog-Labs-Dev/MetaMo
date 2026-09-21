# Offline ContextFrames service boundaries

Run from the PeTTa workspace root:

```bash
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/offline_ingestion_test.metta
python3 MetaMo/applications/omegaclaw_v1/tests/offline_services_test.py
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
The test uses an explicit observed host failure for appraisal. Existing projection
compacts even empty error/result strings into nonempty summaries; the current
signal helpers can mistake those summaries for observations. That separate
projection/signal issue remains open and is not hidden by a replacement bundle.

The earlier full-bridge attempt did not produce a policy result; this test does
not establish that `motivationContextBlock` completes. Full bridge diagnosis and
the live vertical slice remain separate work. CI is unchanged.
