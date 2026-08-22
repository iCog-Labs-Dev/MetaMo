# Qwestor: A Use Case Implementation on the MetaMo System

**A worked-example guide — architecture, data flow, and how to build on it.**

---

## 1. What Qwestor Is

Qwestor is an autonomous AI research assistant. Rather than operating via fixed instructions, Qwestor maintains a dynamic internal state consisting of goal intensities and modulator parameters that together determine action selection in any given context. Within this usecase it's built **on top of** the MetaMo cognitive framework. MetaMo itself is unified formal framework for AGI motivational systems,  taking a *motivational state* , a *stimulus* , a *set of candidate actions*, and returning a *validated, safety-checked next state* plus a *chosen action*. MetaMo does not know anything about "conversations," "queries," or "verification." Qwestor is the layer that teaches MetaMo how to behave like a conversational reasoning agent by feeding it the right inputs and interpreting its outputs.

Concretely, Qwestor is responsible for:

- Turning a raw user query into structured signals (context parsing).
- Maintaining its own richer internal state (14 goals, 13 modulators, 4 anti-goals) across a session.
- Projecting that richer state down into MetaMo's 8-goal and 6-modulator motivation format.
- Converting context signals into MetaMo's 4-value stimulus format (novelty, conduciveness, risk, effort).
- Filtering which of its 7 possible cognitive actions are even worth considering, given the query.
- Handing all of this to MetaMo, letting MetaMo run its appraisal → decision → safety-check cycle, and reading back the result.
- Persisting the updated state so the next turn in the session starts from where the last one left off.
- Asking an LLM to write the final natural-language answer, conditioned on the action MetaMo selected.


---

## 2. Three-Layer Architecture

```
                 USER
                   │
                   ▼
        ┌─────────────────────────┐
        │   Qwestor App Layer     │   (usecase folder)
        │  - parse query          │
        │  - build context        │
        │  - select candidates    │
        │  - project state        │
        └─────────────────────────┘
                   │
                   ▼
        ┌─────────────────────────┐
        │  MetaMo Integration     │   (runMetaMoCycleDefault)
        │  Layer                  │
        └─────────────────────────┘
                   │
                   ▼
        ┌─────────────────────────┐
        │  OpenPSI Appraisal      │   (updates motivational state)
        └─────────────────────────┘
                   │
                   ▼
        ┌─────────────────────────┐
        │  MAGUS Decision         │   (scores and selects an action)
        └─────────────────────────┘
                   │
                   ▼
          Stability and Safety Checks
                   │
                   ▼
           Updated Motivation State
                   │
                   ▼
            LLM Final Response
```

Two rules hold throughout the system and are worth internalizing:

1. **OpenPSI** : It only reshapes the motivational state (specifically the modulators) in reaction to the stimulus.
2. **MAGUS** : It only scores the candidate actions against whatever motivational state OpenPSI just produced.

Qwestor's whole job is to be a well-behaved *client* of this contract: it prepares state and stimulus, it prepares a shortlist of candidates, and it reads back exactly one action plus one updated state.

---

## 3. File-by-File Reference

```
usecase/
├─ adapters/
│  ├─ tests/
│  │  ├─ qwestor_actions_test.metta
│  │  ├─ state_bridge_test.metta
│  │  └─ stimulus_adapter_test.metta
│  ├─ qwestor_actions.metta      → the 7 cognitive actions, candidate filtering
│  ├─ state_bridge.metta         → Qwestor state  ⇄  MetaMo motivation state
│  └─ stimulus_adapter.metta     → 14-signal context  →  4-value MetaMo stimulus
├─ eval/
│  ├─ raw_runs.json              → raw evaluated turns collected during session tests
│  └─ evaluation_results.json    → global, per-session, and per-action metrics
├─ logs/
│  └─ <session_id>.json          → append-only conversational turn logs
├─ metrics/
│  └─ qwestor_eval.py            → logs every turn and scores it against expectations
├─ plots/
│  ├─ overall_action_analysis.png → five overall and per-action evaluation plots
│  └─ per_session_analysis.png    → four session-level evaluation plots
├─ sessions/
│  └─ <session_id>.json          → persisted goals, modulators, and anti-goals
├─ tests/
│  ├─ session_helpers_test.metta
│  ├─ session_short.py           → canned test sessions (queries, expected actions)
│  └─ utils_tests.metta
├─ README.md
├─ Qwestor–MetaMo Integration Documentation.md
│                                  → architecture, workflow, and extension guide
├─ config.metta                  → default goals, modulators, anti-goals, alpha rates
├─ context_parser.py              → LLM-based query → structured-context parser
├─ main-loop.metta                → runQwestor / qwestorLoop / qwestorLoopFromList
├─ plot_evaluation_results.py     → generates  plots in two composite files
├─ session_helpers.metta          → session persistence glue (metta-side)
├─ session_store.py               → session persistence glue (python-side, JSON files)
├─ anti_goal_helpers.metta        → anti-goal lookup and action exposure helpers
└─ utils.metta                    → generic helpers (clamping, key lookup, accessors)
```

