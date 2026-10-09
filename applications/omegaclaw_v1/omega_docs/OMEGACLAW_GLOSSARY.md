# OmegaClaw and MetaMo: a plain-language glossary

This note explains the terminology used in `MetaMo/applications/omegaclaw_v1`
and `repos/OmegaClaw-Core`. It describes the local project as inspected on
September 17, 2026. Some terms describe planned capabilities; those limits are
called out below.

Start with this division of responsibilities: **Core owns the agent's tasks and
execution. MetaMo recommends what deserves attention. Core checks whether the
actual command may run.**

## 1. The main components

| Term | Plain-language meaning |
| --- | --- |
| **OmegaClaw-Core / Core** | The host agent framework. It manages the execution loop, channels, skills, memory, and ContextFrames. “Host” means the software running and coordinating MetaMo. |
| **MetaMo** | The motivation system. It uses observations and internal priorities to recommend the agent's next kind of work. |
| **`omegaclaw_v1`** | The MetaMo application that connects its motivation system to OmegaClaw. The directory name does not mean every live message already uses the v1 contract format. |
| **ContextFrames / `cfv2`** | Core's way of organizing work into frames, with task context, status, history, and relationships. `cfv2` is a code prefix for ContextFrames v2. |
| **Adapter** | Translation code between components. For example, it turns Core's frame state into the bounded input MetaMo understands. |
| **Bridge** | The orchestration code that runs the motivation cycle and puts its recommendation into the LLM prompt. See `bridge.metta`. |
| **Scheduler** | The host role that decides when and where work runs. A recommendation to the scheduler does not itself execute work. |
| **Executor / handler** | The code that actually performs a command, such as reading a file. |
| **LLM** | Large language model. Here it receives context and instructions and produces command expressions. Its output still needs execution checks. |
| **Neural-symbolic** | Combining language-model output with explicit symbolic records, rules, and checks. |
| **OpenPsi and MAGUS** | Motivation and decision approaches used in MetaMo. In this codebase, OpenPsi contributes appraisal/modulation logic and MAGUS contributes hierarchical goal-based decision logic. |

## 2. Language and runtime terms

| Term | Plain-language meaning |
| --- | --- |
| **MeTTa** | The symbolic programming language used for much of the project. Files end in `.metta`. |
| **PeTTa** | The MeTTa implementation used to run this workspace. It is built on Prolog. |
| **SWI-Prolog** | The underlying Prolog runtime. Files ending in `.pl` contain Prolog code. |
| **Janus** | The bridge between SWI-Prolog and Python. The Python loaded by Prolog may differ from the shell's `python3`. |
| **Atom** | A symbolic value or expression. It can be a name, number, or structured expression such as `(status Active)`. |
| **Space** | A collection of atoms that code can query or update. A space is not automatically a security boundary. |
| **State** | A stored value that can change over time, such as the current mode. Names such as `&constitutional-mode` refer to runtime state bindings. |
| **S-expression** | A parenthesized representation of data or code. `(read-file "notes.txt")` is an example. |
| **Ground value** | Data with no unresolved variables. Dispatch registration requires concrete commands and metadata. |
| **Quote / evaluation** | Quoting treats an expression as data; evaluation runs or resolves it. Boundary validators should inspect supplied records as data. |
| **Composition** | Loading the application's modules in the required order. `composition.metta` loads definitions and defaults without starting a channel. |
| **Import once** | Loading a module only once even when several modules reference it. This prevents duplicate definitions and accidental resets of stored state. |
| **Canonical path** | The resolved physical path used to recognize that two import routes point to the same file. |

For v1, the common launcher is `MetaMo/scripts/run-omegaclaw.py`. Its import
handling matters: native PeTTa imports do not generally guarantee one-time loading.

## 3. Frames, snapshots, and ownership

Think of a **frame** as a task folder containing the information needed to work
on one piece of work.

