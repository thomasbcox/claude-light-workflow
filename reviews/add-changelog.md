Date: 2026-06-03 · Branch: claude/add-changelog · Status: approved

> Approved by Thomas (2026-06-03): "approve - go implement it"

## Problem
The repo has no human-readable record of how the workflow itself changes over time. Git history
exists, but a curated `CHANGELOG.md` gives readers (and future apps adopting this workflow) a quick,
intentional summary of notable changes. This story is also the **shakeout** of the Claude↔Codex
review loop — a small, real change driven end-to-end to validate the `codex exec review` handoff.

## In scope
- A new `CHANGELOG.md` at the repo root.
- One seed entry documenting the initial bootstrap of the workflow.
- "Keep a Changelog"-style structure (an `## [Unreleased]` heading + a dated bootstrap entry).

## Non-goals
- No automation, tooling, or git hooks to maintain the changelog.
- No backfilling granular history beyond the single bootstrap entry.
- No links to a `MEMORY.md`, README badges, or release tagging.

## Acceptance criteria
1. `CHANGELOG.md` exists at the repo root and is valid Markdown.
2. It contains an `## [Unreleased]` section for future changes.
3. It contains a dated entry (2026-06-03) describing the bootstrap: the 3 skills, the guard hook,
   the reviewer contract, the protocol doc, and the installer.
4. The format is consistent and human-readable (Keep a Changelog conventions: Added/Changed/etc.).

## Test notes
- AC1–AC4 are verified by reading the file; the configured gate (placeholder `true`) is run for
  process parity in `/review`.
- No code is added, so there is nothing executable to test beyond the gate.

## Open questions
- None. This is a deliberately minimal shakeout change. (Confirm the date/scope is fine.)
