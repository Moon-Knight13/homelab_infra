#!/usr/bin/env bash
# Stop a running RunPod Pod (preserves disk state).
# Requires: runpodctl CLI authenticated, or RUNPOD_API_KEY in environment.
#
# Usage: stop-pod.sh [<pod-id>]
# Exit: 0 stopped, 1 error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

POD_ID="${1:-${RUNPOD_POD_ID:-}}"
if [[ -z "$POD_ID" ]]; then
  echo "ERROR: no Pod ID — pass as argument or set RUNPOD_POD_ID in config.env" >&2
  exit 1
fi

echo "Stopping Pod $POD_ID..." >&2
runpodctl stop pod "$POD_ID"
echo "Pod $POD_ID stop requested. Disk state preserved." >&2
