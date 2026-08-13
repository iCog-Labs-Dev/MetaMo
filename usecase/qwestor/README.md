# Qwestor Implementation Using Our System

Qwestor is a MetaMo-based motivational architecture for autonomous research
assistance. It uses the pluggable MetaMo runtime while keeping Qwestor's own
goals, modulators, actions, appraisal rules, and goal dynamics.

The implementation is self-contained in `usecase/qwestor`. 

## What Qwestor does

For each research request, Qwestor:

1. extracts a grounded context from the user query and conversation history;
2. converts the context into stimulus features;
3. appraises the features and updates its modulators;
4. builds and scores suitable research actions;
5. applies Qwestor's goal-change and stability rules;
6. executes the selected action through the Python LLM adapter;
7. assesses the result and stores it as feedback for the next turn; and
8. commits the new motivational state once.

Qwestor can select the following actions:

```text
act_clarify    ask for essential missing information
act_search     retrieve external or current information
act_think      perform bounded analysis or hypothesis work
act_respond    answer the request directly
act_decompose  construct an ordered research plan
act_verify     check a claim and report uncertainty
act_synthesize integrate methods, evidence, or viewpoints
act_wait       wait for information that is expected later
```

## Motivational state

Qwestor uses MetaMo's two structural overgoals:

```text
individuation, transcendence
```

Its application goals are used directly rather than mapped to substitute
MetaMo goals:

```text
beneficial, honesty, safety,
help_short, help_long, knowledge, novelty, originality,
success_moderate, success_breakthrough, coherence, social,
efficiency, accuracy
```

Its anti-goals are:

```text
hallucinate, redundant, rabbit_hole, premature
```

The core and application-specific modulators are:

```text
valence, arousal, approach, resolution, threshold, securing,
urgency, risk_aversion, error_tolerance, failure_wariness,
user_expertise, topic_familiarity, creativity
```

All stored goal and modulator values are bounded to `[0, 1]`.

## Architecture

```text
User query
  -> Python perception adapter
  -> grounded Qwestor context
  -> stimulus and appraisal
  -> contextual action candidates
  -> MAGUS decision
  -> goal change and stability projection
  -> coherence blend
  -> selected effect
  -> LLM response and outcome assessment
  -> committed Qwestor state
```

MeTTa owns the motivational state, appraisal, candidate construction, decision,
stability, and commit process. Python owns provider communication, prompt
construction, context parsing, persistence, and host-facing integration.

The `ApplicationBundle` in `bundle.metta` is the composition root. It connects
Qwestor's schema and policies to the generic MetaMo engine without placing
Qwestor-specific behavior in the core runtime.

## Main files

- `schema.metta` defines the goals, anti-goals, and modulators.
- `config.metta` contains Qwestor configuration values.
- `state.metta` creates and validates the canonical state.
- `stimulus.metta` converts perception into decision features.
- `appraisal_profile.metta` defines modulator appraisal behavior.
- `actions.metta` registers actions and their base goal correlations.
- `planning.metta` builds context-sensitive action candidates.
- `decision_profile.metta` configures MAGUS decision scoring.
- `goal_change.metta` calculates the selected action's goal delta.
- `stability.metta` enforces Qwestor bounds and protected values.
- `engine.metta` prepares and commits one engine cycle.
- `bundle.metta` connects Qwestor to the pluggable MetaMo runtime.
- `context_parser.py` validates and grounds provider perception.
- `adapters/` contains the local provider transport, prompts, and LLM adapter.
- `session_store.py` stores and restores Qwestor sessions.
- `run.metta` is the executable one-turn application entry point.

## Provider configuration

Set the provider values in the environment or in the repository `.env` file:

```text
PROVIDER_NAME=gemini | openai | snet | openai_compatible
MODEL_NAME=<model identifier>
API_KEY=<provider key>
REQUEST_TIMEOUT=90
MAX_PROVIDER_ATTEMPTS=3
```

For a custom OpenAI-compatible service, also set:

```text
BASE_URL=<service base URL>
```

An independent provider can assess outcomes by using the same variables with
the `OUTCOME_` prefix:

```text
OUTCOME_PROVIDER_NAME=<provider>
OUTCOME_MODEL_NAME=<model identifier>
OUTCOME_API_KEY=<provider key>
OUTCOME_REQUEST_TIMEOUT=90
OUTCOME_MAX_PROVIDER_ATTEMPTS=3
```


## Running Qwestor

Run the executable entry point from the repository root:

```bash
petta usecase/qwestor/run.metta
```

The command executes the research question in the final
`qwestorRunLiveTurn` expression in `run.metta`. Edit that string to run a
different question. Qwestor performs perception, selects and executes an
action, assesses the outcome, and commits the resulting state.

The host may also inject its own provider or evidence transport through the
local adapter interfaces. Search and verification report that evidence is
unavailable when no evidence transport has been configured; they do not claim
that retrieval succeeded.
