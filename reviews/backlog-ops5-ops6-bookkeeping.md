Date: 2026-06-07 · Branch: claude/backlog-ops5-ops6-bookkeeping · Status: approved
Approved: Thomas approved scope as written, 2026-06-07. (Implementation preceded spec commit — branch was built interactively before story file was written.)

## Problem

Several records fell out of sync during the `auto-merge-close` (PR #6) session, and two new
backlog items were identified. Specifically:

- `BACKLOG.md` OPS-4 row still describes the old (broken) behavior in present tense and is
  listed as Open, not Done.
- `BACKLOG.md` has no OPS-5 (auto-merge preflight too strict) or OPS-6 (guard hook gaps).
- OPS-6 as initially drafted described the old string-matcher hook; Codex audit corrected it
  to the two confirmed remaining gaps (hardcoded branch names; wrapper-prefix bypass).
- `BACKLOG.md` lifecycle sentence points to `.story.md` files; current `/frame` writes
  `reviews/<slug>.md`.
- `CHANGELOG.md` `[Unreleased]` is empty; PRs #4, #5, #6 are unrecorded.
- `CHANGELOG.md` bootstrap entry names the retired `codex exec review` subcommand.
- `reviews/defer-to-native.md` and `reviews/add-changelog.md` carry `Status: merged`,
  violating the declared-vs-observed doctrine established in PR #2.

## In scope

1. `BACKLOG.md` — move OPS-4 to Done; add OPS-5 and OPS-6 (corrected); fix lifecycle
   sentence; fix "not yet storied" sub-header reference.
2. `CHANGELOG.md` — backfill dated entries for PRs #4, #5, #6; fix bootstrap `codex exec
   review` reference.
3. `reviews/defer-to-native.md`, `reviews/add-changelog.md` — correct `Status: merged` →
   `Status: approved`.

## Non-goals

- No changes to hook, config, or test files.
- No changes to README or `workflow-protocol.md` (those docs are out of scope here; OPS-6
  doc-softening is a separate story when the hook is fixed).
- Not fixing the underlying issues OPS-5/OPS-6 describe — this story only records them.

## Acceptance criteria

1. `BACKLOG.md` Done table contains an OPS-4 row citing PR #6 / `499d6b6`.
2. OPS-4 does not appear in the open table.
3. `BACKLOG.md` open table contains OPS-5 (auto-merge preflight) and OPS-6 (guard gaps:
   hardcoded branch names + wrapper prefix bypass).
4. OPS-6 description references the two confirmed gaps, not "string-matcher."
5. `BACKLOG.md` lifecycle sentence references `reviews/<slug>.md`, not `.story.md`.
6. `CHANGELOG.md` contains dated entries for PR #4 (`backlog-bookkeeping`), PR #5
   (`harden-merge-and-guard`), and PR #6 (`auto-merge-close`).
7. `CHANGELOG.md` bootstrap entry no longer mentions `codex exec review`.
8. `reviews/defer-to-native.md` and `reviews/add-changelog.md` headers read
   `Status: approved`.
9. `bash tests/guard_test.sh` passes (19/19).
10. Diff touches only `BACKLOG.md`, `CHANGELOG.md`, `reviews/defer-to-native.md`,
    `reviews/add-changelog.md`, `.claude/skills/review/SKILL.md`, and this story file.
11. `/review` step 2 in `.claude/skills/review/SKILL.md` no longer instructs appending
    a `git diff --stat` block to the build note — only the AC→file map and gate result.

## Test notes

- AC1–8: verified by reading the changed files.
- AC9: `bash tests/guard_test.sh` → must exit 0.
- AC10: `git diff --name-only main...HEAD` must show only the five files listed.

## Open questions

None.

## Build note (2026-06-07)

AC→file map:
- AC1–5 (OPS-4 to Done, OPS-5/OPS-6 added, lifecycle fix): `BACKLOG.md`
- AC6–7 (CHANGELOG backfill, bootstrap fix): `CHANGELOG.md`
- AC8 (Status: merged → approved): `reviews/defer-to-native.md`, `reviews/add-changelog.md`
- AC9 (gate): `bash tests/guard_test.sh` → 19/19 passed
- AC10 (docs-only diff): confirmed via `git diff --name-only main...HEAD`

Gate: `bash tests/guard_test.sh` → 19/19 passed.

*(Diffstat omitted — derivable via `git diff --stat main...HEAD`; see also I1 in Codex review below.)*

## Codex review (2026-06-07, base main, HEAD 05403c2)

**Summary:** Functional bookkeeping changes satisfy the stated AC1–8 and AC10 criteria. One finding: the build note diffstat was captured before the story file reached its final size.

### IMPORTANT

**I1 — Build note diffstat is stale**
- File: `reviews/backlog-ops5-ops6-bookkeeping.md` line 77
- Claim: Build note records `reviews/backlog-ops5-ops6-bookkeeping.md | 62` and `5 files changed, 106 insertions(+), 10 deletions(-)`, but `git diff --stat main...HEAD` reports the story file as 80 lines and totals 124 insertions.
- Suggestion: Regenerate from `git diff --stat main...HEAD` so the audit trail matches the reviewed branch scope.

## Decisions (2026-06-07)

- I1: **fix** — folded into scope: drop diffstat from `/review` step 2 (self-referential staleness); fix current build note; add AC11 to spec.

## Build note (2026-06-07, re-review round 2, base a009e58)

Delta since last review: one commit (`28c9199`) — I1 fix only.

AC→file map (delta):
- AC11 (`/review` step 2 no longer instructs diffstat): `.claude/skills/review/SKILL.md`
- Current build note fixed (stale stat replaced with gate result): `reviews/backlog-ops5-ops6-bookkeeping.md`
- Spec updated (Non-goals, AC10, AC11 added): `reviews/backlog-ops5-ops6-bookkeeping.md`

Gate: `bash tests/guard_test.sh` → 19/19 passed.
