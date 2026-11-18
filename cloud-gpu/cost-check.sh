#!/usr/bin/env bash
# Check RunPod billing against monthly budget.
# Requires: RUNPOD_API_KEY in environment (uses RunPod billing API).
#
# Usage: cost-check.sh
# Output: JSON object on stdout:
#   {"month":"2026-11","spent_usd":42.50,"budget_usd":125,"pct":34,
#    "warn":false,"blocked":false,"remaining_usd":82.50}
# Exit: 0 within budget, 1 warning threshold, 2 blocked.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

RUNPOD_BUDGET_MONTHLY_USD="${RUNPOD_BUDGET_MONTHLY_USD:-125}"
RUNPOD_BUDGET_WARN_PCT="${RUNPOD_BUDGET_WARN_PCT:-80}"
RUNPOD_BUDGET_BLOCK_PCT="${RUNPOD_BUDGET_BLOCK_PCT:-95}"

if [[ -z "${RUNPOD_API_KEY:-}" ]]; then
  echo "ERROR: RUNPOD_API_KEY not set — cannot query billing" >&2
  exit 1
fi

MONTH="$(date +%Y-%m)"

# Query RunPod billing API for current month spend
# Uses the GraphQL billing endpoint
billing_response="$(curl -sfS --max-time 15 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -d '{"query":"query { myself { currentSpend { amount currency } } }"}' \
  "https://api.runpod.io/graphql" 2>/dev/null)" || {
  echo "ERROR: failed to query RunPod billing API" >&2
  exit 1
}

spent="$(echo "$billing_response" | jq -r '.data.myself.currentSpend.amount // 0')"

# Calculate thresholds
warn_threshold="$(echo "$RUNPOD_BUDGET_MONTHLY_USD $RUNPOD_BUDGET_WARN_PCT" | awk '{printf "%.2f", $1 * $2 / 100}')"
block_threshold="$(echo "$RUNPOD_BUDGET_MONTHLY_USD $RUNPOD_BUDGET_BLOCK_PCT" | awk '{printf "%.2f", $1 * $2 / 100}')"
remaining="$(echo "$RUNPOD_BUDGET_MONTHLY_USD $spent" | awk '{printf "%.2f", $1 - $2}')"
pct="$(echo "$spent $RUNPOD_BUDGET_MONTHLY_USD" | awk '{if ($2 > 0) printf "%d", $1 * 100 / $2; else print 0}')"

warn=false
blocked=false
exit_code=0

if (( $(echo "$spent >= $block_threshold" | bc -l) )); then
  blocked=true
  warn=true
  exit_code=2
  echo "BLOCKED: spend \$$spent exceeds ${RUNPOD_BUDGET_BLOCK_PCT}% of \$$RUNPOD_BUDGET_MONTHLY_USD budget" >&2
elif (( $(echo "$spent >= $warn_threshold" | bc -l) )); then
  warn=true
  exit_code=1
  echo "WARNING: spend \$$spent exceeds ${RUNPOD_BUDGET_WARN_PCT}% of \$$RUNPOD_BUDGET_MONTHLY_USD budget" >&2
fi

jq -n \
  --arg month "$MONTH" \
  --argjson spent "$spent" \
  --argjson budget "$RUNPOD_BUDGET_MONTHLY_USD" \
  --argjson pct "$pct" \
  --argjson warn "$warn" \
  --argjson blocked "$blocked" \
  --argjson remaining "$remaining" \
  '{month:$month,spent_usd:$spent,budget_usd:$budget,pct:$pct,
    warn:$warn,blocked:$blocked,remaining_usd:$remaining}'

exit "$exit_code"
