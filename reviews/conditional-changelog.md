# conditional-changelog

Date: 2026-07-01 · Branch: claude/conditional-changelog · Status: approved

## Problem
`/close` step 5(b) **unconditionally** writes a `CHANGELOG.md` entry — it assumes every repo keeps a
hand-maintained changelog. That's the skill's default convention, not a repo law. For this workflow,
"what shipped and why" is already recorded **twice** — in each `reviews/<slug>.md` and in the
`merge: <slug>` commit's `Story:` trailer — so a hand-maintained changelog is a **third copy that
drifts**, the same self-referential staleness the workflow fights elsewhere (why the build note
dropped `git diff --stat`; why bookkeeping-only stories are banned). DRY is a stated value.

Two coupled changes: **(1)** make `/close`'s CHANGELOG step **conditional** so the skill respects each
repo's local convention (write only if the repo keeps a changelog); **(2)** **retire this repo's own
`CHANGELOG.md`**, since by that same argument it's the redundant third copy with no audience yet
(pre-release, single-developer). `git log <base> --grep "^merge: "` is the changelog when one is
ever wanted.

## In scope
- **Part 1 — make `/close` conditional** (`.claude/skills/close/SKILL.md`): the step-5(b) CHANGELOG
  entry is written **only when a `CHANGELOG.md` already exists** at the repo root; when absent, skip it
  (do **not** create one) — the merge commit + story file are the ship record. Reword the related
  lines (the "no tracked backlog item ⇒ CHANGELOG only" clause; the step-6 "release records" note).
- **Part 2 — retire this repo's changelog:** `git rm CHANGELOG.md`, and update the repo's own docs
  that describe `/close` as always writing it — `BACKLOG.md` (lifecycle line) and
  `.claude/workflow-protocol.md` — so no doc claims a changelog is always produced.

## Non-goals
- **Not** removing the CHANGELOG capability from `/close` — repos that *do* keep a changelog still get
  entries. This makes it *conditional*, not gone.
- **Not** touching the `reviews/` audit trail (frozen history that mentions CHANGELOG) or
  README/ARCHITECTURE (they don't reference it).
- **No** new config surface if avoidable — prefer the file's presence as the signal (see OQ1).
- Not changing the `BACKLOG-Done` half of step 5(b) (that stays conditional on a tracked item), nor
  any other `/close` behavior.

## Acceptance criteria
1. **CHANGELOG step is conditional.** `close/SKILL.md` step 5(b) writes the CHANGELOG entry **only if
   a `CHANGELOG.md` exists**; when absent it explicitly skips (creates nothing) and names the merge
   commit + story file as the ship record. The `AUDIT-`/generic-backlog wording on the adjacent line
   is preserved (the `dev_audit_test.sh` anchor still passes).
2. **This repo's `CHANGELOG.md` is removed.** `CHANGELOG.md` no longer exists; nothing in the repo's
   own docs (outside `reviews/`) still claims `/close` always writes one.
3. **Docs coherent.** `BACKLOG.md`'s lifecycle line and `.claude/workflow-protocol.md`'s `/close`
   description describe the changelog as **optional / per repo convention** (and this repo's ship
   record as the merge commit + story file).
4. **Gate green.** `bash tests/guard_test.sh && … reviewer_test.sh && … dev_audit_test.sh` passes
   (no test references CHANGELOG; the `AUDIT-` anchor in `dev_audit_test.sh` still holds).

## Test notes
- **AC1:** read `close/SKILL.md` step 5(b) — the CHANGELOG write is gated on `CHANGELOG.md` existing,
  with an explicit skip-and-don't-create branch; `grep` confirms `AUDIT-` still present in that file.
- **AC2:** `test ! -f CHANGELOG.md`; `git diff --name-only main...HEAD` shows `CHANGELOG.md` deleted;
  `grep -rl CHANGELOG` over the repo excluding `reviews/` shows only the (updated) skill + docs, none
  asserting an always-write.
- **AC3:** inspect the reworded `BACKLOG.md` line 11 and `workflow-protocol.md` lines.
- **AC4:** run the gate.
- **Scope containment:** `git diff --name-only main...HEAD` shows only
  `.claude/skills/close/SKILL.md`, `CHANGELOG.md` (deleted), `BACKLOG.md`,
  `.claude/workflow-protocol.md`, and this story file.

## Open questions
1. **Gating signal** — **file presence** (`[ -f CHANGELOG.md ]`) vs a `.claude/workflow.json` flag.
   **Recommend file-presence:** the file's existence *is* the convention, single source of truth, no
   new config to drift. (A flag adds surface and can disagree with reality.)
2. **Global vs local effect** — `close/SKILL.md` is a global skill (deployed via `install.sh`), so
   Part 1 becomes the estate-wide behavior once redeployed. That's intended (every repo respects its
   own convention). Flagging it, not questioning it.

