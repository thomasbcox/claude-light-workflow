# shell-tooling

Date: 2026-07-01 · Branch: claude/shell-tooling · Status: approved

## Problem
Dogfooding `/dev-audit` on this repo with real tools (see `reviews/audit-2026-07-01.md`) surfaced
two related shell-tooling gaps:
1. **`install.sh:89` has a dead variable** — `local entry srcrel destpath status cls` declares
   `status`, which is never assigned or read (shellcheck **SC2034**). Confirmed: the only other
   "status" tokens in the file are the `git status` subcommand and comments.
2. **`/dev-audit`'s Table A has no Shell/Bash row** (OPS-10). A shell-heavy repo — including this
   one — gets no first-class tool selection, so `shellcheck`/`shfmt` (exactly the tools that found
   #1) fall through to the generic "cross-cutting" row and are easy to miss.

Both are the same theme: shell tooling. This story fixes #1 and closes OPS-10, and asks whether to
wire shell linting into the repo's own gate (which would have caught #1 automatically).

## In scope
- **Fix #1:** remove the unused `status` from the `local` declaration at `install.sh:89`.
- **Fix #2 / OPS-10:** add a **Shell row** to `/dev-audit` Table A in
  `.claude/skills/dev-audit/SKILL.md`, following the existing 6-column format (marker `*.sh` /
  shebang; linter/format `shellcheck`, `shfmt`; read-only column `shellcheck`, `shfmt -d`; SAST
  `semgrep`; test runner `bats` / shell test scripts).
- **Drift linter:** add an anchor in `tests/dev_audit_test.sh` for the new Shell row.
- **Backlog:** OPS-10 (already logged in `BACKLOG.md`, working-tree) is the tracked item this story
  resolves; `/close` moves it to Done.

## Non-goals
- **CI setup** — separate follow-up (now unblocked by the public flip), not this story.
- **Reformatting the 4 shell files** to shfmt style — only if Open Question 2 is approved.
- **A Markdown/docs row** in Table A — only if Open Question 3 is approved.
- No behavioral change to `/dev-audit` beyond the one new table row; no change to any other skill.

## Acceptance criteria
1. **Dead variable removed.** `install.sh:89`'s `local` declaration no longer includes `status`;
   `shellcheck --severity=warning install.sh` is clean; `./install.sh --check` still runs correctly.
2. **Shell row present.** Table A in `SKILL.md` has a Shell row keyed on `*.sh`/shebang, listing
   `shellcheck` + `shfmt` with the read-only invocations `shellcheck` and `shfmt -d` in the
   read-only column (consistent with the F1 non-destructive invariant).
3. **Linter anchors it.** `tests/dev_audit_test.sh` asserts the Shell row exists; the full gate is
   green.

*(Former AC4 — gate-wiring — dropped: OQ1 deferred to CI, see Scope decision.)*

## Test notes
- **AC1:** `shellcheck --severity=warning install.sh` exits 0; `grep -n 'local entry' install.sh`
  shows no `status`; run `./install.sh --check` to confirm the function still behaves.
- **AC2/AC3:** `bash tests/dev_audit_test.sh` green with the new Shell-row anchor; visual check that
  the row matches Table A's column shape.
- **AC4 (if approved):** the gate command includes the shellcheck step and exits 0.
- **Scope containment:** run `git diff --name-only main...HEAD` and verify no files appear beyond
  those the ACs enumerate: `install.sh`, `.claude/skills/dev-audit/SKILL.md`,
  `tests/dev_audit_test.sh`, `BACKLOG.md` (OPS-10), and this story file. *(No `.claude/workflow.json`
  — gate-wiring deferred.)*

## Open questions
_All resolved at the frame consult (2026-07-01) — see Scope decision._
1. **Wire `shellcheck` into the gate?** → **Deferred to the CI follow-up.** Keep the gate minimal
   (`bash/git/python3/jq`); shellcheck enforcement belongs in CI (now unblocked by the public flip),
   not coupled to every local run. This resolves Codex's QUESTION by making no gate-contract change.
2. **`shfmt -d` in the gate + reformat 4 files?** → **Deferred.**
3. **Markdown/docs row in Table A?** → **Deferred.**

## Scope decision (2026-07-01)
Thomas: **approve core · defer gate-wiring to CI · defer both extras.** Binding scope = the three
core ACs only (dead-var fix · Shell row · linter anchor), plus resolving OPS-10. No gate change, no
reformat, no Markdown row, no README/ARCHITECTURE requirements edit.

## Design decisions (2026-07-01)
- **Codex QUESTION (gate wiring changes the minimal tool contract) → resolved by DEFERRAL.** OQ1 is
  deferred to CI, so this story makes **no** change to `.claude/workflow.json` or the gate's
  dependency contract. The minimal-gate invariant (`bash/git/python3/jq`) is preserved. shellcheck
  enforcement is a separate CI story.
- Core shape (Shell row via the existing declarative Table A + drift-linter anchor) ratified as-is —
  no one-way doors.

## Design sketch — HOW
- **`install.sh`:** delete the `status` token from `local entry srcrel destpath status cls` — a
  one-word removal, no logic change (the function's status is `return 0` / `DRIFT_COUNT`, never that
  variable).
- **Table A (SKILL.md):** insert one row in the existing markdown table, matching the 6-column
  shape and the F1 read-only-column convention. No new structure — it's the declarative table
  doing exactly what it's designed for (a new ecosystem = a new row, not new prose).
- **Drift linter:** one `has "..." "$SKILL" "<Shell-row anchor>"` line, same pattern as the other
  Table A anchors.
- **Gate wiring:** *deferred to a CI follow-up* (OQ1) — no `tests/shell_lint.sh`, no
  `testCommand` change in this story.

## Build note (2026-07-01)
AC → file map:
- AC1 (remove unused `status` local) → `install.sh`
- AC2 (Table A Shell row, closes OPS-10) → `.claude/skills/dev-audit/SKILL.md`
- AC3 (drift-linter anchor for the Shell row) → `tests/dev_audit_test.sh`
- OPS-10 tracked item → `BACKLOG.md`

## Codex design review (2026-07-01)
Verdict: **core sketch is sound** — fixing the dead variable, adding Shell as a first-class Table A
row, and anchoring it with the existing drift-linter pattern all match this repo's Markdown-skill /
declarative-table conventions. One shape concern, on OQ1.

**QUESTION — Gate wiring changes the minimal tool contract** · one-way · nonstandard
- *Claim:* OQ1 (adding `shellcheck` to the gate) is modern and useful, but it expands the standing
  gate dependency set beyond `bash/git/python3/jq`. The spec names the trade-off, but the sketch
  doesn't make the dependency-contract change part of the acceptance surface beyond "document it."
- *Alternative:* Either **defer** shellcheck gate-wiring to a CI/tooling follow-up (keep this story
  to the Table A row + dead-var fix + manual shellcheck verification), **or** make OQ1 an explicit
  Thomas-ratified gate-contract change **with ACs** to update the README/ARCHITECTURE *requirements*
  and to define missing-`shellcheck` behavior (hard-fail vs graceful skip).
- *Win:* Preserves the repo's minimal local gate unless deliberately changed; if accepted, the new
  dependency is centralized in the public requirements, not hidden in `workflow.json`.
