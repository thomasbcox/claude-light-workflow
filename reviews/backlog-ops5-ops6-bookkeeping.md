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

- No changes to any skill, hook, config, or test file.
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
10. Diff is docs-only — only `BACKLOG.md`, `CHANGELOG.md`, `reviews/defer-to-native.md`,
    `reviews/add-changelog.md`, and this story file change.

## Test notes

- AC1–8: verified by reading the changed files.
- AC9: `bash tests/guard_test.sh` → must exit 0.
- AC10: `git diff --name-only main...HEAD` must show only the five files listed.

## Open questions

None.
