"""Test-only observations of synthetic adapter adaptation, not a real learning algorithm."""
import json
import os
from pathlib import Path


# Example: each native intake observes this process's current state without resetting it.
def observe(value, reliability, parameters, pending, host, context):
    memory = Path(os.environ['OMEGACLAW_BENCHMARK_MEMORY']) / 'probe-learning.json'
    row = dict(context=context, value=value, reliability=reliability, parameters=parameters,
               pending=pending, host=host, memory=json.loads(memory.read_text()) if memory.exists() else None)
    output = Path(os.environ['OMEGACLAW_BENCHMARK_OUTPUT']) / 'learning-probe.jsonl'
    with output.open('a') as stream:
        stream.write(json.dumps(row) + '\n')
    return 1


# Example: a synthetic learned value persists only in this comparison's memory directory.
def retain(value):
    path = Path(os.environ['OMEGACLAW_BENCHMARK_MEMORY']) / 'probe-learning.json'
    path.write_text(json.dumps(value))
    return 1
