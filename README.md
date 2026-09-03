# MetaMo

MetaMo is a MeTTa/PeTTa framework for motivational decision-making. It combines:

- OpenPSI appraisal, which updates motivational modulators from a stimulus;
- MAGUS decision-making, which scores and selects among candidate actions; and
- dynamics and safety checks for damping, boundary stabilization, projection,
  contractivity, and safe-region validation.

A MetaMo cycle accepts a motivational state, a stimulus, and candidate actions,
then returns a selected action and validated state transitions. Applications can
add their own perception, action, persistence, and response layers around this
cycle.

## Repository layout

```text
core/       State types, accessors, constants, and shared helpers
openpsi/    Appraisal and feeling dynamics
magus/      Goal/modulator-based action scoring and selection
dynamics/   Stability, coherence, and safety functions
category/   Functors and bimonad abstractions
main/       Reusable MetaMo cycle and integration entry points
llm/        Python/MeTTa bridges and LLM parsing/response helpers
applications/ Example interactive multi-subsystem assistant
usecase/    Qwestor integration and trading-agent example
scripts/    Configuration generation and test utilities
```

## Requirements

- Python 3.10+
- [PeTTa](https://github.com/trueagi-io/PeTTa), including its `run.sh` runner
- Python dependencies in [`requirements.txt`](requirements.txt)
- A Gemini API key for the LLM-backed assistant and Qwestor use case

Install the Python dependencies in a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

Keep credentials in a local `.env` file (it is ignored by Git):

```env
GEMINI_API_KEY=your_api_key_here
```

The LLM helpers load this file from the repository root. Some components also
support the Google GenAI client’s default credential configuration.

## Running tests

The recommended runner discovers every MeTTa test file and executes it through
PeTTa. Point it at your PeTTa checkout:

```bash
python3 scripts/run-tests.py \
  --root . \
  --petta-runner /path/to/PeTTa/run.sh
```

Alternatively, if `petta` is available on `PATH`:

```bash
./test.sh
```

Useful runner options include `--jobs N` for parallel test execution and
`--timeout SECONDS` for the per-file timeout. `PETTA_PATH` and `PETTA_RUNNER`
can be used instead of passing `--petta-runner`.

## Running the example assistant

The interactive example uses two motivational subsystems, curiosity and ethics,
and asks an LLM to produce the final natural-language response:

```bash
/path/to/PeTTa/run.sh applications/research_assistant.metta
```

Enter a query at the prompt. Type `quit` or `exit` to stop. The application
prints the selected action, subsystem preferences, consensus state, and the
generated response.

## MetaMo cycle API

The reusable MeTTa integration is defined in [`main/main.metta`](main/main.metta).
The central function is:

```text
runMetaMoCycleDefault bimonad states stimulus candidates consensusPair translator
```

Its result contains the final action, merged current and target states, local
actions, local target states, next subsystem states, and optional peer
simulations. A host application generally needs to:

1. construct or load subsystem motivational states;
2. convert its perception into a four-value stimulus;
3. generate candidate actions;
4. run the cycle;
5. execute the returned action; and
6. persist the returned next states.

The default wiring is configured in [`core/config.metta`](core/config.metta),
where appraisal, decision, and dynamics modules can be replaced without
changing the orchestration code.

## Use cases

### Qwestor research assistant

[`usecase/main-loop.metta`](usecase/main-loop.metta) implements a conversational
pipeline that parses a query, projects Qwestor state into MetaMo, builds a
stimulus, filters candidate actions, runs a MetaMo cycle, generates a response,
and persists the session.

See the [usecase guide](usecase/README.md) and the detailed
[Qwestor integration documentation](usecase/Qwestor%E2%80%93MetaMo%20Integration%20Documentation.md).

Run its tests with:

```bash
python3 scripts/run-tests.py \
  --root usecase \
  --petta-runner /path/to/PeTTa/run.sh
```

### Trading agent

[`usecase/metamo-trading-agent/`](usecase/metamo-trading-agent/) compares a
MetaMo trading agent with a momentum baseline across fixed market scenarios.
It includes scenario generation, MeTTa tests, run-log plotting, and support for
CSV price data. Start with the [trading-agent README](usecase/metamo-trading-agent/README.md).

## Configuration

For the core framework, edit the module declarations and constants in
[`core/config.metta`](core/config.metta). The Qwestor-specific defaults live in
[`usecase/config.metta`](usecase/config.metta).

For larger configuration changes, [`scripts/generate-config.py`](scripts/generate-config.py)
can render validated configuration data into MeTTa files. Run:

```bash
python3 scripts/generate-config.py --help
```

## Contributing

Keep framework logic in the relevant MeTTa module, add or update a matching test
under that module’s `tests/` directory, and run the repository test suite before
submitting changes. Application-specific adapters should remain in `applications/`
or `usecase/` rather than coupling the core cycle to a particular domain.

## License

See [`LICENSE`](LICENSE).
