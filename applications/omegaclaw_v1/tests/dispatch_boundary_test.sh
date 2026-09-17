#!/usr/bin/env bash
set -euo pipefail
python3 - "$(dirname "$0")/../../../.." <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1]).resolve()
loop = (root / 'repos/OmegaClaw-Core/src/loop.metta').read_text()
startup = (root / 'MetaMo/applications/omegaclaw_v1/run.metta').read_text()
assert '(eval $s)' not in loop
assert '(coreDispatchCommand $dispatchTicket $s)' in loop
assert '(coreDispatchCommand $dispatchTicket (quote (switch-mode)))' in loop
assert '(if (== (get-state &cfv2-root-mode) Fast) (switch-mode)' not in loop
assert loop.index('($dispatchTicket (coreDispatchBegin))') < loop.index('lib_llm_ext.callProvider')
assert loop.index('(recordDispatchFailure $R)') < loop.index('(py-call (helper.normalize_string $R))')
assert startup.index('!(initMetaMoDispatch)') < startup.index('!(motivatedOmegaclaw)')
PY