### 3.1 `config.metta`
Defines everything the system starts with when there is no prior session:

- **`alpha`** — learning rates and thresholds used elsewhere in MetaMo (e.g. `goal_alpha 0.18`, `decompose_min_complexity 0.60`, `intent_margin 0.12`). These tune *how fast* the state moves and *where the boundaries* between actions sit.
- **`default-mods`** — the 13 Qwestor modulators (`m_urgency`, `m_resolution`, `m_user_expertise`, `m_threshold`, `m_topic_familiarity`, `m_failure_wariness`, `m_securing`, `m_approach`, `m_arousal`, `m_risk_aversion`, `m_error_tolerance`, `m_creativity`, `m_valence`).
- **`default-goals`** — the 14 Qwestor goals (`efficiency`, `accuracy`, `success_moderate`, `knowledge`, `novelty`, `success_breakthrough`, `coherence`, `originality`, `social`, `help_short`, `help_long`, `over_beneficial`, `over_safety`, `over_honesty`).
- **`default-anti-goals`** — 4 values (`hallucinate`, `redundant`, `rabbit_hole`, `premature`) that penalize risky actions dynamically (see 3.2).

### 3.2 `adapters/qwestor_actions.metta`
Declares Qwestor's **7 cognitive actions**, each as a MetaMo `(action $id $goalCorrelations $riskEstimate $deltaG)` atom:

| Action | Purpose |
|---|---|
| `act_respond` | Generate a response to the user’s query |
| `act_search` | Search external sources, gather informa-
tion |
| `act_verify` | Cross-check claims before asserting|
| `act_clarify` | Request more information before proceed-
ing |
| `act_decompose` | Break complex query into sub-tasks |
| `act_think` | Explore related questions, build context |
| `act_synthesize` | Combine multiple sources into coherent
answer |

Each action also has an **anti-goal exposure vector** `(hallucinate redundant rabbit_hole premature)`. The *risk estimate* embedded in an action is not fixed, rather it's dynamically bumped by:

```
adjusted_risk = base_risk + 0.25 × (current_anti_goal_vector · action_exposure_vector)
```

Example:- if the running "hallucinate" anti-goal is currently high, `act_respond` (which is exposed to hallucination risk) automatically becomes riskier *before* MAGUS ever scores it.

**Candidate filtering by context** — `qwestorCandidatesForContext`. Rather than handing MAGUS all 7 actions every turn, Qwestor pre-filters to a relevant shortlist using a priority cascade:

```
if verify_request OR threshold > 0.75 OR failure_signal > 0.65 → verify-family
else if ambiguity > 0.65                                       → clarify-family
else if needs_task_plan > 0.65                                 → decompose-family
else if needs_external_evidence > 0.65                         → search-family
else if needs_multi_source_integration > 0.65                  → synthesize-family
else if reflective_intent > 0.65 OR complexity > 0.65          → think-family
else                                                            → default (respond, verify)
```

Each "family" is a short list, e.g. `qwestorVerifyCandidates = (act_verify, act_search, act_clarify, act_respond)`. This is why MAGUS never even sees `act_decompose` or `act_think` when the query is clearly a verification request — they were removed *before* the MetaMo cycle runs. MAGUS doesn't sees those actions, allowing it to focus only on context-appropriate candidates. As a result, context filtering drastically narrows the decision space, reducing unnecessary comparisons and making action selection more efficient and targeted.

### 3.3 `adapters/state_bridge.metta`
Converts between Qwestor's 14-goal and 13-modulator internal state into MetaMo's 8-goaland 6-modulator `(motivation goals modulators)` atom, in both directions:

