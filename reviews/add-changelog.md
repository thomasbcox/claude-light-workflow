Date: 2026-06-03 · Branch: claude/add-changelog · Status: merged

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

## Build note (2026-06-03, updated for expanded scope)
AC→file map:
- AC1–AC4 (changelog) → `CHANGELOG.md` (new, root).
- Expanded scope (workflow fix) → `.claude/skills/review/SKILL.md` (corrected codex command),
  `.claude/skills/review/finding-schema.json` (strict schema).
- Spec/trail → `reviews/add-changelog.md`, `reviews/add-changelog.codex.json`.

Substantive `git diff --stat main` (excludes the trail files):
```
 .claude/skills/review/SKILL.md            | 11 +++---
 .claude/skills/review/finding-schema.json |  9 +++--
 CHANGELOG.md                              | 21 ++++++++++
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

## Decisions (2026-06-03)
Thomas: "fix all three as recommended."
- Finding 1 (SKILL.md stale subcommand wording) → **FIX**
- Finding 2 (CHANGELOG.md stale command) → **FIX**
- Finding 3 (Build note stale diff-stat) → **FIX**

## Fixes (2026-06-03)
- Finding 1: reworded `review/SKILL.md` frontmatter description + intro to the read-only
  `codex exec` + structured-output handoff (removed the obsolete `codex exec review` self-reference).
- Finding 2: reworded the `CHANGELOG.md` bootstrap entry's `review` line to the corrected handoff.
- Finding 3: regenerated the Build note's AC→file map and diff stat to the actual 4-file scope.
All three were doc/wording only — no code or workflow-authority changes.

## Codex re-review (2026-06-03, diff-only, base f5c3b90, HEAD 11d9121)
Clean — 0 findings. "The three prior IMPORTANT findings are resolved in the diff-only re-review."
(Raw: `reviews/add-changelog.codex.json`.)
