Date: 2026-06-05 · Branch: claude/close-gate-and-backlog · Status: approved

# close-gate-and-backlog — fix the merge gate / status lifecycle and formalize the backlog

## Problem

Two related strands, bundled into one story because they touch the same skill files and audit-trail conventions.

**A. Merge-gate defects (BUG-D1/D2/D3)** — sourced from [`workflow-skill-defects.story.md`](../workflow-skill-defects.story.md).
The `frame→review→close` loop is supposed to guarantee a merge never happens without an unambiguous, in-the-moment human "merge" instruction. Three defects in `close/SKILL.md` undermine that:
- **D1** — step 2 pre-sets `Status: merged` speculatively, before the step-4 "re-review or merge?" fork is resolved. If Thomas chooses re-review, the branch carries a `merged` header while still unmerged. The trail records a false state (the independent reviewer has flagged this externally).
- **D2** — the hard constraint *"never merge without explicit approval in the current session"* never says whether invoking `/close` itself counts as that approval. The wording is squishy.
- **D3** — that ambiguity gets acted on: observed `/close` running the gate, committing, and merging immediately, skipping the step-4 fork. The command invocation was treated as consent.

**B. Backlog formalization (OPS housekeeping)** — there is no staging artifact in front of the loop. The identified bugs and tooling improvements live only in chat. We add a committed `BACKLOG.md` as the staging area (already drafted, untracked on this branch) and make it discoverable from the README.

## In scope

1. `.claude/skills/close/SKILL.md` — fix D1/D2/D3 per the ACs below, plus the shipped-tag + derived-status mechanism (AC8/AC9).
2. `.claude/skills/review/SKILL.md` — minimal matching tweak to the decision-menu / routing wording so the gate is consistent across the two skills (only what AC2/AC3 require; no redesign).
2b. `.claude/workflow-protocol.md` + `.claude/skills/frame/SKILL.md` — document the declared-vs-observed status lifecycle (AC10).
3. `BACKLOG.md` — include the already-drafted staging-area artifact (commit it; minor edits as needed for consistency with the chosen AC1 resolution).
4. `README.md` — add a discoverability pointer to `BACKLOG.md` in the Artifacts section.
5. `workflow-skill-defects.story.md` — commit the discovery doc to the branch as part of the trail (already untracked).

## Non-goals