- **`projectToMotivation`** (Qwestor → MetaMo), using averages/means as documented in 4.2 below.
- **`injectMotivation`** (MetaMo → Qwestor), the inverse it writes MetaMo's updated goals/modulators back into Qwestor's larger state, while preserving the Qwestor-only fields.
- **`motivationSummary`** — turns a motivation atom into a human-readable pair-list for logging.

This round-trip (`projectToMotivation` → MetaMo cycle → `injectMotivation`) gives Qwestor **motivational continuity across turns**: the state a session ends turn N in is the state it starts turn N+1 from.

### 3.4 `adapters/stimulus_adapter.metta`
Converts the 14-signal context list from `context_parser.py` into MetaMo's 4-value `(stimulus novelty conduciveness risk effort)` atom. Exact formulas are in 4.3.

### 3.5 `context_parser.py`
Calls an LLM (Gemini) with a fixed system prompt/schema and asks it to classify the raw user query into 14 numeric/boolean/categorical signals:

`urgent, complexity, ambiguity, expertise, threshold, topic_familiarity, failure_signal, intent_type, reflective_intent, verify_request, needs_external_evidence, needs_task_plan, needs_multi_source_integration, valence`

Key features:
- Clamps every numeric field to `[0,1]` (or `[-1,1]` for `valence`) so a malformed LLM output can't break downstream math.
- Retries up to 3 times with a 10s backoff (`wrap_parser`), and falls back to the static `context` defaults, if all attempts fail — the pipeline never crashes on a parser outage, it just runs with a neutral context.

### 3.6 `main-loop.metta`
The orchestrator. Its centerpiece is `runQwestor`, an 11-step pipeline (detailed in 4 with a live example). It also provides:

- **`qwestorLoop`** — an interactive REPL: keeps calling `runQwestor` on new user input until `quit`/`exit`, then persists the session.
- **`qwestorLoopFromList`** — replays a fixed list of queries (used for the canned test sessions in `tests/session_short.py`).
- **`saveCurrentSession`** — extracts the current goals/mods/anti-goals from the space and hands them to `session_store.save_session`.

### 3.7 `session_store.py` / `session_helpers.metta`
Simple JSON-file-backed persistence:

- `sessions/<session_id>.json` — the last saved `{goals, mods, anti_goals}` for that session.
- `logs/<session_id>.json` — an append-only turn log of `{timestamp, query, action, answer}`.

`has_session` gates whether `main-loop.metta` boots from a saved state or from `config.metta`'s defaults. `load_test_session` also lets pull a canned query list straight out of `tests/session_short.py` by name, for repeatable smoke-testing.

### 3.8 `metrics/qwestor_eval.py`
Independent of the MeTTa runtime — every completed turn is logged here via `record_turn`, which:

1. Normalizes the raw MAGUS candidate scores (parses `(action-score act_x 0.87)`-style atoms or plain text) into a clean `{"action": ..., "score": ...}` list.
2. Writes the raw turn to `eval/raw_runs.json`.
3. Re-derives, for every turn, whether the *expected* action for that exact query (from `tests/session_short.py`) matches what was actually chosen (`strict_correct`), and whether it at least falls in the *acceptable* fallback set (`soft_score`).
4. Aggregates per-session and global metrics into `eval/evaluation_results.json`: strict accuracy, soft accuracy, top-3 hit rate, average decision margin between the top two candidates, and a full confusion matrix (expected action × predicted action).


### 3.9 `plot_evaluation_results.py`
Reads `eval/evaluation_results.json` and generates dynamic evaluation charts. It groups the related charts into two composite files under `plots/`:

- `plots/per_session_analysis.png` — strict accuracy by session, strict/soft/top-3 metrics by session, decision margins, and correct-versus-incorrect turn counts.
- `plots/overall_action_analysis.png` — overall metrics, strict/soft accuracy, expected-versus-predicted action counts, per-action recall, and the confusion matrix.

Every score, count, session, and action shown in the charts is extracted from the current evaluation-results file, so rerunning the session tests and plotting script refreshes both.

### 3.10 `utils.metta`
Shared low-level helpers used everywhere above: `clampToUnitInterval`, `findByKey` (association-list lookup), `getMod`/`getGoalQwestor`/`getAntiGoal` (typed accessors into the Qwestor space triple), and small list utilities (`addItems`, `decons`-style recursion helpers).

---

## 4. The Pipeline

`runQwestor(&space, query)` performs the following 11 steps every turn:

