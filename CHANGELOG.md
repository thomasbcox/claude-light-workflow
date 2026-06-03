# Changelog

All notable changes to this workflow are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
