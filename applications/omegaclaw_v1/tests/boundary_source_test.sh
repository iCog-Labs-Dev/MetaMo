#!/usr/bin/env bash

set -euo pipefail

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bridge="$test_dir/../bridge.metta"

if rg -n 'getHistory|\(get-state &prevmsg\)|\(get-state &lastresults\)|\(get-state &error\)|\(get-state &task-execution-observed\)' "$bridge"; then
  echo "MetaMo bridge contains a raw ContextFrames state read" >&2
  exit 1
fi

rg -n 'frameStateForMetaMo|frameRuntimeResults|frameBundleCurrentHistory|lastAttentionDirective' "$bridge" >/dev/null

# R2 consumers and registry must not reintroduce weighted producer facts or
# alternate direct-update paths. Provider wire rows are decoded only by adapters.
if rg -n '\((addSignal|hasSignal|legacySignalView|ModeSignalTrigger|SignalStrength|SignalEffect|SignalMode)([[:space:]]|\))' \
    "$test_dir"/../*.metta; then
  echo "R2 consumer or registry reintroduced a retired signal API" >&2
  exit 1
fi