| Term | Plain-language meaning |
| --- | --- |
| **Current frame** | The frame the host is currently working on. |
| **Root state** | Shared ContextFrames information, including the current frame ID and host mode. |
| **Frame status** | The host's recorded condition of a frame, such as active or completed. This is different from how important MetaMo thinks it is. |
| **Frame relation** | A recorded connection between frames, such as `DuplicateOf`, `ContinuationOf`, or `SubgoalOf`. |
| **Snapshot** | A captured view of state at a particular point. It can become outdated after the host changes. |
| **Bounded snapshot** | A snapshot exposing selected information under defined limits, rather than unrestricted access to all host state. Complete deployment limits are still part of host integration work. |
| **Projection** | Converting detailed host state into the smaller representation a consumer needs. It may include summaries. |
| **Slice** | A smaller view selected from an existing bundle, such as minimal frame information or task context. It does not fetch a new snapshot. |
| **State ownership** | Which component is authoritative for a value. Core owns task completion and permissions; MetaMo owns its local motivation values. |
| **Bookkeeping** | Updating host task records from observed results before publishing the next snapshot. |
| **Lifecycle** | The stages work passes through: creation, execution, observation, completion, and possibly recovery. |
| **Commitment** | A host-owned obligation to do work. A motivational preference does not create or complete that obligation by itself. |

The motivation cycle uses one bundle through signals, candidate selection,
scoring, and directives. This avoids mixing observations captured at different
times. Dispatch takes fresh context later to check that execution is still allowed.

## 4. Motivation and decision-making

| Term | Plain-language meaning |
| --- | --- |
| **Goal weight** | How strongly the motivation system values something, such as helping the user or learning. This is distinct from a host task or commitment. |
| **Motive** | A local drive, such as clarity, progress, reliability, adaptivity, coherence, or responsiveness. |
| **Anti-goal** | Something the scoring system tries to avoid. It contributes a penalty; a penalty alone is not an execution prohibition. |
| **Modulator** | A numeric setting that changes how the system responds or chooses, such as urgency or caution. |
| **Signal** | An interpreted observation such as failure, stalled progress, ambiguity, or a waiting user. |
| **Stimulus** | The compact appraisal input: novelty, risk, importance, uncertainty, opportunity, and progress. |
| **Appraisal** | Evaluating what observations mean for motivation. A failure can increase the drive for reliability and caution. |
| **Candidate** | A possible kind of next action. `respond`, `execute-skill`, and `verify-frame-state` are examples. A candidate is less specific than an executable command. |
| **Availability** | Whether a candidate is relevant under the current conditions. Being relevant does not establish permission to execute it. |
| **Pruning** | Removing rejected candidates before comparing scores. `pruneActionsForBundle` returns admitted actions and rejection reasons. |
| **Score** | A numeric preference used to compare eligible candidates. A high score cannot override a rejection. An admitted zero-score candidate is still eligible. |
| **Priority** | A value expressing how much attention recommended work should receive. It does not grant permission. |
| **Directive** | Structured guidance about what to do or inspect next. It is advisory until the host checks and executes concrete work. |
| **Autonomy phase** | Local tracking of background activity, such as recalling goals, proposing a goal, planning, or taking a background step. |
| **Self-model** | Local estimates about the agent's performance and condition. These estimates are not independently verified capability claims. |

The eleven configured modulators can be read as these intuitive controls. Their
actual effects depend on the scoring and update rules; they are not human emotions.

| Modulator | Intuitive meaning |
| --- | --- |
| `urgency` | Pressure to act promptly. |
| `caution` | Preference for checking and avoiding risk. |
| `persistence` | Tendency to continue the current approach. |
| `exploration_bias` | Preference for trying alternatives. |
| `context_depth` | Weight placed on examining context. |
| `human_deference` | Weight placed on human guidance. |
| `arousal` | An activity-related modulation value. |
| `valence` | A positive/negative appraisal-related value. |
| `threshold` | A modulation value associated with caution and readiness. |
| `securing` | Emphasis on stability and protection. |
| `focus` | Emphasis on concentrating activity. |

## 5. “Mode” has three different meanings

| Kind | Values | Meaning |
| --- | --- | --- |
| **Constitutional mode** | `Engaged`, `Threat`, `Rumination`, `Sleep` | MetaMo's broad motivational operating condition. |
| **Host/frame mode** | `Fast`, `Slow` | ContextFrames' distinction between interactive and slower/background work. User messages are assigned to the Fast path. |
| **Decision mode and directive** | Modes such as `orient`, `execute`, `verify`, `recover`; guidance such as `inspect` | How the selected work should be approached. |

In the current constitutional selector, danger or an angry-user signal selects
**Threat**; failures or stalled progress select **Rumination**; no current frame
selects **Sleep** when the earlier triggers do not apply; otherwise it selects
**Engaged**. These are implemented rules, not psychological diagnoses.

