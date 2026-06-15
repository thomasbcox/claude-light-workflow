Date: 2026-06-14 · Branch: claude/drop-shipped-tag · Status: approved

# Story: Drop the `shipped/<slug>` tag — let the merge commit be the only ship record

> **Approved 2026-06-14.** Thomas: "1 mark done now; 2 delete tags." → BUG-5 moves
> to **Done** in `BACKLOG.md` in this story (resolution: obviated by removing the
> tag); and the 13 existing `shipped/*` tags (local + remote) are **deleted** as
> part of this story.

## Problem

`/close` records "this story shipped" in **two** places:

1. **Authoritative:** the `merge: <slug>` merge commit (with a `Story:` trailer) /
   the PR's `MERGED` state — atomic, owned by git.
2. **Best-effort convenience:** a pushed `shipped/<slug>` tag.

The doctrine already admits (2) is non-authoritative and that its absence means
nothing. So the tag is a **redundant second source of truth** — and it is not free:

- **It is the sole cause of BUG-5.** `/close` creates the tag *after* the merge,
  when `gh pr merge --delete-branch` has left the checkout on `main`, then
  `git push origin "shipped/<slug>"`. The guard blocks pushes from a base branch,
  so the push is denied. This forced an undocumented detached-HEAD workaround on
  every remote close (PRs #14, #15), and tempted a fix that taught the guard to
  parse refspecs (`guard-allow-tag-push` / PR #16) — which then shipped two BLOCKER
  bypasses in review. That whole branch was **abandoned (PR #16 closed unmerged)**
  in favour of this simpler cut.
- **It is a drift risk** the doctrine has to keep warning about ("a merged PR with
  a missing tag is still shipped — repair by re-tagging") — caveats that only exist
  *because* the tag exists.

Removing the tag makes "shipped" a single derived fact, makes BUG-5 impossible
(nothing pushes from `main`), and lets the guard stay simple.

## Solution

Delete the `shipped/<slug>` tag as a workflow concept. "Did story X ship?" is
**derived**, never marked:

- **Remote:** `gh pr view <PR#> --json state -q .state` → `MERGED`.
- **Either:** the merge commit is in base history —
  `git log <baseBranch> --oneline --grep "^merge: <slug>"` (non-empty ⇒ shipped).
- A `shipped/*` listing becomes `git log <baseBranch> --oneline --grep "^merge: "`.

`/close` step 5 then ends at the merge + MERGED-poll; the tag create/push/verify
lines are removed (both the remote and local-only recipes). After the merge there
is no push from `main`, so the guard is never engaged and needs **no change**.
Merge mechanics (`gh pr merge --auto`/direct, `--match-head-commit`, the MERGED
poll) and the merge-approval gate are untouched.

## In scope

- **`.claude/skills/close/SKILL.md`** — remove every `shipped/<slug>` reference
  (hard-constraint bullet, step-5 remote recipe tag create/push/verify lines,
  step-5 local-only recipe tag line, step-6/step-7 mentions). Step 7's "did it
  ship?" derivation keeps only the merge-commit / PR-`MERGED` signals.
- **`.claude/workflow-protocol.md`** — in the declared-vs-observed section and the
  "Per-repo artifacts" list, drop the tag as the convenience marker; "did it
  merge/ship?" is the merge commit / PR-`MERGED`, looked up via `git log --grep`.
- **`.claude/skills/frame/SKILL.md`** — the one-line header-doctrine reference:
  drop "+ `shipped/<slug>` tag" so it reads "owned by git (the merge commit)".
- **`README.md`** — remove the `shipped/<slug>` artifact bullet; fold its
  declared-vs-observed point into the surrounding text without the tag.
- **`BACKLOG.md`** — move **BUG-5 to Done** now, resolution = *obviated by design*
  (the tag it depended on is gone), citing this story / its PR.
- **Existing `shipped/*` tags** — delete all 13 (local + remote): a ref-only
  operation, not a tracked file change, performed during implementation and
  recorded in a `## Cleanup` note in this story.

## Non-goals

- **No verb split.** `/close` stays one command (the minimal option was chosen,
  not `/revise` + `/ship`).
- **No guard-hook change.** Main's guard is already the simple version; with the
  tag gone it is never engaged from `main`. The abandoned refspec-parsing stays
  abandoned.
- **No change to merge mechanics or the merge-approval gate.**
- **No rewriting of historical prose records** — the Done/CHANGELOG *entries* that
  mention the tag convention for past stories are history and stay as-is (only the
  refs themselves are deleted, per the decision above).
- **No CHANGELOG entry / Done-move bookkeeping for _this_ (`drop-shipped-tag`)
  story** — that is a separate bookkeeping story per the `bookkeeping-pr*`
  precedent. (BUG-5's Done-move *is* in scope here, by decision.)

## Acceptance criteria

1. **`/close` no longer creates, pushes, or verifies a `shipped/<slug>` tag.** No
   `shipped/` reference remains in `.claude/skills/close/SKILL.md`; the step-5
   recipes (remote and local-only) end at the merge / MERGED-poll.
2. **`/close` step 7 derives "shipped" from git only** — merge commit
   (`git log <base> --grep "^merge: <slug>"`) and/or PR-`MERGED` — with no tag
   lookup.
3. **Doctrine updated.** `.claude/workflow-protocol.md` no longer presents the
   `shipped/<slug>` tag as an artifact/convenience marker; declared-vs-observed is
   intact with the merge commit / PR-`MERGED` as the sole observed signal.
4. **`/frame` header doctrine** no longer references the `shipped/<slug>` tag.
5. **README** no longer lists the `shipped/<slug>` tag artifact.
6. **No `shipped/` references remain** in `.claude/skills/`, `.claude/workflow-protocol.md`,
   or `README.md`: `grep -rl 'shipped/'` over those paths returns nothing.
7. **BUG-5 is in Done** in `BACKLOG.md` (no longer an open item), resolution noted
   as obviated-by-design via this story.
8. **Gate green** and **no guard-hook change**: `bash tests/guard_test.sh` passes
   (still 19 cases), and `git diff main...HEAD -- .claude/hooks/block-main-writes.sh
   tests/guard_test.sh` is empty.
9. **All `shipped/*` tags are gone** — `git tag -l "shipped/*"` and
   `git ls-remote --tags origin "shipped/*"` both return nothing.
10. **Scope containment.** `git diff --name-only main...HEAD` shows only
    `.claude/skills/close/SKILL.md`, `.claude/skills/frame/SKILL.md`,
    `.claude/workflow-protocol.md`, `README.md`, `BACKLOG.md`, and
    `reviews/drop-shipped-tag.md`. (Tag deletion is a ref operation, not a tracked
    file, so it does not appear in the diff.)

## Test notes

- AC1/AC2/AC4: read the edited sections; confirm no `shipped/` token and that the
  recipes/derivation end at merge/PR-state.
- AC3/AC5: read the edited doctrine/README sections.
- AC6: `grep -rl 'shipped/' .claude/skills .claude/workflow-protocol.md README.md`
  → no output.
- AC7: inspect the BUG-5 line in `BACKLOG.md`.
- AC8: `bash tests/guard_test.sh` → `ALL GUARD TESTS PASSED`, `passed=19`; and the
  guard/test diff against `main` is empty.
- AC9: `git tag -l "shipped/*"` and `git ls-remote --tags origin "shipped/*"` are
  both empty.
- AC10: `git diff --name-only main...HEAD` lists only the enumerated files.
- Dogfood: this story's own `/close` will run the *new*, tag-free recipe — the
  merge should complete with no push from `main` and no guard engagement.

## Open questions

_Resolved at approval: (1) BUG-5 → Done now (obviated-by-design via this story);
(2) delete the 13 existing `shipped/*` tags (local + remote)._

## Cleanup (2026-06-14)

Deleted all 13 historical `shipped/*` tags (local + remote), per decision 2:
`auto-merge-close`, `backlog-bookkeeping`, `backlog-ops5-ops6-bookkeeping`,
`bookkeeping-pr11-pr12`, `bookkeeping-pr14-bug5`, `bookkeeping-pr8-pr9`,
`close-gate-and-backlog`, `harden-merge-and-guard`, `install-drift-check`,
`ops5-ops7-ergonomics`, `ops5-reqchecks-fallback`, `review-codex-stdin`,
`review-schema-abs-path`. Verified: `git tag -l "shipped/*"` and
`git ls-remote --tags origin "shipped/*"` both empty. (Ref-only operation — not a
tracked file change. Done from the feature branch, so the guard was not engaged.)

> **Done-row note:** BUG-5's Done row cites `PR #17` (predicted) with a `<merge>`
> sha placeholder — finalize the PR number at `/review` (PR creation) and the merge
> sha at `/close`, or in the follow-up bookkeeping story.
