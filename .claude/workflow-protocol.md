# Lightweight Claude↔Codex Review Protocol

A small, human-controlled development loop. One idea above all:
**the actor that builds is never the actor that approves.**

> This is the deploy source. The live copy every app reads is `~/.claude/workflow-protocol.md`
> (placed there by `install.sh`). Keep them in sync via the installer.

## Actors
- **Thomas** — owner / decider. Approves scope, decides each finding's disposition, approves the merge.
- **Claude** — builder / scribe. Writes the spec, the code, and the audit trail; calls Codex; applies approved fixes; merges on Thomas's word. Never self-approves scope or merge.
- **Codex** — independent reviewer (`codex exec -s read-only` with a structured-output schema; the canonical command lives in `review/SKILL.md`). Critiques and classifies; never fixes or merges.
- **Tests / gate** — the mechanical judge. Objective pass/fail. Green never implies business approval.
- **The repo** — the one source of truth; the per-branch story file `reviews/<slug>.md` is the audit trail.

## The loop
1. **`/frame`** — Thomas states a need → Claude drafts a spec on a feature branch → **Thomas approves scope** → Claude implements AC-by-AC.
2. **`/review`** — gate goes green → `codex exec -s read-only --output-schema …` produces structured findings → Claude presents a decision menu → **Thomas decides per finding**.
3. **`/close`** — Claude applies only approved fixes → gate green → re-review (Thomas's call) or **Thomas approves merge** → record the release on the branch (CHANGELOG + BACKLOG-Done) → merge + cleanup.

Loop 2 ↔ 3 as many rounds as needed.

## Rules (the whole thing in five lines)
1. The repo is authoritative; `reviews/<slug>.md` is the trail (spec → build → findings → decisions, appended).
2. Claude builds and self-fixes to green; Codex judges; Thomas decides.
3. The human decides exactly twice: **scope** (after `/frame`) and **merge** (in `/close`). A prior general "yes" never counts for merge.
4. No AI grades its own homework — the builder is never the approver.
5. No direct commits/pushes to the base branch; the feature-branch + merge path is the only way in (enforced by the guard hook).

> **Records ride with the merge, not after it.** `/close` writes the `CHANGELOG.md` entry and the
> `BACKLOG.md` Done-move on the feature branch *after* the merge instruction, so they arrive on the
> base branch as part of the merge commit — never a separate post-merge base write, never speculative
> (a re-review choice never reaches them; the story header is never set to `merged`).
> **No bookkeeping-only stories:** open a follow-up only for a real defect or a new decision, never
> solely to reconcile a previous story's records.

## Status & shipped-state (single source of truth)
The story-file header records only **declared** state — `proposed → approved`, with `approved`
as the terminal value. It never stores **observed** state. "Did it merge/ship?" is owned by git,
not the file. The shipped signal is the merge commit (`merge: <slug>`, with a `Story:` trailer) /
the PR's `MERGED` state — atomic: it exists or it doesn't, and it is the **single** source of
truth. Derive a shipped check with `git log <base> --oneline --grep "^merge: <slug>"` (or
`gh pr view --json state`); list everything shipped by dropping the `<slug>`. The header can never
drift from reality because it never holds the merge fact — the same discipline as Kubernetes
`spec` (declared) vs `status` (observed).

## Per-repo artifacts
- `reviews/<slug>.md` — the story file / audit trail.
- `reviews/<slug>.codex.json` — raw structured Codex output per round.
- `.claude/workflow.json` — config: `baseBranch`, `branchPrefix`, `testCommand`, `codexModel`.
- `AGENTS.md` — Codex's reviewer contract (tunable per repo).

## Global (installed once, shared by every app)
- `~/.claude/skills/{frame,review,close}/` — the three skills (+ `review/finding-schema.json`).
- `~/.claude/hooks/block-main-writes.sh` — the guard hook, wired in `~/.claude/settings.json`.
- `~/.claude/workflow-protocol.md` — this document.
- `~/.claude/workflow-AGENTS-template.md` — the contract template `/frame` copies into new repos.
