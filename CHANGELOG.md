# Changelog

All notable changes to this workflow are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2026-06-06] — auto-merge-close (PR #6)

### Fixed
- **`/close` remote merge race (OPS-4)**: replaced the hand-rolled `mergeStateStatus` 5×5s poll
  loop with `gh pr merge --auto`, delegating merge timing to GitHub. Added `autoMergeAllowed`
  pre-flight check (via `gh api repos/{owner}/{repo} --jq .allow_auto_merge`) and a MERGED-state
  poll (30×10s, 5-min timeout) for synchronous confirmation. Retains `--match-head-commit` for
  drift safety.

## [2026-06-06] — harden-merge-and-guard (PR #5)

### Fixed
- **`/close` stale-head risk**: remote recipe now captures the local fix SHA, pushes HEAD before
  merging, asserts `headRefOid == localSha`, and merges with `--match-head-commit <sha>`.
- **Guard hook bypass forms**: rewrote `block-main-writes.sh` to tokenize argv and walk global git
  options (`-C`, `-c`, `--git-dir`, etc.) to the true subcommand, catching `git -C <repo> commit`,
  `git -c k=v commit`, `+refspec` force pushes, `--force-with-lease=<ref>` value forms, and
  `--mirror`. False-positive on benign commands (e.g. `grep 'git push'`) eliminated.
- **Docs**: README and `workflow-protocol.md` no longer advertise the retired `codex exec review`
  subcommand; updated to `codex exec -s read-only --output-schema …`.

### Added
- **Guard test harness** (`tests/guard_test.sh`): 19 JSON-payload cases covering bypass forms
  (denied) and false-positive forms (allowed), wired as the repo's `testCommand`.

## [2026-06-05] — backlog-bookkeeping (PR #4)

### Changed
- **`BACKLOG.md`**: BUG-D1/D2/D3 moved to Done (shipped PR #2); open bugs section cleared.
- **`CHANGELOG.md`**: `[Unreleased]` section populated with the `close-gate-and-backlog` fixes.

## [2026-06-03] — close-gate-and-backlog (PR #2)

### Fixed
- **`/close` merge gate & status lifecycle**:
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
- **Structured findings schema** (`.claude/skills/review/finding-schema.json`) for the Codex review handoff.
- **Per-repo config** (`.claude/workflow.json`) and the `reviews/` audit trail.
- **Installer** (`install.sh`) to promote the skills and hook to `~/.claude` for use across all apps.
