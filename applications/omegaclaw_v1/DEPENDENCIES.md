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

Why the layout matters:

- PeTTa initializes its library search path from its own `src/../lib`.
  `(library MetaMo ...)` therefore resolves through that workspace's sibling
  `MetaMo/` directory.
- The v1 entry point uses `../../../repos/OmegaClaw-Core/...` imports.
  Tests use deeper relative paths appropriate to their entry-file directories.
- `reasoner_engines.pl` locates `../../../lib` relative to its own source file.
  Compiler and engine libraries must come from the intended workspace baseline.
- Moving or copying `run.metta` to the workspace root breaks its relative path
  contract. Run the original file in place. Do not use the previous README's
  `cp ... ./run_omega.metta` instructions.
- Standalone MetaMo installation beside an unrelated PeTTa checkout is not a
  supported v1 layout until import resolution is standardized and tested.

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
sh ./run.sh MetaMo/applications/omegaclaw_v1/tests/minimal_loop_test.metta -s
sh ./run.sh MetaMo/applications/omegaclaw_v1/tests/reasoner_integration_test.metta -s
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
OMEGACLAW_AUTH_SECRET=<channel-secret> sh ./run.sh MetaMo/applications/omegaclaw_v1/run.metta IRC_channel="<irc-channel>" -s
```

Verify checkout identities with `git rev-parse HEAD` in each directory listed
in the revision table before comparing test results.

## Compatibility evidence and alternate runners

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