**Preemption** means higher-priority work takes precedence when several admitted
candidates compete. The implemented scheduling order is **Threat-remediation >
Recovery > Interactive > Orienting > Engaged > Rumination > Sleep**. Only the
highest admitted class reaches numeric scoring; scores break ties within it.
These scheduling classes are separate from constitutional modes and do not
change Fast/Slow execution modes. See the [scheduling note](MetaMo/applications/omegaclaw_v1/omega_docs/SCHEDULING.md).

## 6. Stability and mathematical terminology

| Term | Practical meaning in this project |
| --- | --- |
| **Vector** | An ordered list of numbers. Goal and modulator vectors store several values together; index definitions identify each position. |
| **Delta / `deltaG`** | A proposed change in goal values. A positive delta raises a value; a negative delta lowers it. |
| **Baseline** | A default or reference value used by the motivation rules. |
| **Decay** | Reducing the influence of a value over time according to an update rule. |
| **Homeostasis** | Rules that help keep internal motivation values in a workable range. |
| **Damping** | Softening changes so internal values do not swing too sharply. |
| **Safe region** | Configured acceptable bounds on motivational state. Being inside it does not prove that a command is authorized or harmless. |
| **Projection to the safe region** | Adjusting a proposed motivational state to satisfy those bounds. This differs from projecting host state into a frame bundle. |
| **Contractive update check** | A check intended to keep state updates from amplifying differences uncontrollably. It is a stability check, not execution authorization. |
| **Pseudo-bimonad** | The code's wrapper combining appraisal, decision-making, and stability functions into a reusable cycle. You can follow the application without learning category theory. |
| **Lax distributive-law check** | A consistency check comparing appraisal/decision orderings within an allowed tolerance. It helps detect incompatible state updates. |
| **Consensus** | Combining preferences from more than one state/context when selecting an action or target state. |
| **Individuation / `gInd_over`** | An overarching motivational axis associated here with maintaining coherence, reliability, and existing functioning. |
| **Transcendence / `gTrans_over`** | An overarching axis associated here with learning, exploration, and adaptation. |

## 7. Contracts and the six shared records

A **boundary contract** specifies the data components exchange and what each
side may assume. A **schema** defines a record's fields and types. A **wire
record** is the agreed exchange representation, even when exchange happens
inside one process rather than over a network.

| Record | In everyday language |
| --- | --- |
| **`FrameStateBundle`** | “Here is the host context you may use to make this recommendation.” |
| **`MetaMoPolicyOutput`** | “Here is the operation MetaMo recommends, its admission result, and its priority.” |
| **`AttentionDirective`** | “Direct attention to this target and this slice of context.” |
| **`ReasonerMotivationalProposal`** | “The reasoning engine suggests this work, supported by this evidence.” |
| **`ExecutionOutcome`** | “Here is what was observed about a particular execution.” |
| **`FrameVerificationEvidence`** | “Here is evidence confirming, refuting, or leaving unresolved a claim about frames.” |

Other contract vocabulary:

- **Envelope / `IntegrationRecord`:** the wrapper containing schema version,
  record ID, producer, context, and payload.
- **Payload:** the actual content inside the envelope.
- **Producer / consumer:** the component creating a record / the component
  reading it. A producer name alone does not authenticate its sender.
- **Validation:** checking shape, types, and local consistency. A valid record
  is not automatically authorized work.
- **Reference:** an identifier pointing to another record or piece of evidence.
  Checking its shape does not prove the referenced item exists.
- **Revision:** a version counter used to detect state changes.
- **Causality:** linking an outcome to the execution and decision that caused it.
- **Legacy v0:** the older unversioned runtime records. They do not become v1
  just because they are used inside the `omegaclaw_v1` directory.

**Current limit:** v1 construction and validation APIs exist, but the live loop
still uses legacy records. Full host migration, durable identity management, and
reference enforcement remain integration work.

## 8. Policy and admission