## Decisions (2026-07-02, base main, HEAD f8584e6)
Approach clean; one correctness finding approved as **fix** (line-level wording, not a redesign →
`/close` applies it, then re-review-or-merge fork):
- **Zero-record path wording (5(c)/(d)) → FIX.** Generalize `close/SKILL.md` step 5(c)/(d) around the
  merge candidate ("Re-gate HEAD" / "Merge the gated HEAD"; "approved fixes + any release records") so
  the no-record-commit path is consistent end-to-end — completing the AC1 fix.

## Codex review (2026-07-02, base main, HEAD f8584e6) — correctness pass
Summary: file-presence gate ✓, `CHANGELOG.md` deleted ✓, `BACKLOG.md`/`workflow-protocol.md` coherent
✓, `AUDIT-` anchor preserved ✓. **One finding** — the zero-record path is only half-worded.

**IMPORTANT — Zero-record path still assumes a record commit in later step wording** ·
`close/SKILL.md` step 5(c)/(d)
- *Claim:* Step 5(b) now correctly makes **no** record commit when there's no `CHANGELOG.md` and no
  tracked item, but step 5(c) still says "Re-gate **the record commit**" and 5(d) calls the merge
  target the "**gated record HEAD**" / "approved fixes **+ records**". In the zero-record case that HEAD
  contains no release records — internally inconsistent on the exact edge AC1 introduced.
- *Suggest:* Generalize 5(c)/(d) around the merge candidate: "Re-gate **HEAD**" / "Merge the **gated
  HEAD**"; change the remote comments to "approved fixes **+ any release records**".

