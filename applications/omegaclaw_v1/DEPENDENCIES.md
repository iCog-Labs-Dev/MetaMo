# OmegaClaw v1 dependency baseline and workspace layout

Recorded 13 September 2026. These revisions describe the inspected local
workspace. Compatibility evidence below is limited to the checks actually run;
this is not a claim that the live integration or all Python dependencies work.

## Source revisions

| Component | Exact commit | Location relative to workspace root |
| --- | --- | --- |
| Workspace PeTTa fork | `0576ffb6ec05c5bca04b668afe2c8085ad3dc420` | `.` |
| MetaMo | `b1d2ce652a3fab1dd05a91a794a6c8e31527f595` | `MetaMo/` |
| OmegaClaw-Core | `8cabe49da4010dd981150dec1b6b3f25b3153035` | `repos/OmegaClaw-Core/` |
| petta_lib_chromadb | `456385457e4e99ee049c2c0966988a6cd7ff3705` | `repos/petta_lib_chromadb/` |

The workspace commit records an older MetaMo gitlink,
`d20dc5d4f408c214d232b099266378fed0f58d6c`. Reproducing the baseline therefore
requires explicitly selecting the MetaMo revision above after initializing
the workspace's dependencies. A recursive checkout of the workspace commit
alone does not reproduce the current application.

The workspace compiler and OmegaClaw-Core had no tracked source modifications
at inspection. ChromaDB's checkout had only an untracked `__pycache__/`.
MetaMo documentation additions are not part of the recorded MetaMo commit.

## Supported source layout

Keep the application in place inside one PeTTa workspace:

```text
<workspace>/
├── run.sh
├── src/                         # compiler from the workspace revision
├── lib/
│   ├── lib_import.metta
│   ├── lib_import.pl
│   ├── lib_nars.metta           # inference engines used by MetaMo
│   └── lib_pln.metta
├── MetaMo/
│   ├── core/
│   ├── scripts/run-tests.py
│   └── applications/omegaclaw_v1/
│       ├── run.metta
│       ├── reasoner_engines.pl
│       ├── contexts/
│       └── tests/
└── repos/
    ├── OmegaClaw-Core/          # includes separate lib_nal/lib_pln rules
    └── petta_lib_chromadb/
```

The inspected `<workspace>` is
`/Users/nahomsenay/Hyperclaw-Metamo-Fork`. The directory name can change; the
relative structure above is required by current imports.

The standard launcher is now `MetaMo/scripts/run-omegaclaw.py`; see
[COMPOSITION.md](COMPOSITION.md). It maps named packages to explicit physical
roots and loads each module once. Its default compiler workspace is MetaMo's
parent; `--workspace` supports a separate compiler checkout containing `lib/`
and `repos/`. MetaMo imports always target the checkout containing the launcher.
The inference engines use that selected compiler workspace's `lib/` as well.
Relative imports, when used, are relative to the importing file.

The native PeTTa runner does not provide these composition guarantees. Keep the
original entry point and invoke it through the common launcher below.

## Runtime and Python dependency status

The smoke checks used SWI-Prolog `9.2.9` on `x86_64-darwin`. Its Janus bridge
reported embedded Python `3.9.6`, with NumPy `2.0.2`. This describes the test
environment; it is not a recommended complete live-runtime environment.
`google-genai` was absent from that embedded Python environment.

MetaMo's root `requirements.txt` currently lists unpinned `numpy`,
`google-genai`, and `dotenv`. The recorded OmegaClaw-Core revision declares:

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

These are recorded source declarations, not a verified installation lock.
Their availability, platform support, Python compatibility, and combined
resolution were not tested here. The ChromaDB adapter imports `chromadb` but
has no separate `requirements.txt`. A complete Python lock and a clean live
installation remain Phase 1 follow-up work. Check the Python embedded by
SWI-Prolog, not only the shell's `python3`, when validating installed packages.

## Explicit commands

From `<workspace>`, run the offline smoke checks with the local compiler:

```bash
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/minimal_loop_test.metta
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/reasoner_integration_test.metta
```

Run the focused suite and source guards:

```bash
python3 MetaMo/scripts/run-tests.py --root MetaMo/applications/omegaclaw_v1 --petta-runner ./run.sh --jobs 1
bash MetaMo/applications/omegaclaw_v1/tests/adapter_boundary_test.sh
bash MetaMo/applications/omegaclaw_v1/tests/boundary_source_test.sh
```

The intended live invocation, after configuring dependencies and channel
credentials, is below. It was not executed as part of this baseline check:

```bash
OMEGACLAW_AUTH_SECRET=<channel-secret> python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/run.metta IRC_channel="<irc-channel>"
```

Verify checkout identities with `git rev-parse HEAD` in each directory listed
in the revision table before comparing test results.

## Current composition validation

With the common launcher, all 12 v1 MeTTa test files and eight import/runner regression
tests pass locally. The reasoner test now runs 18 of its own assertions; the six
minimal-loop assertions are no longer executed indirectly by importing a test.
The earlier native-runner observations below are historical diagnosis, not
results for the current launcher. Full live-runtime compatibility is unverified.

The context integration (77 assertions), minimal loop (6), and NARS/PLN
integration (18) also pass with the workspace-local native `run.sh`. The last
two pass with the native compiler's stack constrained to 64 MiB. See
`COMPOSITION.md` for the repaired import graph and the composition prerequisite
for loading the reasoner extension.

## Historical compatibility evidence and alternate runners

Using the workspace-local runner and the recorded source revisions:

- Minimal-loop smoke: exit 0, 6 passing assertions, no failing assertions.
- NARS/PLN integration smoke: exit 0, 24 passing assertions, no failing assertions.

These checks establish compatibility for those offline paths. They do not
exercise a live channel, complete production motivation cycle, persistence,
or all host dependencies.

The local suite was also attempted with the workspace runner, `--jobs 1`, and
a 45-second per-file timeout. Projection, motivation scoring, and decision
tests passed. Five focused context tests and the context integration test
failed assertions, often returning duplicate results. The minimal-loop test
exceeded the Prolog stack limit under the suite invocation. The reasoner test
timed out, after which `scripts/run-tests.py` itself raised a `TypeError` while
joining captured bytes as text. There is therefore no passing full-suite
baseline. Source layout alone does not resolve the remaining invocation/import
problems; the smoke commands and suite are not yet interchangeable.

The machine's `/usr/local/bin/petta` wrapper instead uses
`/Users/nahomsenay/projects/PeTTa`, at commit
`ccbbf0216d740d089dd69bbe6f1b73ae01ecbfb4`. It has no `MetaMo/` sibling beneath
its own root. The earlier 3/11 suite result used that external runner; its
library resolution differs from the workspace-local setup. Do not use that
result to claim the local source revisions are mutually incompatible, or use
the unqualified `petta` wrapper as the reproducible baseline command.

CI currently selects upstream PeTTa tag `v1.0.2`, not the workspace fork commit
above. That tag was not available for local commit resolution during inspection.
The workflow also does not check out OmegaClaw-Core and the ChromaDB adapter
in this layout. CI parity with this v1 baseline remains unverified.
