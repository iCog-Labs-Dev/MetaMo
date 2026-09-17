#!/usr/bin/env bash
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"

bridge="$app_dir/bridge.metta"
signals="$app_dir/signals.metta"
candidates="$app_dir/candidate_selection.metta"
decision="$app_dir/omegaclaw_decision.metta"
lifecycle="$app_dir/task_lifecycle.metta"

# The motivational cycle must pass one bundle through every boundary.
rg -q '\$bundle.*prepareTaskStateForMetaMo' "$bridge"
rg -q 'refreshSignals \$bundle' "$bridge"
rg -q 'generateCandidates \$bundle' "$bridge"
rg -q 'pruneActionsForBundle \$bundle' "$bridge"
rg -q 'schedulerAttentionDirective \$bundle' "$bridge"
rg -q 'omegaclawScoreForBundle \$bundle' "$bridge"
rg -q 'omegaclawScoreForBundle \$bundle' "$decision"
rg -q 'setActiveFrameBundle \$bundle' "$lifecycle"
rg -q 'omegaclawDecideBound' "$decision"

# MetaMo modules may not read arbitrary OmegaClaw runtime state themselves.
if rg -q 'get-state &(prevmsg|lastresults|error|new-msg-flag|task-open|active-task|cfv2-)' \
    "$signals" "$candidates" "$decision"; then
  echo "MetaMo module bypasses the adapter boundary" >&2
  exit 1
fi

# Lifecycle decisions must use bundle-scoped predicates rather than calling
# helpers that reach back into OmegaClaw task state.
if rg -q '\((idleAutonomyActive|directUserResponseNeeded|resultQuestionNeedsResponse|taskResultReady|executionContinuationNeeded|executionRiskCurrentlyHigh|freshExecutionRequestNeeded|awaitingClarificationResponse)(\)|\s)' \
    "$candidates"; then
  echo "Candidate selection bypasses the bundle-scoped lifecycle boundary" >&2
  exit 1
fi

# Signal extraction may maintain MetaMo-local signal history, but it must not
# mutate the task state owned by ContextFrames/OmegaClaw.
if rg -q 'change-state! &(active-task|task-open)' "$signals"; then
  echo "Signal extraction mutates task runtime state" >&2
  exit 1
fi

# The source order is part of the contract.
python3 - "$bridge" "$lifecycle" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
steps = [
    "($bundle (prepareTaskStateForMetaMo))",
    "refreshSignals $bundle",
    "computeAllDimensions",
    "pruneActionsForBundle $bundle",
    "scheduleAdmittedActions (getSignals) $admittedActions",
    "runMetaMoCycleDefault",
    "schedulerAttentionDirective $bundle",
]
positions = [source.index(step) for step in steps]
assert positions == sorted(positions), positions
lifecycle = Path(sys.argv[2]).read_text().split('(= (prepareTaskStateForMetaMo)', 1)[1]
steps = ['(refreshTaskExecutionObserved)', '(completePreviousTaskIfSuccessful)',
         '(frameStateForMetaMo)', '(setActiveFrameBundle $bundle)']
positions = [lifecycle.index(step) for step in steps]
assert positions == sorted(positions), positions
assert lifecycle.count('(frameStateForMetaMo)') == 1
assert '(frameStateForMetaMo)' not in source
assert '(refreshTaskExecutionObserved)' not in source
assert '(completePreviousTaskIfSuccessful)' not in source
assert 'feasibilityGateActions $bundle' not in source
assert '($admittedActions (if $feasibility $actions ()))' not in source
assert 'recordCandidateRejections $rejections' in source
assert '(omegaclawBimonad) $sysStates $stimulus $scheduledActions () ()' in source
PY
