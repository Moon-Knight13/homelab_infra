# On-Prem Dev Platform

[![ci](https://github.com/Moon-Knight13/homelab_infra/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Moon-Knight13/homelab_infra/actions/workflows/ci.yml)
[![semgrep](https://github.com/Moon-Knight13/homelab_infra/actions/workflows/semgrep.yml/badge.svg?branch=main)](https://github.com/Moon-Knight13/homelab_infra/actions/workflows/semgrep.yml)
[![secret-scan](https://github.com/Moon-Knight13/homelab_infra/actions/workflows/secret-scan.yml/badge.svg?branch=main)](https://github.com/Moon-Knight13/homelab_infra/actions/workflows/secret-scan.yml)

A reusable, infrastructure-as-code **pattern** for a small, secure datacentre — headless
Proxmox virtualisation behind a policy-as-code pfSense firewall, hardened to CIS benchmarks
and evidenced against UK Secure by Design as it is built. Not one homelab: a pattern any
equivalent lab stands up by swapping a single inventory file, tears down and *rerolls* from
source in under four hours, and hands over to a stranger without loss.

This is the **public pattern repository** — roles, playbooks, templates, and documentation
with no deployment specifics. Deployment data, secrets, and generated compliance evidence
live in separate **private** repositories by design.

## 📊 Briefings

Two self-contained, theme-aware pages (technical **and** non-technical readers). Rendered
live via GitHub Pages — no external requests. The **Page** links below open the live site;
the **Source** links open the raw HTML in the repo (or open it locally).

| Page | What it covers | Source |
|------|----------------|--------|
| **[On-Prem Dev Platform — what &amp; how](https://moon-knight13.github.io/homelab_infra/platform.html)** | The project: mission, who it serves, the 25 capabilities, the tech stack, measurable promises, the layered architecture, the rebuild story, and the security model. Start here. | [`platform.html`](docs/explainer/platform.html) |
| **[Engineering overview](https://moon-knight13.github.io/homelab_infra/)** | The technical build: architecture layers, the tech stack, the phased build plan, and the CI quality gates. For a technical audience. | [`index.html`](docs/explainer/index.html) |

## What the platform does

Twenty-five capabilities, grouped by the job they do — each with a concrete, testable success
signal:

- **Provision &amp; virtualise** — bare machines boot and install themselves over the network,
  unattended; everything runs inside a validated virtualisation layer.
- **Network as policy** — the firewall is code; the network is split into isolated zones that
  deny each other by default, every rule generated from one policy source.
- **Harden &amp; prove** — CIS hardening gates every merge and is re-scanned for drift; the
  security case is assured against UK Secure by Design with named risk owners.
- **Identity &amp; access** — mandatory MFA for admin access; a recorded-approval → review →
  provable-offboarding lifecycle.
- **Deliver services safely** — every service onboards through a readiness checklist; images
  are scanned and deployed by digest via outbound pull only; intrusion detection survives
  failover.
- **Operate &amp; survive** — automated gates on every change, fast-rebuild backups, air-gap
  promotion bundles, queryable live state, and cold-handover documentation drills.

See the [platform briefing](https://moon-knight13.github.io/homelab_infra/platform.html) for the full picture, or the
[architecture &amp; capability detail](#planning--architecture) below.

## Guarantees

Measured, not asserted — the twelve-month success criteria:

- **≤ 4 hours** bare-metal to healthy, including critical-service data restore
- **≤ 1 day** to onboard a new service (**≤ 30 min** operator effort)
- **CIS Level 2** on the hypervisor host — or formal, signed-off waivers
- **Zero leaks** in this public repository, by layered scanning and human review
- Stood up at least once on **non-reference hardware** by inventory swap alone

## Adopt this pattern

Two sanctioned paths — pick by how you intend to run it:

- **Overlay-nested (recommended, maintained).** Keep this pattern repository upstream and layer
  a **private overlay** (inventory, host data, secrets) at a gitignored path over it. You keep
  receiving upstream fixes and the public/private boundary stays clean. Best for long-lived
  deployments and anyone contributing back.
- **Template fork (one-off / air-gapped).** This repository is a **GitHub template** — use
  **"Use this template"** to generate your own **private** copy and tweak it in place. Simpler for
  a single lab, but you diverge from upstream, and the copy must stay private: the leak controls
  still run, and the guarantee becomes *"this fork is never published."*

Either way you retarget hardware by swapping inventory — no role edits. The template and this
public pattern contain **pattern only**: no addresses, secrets, or deployment specifics.

## How it's engineered

This project is built on the **[Claude Secure Template](https://github.com/Moon-Knight13/claude_template_repo)**
(`claude_template_repo`) — a language-agnostic, Claude-first development template providing
the delivery discipline this platform is held to:

- **AI task routing** — low-risk work runs on a local model; security, architecture, and
  cross-cutting changes escalate to Claude ([docs/AI_ROUTING_POLICY.md](docs/AI_ROUTING_POLICY.md)).
- **Deterministic security gates** — gitleaks secret scanning, semgrep SAST (incl. MITRE
  ATLAS rules), and Trivy container scanning, all **required** in CI — a red check blocks the
  merge ([`.github/workflows/`](.github/workflows/)).
- **BMAD planning workflow** — structured product → architecture → epics planning
  ([docs/BMAD_WORKFLOW.md](docs/BMAD_WORKFLOW.md)).
- **Kanban orchestration** — a per-repo board routes each card to a human, Claude, or a local
  model ([docs/KANBAN_WORKFLOW.md](docs/KANBAN_WORKFLOW.md)).
- **Deny-by-default devcontainer** — the whole loop runs inside a container whose network is
  locked down by default.

The template's own [visual overview](https://moon-knight13.github.io/claude_template_repo/) covers that delivery workflow in one page. For this platform's own engineering — architecture, stack, and build plan — see the [engineering overview](https://moon-knight13.github.io/homelab_infra/).

## Planning &amp; architecture

The platform is greenfield: the specification and architecture are complete and reviewed; the
build is sequenced foundations-first (provisioning → network policy → hardening → services).

Planning artifacts — the full specification (25 capabilities, constraints, non-goals), the
architecture spine, and the decision log — are maintained in a **private planning repository**
and are not reproduced here. The briefings above are the public, pattern-level reading of that
work.

## Repository structure

```
.claude/commands/    Claude Code skills (/bmad, /next-issue, /run-epic, /day0-check, /route-task, …)
.devcontainer/       Dev environment with deny-by-default firewall and pre-installed tooling
.github/             CI, secret scan, semgrep, container scan, weekly audit; issue & PR templates; Pages
docs/                Briefings (docs/explainer/), routing, BMAD, and kanban workflow docs
scripts/             Bootstrap, routing, CI helpers, and validators
```

Not in this repository, by design: deployment inventory and secrets (private overlay),
generated compliance evidence (private evidence store), and any live addresses, hostnames, or
identity-linking data.

## Security

Public-repo hygiene is a first-class requirement, not an afterthought:

- No secrets, internal addresses, or identity-linking data — enforced by layered controls:
  automated scanners, custom deny-list patterns, code-owner review on all paths, and periodic
  human review as the primary signal.
- Branch protection with required status checks; conventional commits; one branch / one PR per
  unit of work.
- See [SECURITY.md](SECURITY.md) for the disclosure policy.

## License

Apache 2.0 — see [LICENSE](LICENSE).

---

*Engineered with the [Claude Secure Template](https://github.com/Moon-Knight13/claude_template_repo).*
