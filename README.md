# claude-light-workflow

A lightweight, human-controlled development loop where **Claude builds, Codex critiques, and the
human decides** — with a small per-branch audit trail. A trimmed-down port of the heavier "AI
Protocol v3" (see [`ai-dev-workflow-architecture.md`](ai-dev-workflow-architecture.md)), keeping only
what's needed for a good Claude↔Codex back-and-forth.

The full doctrine lives in [`.claude/workflow-protocol.md`](.claude/workflow-protocol.md).

## The loop

| Skill | Does | Human gate |
|---|---|---|
| `/frame`  | request → spec **+ design sketch** → Codex design-reviews the sketch → implement AC-by-AC | **approves scope + design** |
| `/review` | gate green → **approach pass** (shape, best-practice) gates **correctness pass** (diff) → decision menu | **decides per finding** |
| `/close`  | apply approved fixes → re-review or merge → cleanup | **approves merge** |

**Who decides what.** The human is consulted at three altitudes — **requirements**, **high-level
design** (the `/frame` design sketch), and **implementation tradeoffs** (the `/review` approach pass)
— plus the merge. Blocking is gated by reversibility: only **one-way-door** decisions (architecture,
data model, a new dependency, or a cross-cutting pattern future code will copy) stop you; reversible
calls default to Claude, logged for veto. Independently, Codex **always** assesses each change against
modern best practice and flags substandard choices — even reversible ones — with guardrails (a
concrete win, not novelty). Full rules in [`.claude/workflow-protocol.md`](.claude/workflow-protocol.md).

Codex is called directly via the `codex` CLI — a read-only `codex exec -s read-only` run with a
structured-output schema (the canonical command lives in [`review/SKILL.md`](.claude/skills/review/SKILL.md)),
no copy/paste. It runs read-only and never commits; Claude captures its structured findings and commits the trail.

## Artifacts (the audit trail)
- [`BACKLOG.md`](BACKLOG.md) — staging area in front of the loop: outstanding bugs (`BUG-`) and tooling improvements (`OPS-`), each graduating to a `reviews/<slug>.md` story.
- `reviews/<slug>.md` — spec + design sketch → Codex findings → decisions, appended across rounds.
- `reviews/<slug>.design.json` — frame-time Codex design-sketch review.
- `reviews/<slug>.approach.json` — review-time approach-pass output.
- `reviews/<slug>.codex.json` — review-time correctness output per round.
- `.claude/workflow.json` — per-repo config: `baseBranch`, `branchPrefix`, `testCommand`, `codexModel`.
- `AGENTS.md` — Codex's reviewer contract.

The story header records only declared state (`proposed → approved`). Whether it shipped is owned by git — the `merge: <slug>` commit / PR-`MERGED` state — and read back by deriving (`git log <base> --grep "^merge: <slug>"`), never stored in the header.

## Guardrail
One hook, [`block-main-writes.sh`](.claude/hooks/block-main-writes.sh): parses each command's real
`git` invocation (so `git -C <repo> commit` and `git -c k=v commit` are caught, and a `grep 'git push'`
is not) and blocks commits/pushes to the base branch, `--no-verify`, and force-pushes
(`--force` / `--force-with-lease` / `-f` / `--mirror` / `+refspec`). It's a cooperative guardrail, not an
adversarial sandbox — the real backstop is server-side branch protection; bypassing the hook still takes a
diff-visible edit to it or `settings.json`. Covered by [`tests/guard_test.sh`](tests/guard_test.sh) (the gate).

## Deferring to a repo's native workflow
Because the skills + hook install globally (`~/.claude`), they reach every repo. A repo that already
runs a heavier/native workflow signals it with a **`docs/ai-protocol.md`** marker at its root. When
that marker is present, the light workflow **stands down**: the guard hook becomes a no-op (the
repo's own hooks govern) and `/frame`, `/review`, `/close` stop and point you at the native skills.
Repos without the marker are governed by the light workflow as normal.

## Test here, then deploy everywhere
1. **Test** in this repo (skills/hook are project-local under `.claude/`). Run a real `/frame → /review → /close`.
2. **Deploy** to every Claude Code app on this machine: `./install.sh` copies the skills + hook to
   `~/.claude/` and wires the hook into `~/.claude/settings.json` (idempotent, backs up first).
3. In each app, run `/frame` once — it bootstraps that repo's `.claude/workflow.json` + `AGENTS.md`.

## Requirements
`codex` CLI (`codex exec`), `git`, `python3`, `jq`. `gh` + a remote enable PR mode; without a
remote the loop runs fully local (local `--no-ff` merge).
