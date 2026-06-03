Date: 2026-06-03 · Branch: claude/add-changelog · Status: approved

> Approved by Thomas (2026-06-03): "approve - go implement it"
> Scope expanded by Thomas (2026-06-03): fold in the workflow fixes the shakeout surfaced
> (corrected `/review` codex command + strict finding schema) and re-review the full diff.

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

## Build note (2026-06-03)
AC→file map:
- AC1–AC4 → `CHANGELOG.md` (new, root).
- Spec/trail → `reviews/add-changelog.md`.

`git diff --stat main...HEAD`:
```
 CHANGELOG.md             | 20 ++++++++++++++++++++
 reviews/add-changelog.md | 34 ++++++++++++++++++++++++++++++++++
 2 files changed, 54 insertions(+)
```
Gate: placeholder (`echo … && true`) — no executable code added.

## Codex review (2026-06-03, base main, HEAD f5c3b90)
Summary: The changelog mostly satisfies the original ACs, but the expanded workflow-fix scope is only
partially reflected — stale `codex exec review` references remain in the review skill and changelog,
and the Build note no longer matches the actual four-file diff. (Raw: `reviews/add-changelog.codex.json`.)

| # | Severity | File:line | Claim |
|---|---|---|---|
| 1 | IMPORTANT | `.claude/skills/review/SKILL.md`:28 | Skill description/intro still say it runs review via `codex exec review`, which the body now forbids — internal contradiction. |
| 2 | IMPORTANT | `CHANGELOG.md`:12 | Bootstrap entry still cites `codex exec review`, pointing future adopters at the retired command. |
| 3 | IMPORTANT | `reviews/add-changelog.md`:43 | Build note diff-stat shows 2 files; the real diff is 4 (adds SKILL.md + finding-schema.json). Stale audit trail. |
