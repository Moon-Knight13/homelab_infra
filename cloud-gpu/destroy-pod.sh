#!/usr/bin/env bash
# Permanently destroy a RunPod Pod and its volume.
# This is irreversible — requires explicit confirmation.
# Requires: runpodctl CLI authenticated, or RUNPOD_API_KEY in environment.
#
# Usage: destroy-pod.sh [--yes] [<pod-id>]
#   --yes     skip confirmation prompt (for automation)
#   <pod-id>  override Pod ID from config.env
# Exit: 0 destroyed, 1 error or cancelled.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

CONFIRM=false
POD_ID="${RUNPOD_POD_ID:-}"

for arg in "$@"; do
  case "$arg" in
    --yes) CONFIRM=true ;;
    *) POD_ID="$arg" ;;
  esac
done

if [[ -z "$POD_ID" ]]; then
  echo "ERROR: no Pod ID — pass as argument or set RUNPOD_POD_ID in config.env" >&2
  exit 1
fi

# Show current status before destroying
echo "Pod to destroy: $POD_ID" >&2
"$SCRIPT_DIR/status.sh" "$POD_ID" 2>/dev/null || true
echo "" >&2

if [[ "$CONFIRM" != "true" ]]; then
  echo "WARNING: This will permanently delete Pod $POD_ID and all data on its volume." >&2
  echo "This action cannot be undone." >&2
  read -rp "Type the Pod ID to confirm destruction: " input
  if [[ "$input" != "$POD_ID" ]]; then
    echo "Aborted — input did not match Pod ID." >&2
    exit 1
  fi
fi

echo "Destroying Pod $POD_ID..." >&2
runpodctl remove pod "$POD_ID"
echo "Pod $POD_ID destroyed." >&2

# Clear Pod ID from config
if [[ -f "$SCRIPT_DIR/config.env" ]]; then
  sed -i "s/^RUNPOD_POD_ID=.*/RUNPOD_POD_ID=/" "$SCRIPT_DIR/config.env"
  echo "Cleared Pod ID from config.env." >&2
fi
