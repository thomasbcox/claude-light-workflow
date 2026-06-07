Date: 2026-06-07 · Branch: claude/ops5-ops7-ergonomics · Status: approved
Approved: Thomas approved scope as written, 2026-06-07 ("proceed with this as the approved spec"), after resolving the required-check-detection question (classic branch protection only; rulesets out of scope) and flagging the CI-status gap as a separate backlog item (OPS-8).

## Problem

Two small workflow-ergonomics defects in the skill instructions, bundled because each is
~1 AC, neither touches the hook or tests, and both sharpen tools (`/close`, `/frame`) the
rest of the backlog will lean on.

- **OPS-5** — `/close`'s merge pre-flight ([.claude/skills/close/SKILL.md:28-30](../.claude/skills/close/SKILL.md))
  aborts whenever `allow_auto_merge` is `false` on the repo. That is too strict: when there
  are no required status checks, a direct `gh pr merge` would succeed immediately, so there
  is nothing to delegate timing for. The abort should fire only when auto-merge is disabled
  *and* the base branch has at least one required status check.
- **OPS-7** — `/frame`'s spec template ([.claude/skills/frame/SKILL.md:33](../.claude/skills/frame/SKILL.md))
  gives no guidance against counting files in `## Test notes`. File counts ("must show only
  N files") are a DRY violation: they restate the AC's file list and go stale on any scope
  change. Scope-containment ACs should instead be verified by `git diff --name-only` against
  the AC's enumerated list. (This regression was already observed and corrected by hand in
  the `backlog-ops5-ops6-bookkeeping` story's N1 fix; OPS-7 bakes the lesson into the template.)

## In scope

1. `.claude/skills/close/SKILL.md` — replace the auto-merge pre-flight with a three-way
   branch: (a) auto-merge enabled → existing `--auto` path; (b) auto-merge disabled + no
   required checks → direct `gh pr merge` (no `--auto`), merges immediately; (c) auto-merge
   disabled + ≥1 required check → abort with guidance. Update the surrounding prose comment.
2. `.claude/skills/frame/SKILL.md` — extend the `## Test notes` template bullet with
   guidance to verify scope-containment ACs via `git diff --name-only` against the AC's file
   list, never a restated file count.

## Non-goals

- No changes to the guard hook, `workflow.json`, tests, README, or `workflow-protocol.md`.
- Not touching the `/close` poll-for-`MERGED` loop, tag step, or local-only path — only the
  pre-flight + the merge invocation it guards.
- Not addressing GitHub *rulesets* as a required-check source beyond classic branch
  protection (see Open questions).
- Not re-running or re-writing past stories whose test notes already used file counts.

## Acceptance criteria

1. In `.claude/skills/close/SKILL.md`, the merge step no longer unconditionally aborts when
   `allow_auto_merge` is `false`.
2. The merge step detects required status checks on the base branch (classic branch
   protection), treating any absent or inaccessible protection response — including the
   `403 Upgrade to GitHub Pro` returned for free-account private repos, and `404` — as zero
   required checks.
3. When auto-merge is disabled and there are zero required checks, the step performs a direct
   `gh pr merge` (without `--auto`) that ships exactly the reviewed HEAD (retains
   `--match-head-commit "$localSha"`).
4. When auto-merge is disabled and there is ≥1 required check, the step aborts with a message
   explaining the condition and the remedy.
5. When auto-merge is enabled, behavior is unchanged from today (the existing `--auto` path).
6. In `.claude/skills/frame/SKILL.md`, the `## Test notes` template bullet instructs that
   scope-containment ACs be checked with `git diff --name-only` against the AC's enumerated
   file list, and explicitly warns against restating a file count.

## Test notes

- AC1–6: verified by reading the two changed files; the skills are executable prose, so there
  is no unit harness for them — correctness is read-confirmed and the bash logic is traced by
  inspection.
- AC2: confirm the chosen detection command degrades to zero on a 404 (`2>/dev/null || echo 0`
  or equivalent), so repos without branch protection take the direct-merge path, not an error.
- Gate: `bash tests/guard_test.sh` must still pass (no hook/test changes, so it should be
  unaffected).
- Scope containment: run `git diff --name-only main...HEAD`; verify no files appear beyond
  those listed in the In-scope section (`.claude/skills/close/SKILL.md`,
  `.claude/skills/frame/SKILL.md`) plus this story file.

## Open questions

None. (Resolved 2026-06-07: detect required checks via classic branch protection only;
treat any failure — incl. the `403 Upgrade to GitHub Pro` on free-account private repos — as
zero. GitHub *rulesets* as a required-check source are explicitly out of scope and noted as a
known limitation in the skill comment, to revisit only if the repo goes public/paid or adopts
rulesets.)

## Build note (2026-06-07)

AC→file map:
- AC1–5 (OPS-5: three-way merge pre-flight — auto-merge path / direct-merge / abort-on-
  required-checks; required-check detection degrading to zero on 403/404; stale section prose
  corrected): `.claude/skills/close/SKILL.md`
- AC6 (OPS-7: `## Test notes` template warns against file counts for scope-containment ACs,
  directs `git diff --name-only` against the AC's file list): `.claude/skills/frame/SKILL.md`

## Codex review (2026-06-07, base main, HEAD 42df681)

**Summary:** Reviewed `git log --oneline main..HEAD`, `git diff main...HEAD`, and the spec
against the approved scope. The diff is limited to the two in-scope skill files plus the story
file; no spec violations found in the changed instructions. (Codex noted it could not run the
guard gate itself — the read-only sandbox blocks `mktemp`/`git init` — so that is an
environmental limitation, not a branch finding. The gate was run green outside the sandbox:
19/19.)

**Findings:** none — empty findings array.
