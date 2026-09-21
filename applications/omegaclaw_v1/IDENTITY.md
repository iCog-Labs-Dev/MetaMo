# Host-owned integration identities

`host_identity.metta` implements allocation/publication orchestration, typed
reference resolution, and causal agreement checks for `CONTRACTS.md`.
`identity_store.py` supplies only UUIDs, producer namespaces, and durable opaque
storage. There is no new Prolog implementation. MeTTa checks use higher-order
`identityEvery`/`identityAll` and named predicates; data passed to predicates is
quoted so fields such as `(id ...)` cannot become executable calls.

## Host API

Import from trusted host startup, after `lib_import` is available:

```metta
!(import! &self (library MetaMo applications/omegaclaw_v1/host_identity))
```

Use the common launcher to load shared contracts once. The module is opt-in and
does not open storage, start a channel, register model skills, or change the
existing legacy production loop. Its mutation APIs belong to trusted host code;
they are not an authorization boundary for arbitrary code already running in
the interpreter. Treat store paths, producer roles, native entity versions,
observations, and dispatch-check revisions as host-supplied data.

| API | Result and ownership |
| --- | --- |
| `identityOpen PATH ""` | Create an empty ledger with a new host lineage and producer namespaces; reject an existing file. Returns `(IdentityHost HOST)`. |
| `identityOpen PATH HOST` | Resume that exact persisted lineage. Missing/corrupt data or another host does not create a replacement. |
| `identityProducer ROLE` | Return the persisted namespace for `host`, `metamo`, `scheduler`, `nars`, `pln`, `llm`, `rule-engine`, `human-adapter`, `verification`, or `executor`. |
| `identityAdoptEntity KIND ID REVISION DATA` | Retain a native `FrameRef`, `RelationRef`, `BudgetRef`, `ConstraintsRef`, or `HostPolicyRef` version. Returns `(IdentityEntity REF DATA)`. |
| `identityCapture STATE-REV POLICY-REV PAYLOAD` | Allocate and store a `FrameStateBundle` envelope whose record ID equals its snapshot ID. Validate admitted entity versions, relation endpoints, observations, and policy references. |
| `identityPublish ROLE CONTEXT PAYLOAD` | Allocate a fresh record in the appropriate producer namespace, validate its wire shape and causal links, then persist it. Supports the other five v1 record schemas. |
| `identityDispatch DIRECTIVE-REF CHECKED-STATE-REV CHECKED-POLICY-REV` | Allocate/return `DispatchLink`, retaining its decision, proposal, original snapshot, requested frame revision, and actual checked revisions, including blocked attempts. |
| `identityExecution DISPATCH-REF` | Allocate/return the single `ExecutionLink` for that dispatch before invocation. This allocates an identity, not permission to invoke. |
| `identityObserve CONTEXT FRAME-REFS RELATION-REFS EXECUTION-OR-None PROVENANCE` | Allocate an immutable `ObservationLink` containing the supplied host-observed versions and provenance. Read its `id` field for the `ObservationRef`. |
| `identityResolve EXPECTED-TYPE REF` | Resolve the exact namespace, type, ID and version. Wrong types return `MalformedRecord`; unavailable references return `MissingReference`. |
| `identityRedeliver RECORD` | Return the identical stored record without allocating; conflicting content is `IdentityConflict`, an unknown ID is `MissingReference`. |
| `identityClose` | Close the ledger and release its process lock. |

Use `identityField` to access tagged results and `integrationRecordReference`
for envelope references. Shape/causal failures return `ContractRejection`.
Filesystem/locking failures raise host errors and must prevent publication or
invocation; callers must not catch them and assume success.

## Native identity and lifetime

Frame and root IDs are preserved **exactly as Core supplies them**. The adapter
does not parse Core's timestamp-shaped IDs, generate replacement frame IDs, or
use task descriptions to deduplicate work. The host must never assign a retained
native ID to a different work item, including after completion/deletion. Native
IDs are qualified by the durable host lineage. If a source can recycle them,
it cannot be adopted as the same identity without a separate host migration.

The first adopted entity version may have an existing revision; subsequent new
versions advance by one. Re-registering an identical version/content is
idempotent; replacing that content is rejected. All versions remain available.
For relations, `DATA` is the captured `FrameStateRelation` so source, target,
type, confidence, and revision can be checked. Other entity data remains opaque
host data; reference resolution does not evaluate policy or verify display
summaries against the native store.

Record and attempt IDs are collision-resistant UUIDv4 strings. Fresh capture or
recomputation gets a new ID even at unchanged revisions. Redelivery preserves
the original immutable record. Dispatch allocation is keyed by directive, and
execution allocation by dispatch, across restart. An unfinished allocation is
retained and may be completed with the same ID; it never implies invocation.
An explicit retry needs a fresh decision/directive chain.

The JSON ledger is exclusively locked for one process and serialized across
threads. Each update writes/fsyncs a temporary image, atomically replaces the
ledger, and fsyncs its directory before returning. After an uncertain storage
failure, close/resume is required before further operations. Ordinary restart
preserves IDs and producer namespaces. A backup restore, host-state fork, or
lost identity ledger requires a new ledger/lineage; the operator must not use
`resume` on a rolled-back copy. The ledger alone cannot detect backup rollback.

## Causal checks and scope

The retained chain is:

```text
snapshot → optional proposal → decision → directive → dispatch → execution
    └─ admitted frame/relation versions                 └─ outcome ─┘
                                                   observations / verification
```

Proposals, decisions and directives must agree on the exact snapshot, operation,
target and admission. Relation verification must match its original relation
version and observations. Outcomes must match their dispatch's decision,
directive, proposal, target, and execution. Evidence from another execution is
rejected. An outcome cannot omit an already allocated execution identity.
Standalone verification may use execution `None`.

Late execution observations may refer to later retained entity revisions while
the outcome keeps its original decision context. Such observations cannot be
used by a proposal whose admitted snapshot has different versions. This is
historical causal validation, not checking freshness against current host state.

The host must still capture after lifecycle bookkeeping under its own mutation
lock and supply authoritative state/policy revisions. Production v1 migration,
global revision tracking, transactional dispatch claims/resource reservations,
exactly-once external effects, outcome-grading deduplication, and evidence
write-back remain separate integration work. The JSON ledger stores identities
and links; it is not the executor's transactional claim ledger. It rewrites the
image per mutation and retains all entries, so large deployments will need a
host storage backend with equivalent guarantees.

## Verification

From `MetaMo/applications/omegaclaw_v1`:

```sh
python3 ../../scripts/run-omegaclaw.py tests/host_identity_test.metta
python3 tests/identity_store_test.py
```

The MeTTa suite uses the real identity store and reusable native-shaped fixtures
in `tests/fixtures/identity_v1.metta`; only its filesystem location is temporary.
It exercises all six publication/consumer schemas, native IDs, proposal/native
chains, blocked attempts, late outcomes, exact contexts, cross-host/wrong-type
references, inconsistent evidence, startup, redelivery and restart. Python tests
cover allocation, immutable storage, concurrent callers, process locking, fresh
process resume, corrupt/missing state, new lineages and storage failure.
