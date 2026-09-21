# OmegaClaw v1 dependency baseline and workspace layout

Refreshed 21 September 2026. The revisions plus source overlays below were
reconstructed in a separate temporary workspace and verified offline. Commits
alone do not reproduce this baseline yet. This is not a live-runtime,
full-repository, or clean Python installation compatibility claim.

## Source revisions

| Component | Exact commit | Workspace-relative location |
| --- | --- | --- |
| Workspace PeTTa fork | `0576ffb6ec05c5bca04b668afe2c8085ad3dc420` | `.` |
| MetaMo | `7ec0f78ccfc7c275fe0e090ffbf24b7cd97e1605` | `MetaMo/` |
| OmegaClaw-Core | `8cabe49da4010dd981150dec1b6b3f25b3153035` | `repos/OmegaClaw-Core/` |
| petta_lib_chromadb | `456385457e4e99ee049c2c0966988a6cd7ff3705` | `repos/petta_lib_chromadb/` |

The workspace commit records MetaMo gitlink
`d20dc5d4f408c214d232b099266378fed0f58d6c`. Select the MetaMo revision above
explicitly; recursive checkout of the workspace commit is insufficient.
PeTTa compiler sources are unchanged. Application-local `helpers.metta`, its
composition import, seven shared-core wrappers, and runner-hardening tests are
already in the recorded MetaMo commit.

## Required working-tree source overlays

Preserve these files from the assessed workspace as well as the commits.
Paths in this table are relative to their component checkout.

| Component | Files and status | Purpose |
| --- | --- | --- |
| MetaMo | `scripts/run-tests.py` (modified) | Workspace selection, v1 routing, failure detection, timeout cleanup. |
| MetaMo | `scripts/run-omegaclaw.py`, `scripts/petta-imports.pl` (untracked) | Canonical package roots, source-relative imports, one-time loading, auditing. |
| MetaMo | `scripts/import-resolution-test.py` (untracked) | Eight import/launcher regressions. |
| MetaMo | `test.sh` (modified) | Alternate test entry point routes v1 through the common launcher; not used for the focused suite below. |
| Core | `src/loop.metta` (modified), `src/dispatch.metta`, `src/dispatch.pl` (untracked) | Session dispatch integration, revalidation, replay protection. The live loop itself is not exercised by this offline baseline. |
| Core | `Autotests/dispatch/dispatch_test.pl` (untracked) | Standalone host dispatch regression source. |

SHA-256 fingerprints of copied overlays, relative to the workspace:

```text
3e0937d54d44b19d5dd69ce0b9ac890a589d461e6ea1a1226e24e33ced82293b  MetaMo/scripts/run-tests.py
fc97fe0e9a3cba378f6741fc4caf424f869aa49aa4c5c8b4730786e51f88423e  MetaMo/scripts/run-omegaclaw.py
b5380ed9da3814a91c602c6cf36335be33073f2cabbf6faece7c7d5fc5e05cf6  MetaMo/scripts/petta-imports.pl
49b216d05620851afd2d7f40cd08eb593132b48c15e1a8f8323f62b23c28170d  MetaMo/scripts/import-resolution-test.py
63dea94b79b1228500be77769798401f8c3e09ec454a0b28cc43f0b5a6b02125  MetaMo/test.sh
cdfa80997d07e8d41a2fdd21889b410d6456cd819cd431d2a77203f93dbe1b5a  repos/OmegaClaw-Core/src/loop.metta
c1f4649bc4ba2e18d02ca85f17fdee1a10e302328bb65def5756f5907c817366  repos/OmegaClaw-Core/src/dispatch.metta
1c75249cbc7b005c26b1ccc232903d5dbf63cda96f49422d124ec810f3e78a54  repos/OmegaClaw-Core/src/dispatch.pl
ddc6e591c4f69463088dd588d4c490ee97f08893d8078622ade9b139ad790fc3  repos/OmegaClaw-Core/Autotests/dispatch/dispatch_test.pl
```

