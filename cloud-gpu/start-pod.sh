#!/usr/bin/env bash
# Start an existing (stopped) RunPod Pod.
# Requires: runpodctl CLI authenticated, or RUNPOD_API_KEY in environment.
#
# Usage: start-pod.sh [<pod-id>]
#   <pod-id>  override Pod ID from config.env
# Exit: 0 started, 1 error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

POD_ID="${1:-${RUNPOD_POD_ID:-}}"
if [[ -z "$POD_ID" ]]; then
  echo "ERROR: no Pod ID — pass as argument or set RUNPOD_POD_ID in config.env" >&2
  exit 1
fi

echo "Starting Pod $POD_ID..." >&2
runpodctl start pod "$POD_ID"
echo "Pod $POD_ID start requested." >&2

# Wait briefly and check status
sleep 3
"$SCRIPT_DIR/status.sh" "$POD_ID" 2>/dev/null || true
