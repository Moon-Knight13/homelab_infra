#!/usr/bin/env bash
# Check RunPod Pod status — runtime state, GPU utilization, uptime, cost estimate.
# Requires: runpodctl CLI authenticated, or RUNPOD_API_KEY in environment.
#
# Usage: status.sh [<pod-id>]
# Output: JSON object on stdout with status fields.
# Exit: 0 running, 1 not running or error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

POD_ID="${1:-${RUNPOD_POD_ID:-}}"
if [[ -z "$POD_ID" ]]; then
  echo "ERROR: no Pod ID — pass as argument or set RUNPOD_POD_ID in config.env" >&2
  exit 1
fi

# Query Pod status via runpodctl
pod_info="$(runpodctl get pod "$POD_ID" 2>&1)" || {
  echo "ERROR: failed to query Pod $POD_ID" >&2
  echo "$pod_info" >&2
  exit 1
}

echo "$pod_info"

# Parse state for exit code
state="$(echo "$pod_info" | grep -ioP '(running|exited|stopped|created)' | head -1 || echo "unknown")"
case "${state,,}" in
  running) exit 0 ;;
  *) exit 1 ;;
esac