Hashes identify content; they do not distribute the uncommitted files.
Reconstruction requires the assessed working tree or copies of these overlays.
Commit or package them before treating this as a portable release baseline.
The MetaMo `.gitignore` change, workspace Chroma database modification,
top-level notes/tests, and ChromaDB `__pycache__/` were not copied and are not
prerequisites for the verified offline commands.

## Supported layout and launcher

```text
<workspace>/
├── run.sh
├── src/                         # PeTTa compiler
├── lib/                         # lib_import, lib_nars, lib_pln
├── MetaMo/
│   ├── core/
│   ├── scripts/                 # launcher, import loader, test runner
│   └── applications/omegaclaw_v1/
└── repos/
    ├── OmegaClaw-Core/          # separate host lib_nal/lib_pln rules
    └── petta_lib_chromadb/
```

The assessed workspace is `/Users/nahomsenay/Hyperclaw-Metamo-Fork`.
Use `MetaMo/scripts/run-omegaclaw.py`; see [COMPOSITION.md](COMPOSITION.md).
Its default compiler workspace is MetaMo's parent. `--workspace` can select
another compiler checkout containing `lib/` and `repos/`; MetaMo imports always
target the checkout containing the launcher. Relative imports resolve against
their source file. Native `run.sh` does not provide the same one-time loading
guarantees. Do not substitute the unqualified `petta` wrapper, which may select
a different compiler checkout.

## Runtime and dependency limits

The refreshed checks used SWI-Prolog `9.2.9` on `x86_64-darwin`, shell Python
`3.9.6`, and Janus embedded Python `3.9.6` with NumPy `1.26.4`. NumPy differs
from the historical 13 September environment (`2.0.2`). These are observed
versions, not an installation lock. No channel credentials or external services
were used. Live provider packages were not validated in this refresh.

MetaMo's requirements list unpinned `numpy`, `google-genai`, and `dotenv`.
The recorded Core revision declares:

```text
janus-swi
torch==2.12.1
chromadb==1.5.9
openai==2.38.0
uagents==0.25.1
transformers==5.8.0
sentence-transformers==5.5.1
import-kb==0.1.8
py-landlock==0.1.1
pyyaml==6.0.3
ddgs==9.14.4
```

These declarations were not installed or validated together. The ChromaDB
adapter imports `chromadb` without its own requirements file. A complete Python
lock and clean live installation remain follow-up work. Check the Python
embedded by SWI-Prolog, not only the shell interpreter.

## Reconstruct the assessed source setup

The following uses local repository histories and the nine overlay files above.
It creates a new temporary workspace without modifying the source or fetching
dependencies. Adjust `baseline_source` if it has moved and verify overlay hashes
before using a newer working tree. This reconstructs source, not installed
Python/SWI-Prolog dependencies.

```bash
set -e
baseline_source=/Users/nahomsenay/Hyperclaw-Metamo-Fork
baseline_parent=$(mktemp -d /private/tmp/metamo-baseline.XXXXXX)
baseline_workspace="$baseline_parent/workspace"
git clone --quiet --no-hardlinks "$baseline_source" "$baseline_workspace"
git -C "$baseline_workspace" checkout --quiet --detach 0576ffb6ec05c5bca04b668afe2c8085ad3dc420
git clone --quiet --no-hardlinks "$baseline_source/MetaMo" "$baseline_workspace/MetaMo"
git -C "$baseline_workspace/MetaMo" checkout --quiet --detach 7ec0f78ccfc7c275fe0e090ffbf24b7cd97e1605
git clone --quiet --no-hardlinks "$baseline_source/repos/OmegaClaw-Core" "$baseline_workspace/repos/OmegaClaw-Core"
git -C "$baseline_workspace/repos/OmegaClaw-Core" checkout --quiet --detach 8cabe49da4010dd981150dec1b6b3f25b3153035
git clone --quiet --no-hardlinks "$baseline_source/repos/petta_lib_chromadb" "$baseline_workspace/repos/petta_lib_chromadb"
git -C "$baseline_workspace/repos/petta_lib_chromadb" checkout --quiet --detach 456385457e4e99ee049c2c0966988a6cd7ff3705
for file in run-tests.py run-omegaclaw.py petta-imports.pl import-resolution-test.py; do
  cp "$baseline_source/MetaMo/scripts/$file" "$baseline_workspace/MetaMo/scripts/$file"
done
cp "$baseline_source/MetaMo/test.sh" "$baseline_workspace/MetaMo/test.sh"
for file in loop.metta dispatch.metta dispatch.pl; do
  cp "$baseline_source/repos/OmegaClaw-Core/src/$file" "$baseline_workspace/repos/OmegaClaw-Core/src/$file"
done
mkdir -p "$baseline_workspace/repos/OmegaClaw-Core/Autotests/dispatch"
cp "$baseline_source/repos/OmegaClaw-Core/Autotests/dispatch/dispatch_test.pl" "$baseline_workspace/repos/OmegaClaw-Core/Autotests/dispatch/dispatch_test.pl"
cd "$baseline_workspace"
```

