# Inference Control

This application is intended to direct limited reasoning effort toward useful
PLN inferences. PLN handles rule application, uncertain truth values, and
evidence. MetaMo will appraise and prioritize possible inferences using its
goals and modulators.

## Reasoning loop

1. Read a query, beliefs, and a resource budget.
2. Generate proposals from applicable rules and premises.
3. Select proposals using the current controller state.
4. Apply the selected rules and record their conclusions and evidence.
5. Update the controller from the results, then continue or stop.

The PLN code in this directory exposes proposals separately from rule
execution. That boundary lets the controller choose a step before its truth
value is computed. The default query function provides a confidence-first
reference behavior.