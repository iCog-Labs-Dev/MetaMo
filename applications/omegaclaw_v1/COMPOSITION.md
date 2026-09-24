# Predictable v1 module composition

## Diagnosis

PeTTa's native importer processes a file on every import. Each MeTTa function
definition adds another global Prolog clause, and each top-level `bind!` runs
again. Rebinding a state replaces its value; rebinding a space loses the
previous space reference and its accumulated contents.

The v1 dependency graph previously loaded context leaves directly, through
`context_integration`, and again through leaf dependencies. For example, the
facade imports `context_accessors`, `context_policy` imports it again, and
`context_directives` imports both. The scoring tests also imported the registry
twice. These routes explain repeated accessor/directive results and repeated
allocation of directive and relation-evidence state.

There was a separate setup issue: the reasoner integration test imported the
runnable minimal-loop test, executing its initialization and six assertions as
a side effect. Finally, the production import order placed proposals before the
decision scorer. PeTTa could compile the unresolved scorer call as data; using
the production composition in the reasoner test reproduced an arithmetic type
error on `omegaclawScoreForBundle`.

## Contract

- Use `scripts/run-omegaclaw.py` for v1 execution and import auditing. Native
  `petta`/`run.sh` do not provide these import semantics.
- Named imports resolve from explicit roots: this MetaMo checkout, the selected
  PeTTa `lib/`, and that workspace's two `repos/` dependencies. Relative imports
  resolve from the importing source file, not the initial entry file or shell.
- Canonical physical paths identify modules. Direct, named, facade, `..`, and
  symlink routes to the same file share one successful load.
- A successful MeTTa module load compiles definitions, adds registry facts, and
  runs allocation forms once. Subsequent imports preserve state and space
  contents; they are not a reset API.
- Modules become loaded only after successful completion. A load error aborts
  execution; failed imports are not treated as successfully cached modules.
  Partial effects are not rolled back, so restart after a failed load.
- Cyclic imports fail explicitly rather than exposing partially loaded modules.
- Loading one MeTTa module into a second space fails explicitly. PeTTa function
  compilation is global; a second space is not an isolated copy of module code.
  This launcher is intended for v1's single-space module composition.
- Python imports verify the loaded module's `__file__` against the requested
  physical file. Errors and same-name module collisions are not silently ignored.

## Composition and initialization

`composition.metta` owns the application import order: shared core, configuration
and state adapters, modes/signals/appraisal, homeostasis/lifecycle, context facade,
candidate generation, decision scoring, persistence, and bridge. It does not
import the optional proposal adapter or inference engines.

Reasoner integration is deferred. `reasoner_integration.metta` is an opt-in
extension loaded after composition; it owns `reasoner_proposals` and engine
loading. Tests needing proposal admission without inference import only
`reasoner_proposals` after composition. The dependency points from the optional
adapter into the core's policy/scoring APIs; the core does not call the adapter.
Wire schemas and optional proposal references remain shared data contracts.

`run.metta` imports the host dependencies and this common composition, then calls
`motivatedOmegaclaw` explicitly. Importing `composition.metta` allocates defaults
but does not start a channel, initialize a task, or restore persistence.

The context facade is the public bundle of context modules. Consumers needing
the complete boundary import it once instead of listing its children as well.
Context leaves do not import one another. The facade loads accessors before
policy, then directives, so this graph also compiles once under native `run.sh`.
Focused tests may import individual leaves only when they explicitly load their
prerequisites in order and do not also import the facade.

The context integration test and focused context tests use explicit host source
paths so native PeTTa does not silently skip an unregistered OmegaClaw-Core
namespace. From the workspace root, the integration test also runs directly:

```bash
sh run.sh MetaMo/applications/omegaclaw_v1/tests/context_integration_test.metta -s
```

This command passes all 77 assertions without the custom import cache. A native
runner regression check prevents the caching launcher from concealing future
duplicate imports. This does not give native PeTTa general import-once semantics.

`tests/fixtures/minimal_loop.metta` contains shared offline definitions and
imports the same application composition. Its scenario reset is the explicit
`initMinimalLoopFixture` function. Importing the fixture neither resets a live
scenario nor executes test assertions. The minimal-loop and reasoner tests each
call setup once, in their own process.

The native reasoner test previously returned sixteen `nars` alternatives for
its first scalar assertion: `reasoner_integration` reimported both `lib_import`
and `reasoner_proposals` after the fixture's composition had loaded them.
The extension requires composition first. Proposal imports now belong exclusively
to the extension, alongside its engine adapter; composition no longer loads them.
This preserves one-time compilation and proposal-state allocation under native
PeTTa. Do not separately import the proposal module and the full inference
extension into the same native process.

Host helper and ContextFrames imports live at each test entry point, using
explicit source paths. They are no longer hidden behind a package alias that
native PeTTa does not register. The reusable fixture receives those host
definitions from its caller. Engine libraries resolve beside the compiler
actually running, and runnable forms in engine libraries produce an explicit
load error rather than silently leaving inference calls unresolved.

After the earlier context-import repair, the minimal-loop overflow was no
longer reproducible in the current tree. Both the minimal loop (6 assertions)
and real NARS/PLN integration (18 assertions) now pass under native `run.sh`
and under the same native compiler constrained to a 64 MiB stack. The existing
inference, evidence, negative-premise, rejection, and reliability assertions
are unchanged. No deduplication or blanket result collapsing was added.

## Verification and inspection

From the MetaMo repository root:

```bash
python3 scripts/run-tests.py --root applications/omegaclaw_v1 --import-report-dir /tmp/omegaclaw-imports
python3 scripts/import-resolution-test.py
python3 applications/omegaclaw_v1/tests/reasoner_boundary_test.py
python3 scripts/run-omegaclaw.py applications/omegaclaw_v1/run.metta --audit --report /tmp/omegaclaw-run-imports.json
```

Use `--workspace /absolute/path/to/PeTTa` on the standalone launcher, or
`--petta-runner /absolute/path/to/PeTTa/run.sh` on the suite, to select a different
workspace explicitly. The `run.sh` argument selects the compiler directory;
v1 tests still execute through the common launcher.

JSON reports list each declared import edge's owner, request, kind, and physical
target. They include transitive MeTTa imports, declared Prolog helpers, and the
two inference engine files. Repeated edges are expected where dependencies are
shared; they do not imply repeated execution. Audit mode parses source without
executing application Python, MeTTa setup, or channel startup. It does not audit
transitive Python package imports or arbitrary computed imports inside functions;
imports reached at execution still use the same resolver.

Validation after this change: all 12 v1 MeTTa test files passed, including a new
12-assertion composition test. Eight import/runner regression tests passed. The tests
cover state/evidence preservation, singleton registry facts and function results,
explicit fixture setup, symlink identity, shell-directory independence, missing
sources, application-free auditing, cycle detection, and cross-space rejection.
No live channel or persistence backend was started. CI/CD YAML remains unchanged.


Host continuation loads after the commitment adapter and before lifecycle
publication. `hostRefreshContinuation` is called directly before snapshot capture;
its command-bearing host values must not be passed through dynamic `eval`.
Only inert command identity text enters the bounded continuation view. Commitment
imports now belong to the composition so native loading still occurs once.