| Term | Plain-language meaning |
| --- | --- |
| **Policy** | Rules restricting what work may run. Distinguish host authorization policy from MetaMo's advisory policy output. |
| **Typed policy** | Policy represented by explicit structured fields, rather than free-form text. |
| **Scope / `PolicyScope`** | The area a policy applies to: globally or to a particular frame. Both applicable scopes must allow the operation. |
| **`PolicyOperation`** | Trusted metadata describing the concrete operation: candidate, target, skill, permissions, destinations, and costs. |
| **`AdmissionRequest`** | The requested kind of work and its target, such as proposing a candidate or requesting a frame switch. |
| **Permission** | An explicit capability required by the operation, such as `files.read`. |
| **Allowlist** | The explicit set of skills, permissions, or destinations allowed by a scope. An empty list grants none of those entries. |
| **Egress** | Data going out to a destination, such as an external service. The policy checks declared destinations. |
| **Constraint** | An additional restriction, such as denying a skill or limiting cost. |
| **Feasibility gate / admission gate** | The check returning an admitted or rejected decision. Preliminary frame/mode checks are narrower than the concrete typed operation checks. |
| **Fail closed** | Missing, invalid, or unsupported authorization information results in rejection. |
| **Trusted host metadata** | Operation details derived by host code from the actual handler and arguments. Model claims about permissions or costs are not sufficient. |
| **No-action** | An explicit result that starts no command, rather than falling back to unchecked execution. |

For example, an `execute-skill` candidate might score highly. A concrete file
read still requires host metadata and applicable permission. If either global
or frame policy rejects it, that score cannot make it executable.

## 9. Dispatch and execution outcomes

| Term | Plain-language meaning |
| --- | --- |
| **Dispatch** | The host's final process for checking and invoking a concrete command. |
| **Command binding** | A trusted registration connecting an exact command to its request and operation metadata. |
| **Ticket** | An opaque handle linking a dispatch attempt to captured intent, context, and session revision. Possessing it does not bypass the final check. |
| **Revalidation** | Checking again immediately before invocation because conditions may have changed since recommendation. |
| **Stale snapshot** | A captured context that no longer matches current state or revision. A new decision is required. |
| **Revocation** | Removing a previously registered command binding or authority. Outstanding work may then be blocked. |
| **Mutex / serialized execution** | A lock that prevents participating operations from changing relevant state between the final checks and invocation. External writers must use the same mutation API. |
| **Invocation claim** | Recording that a ticket has begun its one allowed invocation. |
| **Replay** | Receiving the same ticket/command again. Identical redelivery returns the recorded result; a different command on that ticket is a conflicting replay. |
| **Idempotency** | Repeating a request without repeating its effects. The current ticket replay handling provides a session-level form of this protection. |
| **`Blocked`** | Dispatch rejected the command before invoking its handler. |
| **`Executed`** | The handler returned. This does not by itself prove the user's task was completed successfully. |
| **`Unobserved` / `ExecutionUncertain`** | Invocation began but failed or threw, so effects may have occurred. Automatic retry could repeat those effects. |
| **Session-only** | Guarantees apply within the running session; they do not establish recovery across a crash or restart. |

**Current limit:** v1 dispatch requires explicit host policies and command
bindings. Its live adapter supports same-frame candidate work; cross-frame and
mode-transition execution remain unsupported on that path. One ticket permits
at most one invocation, including when the model produces a batch of commands.

## 10. Resource budgets

| Term | Plain-language meaning |
| --- | --- |
| **Resource / unit** | What is being counted and how it is measured, such as commands in units or spending in microcredits. Units must match. |
| **Limit** | The total amount permitted for an account. |
| **Spent** | The amount already consumed. |
| **Reserved** | Capacity held for work that has not yet been fully accounted for. |
| **Available** | What remains usable: `limit − spent − reserved`. |
| **Prospective cost** | A conservative estimate or enforceable upper bound for work before execution. |
| **Reservation ledger** | Host records tracking which execution holds which capacity. |
| **Atomic reservation** | Reserving all required accounts together, or none, so partially accepted work cannot overspend. |
| **Settlement** | Replacing a reservation with measured usage and releasing unused capacity. |
| **Reconciliation** | Resolving uncertain usage or unfinished work after failure or restart. |
| **Durable** | Recorded in a way that survives process termination and supports recovery. |

Example: a limit of 10, spent amount of 3, and reservation of 2 leave **5
available**. A proposed cost of 6 must be rejected. An uncertain outcome is not
evidence that the reserved amount can be refunded.

**Current limit:** numeric admission and the accounting projection are
implemented. Live reservations, settlement, and a durable ledger remain host work.

