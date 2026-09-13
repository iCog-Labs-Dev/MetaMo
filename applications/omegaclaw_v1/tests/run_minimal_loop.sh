#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"

exec python3 "$test_dir/../../../scripts/run-omegaclaw.py" "$test_dir/minimal_loop_test.metta" "$@"
