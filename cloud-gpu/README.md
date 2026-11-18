# Cloud GPU Spoke — RunPod Provisioning

On-demand cloud GPU for AI model inference failover, managed as infrastructure-as-code
alongside the on-prem platform.

## Architecture

Failover chain for AI-assisted development:

```
Claude MAX (primary) → RunPod GPU Pod (failover) → local Ollama (last resort)
```

This spoke provisions and manages the RunPod tier. When Claude MAX is unavailable or
rate-limited, the hub agent (`my_claude_dev`) routes requests to a RunPod-hosted model
via its OpenAI-compatible API.

## Model

| Field | Value |
|-------|-------|
| Model | `Qwen3-Coder-30B-A3B` abliterated (huihui-ai) |
| Architecture | MoE — 30B total, ~3B active parameters |
| Quantisation | FP8 (fits 48GB VRAM) |
| Context | Up to 262K tokens (capped at 65K for cost) |
| Licence | Apache 2.0 |
| Serving | vLLM with OpenAI-compatible API |

## GPU Selection

| Field | Value |
|-------|-------|
| GPU | NVIDIA RTX A6000 (48GB VRAM) |
| Deployment | Community Cloud Pod |
| Rate | ~$0.33/hr |

## Cost Budget

| Metric | Value |
|--------|-------|
| Monthly cap | $125 USD (~£100) |
| Projected use | $15–30/month at 2–4 hrs/day |
| Warning threshold | 80% ($100) |
| Block threshold | 95% ($119) |

`cost-check.sh` queries RunPod billing and enforces these limits. `create-pod.sh` runs
the cost check as a preflight gate.

## Setup

### Prerequisites

1. [RunPod account](https://www.runpod.io/) with API key
2. `runpodctl` CLI installed and authenticated:
   ```bash
   # Install
   wget -qO- cli.runpod.net | sudo bash

   # Authenticate
   runpodctl config --apiKey "$RUNPOD_API_KEY"
   ```
3. `jq` and `curl` available

### Configuration

```bash
cp config.env.example config.env
# Edit config.env — set any overrides. API key stays in environment, not in the file.
```

## Operations

### Create a new Pod

```bash
# Dry run — shows the command without executing
./create-pod.sh --dry-run

# Create the Pod
./create-pod.sh
# Pod ID is written to config.env automatically.
```

### Daily start/stop cycle

```bash
# Start the Pod (resumes from stopped state)
./start-pod.sh

# Check status and health
./status.sh
./health.sh

# Stop when done (preserves disk — no GPU billing while stopped)
./stop-pod.sh
```

### Monitor cost

```bash
./cost-check.sh
# Returns JSON: spent, remaining, warn/blocked flags.
```

### Teardown

```bash
# Permanent — destroys Pod and volume. Requires confirmation.
./destroy-pod.sh
```

## Health Integration

`health.sh` outputs JSON compatible with the `spoke-health` pattern in `my_claude_dev`.
The hub agent calls it to verify the RunPod spoke before routing inference traffic.

Health checks verify:
- Pod reachable via RunPod proxy URL
- Model loaded (vLLM `/v1/models` endpoint)
- Inference working (timed test prompt via `/v1/chat/completions`)
- Response latency within threshold

## File Layout

```
cloud-gpu/
├── README.md              this file
├── config.env.example     configuration template
├── create-pod.sh          provision new Pod
├── start-pod.sh           start existing Pod
├── stop-pod.sh            stop Pod (preserves disk)
├── destroy-pod.sh         permanent teardown
├── status.sh              query Pod state
├── cost-check.sh          billing vs. budget
└── health.sh              spoke health probe
```

## Security

- **No credentials in files.** API key read from `RUNPOD_API_KEY` environment variable
  or `runpodctl` CLI config.
- `config.env` is gitignored — only `config.env.example` is committed.
- `destroy-pod.sh` requires explicit confirmation (type the Pod ID).
- `create-pod.sh` checks budget before provisioning.
