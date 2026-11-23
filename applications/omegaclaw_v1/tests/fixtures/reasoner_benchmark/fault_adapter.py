"""Test-only snapshots of real intake, selection, callback and feedback state."""
import json
import os
from pathlib import Path


# Example: each fault comparison writes only into its own retained output directory.
def record(stage, invocation, payload, reliability, receipts, selections, assessments, learning, effects, budgets):
    row = dict(stage=stage, invocation=invocation, payload=payload, reliability=reliability,
               receipts=receipts, selections=selections, assessments=assessments,
               learning=learning, effects=effects, budgets=budgets)
    path = Path(os.environ['OMEGACLAW_BENCHMARK_OUTPUT']) / 'fault-audit.jsonl'
    with path.open('a') as stream:
        stream.write(json.dumps(row) + '\n')
    return 1
