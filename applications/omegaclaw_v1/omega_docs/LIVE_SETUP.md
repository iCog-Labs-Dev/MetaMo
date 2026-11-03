# A verified local setup with real services

Subsequent execution-feedback evidence and the additional Core budget fix are
documented in [LIVE_CYCLE.md](LIVE_CYCLE.md). The setup results below describe
the earlier readiness check and retain their original scope.

On 24 September 2026, this setup verified the runtime dependencies, provider,
memory, one test channel, and a small set of explicitly allowed skills. The
results establish that setup on this machine; broader live-loop behavior needs
its own checks.

## Run this check again

From `MetaMo/applications/omegaclaw_v1` in the workspace layout documented in
`DEPENDENCIES.md`:

```sh
python3 tools/verify_live_setup.py
```

Supply `ASI_API_KEY` through the existing environment or Core's existing dotenv
configuration. Do not put it in the host policy file. This profile uses direct
ASICloud access: `GATEWAY_URL` must be unset. The command needs network access
and makes real, billed synthetic requests. It never prints the key. Local model
`intfloat/e5-large-v2` must already be cached; Core's embedding initialization
sets `HF_HUB_OFFLINE=1` and does not download it.

The runner creates a fresh `/private/tmp/oc-setup-*` directory (or under
`--output DIRECTORY`) and prints its location. It generates:

- `host.json`: explicit global/frame permissions, budgets, constraints and exact
  `read-file` / `show-current-frame` command bindings.
- `input.txt` and `inbox.json`: synthetic approved content and a one-message
  local inbox. No workspace documents or real conversations are used.
- `chroma/` and `history.metta`: isolated persistence locations.
- `setup.metta` and `reopen.metta`: readiness entries using the exact imports and
  startup initialization from production `run.metta`, replacing only its final
  autonomous-loop invocation with explicit component checks.
- Logs, import reports, component JSON reports, and `summary.json`, including
  source fingerprints, exact commands, timeouts, exit codes and assertion counts.

There are no provider, memory, channel or handler doubles. Each process has a
180-second deadline; timeout terminates its process group and fails the result.
There are no automatic harness retries. Explicit provider diagnostics use a
30-second request timeout with transport retries disabled. Native frame ingestion
also exercises Core's ASICloud relation-classifier route with its usual settings.

## Verified configuration

| Setting | Verified value |
| --- | --- |
| Runtime | SWI-Prolog 9.2.9, x86_64-darwin; Janus embedded Python 3.9.6 |
| Provider | `provider=ASICloud`, `minimax/minimax-m3` |
| Endpoint | `https://inference.asicloud.cudos.org/v1` |
| Command-response limit | 512 tokens |
| Embedding | `embeddingprovider=Local`, cached `intfloat/e5-large-v2`, 1,024 dimensions |
| Memory | Real embedded ChromaDB persistent client; shared path for memories and frame sketches |
| Channel | `commchannel=local`, JSON inbox and stdout outbox; no external recipients |
| Relation provider | `FRAME_REL_PROVIDER=ASICloud` |
| Storage isolation | `CHROMA_DB_PATH`, `OMEGACLAW_HISTORY_PATH`, `OMEGACLAW_LOCAL_INPUT` point into the artifact directory |
| Thread configuration | `TOKENIZERS_PARALLELISM=false`, `OMP_NUM_THREADS=1` |

[requirements-live-verified.txt](../requirements-live-verified.txt) records the
direct package versions observed inside Janus. These differ from Core's declared
requirements and are the combination exercised here. This is a verified existing
installation, not a clean-install lock or a guarantee for other platforms.
PeTTa/Janus and the cached embedding model are additional runtime requirements.

## Skills and policy

