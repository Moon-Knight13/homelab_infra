# BMAD Workflow

This template uses BMAD as the default project workflow for Claude-led delivery.

## Stages
1. Discovery and scope
2. Requirements and PRD
3. Architecture and risk review
4. Task decomposition and plan
5. Implementation and validation
6. Security hardening and release readiness

## Usage
- Install BMAD through template bootstrap scripts.
- Use BMAD guidance in planning and delivery phases.
- Use bmad-help in Claude sessions when next steps are unclear.

## Planning artifacts: private repo, restore on fresh clone

BMAD outputs (`_bmad-output/`: specs, PRDs, append-only `.memlog.md` decision logs,
absorbed plans) are **not** tracked in this public repo — memlogs are an unfiltered
audit trail and must never be published. They live in the private repo
`Moon-Knight13/homelab_planning`, nested inside the workspace as `_bmad-output/`
(this repo's `.gitignore` excludes that path, so the two repos never conflict).

Restore after a fresh clone (after the devcontainer has bootstrapped BMAD):

```sh
cd <this repo's checkout>
gh repo clone Moon-Knight13/homelab_planning _bmad-output
# or: git clone git@github.com:Moon-Knight13/homelab_planning.git _bmad-output
```

BMAD skills then resume automatically — they resolve paths from
`_bmad/bmm/config.yaml` (`output_folder: _bmad-output`), find in-progress runs by
frontmatter `status: draft`, and rebuild context from each run's `.memlog.md`.

Rules:
- The framework (`_bmad/`, skills) is regenerated per machine by
  `scripts/install-bmad.sh`; only outputs belong in the planning repo.
- Commit and push `_bmad-output/` at the end of a planning session
  (`cd _bmad-output && git add -A && git commit && git push`).
- Never copy planning-repo content into this public repo unsanitized, and never
  flip the planning repo public — see its README for why.
- Memlogs are append-only; write via `_bmad/scripts/memlog.py`, never by hand.

## From decomposition to the board
Once the Task Decomposition stage produces a task list, `/bmad-to-board` turns it
into an epic plus story issues on the Kanban board (with BMAD Stage and a
suggested Route set on each), where they can be claimed and built. See
[KANBAN_WORKFLOW.md](KANBAN_WORKFLOW.md).