## Codex approach review (2026-07-02, base main, HEAD f8584e6) — CLEAN
Verdict: **approach is sound.** Coherent declarative record set — `CHANGELOG.md` gated by root
file-presence, `BACKLOG.md` by a tracked item, commit only when ≥1 record edit exists; the zero-record
path is first-class ("no record commit, proceed on the already-gated HEAD"). `BACKLOG.md` +
`workflow-protocol.md` agree — no live doc outside `reviews/` still claims an always-write; both keep
"records ride with the merge" while allowing no record commit. `CHANGELOG.md` deleted; `AUDIT-` anchor
preserved; no new config/dependency. **Zero findings** (a minor note that 5(c)/5(d) wording is slightly
imprecise, "not a merge-shape footgun" — no finding). Correctness proceeds.
*(Live: PR #26's `gate` passed in 8s.)*

## Build note (2026-07-02)
AC → file map:
- AC1 (conditional CHANGELOG + declarative record set / no empty commit) → `.claude/skills/close/SKILL.md`
- AC2 (retire this repo's changelog) → `CHANGELOG.md` (deleted)
- AC3 (docs coherent — changelog optional) → `BACKLOG.md`, `.claude/workflow-protocol.md`
- AC4 (gate green; `AUDIT-` anchor holds) → verified, no file

## Scope decision (2026-07-01)
Thomas: **approve + fix the finding.** Scope = Part 1 (conditional CHANGELOG via file-presence) +
Part 2 (retire this repo's `CHANGELOG.md` + update `BACKLOG.md`/`workflow-protocol.md`), **plus**
Codex's zero-record-path fix (declarative record set; no record commit when there are zero edits).

## Design decisions (2026-07-01)
- **Gating signal (OQ1) → file-presence** (ratified): `/close` writes CHANGELOG only if `CHANGELOG.md`
  exists; no `workflow.json` flag.
- **Codex IMPORTANT (zero-record close path) → FIX.** Step 5(b) becomes a declarative record set —
  CHANGELOG if present, BACKLOG if a tracked item; **commit the record edits only if any, else make no
  record commit** and proceed on the already-gated HEAD. Required for this story's own `/close` (it has
  no tracked item and retires the CHANGELOG → zero record edits).
- Global-skill effect (OQ2) acknowledged: Part 1 is estate-wide once redeployed — intended.

## Codex design review (2026-07-01)
Verdict: **core shape sound** — file-presence is the right DRY signal (a `workflow.json` flag would be
another drifting source); the retirement edit set (`close/SKILL.md` + `BACKLOG.md` +
`workflow-protocol.md`; README/ARCHITECTURE need nothing) is coherent and complete. One procedural gap
to tighten first.

**IMPORTANT — Make the zero-record close path explicit** · two-way · kludgy · `close/SKILL.md` step 5(b)/(c)
- *Claim:* Step 5(b) currently relies on an **unconditional** record edit (CHANGELOG is always written,
  so there's always something to commit). Once CHANGELOG is optional, a repo with **no `CHANGELOG.md`
  and a story with no tracked backlog item** has **zero** record edits — and if the step still says
  "commit the record changes," Claude hits a **no-op commit failure** or makes an **empty bookkeeping
  commit**, cutting against the new "merge commit + story file are the ship record" doctrine.
  *(Note: this story is itself that case — no tracked backlog item, and it retires this repo's
  CHANGELOG — so its own `/close` is the first to hit this path.)*
- *Alternative:* Reword step 5(b) as a small **declarative record set**: update `CHANGELOG.md` only if
  present; update `BACKLOG.md` only if a tracked item is resolved; then **commit the record edits if
  any — if the set is empty, make no record commit** and proceed to the re-gate/merge on the
  already-gated HEAD. Keep 5(c) gating whatever HEAD will be merged.
- *Win:* Removes the empty-commit/error path the optional changelog introduces; makes the
  no-changelog/no-backlog case first-class, no new config.

## Design sketch — HOW
- **Part 1 (`close/SKILL.md` step 5(b)):** gate the CHANGELOG bullet on `CHANGELOG.md` existing —
  "*if the repo keeps a `CHANGELOG.md`*, add the dated entry …; **otherwise skip it (do not create
  one)** — the `merge: <slug>` commit + `reviews/<slug>.md` are the ship record." Adjust the adjacent
  "no tracked backlog item ⇒ CHANGELOG entry only" clause to "⇒ nothing to record beyond the merge
  commit (+ CHANGELOG if the repo keeps one)". Keep the `BUG-/OPS-/AUDIT-` wording intact (linter
  anchor). Touch the step-6 "release records (CHANGELOG / BACKLOG-Done)" aside to "(CHANGELOG if kept
  / BACKLOG-Done if tracked)".
- **Part 2 (retire):** `git rm CHANGELOG.md`. Update `BACKLOG.md` line 11 (drop "adds the CHANGELOG.md
  entry" as an always-step; describe the ship record as the merge commit + story, changelog optional).
  Update `.claude/workflow-protocol.md` lines 19 + 39 similarly (the `/close` record step + the
  "records ride with the merge" note become "CHANGELOG if the repo keeps one").
- **No new config, no new file, no logic in code** — this is instruction-doc editing + one file
  deletion. The gating "mechanism" is prose Claude follows (`/close` is a Markdown procedure), matched
  to the file-presence check.