| Step | What happens | Owner |
|---|---|---|
| 1 | Parse the raw query into a 14-signal context list | `context_parser.py` |
| 2 | Project the Qwestor space into a MetaMo motivation state | `state_bridge.metta` |
| 3 | Convert the context list into a 4-value MetaMo stimulus | `stimulus_adapter.metta` |
| 4 | Wrap the motivation state into per-subsystem states (`qwestor`, `ethics`) | `main-loop.metta` |
| 5 | Filter down to a relevant candidate-action shortlist | `qwestor_actions.metta` |
| 6 | Run the full MetaMo cycle (appraisal → decision → safety) | MetaMo core |
| 7 | Extract the selected action | `main-loop.metta` |
| 8–9 | Extract and unpack the next motivation state | `main-loop.metta` |
| 9b | Inject the new motivation back into the Qwestor space | `state_bridge.metta` |
| — | Generate the final natural-language answer, conditioned on the chosen action and the updated goal state | LLM |
| 10 | Re-score all candidates against the same decision context, for logging/metrics only (no new decision is made here) | `qwestor_eval.py` |
| 11 | Package `(selected, candidates, next-motivation, stimulus)` and persist the turn | `main-loop.metta` |

### 4.1 Step 1 — Context parsing
The Python parser turns free text into structured signals. 

### 4.2 Step 2 — Qwestor → MetaMo goal/modulator projection

Goals (`C(x) = clamp(x, 0, 1)`):

```
gInd   = C(over_safety)
gTrans = C(success_breakthrough)
gHelp  = C((help_short + help_long + over_beneficial) / 3)
gCurio = C((knowledge + coherence) / 2)
gNovel = C((novelty + originality) / 2)
gSelf  = C((efficiency + accuracy + success_moderate) / 3)
gEthic = C(over_honesty)
gSoc   = C(social)
```

Modulators:

```
valence    = C((m_valence + 1) / 2)                          ; [-1,1] → [0,1]
arousal    = C((m_arousal + m_urgency) / 2)
approach   = C((m_approach + m_creativity) / 2)
resolution = C((m_resolution + m_topic_familiarity + m_user_expertise) / 3)
threshold  = C((m_threshold + m_error_tolerance) / 2)
securing   = C((m_securing + m_failure_wariness + m_risk_aversion) / 3)
```

### 4.3 Step 3 — Context → stimulus

```
ev_boost        = 0.30 if needs_external_evidence > 0.7 else 0.0
novelty         = C(0.30×(1 - topic_familiarity) + 0.25×complexity + 0.15×reflective_intent + ev_boost)

val_norm        = C((valence + 1) / 2)
vr_penalty      = 0.40 if verify_request else 0.0
amb_penalty     = 0.30 if ambiguity > 0.7 else 0.0
conduciveness   = C(0.40×topic_familiarity + 0.20×(1-ambiguity) + 0.20×val_norm - 0.20×failure_signal - vr_penalty - amb_penalty)

vr_boost        = 0.60 if verify_request else 0.0
amb_risk_boost  = 0.30 if ambiguity > 0.7 else 0.0
risk            = C(0.30×threshold + 0.20×failure_signal + 0.10×(1-topic_familiarity) + vr_boost + amb_risk_boost)

task_boost      = 0.50 if needs_task_plan > 0.8 else 0.0
ms_boost        = 0.40 if needs_multi_source_integration > 0.8 else 0.0
effort          = C(0.20×complexity + 0.10×ambiguity + task_boost + ms_boost)
```

### 4.4 Step 5 — Candidate filtering
See 3.2. Serves as deterministic gate, it happens *before* MetaMo runs, so MAGUS is scoring a short, relevant list, not all 7 actions every time.

### 4.5 Step 6 — Inside the MetaMo cycle
1. **Merge subsystem states** — if only one subsystem is active , the merged state is just that subsystem's state; with more than one it uses a weighted `parallelMerge`.
2. **OpenPSI appraisal** updates the *modulators only* — `decisionState = raiseBoundaryCaution(openPsiAppraise(state, stimulus))`. Goals are untouched at this point.
3. **MAGUS decision** scores every remaining candidate:
   `score = baseScore − riskPenalty − conflictPenalty + growthReward`, where `baseScore` sums `goal_weight × relevant_modulator × correlation` across the goal vector, `riskPenalty = λ × gInd × caution × actionRisk`, and `growthReward` favors exploratory actions when `gTrans`/`arousal`/`approach` are high. MAGUS then applies the winning action's `deltaG` to the goals.
