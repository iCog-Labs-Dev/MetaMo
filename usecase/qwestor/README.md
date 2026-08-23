# Usecase Guide

This folder contains the current Qwestor-style integration over MetaMo.
The implementation already works with the existing main-loop, usecase/main-loop.metta.

## Current Implementation

The runtime path is:

1. Parse the user query in `context_parser.py`.
2. Project the Qwestor state into a MetaMo motivation state.
3. Convert the parsed context into a `Stimulus`.
4. Build the subsystem state list.
5. Run `runMetaMoCycleDefault` with `defaultMetaMoBimonad`.
6. Print the Qwestor decision report in the terminal.


## Subsystem Options

The current usecase is configured for a single subsystem, which is the simplest
and recommended path for the existing pipeline.

If you want genuinely distinct motivational subsystems, step 4 in
[`main-loop.metta`](main-loop.metta) can be expanded to provide two different
`subsystemState` entries, for example `qwestor` and `ethics`, with different
motivation states.

That means you have two supported options:

- Single subsystem: keep one `subsystemState` and use the current default path.
- Two distinct subsystems: supply two different subsystem states and let the
  MetaMo cycle run consensus across them.

The current implementation uses `defaultMetaMoBimonad` from the main registry
and default dynamics, so no special wiring is needed in the loop itself.

## Terminal Result

The decision report is printed by `printQwestorResult`, so the terminal shows
the selected action, candidate list, stimulus values, and the next motivation
state after the cycle completes.

## Environment Setup

For the usecase folder, define the following variables:

```env
GEMINI_API_KEY=your_api_key_here
GEMINI_MODEL=your_model_name_here
```


## References

- [`main-loop.metta`](main-loop.metta)
- [`config.metta`](config.metta)
- [`adapters/stimulus_adapter.metta`](adapters/stimulus_adapter.metta)
- [`utils.metta`](utils.metta)
