#!/usr/bin/env bash
# Health check for RunPod GPU Pod — reachability, model loaded, inference working.
# Mirrors the spoke-health pattern from my_claude_dev.
# Requires: Pod running with vLLM serving on its proxy URL.
#
# Usage: health.sh [<pod-id>]
# Output: JSON object on stdout:
#   {"ts":..,"healthy":..,"reachable":..,"model_loaded":..,"inference_ok":..,
#    "latency_ms":..,"reason":".."}
# Exit: 0 healthy, 1 not healthy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

POD_ID="${1:-${RUNPOD_POD_ID:-}}"
RUNPOD_HEALTH_PROBE_TIMEOUT="${RUNPOD_HEALTH_PROBE_TIMEOUT:-30}"
RUNPOD_HEALTH_TEST_PROMPT="${RUNPOD_HEALTH_TEST_PROMPT:-Reply with the single word: ready}"
RUNPOD_HEALTH_MAX_LATENCY_MS="${RUNPOD_HEALTH_MAX_LATENCY_MS:-10000}"
RUNPOD_MODEL_REPO="${RUNPOD_MODEL_REPO:-huihui-ai/Qwen3-Coder-30B-A3B-abliterated}"

if [[ -z "$POD_ID" ]]; then
  echo "ERROR: no Pod ID — pass as argument or set RUNPOD_POD_ID in config.env" >&2
  exit 1
fi

emit() { # healthy reachable model_loaded inference_ok latency_ms reason
  jq -n --argjson ts "$(date +%s)" \
        --argjson healthy "$1" --argjson reachable "$2" \
        --argjson model_loaded "$3" --argjson inference_ok "$4" \
        --argjson latency_ms "$5" --arg reason "$6" \
        '{ts:$ts,healthy:$healthy,reachable:$reachable,model_loaded:$model_loaded,
          inference_ok:$inference_ok,latency_ms:$latency_ms,reason:$reason}'
  [[ "$1" == "true" ]] && exit 0 || exit 1
}

# Resolve Pod proxy URL from runpodctl
pod_info="$(runpodctl get pod "$POD_ID" 2>/dev/null || echo "")"
if [[ -z "$pod_info" ]]; then
  emit false false false false 0 "pod_not_found"
fi

# Try standard RunPod proxy URL pattern
BASE_URL="https://${POD_ID}-8000.proxy.runpod.net"

# 1. Reachable? (OpenAI-compatible /v1/models endpoint)
if ! models_response="$(curl -sfS --connect-timeout 5 --max-time 10 \
  "$BASE_URL/v1/models" 2>/dev/null)"; then
  emit false false false false 0 "unreachable"
fi

# 2. Model loaded?
if ! echo "$models_response" | jq -e '.data[]?' >/dev/null 2>&1; then
  emit false true false false 0 "no_models_loaded"
fi

# 3. Inference probe — timed OpenAI-compatible completion
start_ms="$(date +%s%N | cut -b1-13)"
probe_response="$(curl -sfS --max-time "$RUNPOD_HEALTH_PROBE_TIMEOUT" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg model "$RUNPOD_MODEL_REPO" --arg prompt "$RUNPOD_HEALTH_TEST_PROMPT" \
    '{model:$model,messages:[{role:"user",content:$prompt}],max_tokens:16}')" \
  "$BASE_URL/v1/chat/completions" 2>/dev/null)" || {
  emit false true true false 0 "inference_timeout"
}
end_ms="$(date +%s%N | cut -b1-13)"
latency_ms=$(( end_ms - start_ms ))

# Check response has content
content="$(echo "$probe_response" | jq -r '.choices[0].message.content // empty' 2>/dev/null || true)"
if [[ -z "$content" ]]; then
  emit false true true false "$latency_ms" "empty_response"
fi

# Check latency threshold
if (( latency_ms > RUNPOD_HEALTH_MAX_LATENCY_MS )); then
  emit false true true true "$latency_ms" "too_slow"
fi

emit true true true true "$latency_ms" "ok"