4. **Safety/stability checks** — lax distributive law (appraise-then-decide ≈ decide-then-appraise), contractivity (small input change ⇒ small output change), and safe-region (`gInd` above a safety floor, goal norm bounded). If any check fails, a conservative fallback averages old and proposed state instead of accepting the raw jump.

### 4.6 Steps 7–9 — Extract, unpack, and write back
The chosen action and the validated next motivation state are pulled out of the cycle result, and `injectMotivation` writes the updated goals/modulators back into the Qwestor space — this gives the agent memory of "where its motivation was" across turns.

### 4.7 Final response generation
`llmGenerateFinalResponse(query, action, gInd, gTrans)` — the LLM is **not** choosing a strategy; it is only asked to *express* the strategy MetaMo already picked, conditioned on the resulting goal emphasis.

### 4.8 Step 10 — Re-scoring for evaluation only
`qwestorCandidateScores` re-runs `scoreCandidate` for every candidate against the *same* decision context MAGUS already used. This produces a full ranked list purely for logging and metrics (`qwestor_eval.py`).

---

## 5. Worked Example: One Full Turn

**Query:** `"Can I rely on this exact statistic without checking sources?"`
**Session:** Starting from `config.metta` defaults since no prior session file exists

### Step 1 — Parsed context
```json
{
  "urgent": 0.8, "complexity": 0.2, "ambiguity": 0.1, "expertise": 0.5,
  "threshold": 0.9, "topic_familiarity": 0.9, "failure_signal": 0.0,
  "intent_type": "factual", "reflective_intent": 0.8, "verify_request": true,
  "needs_external_evidence": 0.9, "needs_task_plan": 0.0,
  "needs_multi_source_integration": 0.5, "valence": 0.0
}
```
This is a familiar, low-ambiguity, low-complexity question — but `threshold` and `verify_request` are both flagged high. The parser is effectively saying: *the user wants certainty, not exploration.*

### Step 2 — Current motivation (projected from defaults)
```
Goals:      gInd 0.65  gTrans 0.44  gHelp 0.533  gCurio 0.55  gNovel 0.47  gSelf 0.64  gEthic 0.65  gSoc 0.58
Modulators: valence 0.50  arousal 0.30  approach 0.425  resolution 0.466  threshold 0.375  securing 0.20
```

### Step 3 — Stimulus
```
novelty = 0.50   conduciveness = 0.64   risk = 0.28   effort = 0.05
```
Because the question is familiar and simple but verification-oriented: risk comes out moderately elevated (driven by `verify_request` and `threshold`), while effort is very low (nothing here needs a plan or multi-source synthesis) and novelty is only moderate.

### Step 5 — Candidate filtering
`verify_request = true` routes this straight into the **verify family**: `(act_verify, act_search, act_clarify, act_respond)`. `act_think`, `act_decompose`, and `act_synthesize` are excluded before MAGUS ever runs, simplifying the search space.

### Step 6 — MAGUS scores 
```
act_verify    0.726
act_search    0.879
act_clarify   0.922   ← selected
act_respond   0.888
```

### Steps 7–9 — Action selected, state updated and written back
```
selected action: act_clarify

next goals:      gInd 0.6505  gTrans 0.44  gHelp 0.5343  gCurio 0.5497
                  gNovel 0.4695  gSelf 0.6405  gEthic 0.6508  gSoc 0.5815
next modulators: valence 0.5085  arousal 0.3128  approach 0.4308
                  resolution 0.4758  threshold 0.3817  securing 0.2047
```
All safety and stability checks passed, so the raw proposed state was accepted as it is, no conservative fallback was needed.

### Final LLM answer
Conditioned on `act_clarify` and the updated `gInd`/`gEthic` emphasis, the LLM produced:

> *It is generally not advisable to rely on any statistic without verifying its original source... trace the origin, check the methodology, cross-reference against other credible sources...*
 

### Step 11 — Logging
This whole turn (query, selected action, answer, all four candidate scores, the parsed context, and the stimulus) is written to `metrics/qwestor_eval.py`'s `record_turn`, which appends it to `eval/raw_runs.json` and recomputes `eval/evaluation_results.json` (strict/soft accuracy, top-3 hit rate, decision margin, confusion matrix) across every turn logged so far. Session state (goals/mods/anti-goals) is persisted via `session_store.save_session` when the session ends.

---

## 6. Guidelines for Building on This System

