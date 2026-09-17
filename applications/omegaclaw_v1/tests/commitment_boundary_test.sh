#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$app_dir" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
for name in ('adapter.metta', 'homeostasis.metta', 'persistence.metta',
             'signals.metta', 'omegaclaw_decision.metta', 'scheduling.metta'):
    source = (root / name).read_text()
    for slot in ('task-open', 'active-task', 'task-commitment-id'):
        assert f'change-state! &{slot}' not in source, (name, slot)
    assert 'mm_commitment_' not in source, name
exports = (root / 'commitments.metta').read_text()
assert '(commitmentSnapshot commitmentEvents)' in exports
assert 'Fixture' not in exports
assert 'mm_commitment_apply' not in exports
assert 'mm_commitment_open' not in exports
lifecycle = (root / 'task_lifecycle.metta').read_text()
assert '(= (completeTaskIfTerminal $_candidate) False)' in lifecycle
assert '(= (completePreviousTaskIfSuccessful)\n   False)' in lifecycle
assert '(refreshTaskCommitment)' in lifecycle.split('(= (prepareTaskStateForMetaMo)', 1)[1]
PY
