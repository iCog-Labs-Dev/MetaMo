#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
WORKSPACE_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)"

: "${OMEGACLAW_AUTH_SECRET:?Set OMEGACLAW_AUTH_SECRET before starting OmegaClaw}"
: "${IRC_CHANNEL:?Set IRC_CHANNEL before starting OmegaClaw}"

cd "$WORKSPACE_ROOT"

exec python3 MetaMo/scripts/run-omegaclaw.py \
  MetaMo/applications/omegaclaw_v1/run.metta \
  IRC_channel="$IRC_CHANNEL"