### 6.1 Running it
- **Single-turn debug run:** uncomment the last line of `main-loop.metta` — `!(runQwestor &space "your query")` — and run the file. This is the fastest way to see one full pipeline pass.
- **Interactive session:** call `(qwestorLoop &space "opening query")`. State persists in-memory across turns and is saved to `sessions/<id>.json` on `quit`/`exit`.
- **Replay a canned session:** call `(qwestorLoopFromList &space (sessionQueries))`, where `(sessionId)` in `main-loop.metta` names one of the sessions defined in `tests/session_short.py`.

### 6.2 Adding a new session ID
Set `(= (sessionId) "your_new_id")` in `main-loop.metta`. On first run there will be no file under `sessions/your_new_id.json`, so `main-loop.metta` will fall back to `(default-goals) (default-mods) (default-anti-goals)` from `config.metta`. Every subsequent run from that point resumes from whatever was last saved.

### 6.3 Adding a new cognitive action
1. Add a `(QwestorAction act_yourname (action act_yourname (goalCorrelations) riskEstimate (deltaG)))` block to `qwestor_actions.metta`, following the 8-slot goal-correlation ordering in 4.2 (`gInd gTrans gHelp gCurio gNovel gSelf gEthic gSoc`).
2. Add a matching `(QwestorAntiGoalExposure act_yourname (hallucinate redundant rabbit_hole premature))` line.
3. Add it to `qwestorCandidates` and to whichever context-family list(s) in 3.2 it should be considered under.
4. Add test queries and expected action to `tests/session_short.py` so `qwestor_eval.py` can immediately tell you whether your new action is winning or losing against the existing ones in the situations you intended it for.

### 6.4 Tuning candidate-selection thresholds
All the numbers that decide which family of actions gets considered (`ambiguity > 0.65`, `threshold > 0.75`, etc. in 3.2, and the stimulus boost thresholds in 4.3) are meant to be tuned, not treated as fixed constants.  

### 6.5 Evaluating changes
After any change to actions, thresholds, or projection formulas:
1. Run `qwestorLoopFromList` across every session in `tests/session_short.py` .
2. Confirm that the completed session tests produced or refreshed `eval/evaluation_results.json`.
3. From the `usecase/` directory, generate the visual evaluation report:

   ```bash
   python plot_evaluation_results.py
   ```

   This creates or refreshes the `plots/` directory containing `per_session_analysis.png` and `overall_action_analysis.png`.
4. Inspect both the generated plots and `eval/evaluation_results.json` — check `strict_accuracy`, `soft_accuracy`, and especially the `confusion_matrix` for the specific action you changed. 
5. Only then consider the change validated — a single hand-checked example is useful for understanding *why* a decision was made, but the aggregate metrics are what tells whether it's actually an improvement.

### 6.6 Extending to multiple subsystems
`main-loop.metta` already wraps the motivation state into two named subsystems (`qwestor`, `ethics`) even though they share one state in this implementation. If you want a second subsystem with genuinely different goals/modulators (e.g. a separate "safety reviewer" persona), give it its own `(subsystemState name motivation)` entry in the `$states` list passed into `runMetaMoCycleDefault` — the merge/step logic in MetaMo already supports more than one subsystem via `parallelMerge`.

### 6.7 Things not to change casually
- **`state_bridge.metta`'s projection formulas** are a compression and adapter layer (14→8 goals, 13→6 modulators). Changing them changes what every downstream action "sees" of the Qwestor state, so any change here should be re-validated against the full test-session suite.

---

## 7. Quick Reference: Goal and Modulator Index Maps

**MetaMo goal vector (8):** `0 gInd · 1 gTrans · 2 gHelp · 3 gCurio · 4 gNovel · 5 gSelf · 6 gEthic · 7 gSoc`

**MetaMo modulator vector (6):** `0 valence · 1 arousal · 2 approach · 3 resolution · 4 threshold · 5 securing`

**Qwestor goal vector (14):** `efficiency · accuracy · success_moderate · knowledge · novelty · success_breakthrough · coherence · originality · social · help_short · help_long · over_beneficial · over_safety · over_honesty`

**Qwestor modulator vector (13):** `m_urgency · m_resolution · m_user_expertise · m_threshold · m_topic_familiarity · m_failure_wariness · m_securing · m_approach · m_arousal · m_risk_aversion · m_error_tolerance · m_creativity · m_valence`

**Qwestor anti-goal vector (4):** `hallucinate · redundant · rabbit_hole · premature`