- Redesigning `/frame` or `/review` beyond the consistency tweak in scope item 2.
- The base-branch write-protection hook (`block-main-writes.sh`) — already works; out of scope.
- Building the OPS-1/2/3 tooling (drift detection, version stamping). Those stay as backlog lines; this story only *records* them in `BACKLOG.md`, it does not implement them.
- Deploying via `install.sh` (that's a post-merge action, not part of this change).

## Acceptance criteria

1. **The story header never asserts `merged` — declared state only (SSOT).** `close/SKILL.md` records only *declared* state in the header (`proposed` → `approved`); `approved` is terminal. Whether the branch shipped is *observed* state owned by git, never hand-written into the header. The header cannot drift from reality because it never stores the merge fact. (Industry option b: single source of truth / declared-vs-observed, à la Kubernetes `spec` vs `status`.)
2. **Unambiguous merge-approval gate.** `close/SKILL.md` states explicitly, in one sentence, that **invoking `/close` is NOT merge authorization**. A distinct, affirmative human merge instruction (the word "merge" or equivalent) is required **after** the step-4 fork is presented, **every** time. A prior or general "yes" does not count; the command invocation does not count.
3. **Mandatory, non-skippable fork.** `close/SKILL.md` makes clear that step 4 must present "re-review or merge?" and **stop** for Thomas's answer — even when there are zero approved fixes to apply (clean review). The clean-review path may not fast-path to merge.
4. **(Recommended) Trail/merge consistency guard.** `close/SKILL.md` notes that the `merged` status and the actual merge must be consistent at every point a reader could observe the branch; if they cannot be made atomic, the wording must not assert a merge that has not occurred.
5. **`BACKLOG.md` committed** as the staging-area artifact, listing BUG-D1/D2/D3 (cross-linked to the defects story) and OPS-1/2/3, with the lifecycle and id conventions described.
6. **README points to `BACKLOG.md`** from the Artifacts section, one line, consistent with the existing artifact entries.
7. **`review/SKILL.md` consistency tweak** applied so its decision-menu/`/close` routing wording does not imply that proceeding to `/close` authorizes a merge.
8. **Merge commit is the authoritative shipped signal; tag is a convenience label.** The authoritative, atomic record that a branch shipped is the merge commit (`merge: <slug>`, with a `Story: reviews/<slug>.md` trailer) / the PR's `MERGED` state. `close/SKILL.md`'s merge step additionally creates `shipped/<slug>` as a *best-effort* annotated tag (a ref, not a base-tree commit — satisfies "no writes to base beyond the merge"), verifies the push, and documents a repair path. The tag's *absence* is never read as "not shipped" (it is not atomic with the merge — git cannot make merge-commit + tag-push one transaction).
9. **"Did it ship?" is derived, not stored — preferring the authoritative signal.** `close/SKILL.md` documents the read-time check: prefer `gh pr view <PR#> --json state` (`MERGED`) / `git log <baseBranch> --grep "^merge: <slug>"`, with `git tag -l "shipped/<slug>"` as a fast secondary lookup only (command-query separation).
10. **The doctrine is updated.** `workflow-protocol.md` and `frame/SKILL.md` document the declared-vs-observed lifecycle: the header's terminal state is `approved`; merge/shipped state lives in the merge commit + `shipped/<slug>` tag.

## Test notes

This repo's gate is a placeholder (`echo … && true`), so verification is by inspection plus the independent Codex review in `/review`:
- AC1: grep `close/SKILL.md` for `Status: merged`; confirm it appears only in the merge step, not step 2. Confirm a documented pre-merge status and a documented tension-resolution.
- AC2: confirm the explicit "invoking `/close` is NOT merge authorization" sentence and the "after the fork, every time" requirement.
- AC3: confirm step 4 says "stop and ask even on a clean review with zero fixes."
- AC4: confirm the consistency-guard note exists.
- AC5/AC6: confirm `BACKLOG.md` is tracked and README has the pointer link; follow the link.
- AC7: confirm `review/SKILL.md` wording no longer implies command-as-consent.

## Build note (2026-06-05)

AC → file map:
- AC1 (no premature `merged`; atomic flip, option c) → `.claude/skills/close/SKILL.md` (hard constraints + steps 2, 5, 6)
- AC2 (invoking `/close` is not merge authorization) → `.claude/skills/close/SKILL.md` (hard constraints + steps 4, 5)
- AC3 (mandatory non-skippable fork, even on clean review) → `.claude/skills/close/SKILL.md` (hard constraints + steps 2, 4)
- AC4 (trail/merge consistency guard) → `.claude/skills/close/SKILL.md` (hard constraints + step 5 revert-on-failure)
- AC5 (BACKLOG staging artifact) → `BACKLOG.md` (+ discovery doc `workflow-skill-defects.story.md`)
- AC6 (README pointer) → `README.md` (Artifacts section)
- AC7 (review consistency tweak + explicit menu note) → `.claude/skills/review/SKILL.md` (steps 7, 8)

`git diff --stat main...HEAD`:
```
 .claude/skills/close/SKILL.md     |  20 +++++---
 .claude/skills/review/SKILL.md    |   4 +-
 BACKLOG.md                        |  48 ++++++++++++++++++
 README.md                         |   1 +
 reviews/close-gate-and-backlog.md |  57 +++++++++++++++++++++
 workflow-skill-defects.story.md   | 103 ++++++++++++++++++++++++++++++++++++++
 6 files changed, 223 insertions(+), 10 deletions(-)
```

## Codex review (2026-06-05, base main, HEAD 495dc84)

**Summary:** The branch implements the backlog artifact and most of the merge-gate wording, but the new close-step status lifecycle still has a merge-path bug: the `merged` status commit is made before the merge and is not guaranteed to be included in the remote PR merge.

### BLOCKER
1. **Remote merge path can omit the merged-status commit** (`close/SKILL.md:27`). Step 5 creates the `Status: merged` commit locally, then the remote path runs `gh pr merge --merge --delete-branch` without pushing first. The merge command is not guaranteed to include the new status commit, contradicting step 6's claim that the `merged` line arrives with the merge and violating AC1/AC4's no-separate-base-commit lifecycle.
   *Suggestion:* after the status commit, push the branch and verify the PR head/checks are on that SHA before `gh pr merge` — or use a merge-state strategy that doesn't depend on an unpublished pre-merge commit.

### IMPORTANT
2. **`merged` status is still committed before the merge happens** (`close/SKILL.md:25`). The hard constraint says never assert `merged` before the merge and that status/reality must agree at every observable point, but step 5 still commits `Status: merged` before issuing the merge. If the merge prompts, hangs, is interrupted, or fails before the revert completes, the branch again has a committed `merged` header while unmerged — the D1/AC4 failure this story is meant to prevent.
   *Suggestion:* don't commit a final `merged` header before the merge. Keep `approved`/`ready` until the merge completes and record merge state via merge/PR metadata, or explicitly accept and document a trailing post-merge status commit.

## Decisions (2026-06-05)

Thomas, this session:
- **AC1 → option (c)** — atomic flip at merge. Carry `approved`/`ready` through the rounds; set `Status: merged` only in the same close step that issues the merge, immediately before the merge command, true within one atomic action. No extra base-branch commits.
- **AC7 → explicit menu note** — beyond the light routing-wording fix, add a line to `/review`'s decision menu stating that deciding fix/defer/reject is not a merge decision; the merge gate is separate and lives in `/close`.
- **Scope approved**, "implement and /review please" — covers building on the branch only; not merge authorization.

## Build note (2026-06-05, re-review round 2)

Changes since last-reviewed SHA `495dc84`, addressing Codex findings ①/② via the SSOT redesign.

AC → file map (new/changed this round):
- AC1 (header declared-state only, never `merged`) → `.claude/skills/close/SKILL.md` (hard constraints, steps 2/5)
- AC8 (annotated `shipped/<slug>` tag + `Story:` trailer; remote fetch-before-tag fixes finding ①) → `.claude/skills/close/SKILL.md` (step 5)
- AC9 (derived "did it ship?" check) → `.claude/skills/close/SKILL.md` (step 7)
- AC10 (declared-vs-observed doctrine) → `.claude/workflow-protocol.md`, `.claude/skills/frame/SKILL.md`
- Trail updates → `BACKLOG.md` (BUG-D1), `README.md` (Artifacts)

`git diff --stat 495dc84...HEAD`:
```
 .claude/skills/close/SKILL.md             | 30 ++++++++++++++++++++----------
 .claude/skills/frame/SKILL.md             |  1 +
 .claude/workflow-protocol.md              | 10 ++++++++++
 BACKLOG.md                                |  2 +-
 README.md                                 |  1 +
 reviews/close-gate-and-backlog.codex.json |  1 +
 reviews/close-gate-and-backlog.md         | 28 ++++++++++++++++++++++++++--
```

## Codex review (2026-06-05, re-review round 2, base 495dc84, HEAD d255521)

**Summary:** The SSOT header change resolves both prior findings — the branch no longer commits `Status: merged` before merge, and the remote PR merge no longer depends on an unpublished merged-status commit. **AC1/AC4/AC9/AC10 covered. ① and ② resolved.** But AC8 is not fully met: the shipped tag is created/pushed *after* the merge as a separate operation.

### BLOCKER
3. **Shipped tag is not atomic with the merge** (`close/SKILL.md:27`). Step 5 claims the tag is created by the merge and that `no tag ⇒ not shipped`, but both paths merge first and tag second. If tag creation/push fails after a successful merge, the branch is shipped with no marker, so the AC9 derived check reports a false "not shipped." Git cannot make a merge commit and a tag ref-update one transaction, so the atomicity claim overpromises.
   *Suggestion:* either make merge + tag one transactional op (not possible across the `gh` merge + tag push), or drop the atomicity / `no tag ⇒ not shipped` claim and make the **merge commit** the authoritative shipped signal, with the tag as a best-effort convenience marker plus push-verification and a documented repair path.

## Build note (2026-06-05, re-review round 3)

Changes since last-reviewed SHA `d255521`, addressing re-review finding ③ (tag not atomic with merge) via the merge-commit-as-authority reframe. Wording/doctrine only — no new mechanism.

- AC8/AC9 reframed (merge commit / PR-MERGED authoritative; tag best-effort; derived check prefers authoritative signal) → `.claude/skills/close/SKILL.md` (hard constraints, steps 5/7)
- Doctrine → `.claude/workflow-protocol.md`
- Trail → `BACKLOG.md`, `README.md`, story AC8/AC9

`git diff --stat d255521...HEAD`:
```
 .claude/skills/close/SKILL.md             | 25 ++++++++++++++-----------
 .claude/workflow-protocol.md              | 13 +++++++------
 BACKLOG.md                                |  2 +-
 README.md                                 |  2 +-
 reviews/close-gate-and-backlog.codex.json |  2 +-
 reviews/close-gate-and-backlog.md         | 17 +++++++++++++++--
```

## Decisions (2026-06-05, review round 2)

- **① / ② → confirmed resolved**, no further action.
- **③ (BLOCKER) → fix, reframe to merge-commit-as-authority.** Thomas chose: the merge commit / PR-MERGED state is the authoritative, atomic shipped signal; the `shipped/<slug>` tag is demoted to a best-effort convenience label (verify push + documented repair path); the derived check prefers the authoritative signal; drop the "no tag ⇒ not shipped" overclaim. Updates `close/SKILL.md`, `workflow-protocol.md`, and story AC8/AC9. Not merge authorization.

## Decisions (2026-06-05, review round 1)

Both Codex findings accepted; they collapse to one resolution.
- **Finding ① (BLOCKER) → fix.** Real: on the `gh pr merge` path the local `merged` commit is never pushed, so it can be dropped from the merge.
- **Finding ② (IMPORTANT) → fix.** Real: option (c)'s pre-merge `merged` commit is racy; an interrupted merge leaves the D1 false state.
- **AC1 reversed: option (c) → option (b) + industry-standard mechanism.** After discussing prior art, Thomas chose the complete fix: header records declared state only (never `merged`); merge/shipped state is observed and owned by git, recorded by the merge commit + an annotated `shipped/<slug>` tag, and read back via a derived check. Scope enlarged to add AC8/AC9/AC10 and update the protocol doctrine + `frame`. Thomas, this session: *"fold it all in, I want a complete fix - enlarge scope as needed."*
- Rationale captured in the trilemma: the self-contained-header property is recovered by an out-of-tree tag (a ref, not a tree write), dissolving the pick-two tension. Not merge authorization.