The generated policy binds once to Core's first actual native frame ID. It allows
reading only the generated canonical `input.txt` path and inspecting that frame.
Global and frame scopes both explicitly allow the two skills and require the
appropriate `files.read`, exact-file, and `frames.read` permissions. Neither has
egress destinations. Global constraints deny shell and file writing. Both scopes
limit prospective command cost to one unit; global/frame available capacities
are ten/two units. These are admission checks, not a durable spending ledger.

Real Core handlers return the expected file content and frame. The same loaded
runtime rejects an unregistered file and shell command, then rejects configured
reads after removing permission, exhausting frame capacity, or setting maximum
cost to zero. Explicit trusted reprovisioning restores the allowed profile.

The readiness entry sets Engaged to test handler availability independently of
selection. It does not demonstrate a constitutional transition or a command
chosen by the live motivational loop. The production dispatch hooks remain loaded;
these handler tests call the trusted Core ticket/gate API directly.

## Acceptance evidence

The final invocation at **2026-09-24 18:45 UTC** passed **22/22 setup assertions**
and **1/1 fresh-process reopen assertion**, with exit code zero and no timeout.
Artifacts: `/private/tmp/oc-setup-mpcdt5c9/`. A retained, secret-free record is in
[tests/LIVE_SETUP_RESULTS_2026-09-24.json](../tests/LIVE_SETUP_RESULTS_2026-09-24.json).

- Three explicit real ASICloud requests passed: confirmation score `0.95`,
  canonical execution-request signal `0.85`, and command response `()`.
  Native frame ingestion also received a successful relation-classifier response.
- Real embeddings and ChromaDB stored/retrieved motivation data and a frame
  sketch. The actual memory query shape parsed into valid motivational entries.
  A second process reopened and retrieved both collections successfully.
- The production channel initializer selected `local`; Core receive routing
  consumed the expected message and then returned empty. The local outbox
  produced the expected JSON reply.
- Both allowed handlers and all five denial checks passed.
- Supporting regressions: 12 host-config Python tests, 8 provider-helper Python
  tests, 5 Core runtime Python tests, and 24 startup MeTTa assertions passed.

Supporting commands, from the application directory:

```sh
python3 tests/host_dispatch_config_test.py
python3 ../../../repos/OmegaClaw-Core/Autotests/test_provider_helpers.py
python3 ../../../repos/OmegaClaw-Core/Autotests/test_live_runtime.py
python3 ../../scripts/run-omegaclaw.py tests/host_startup_test.metta
```

Earlier attempts are retained separately: sandbox network denial
(`/private/tmp/oc-setup-bwwfkedk`); empty provider response with a 128-token limit
(`/private/tmp/oc-setup-3i11w4ol`); and a harness comparison corrected for Janus
text representation (`/private/tmp/oc-setup-5uhv9sh9`). The final run did not retry.
The loader emits a nonfatal `python_builtin,live_setup_probe` diagnostic during
import; the module subsequently loads and its calls pass. This work does not
claim a warning-free compiler/import layer.

## Source baseline and limits

| Component | Commit plus current source overlays |
| --- | --- |
| PeTTa workspace | `0576ffb6ec05c5bca04b668afe2c8085ad3dc420` |
| MetaMo | `ab2bd10b68097bf6680aef7e6e4aba10c8bc6a80` |
| OmegaClaw-Core | `8cabe49da4010dd981150dec1b6b3f25b3153035` |
| ChromaDB adapter | `456385457e4e99ee049c2c0966988a6cd7ff3705` |

Commits alone are insufficient. Preserve the common launcher/import loader;
Core dispatch, loop hooks, provider helpers, local channel, history-path and
frame-memory overlays; the ChromaDB path override; and application startup,
runtime-support and persistence changes. The retained JSON fingerprints all
80 resolved/generated sources used in this check.

This confirms setup readiness on this machine. It does not verify autonomous
execution, failure/recovery, mode transitions, or complete execution traces.
Reopening ChromaDB proves persistence availability, not durable
agent recovery, policy restoration, or exactly-once execution across restarts.
