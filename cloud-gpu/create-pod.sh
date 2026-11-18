#!/usr/bin/env bash
# Create a RunPod GPU Pod for AI model inference.
# Reads configuration from config.env (see config.env.example).
# Requires: runpodctl CLI authenticated, or RUNPOD_API_KEY in environment.
#
# Usage: create-pod.sh [--dry-run]
#   --dry-run  print the runpodctl command without executing
# Output: JSON object with Pod ID and connection details on stdout.
# Exit: 0 success, 1 error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env.example
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

# Defaults (overridable via config.env or environment)
RUNPOD_MODEL_REPO="${RUNPOD_MODEL_REPO:-huihui-ai/Qwen3-Coder-30B-A3B-abliterated}"
RUNPOD_GPU_TYPE="${RUNPOD_GPU_TYPE:-NVIDIA RTX A6000}"
RUNPOD_GPU_COUNT="${RUNPOD_GPU_COUNT:-1}"
RUNPOD_VOLUME_SIZE_GB="${RUNPOD_VOLUME_SIZE_GB:-100}"
RUNPOD_DOCKER_IMAGE="${RUNPOD_DOCKER_IMAGE:-runpod/worker-vllm:stable-cuda12.1.0}"
RUNPOD_EXPOSE_PORTS="${RUNPOD_EXPOSE_PORTS:-8000/http}"
RUNPOD_IDLE_TIMEOUT="${RUNPOD_IDLE_TIMEOUT:-1800}"
RUNPOD_MODEL_QUANTIZATION="${RUNPOD_MODEL_QUANTIZATION:-fp8}"
RUNPOD_MODEL_MAX_LENGTH="${RUNPOD_MODEL_MAX_LENGTH:-65536}"
RUNPOD_VLLM_EXTRA_ARGS="${RUNPOD_VLLM_EXTRA_ARGS:---enable-reasoning --reasoning-parser deepseek_r1}"

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# Preflight: budget check
if [[ -x "$SCRIPT_DIR/cost-check.sh" ]]; then
  budget_json="$("$SCRIPT_DIR/cost-check.sh" 2>/dev/null || echo '{}')"
  blocked="$(echo "$budget_json" | jq -r '.blocked // false')"
  if [[ "$blocked" == "true" ]]; then
    echo "ERROR: monthly budget exceeded — Pod creation blocked." >&2
    echo "$budget_json" >&2
    exit 1
  fi
fi

# Build environment variables for vLLM inside the Pod
VLLM_ENV="MODEL_NAME=$RUNPOD_MODEL_REPO"
VLLM_ENV="$VLLM_ENV,QUANTIZATION=$RUNPOD_MODEL_QUANTIZATION"
VLLM_ENV="$VLLM_ENV,MAX_MODEL_LEN=$RUNPOD_MODEL_MAX_LENGTH"
if [[ -n "$RUNPOD_VLLM_EXTRA_ARGS" ]]; then
  VLLM_ENV="$VLLM_ENV,VLLM_ARGS=$RUNPOD_VLLM_EXTRA_ARGS"
fi

POD_NAME="homelab-gpu-$(date +%Y%m%d)"

cmd=(
  runpodctl create pod
  --name "$POD_NAME"
  --gpuType "$RUNPOD_GPU_TYPE"
  --gpuCount "$RUNPOD_GPU_COUNT"
  --volumeSize "$RUNPOD_VOLUME_SIZE_GB"
  --imageName "$RUNPOD_DOCKER_IMAGE"
  --ports "$RUNPOD_EXPOSE_PORTS"
  --env "$VLLM_ENV"
)

if [[ -n "${RUNPOD_TEMPLATE_ID:-}" ]]; then
  cmd+=(--templateId "$RUNPOD_TEMPLATE_ID")
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY RUN — would execute:"
  printf '  %s\n' "${cmd[@]}"
  exit 0
fi

echo "Creating RunPod Pod: $POD_NAME" >&2
echo "  GPU: $RUNPOD_GPU_TYPE x$RUNPOD_GPU_COUNT" >&2
echo "  Image: $RUNPOD_DOCKER_IMAGE" >&2
echo "  Model: $RUNPOD_MODEL_REPO ($RUNPOD_MODEL_QUANTIZATION)" >&2

output="$("${cmd[@]}" 2>&1)" || {
  echo "ERROR: Pod creation failed:" >&2
  echo "$output" >&2
  exit 1
}

echo "$output"

# Extract Pod ID and persist to config
pod_id="$(echo "$output" | grep -oP 'pod\s+\K[a-z0-9]+' | head -1 || true)"
if [[ -n "$pod_id" ]]; then
  echo "Pod ID: $pod_id" >&2
  if [[ -f "$SCRIPT_DIR/config.env" ]]; then
    sed -i "s/^RUNPOD_POD_ID=.*/RUNPOD_POD_ID=$pod_id/" "$SCRIPT_DIR/config.env"
    echo "Updated config.env with Pod ID." >&2
  fi
fi