## Verified commands and results

From the reconstructed workspace root:

```bash
python3 MetaMo/scripts/run-tests.py --root MetaMo/applications/omegaclaw_v1 --petta-runner ./run.sh --jobs 2 --timeout 60
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/minimal_loop_test.metta
bash MetaMo/applications/omegaclaw_v1/tests/run_minimal_loop.sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/reasoner_integration_test.metta
python3 MetaMo/applications/omegaclaw_v1/tests/runner_hardening_test.py
python3 MetaMo/scripts/import-resolution-test.py
bash MetaMo/applications/omegaclaw_v1/tests/adapter_boundary_test.sh
bash MetaMo/applications/omegaclaw_v1/tests/boundary_source_test.sh
bash MetaMo/applications/omegaclaw_v1/tests/commitment_boundary_test.sh
bash MetaMo/applications/omegaclaw_v1/tests/dispatch_boundary_test.sh
```

On 21 September 2026, reconstruction at
`/private/tmp/metamo-baseline.xJQ2Rb/workspace` produced:

| Check | Result |
| --- | --- |
| Focused suite | 33/33 files: 26 v1 tests plus seven shared-core wrappers |
| Standalone minimal demo, direct launcher | 6 assertions, exit 0 |
| Standalone minimal demo, shell wrapper | Same decision/directive and 6 assertions, exit 0 |
| Standalone NARS/PLN integration | 18 assertions, exit 0 |
| Runner hardening | 12 tests passed |
| Import/launcher regressions | 8 tests passed |
| Four shell guards | All exited 0 |

Suite and standalone demo agree on `respond`, score `0.5`, mode `Rumination`,
and the admitted directive targeting `demo-frame`. This is a fixed-score fixture,
not proof of the real execution-feedback MVP. The import regressions also check
native context integration (77 assertions) and native minimal/reasoner tests,
including a 64 MiB compiler stack for the latter two.

The shared-core wrappers supply application-local `norm`; direct standalone
shared tests without that helper retain the previously recorded failures.
This is not a passing full-repository baseline. No live channel, restart,
clean dependency installation, or CI run was verified.

## Live invocation and historical limits

Subsequent offline-service work adds `tests/offline_ingestion_test.metta`,
`tests/offline_services_test.py`, and `tests/fixtures/offline_services/*.py`,
plus the context-before-signals import order in `composition.metta`. These are
not included in the pinned 33-file reconstruction above. The current working
tree passes 34 MeTTa files and six service-double tests; see
[OFFLINE_SERVICES.md](tests/OFFLINE_SERVICES.md) for their scope and commands.

After configuring live dependencies, channel credentials, and trusted host
policies/exact command bindings per [DISPATCH.md](DISPATCH.md):

```bash
OMEGACLAW_AUTH_SECRET=<channel-secret> python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/run.metta IRC_channel="<irc-channel>"
```

This command was not run. It does not provision dispatch policies; absent
configuration produces no-action.

The 13 September baseline used MetaMo `b1d2ce652a3fab1dd05a91a794a6c8e31527f595`.
Its 3-of-11 result, duplicate/import failures, stack growth, timeout decoding
failure, and later 12-file composition result are historical, superseded for
the focused suite by the reconstruction above. CI still specifies upstream
PeTTa `v1.0.2` and lacks the documented host checkout layout; parity remains
unverified. CI changes are deferred at the user's request.
