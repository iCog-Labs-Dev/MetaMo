#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"

if ! command -v petta >/dev/null 2>&1; then
  echo "petta command not found; install PeTTa or add it to PATH" >&2
  exit 127
fi

exec petta "$test_dir/minimal_loop_test.metta"