## 11. Reasoning and evidence

| Term | Plain-language meaning |
| --- | --- |
| **Reasoner** | A component that applies rules to supplied facts to derive conclusions. |
| **NARS / PLN** | The two inference engines used by the adapter, loaded from PeTTa's `lib_nars` and `lib_pln`. They are distinct from Core's separate rule libraries. |
| **Premise / inference / conclusion** | Input fact / rule-based derivation / resulting claim. Asking for a conclusion does not supply its missing premises. |
| **Truth value / `stv`** | A structured representation of support and confidence used by the engines. |
| **Confidence** | The engine's measure attached to its conclusion. It is not a calibrated probability that the action will succeed. |
| **Evidence stamp** | A stable label recording which evidence contributed to a conclusion. |
| **Provenance** | Information about where a claim came from and what supports it. |
| **Source reliability** | A tracked assessment of a source based on feedback. It does not grant execution authority. |
| **Verification** | Checking a claim against evidence. A request to verify is not already a verified result. |

**Current limit:** offline inference and proposal admission are tested. Automatic
fact extraction, live proposal collection, and outcome feedback still need host
integration.

## 12. Testing and project-status terms

| Term | Plain-language meaning |
| --- | --- |
| **Fixture** | Controlled sample data or setup used by tests. |
| **Assertion** | A test condition that must hold. |
| **Source guard** | A test inspecting source text for a required or prohibited pattern. It can become stale when code is refactored. |
| **Regression test** | A check intended to prevent a previously fixed problem from returning. |
| **Offline test** | A test that runs without live channels or external services. Passing it does not establish live readiness. |
| **Vertical slice / minimal loop** | A small example crossing several layers end to end. The current demo uses a deterministic candidate and fixed score while exercising the real bundle feasibility gate. |
| **CI parity** | Automated continuous-integration checks using the same relevant source versions and dependency layout as local checks. |
| **Persistence** | Saving state for later restoration. Saving motivation is separate from restoring authoritative host tasks or execution claims. |
| **Uncommitted / untracked** | Local changes not yet recorded in a Git commit / files not yet included in Git tracking. A fresh checkout may lack them. |

## 13. One example connecting the vocabulary

Suppose the user asks the agent to inspect a file.

1. **Core** records the task in a **frame** and publishes a **snapshot**.
2. The **adapter** projects it into a **FrameStateBundle**.
3. MetaMo extracts **signals**, performs **appraisal**, and updates its
   **modulators** and **constitutional mode**.
4. Candidate generation and **pruning** determine which kinds of work remain
   eligible. **Scoring** chooses among those candidates.
5. The **bridge** includes the recommendation in the LLM prompt. The model may
   propose a concrete `(read-file "notes.txt")` command.
6. **Dispatch** resolves its trusted **command binding**, checks fresh context,
   and reruns **admission** using the actual operation's policy metadata.
7. If permitted, the **handler** runs. Its result becomes input to later host
   bookkeeping and motivation cycles.

This describes the intended flow and the implemented session dispatch boundary.
Useful live execution still requires host configuration; v1 outcome wiring and
durable resource accounting are not completed by this example.

## Source references

- [Application overview](MetaMo/applications/omegaclaw_v1/omega_docs/README.md)
- [Motivation registry](MetaMo/applications/omegaclaw_v1/registry.metta)
- [Constitutional mode rules](MetaMo/applications/omegaclaw_v1/mode_layer.metta)
- [Motivation cycle and prompt bridge](MetaMo/applications/omegaclaw_v1/bridge.metta)
- [Shared contracts and state ownership](MetaMo/applications/omegaclaw_v1/omega_docs/CONTRACTS.md)
- [Typed policy and request admission](MetaMo/applications/omegaclaw_v1/omega_docs/TYPED_POLICY.md)
- [Budget accounting contract](MetaMo/applications/omegaclaw_v1/omega_docs/BUDGET_ACCOUNTING.md)
- [Session dispatch and its limits](MetaMo/applications/omegaclaw_v1/omega_docs/DISPATCH.md)
- [Module composition and imports](MetaMo/applications/omegaclaw_v1/omega_docs/COMPOSITION.md)
- [Pseudo-bimonad implementation](MetaMo/category/bimonad.metta)
- [Core frame implementation](repos/OmegaClaw-Core/src/context.metta)
