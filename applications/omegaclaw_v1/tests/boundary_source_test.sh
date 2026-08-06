#!/usr/bin/env bash

set -euo pipefail

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bridge="$test_dir/../bridge.metta"

if rg -n 'getHistory|\(get-state &prevmsg\)|\(get-state &lastresults\)|\(get-state &error\)|\(get-state &task-execution-observed\)' "$bridge"; then
  echo "MetaMo bridge contains a raw ContextFrames state read" >&2
  exit 1
fi

rg -n 'frameStateForMetaMo|frameRuntimeResults|frameBundleCurrentHistory|lastAttentionDirective' "$bridge" >/dev/null
