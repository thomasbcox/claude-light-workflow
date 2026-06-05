# Story: Fix the `/close` merge gate and status lifecycle in the frame→review→close skills

> **Portable issue.** Self-contained for the repo that owns the workflow skills
> (`frame`, `review`, `close`) — typically `~/.claude/skills/{frame,review,close}/SKILL.md`.
> Discovered 2026-06-04 while running the loop on an unrelated project; the bugs
> are in the skill instructions themselves, so they reproduce on any repo that uses
> them. No dependency on the project where they surfaced.

## Background

The frame→review→close skills implement a lightweight human-gated review loop:

- **`/frame`** turns a request into an approved spec on a feature branch, then implements it.
- **`/review`** runs the test gate, has an independent reviewer (Codex) critique the branch, and presents a decision menu.
- **`/close`** applies approved fixes, then — on the human's approval — merges.

The intended safety property: **a merge is irreversible and outward-facing, so it
must never happen without an unambiguous, in-the-moment human "merge" instruction.**
Three defects in the instructions undermine that property.

## Problem — three linked defects

### D1. `/close` pre-sets `Status: merged` speculatively
`close` step 2 says: *"If this is the round that will merge, also set the
story-file header to `Status: merged` now, so the trail lands on the feature branch
before the merge."*

But whether the current round **is** the merge round is not known until **after**
step 4 (the "re-review or merge?" fork). When the human chooses re-review, the
branch is left carrying a `Status: merged` header while it is still unmerged and
not an ancestor of the base branch. The trail records a state that is false.

This is driven by a deeper tension the skill tries to finesse: it wants the
`merged` status committed *on the feature branch* (to avoid a separate base-branch
commit), but "on the feature branch" is by definition "before the merge." So the
status is structurally forced to be either premature or to require the base-branch
commit the skill is trying to avoid.

### D2. The merge-approval gate is underspecified ("squishy")
`close`'s hard constraints say: *"Never merge without the human's explicit approval
in the current session. A prior general 'yes' does not count."*

It never states whether **invoking `/close` itself** constitutes that approval.
A reader can plausibly conclude "they ran `/close`, that's the approval" — which is
exactly the failure in D3. The gate needs to say, in one unambiguous sentence, what
does and does not count as merge authorization.

### D3. The ambiguity gets acted on — merge without a distinct "merge" instruction
Observed: on one story the assistant, on receiving the `/close` invocation, ran the
gate, committed, and **merged immediately** — skipping step 4's "re-review or
merge?" question. No distinct human "merge" word was ever given; the command
invocation was treated as consent. This is the irreversible action firing without
the in-the-moment approval the skill is supposed to require.

## Impact
- An irreversible, outward-facing action (merge / branch delete / PR close) can run
  without unambiguous consent.
- The persisted trail can assert `merged` on a branch that is not merged, which
  later readers (and independent reviewers) correctly flag as false — and which
  can mask whether a merge actually happened.
- Behavior is inconsistent run-to-run (sometimes the fork is honored, sometimes
  skipped), so the gate is not a reliable control.

## Acceptance criteria

1. **`/close` no longer sets `Status: merged` before the merge actually happens.**
   The feature branch carries a distinct pre-merge status (e.g. `ready` or
   `approved`) through the review/close rounds. The flip to `merged` happens only
   at the real merge step. Resolve the "no separate base-branch commit" tension
   deliberately and document the chosen resolution (options: (a) accept one
   trailing status commit at merge time; (b) record merge state via the merge
   commit / PR metadata rather than the story header; (c) a `ready` → post-merge
   `merged` convention where `merged` is set in the same step that issues the merge
   and is true within the same atomic action).

2. **The merge-approval gate is stated unambiguously.** `close` explicitly says:
   *invoking `/close` is NOT merge authorization.* A distinct, affirmative human
   instruction to merge (the word "merge" or equivalent) is required **after** the
   re-review fork is presented, **every** time. A prior or general "yes" does not
   count; the command invocation does not count.

3. **Step 4's fork is mandatory and cannot be skipped.** The instructions make
   clear that `/close` must present "re-review or merge?" and **stop**, even when
   there are zero approved fixes to apply (clean review) — the human still chooses.

4. **(Optional, recommended) A guard against the trail/merge mismatch.** Note in
   `close` that the `merged` status and the actual merge must be consistent at all
   times a reader could observe the branch; if they can't be made atomic, the
   status wording should not assert a merge that hasn't occurred.

## Out of scope
- Changes to `/frame` and `/review` beyond what AC2/AC3 require for a consistent
  gate (e.g. `/review`'s decision menu wording may need a matching tweak, but the
  redesign of those skills is separate).
- The base-branch write-protection hook (`block-main-writes.sh`) — it already works;
  this story is about the human approval gate and status lifecycle, not branch protection.

## Notes / discovery evidence
- The independent reviewer flagged the premature `merged` status as a finding
  ("status changed to merged while the branch is still unmerged") — i.e. the bug is
  externally observable, not theoretical.
- D3 is a judgment failure enabled by D2's ambiguity: tightening the wording (AC2)
  is the highest-leverage fix, because it removes the room for "command = consent."
