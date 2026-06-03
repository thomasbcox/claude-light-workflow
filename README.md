# claude-light-workflow

A lightweight, human-controlled development loop where **Claude builds, Codex critiques, and the
human decides** — with a small per-branch audit trail. A trimmed-down port of the heavier "AI
Protocol v3" (see [`ai-dev-workflow-architecture.md`](ai-dev-workflow-architecture.md)), keeping only
what's needed for a good Claude↔Codex back-and-forth.

The full doctrine lives in [`.claude/workflow-protocol.md`](.claude/workflow-protocol.md).

## The loop

| Skill | Does | Human gate |
|---|---|---|
| `/frame`  | request → short spec on a feature branch → implement AC-by-AC | **approves scope** |
| `/review` | gate green → `codex exec review` (read-only) → decision menu | **decides per finding** |
| `/close`  | apply approved fixes → re-review or merge → cleanup | **approves merge** |

Codex is called directly via the `codex` CLI (`codex exec review`) — no copy/paste. It runs
read-only and never commits; Claude captures its structured findings and commits the trail.

## Artifacts (the audit trail)
- `reviews/<slug>.md` — spec → build note → Codex findings → decisions, appended across rounds.
- `reviews/<slug>.codex.json` — raw structured Codex output per round.
- `.claude/workflow.json` — per-repo config: `baseBranch`, `branchPrefix`, `testCommand`, `codexModel`.
- `AGENTS.md` — Codex's reviewer contract.

## Guardrail
One hook, [`block-main-writes.sh`](.claude/hooks/block-main-writes.sh): blocks commits/pushes to the
base branch and `--force` / `--no-verify`. Bypass requires a diff-visible edit.

## Test here, then deploy everywhere
1. **Test** in this repo (skills/hook are project-local under `.claude/`). Run a real `/frame → /review → /close`.
2. **Deploy** to every Claude Code app on this machine: `./install.sh` copies the skills + hook to
   `~/.claude/` and wires the hook into `~/.claude/settings.json` (idempotent, backs up first).
3. In each app, run `/frame` once — it bootstraps that repo's `.claude/workflow.json` + `AGENTS.md`.

## Requirements
`codex` CLI (`codex exec review`), `git`, `python3`, `jq`. `gh` + a remote enable PR mode; without a
remote the loop runs fully local (local `--no-ff` merge).
