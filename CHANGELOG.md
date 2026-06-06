# Changelog

All notable changes to this workflow are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed
- **`/close` merge gate & status lifecycle** (story `close-gate-and-backlog`, PR #2):
  - The story header no longer asserts `Status: merged` before a merge happens. It records only
    *declared* state (`proposed → approved`, terminal); whether it shipped is *observed* state owned
    by git — authoritatively the merge commit / PR-`MERGED` state — read back by deriving, never
    hand-written into the header (single source of truth; declared-vs-observed).
  - `/close` now states unambiguously that **invoking `/close` is NOT merge authorization**; a
    distinct, in-session "merge" instruction is required *after* the re-review fork, every time.
  - The "re-review or merge?" fork is **mandatory and non-skippable**, even on a clean review with
    zero fixes.

### Added
- **`shipped/<slug>` tag convention** — a best-effort, out-of-tree "this shipped" marker created at
  merge time (the merge commit / PR-`MERGED` state remains the authority).
- **`BACKLOG.md`** — staging area in front of the loop (`BUG-`/`OPS-` items) + README pointer.

### Changed
- **`/review`** decision menu/routing wording clarified: deciding fix/defer/reject is not a merge
  decision, and routing to `/close` does not authorize a merge.
- **Doctrine** (`workflow-protocol.md`, `frame`) documents the declared-vs-observed status lifecycle.

## [2026-06-03] — Bootstrap

### Added
- **Three skills** driving the Claude↔Codex review loop: `frame` (intake → spec → implement),
  `review` (gate → read-only `codex exec` with a structured-output schema → decision menu), and
  `close` (apply approved fixes → merge).
- **Guard hook** (`.claude/hooks/block-main-writes.sh`): blocks commits/pushes to the base branch and
  `--force` / `--no-verify`, wired as a `PreToolUse` hook.
- **Reviewer contract** (`AGENTS.md`): Codex's standing instructions — critique and classify, never
  fix or merge.
- **Protocol doc** (`.claude/workflow-protocol.md`): the doctrine and the loop.
- **Structured findings schema** (`.claude/skills/review/finding-schema.json`) for `codex exec review`.
- **Per-repo config** (`.claude/workflow.json`) and the `reviews/` audit trail.
- **Installer** (`install.sh`) to promote the skills and hook to `~/.claude` for use across all apps.
