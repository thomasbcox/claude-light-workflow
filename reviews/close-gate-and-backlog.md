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

1. `.claude/skills/close/SKILL.md` — fix D1/D2/D3 per the ACs below.
2. `.claude/skills/review/SKILL.md` — minimal matching tweak to the decision-menu / routing wording so the gate is consistent across the two skills (only what AC2/AC3 require; no redesign).
3. `BACKLOG.md` — include the already-drafted staging-area artifact (commit it; minor edits as needed for consistency with the chosen AC1 resolution).
4. `README.md` — add a discoverability pointer to `BACKLOG.md` in the Artifacts section.
5. `workflow-skill-defects.story.md` — commit the discovery doc to the branch as part of the trail (already untracked).

## Non-goals

- Redesigning `/frame` or `/review` beyond the consistency tweak in scope item 2.
- The base-branch write-protection hook (`block-main-writes.sh`) — already works; out of scope.
- Building the OPS-1/2/3 tooling (drift detection, version stamping). Those stay as backlog lines; this story only *records* them in `BACKLOG.md`, it does not implement them.
- Deploying via `install.sh` (that's a post-merge action, not part of this change).

## Acceptance criteria

1. **No premature `merged` status.** `close/SKILL.md` no longer sets `Status: merged` in step 2. The feature branch carries a distinct pre-merge status (`approved`/`ready`) through the review/close rounds; any flip to `merged` happens only at the real merge step. The chosen resolution of the "no separate base-branch commit" tension is documented in the skill (see Open question 1 for the recommended option).
2. **Unambiguous merge-approval gate.** `close/SKILL.md` states explicitly, in one sentence, that **invoking `/close` is NOT merge authorization**. A distinct, affirmative human merge instruction (the word "merge" or equivalent) is required **after** the step-4 fork is presented, **every** time. A prior or general "yes" does not count; the command invocation does not count.
3. **Mandatory, non-skippable fork.** `close/SKILL.md` makes clear that step 4 must present "re-review or merge?" and **stop** for Thomas's answer — even when there are zero approved fixes to apply (clean review). The clean-review path may not fast-path to merge.
4. **(Recommended) Trail/merge consistency guard.** `close/SKILL.md` notes that the `merged` status and the actual merge must be consistent at every point a reader could observe the branch; if they cannot be made atomic, the wording must not assert a merge that has not occurred.
5. **`BACKLOG.md` committed** as the staging-area artifact, listing BUG-D1/D2/D3 (cross-linked to the defects story) and OPS-1/2/3, with the lifecycle and id conventions described.
6. **README points to `BACKLOG.md`** from the Artifacts section, one line, consistent with the existing artifact entries.
7. **`review/SKILL.md` consistency tweak** applied so its decision-menu/`/close` routing wording does not imply that proceeding to `/close` authorizes a merge.

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

## Decisions (2026-06-05)

Thomas, this session:
- **AC1 → option (c)** — atomic flip at merge. Carry `approved`/`ready` through the rounds; set `Status: merged` only in the same close step that issues the merge, immediately before the merge command, true within one atomic action. No extra base-branch commits.
- **AC7 → explicit menu note** — beyond the light routing-wording fix, add a line to `/review`'s decision menu stating that deciding fix/defer/reject is not a merge decision; the merge gate is separate and lives in `/close`.
- **Scope approved**, "implement and /review please" — covers building on the branch only; not merge authorization.
