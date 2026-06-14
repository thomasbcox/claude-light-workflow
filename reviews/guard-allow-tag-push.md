Date: 2026-06-14 · Branch: claude/guard-allow-tag-push · Status: approved

# Story: BUG-5 — guard hook should allow the sanctioned `shipped/<slug>` tag push

> **Approved 2026-06-14.** Thomas: "approve" — both open questions resolved as
> recommended (resolve-based tag detection; deploy the fixed hook during this
> story's `/close` before the tag push, detached-HEAD fallback only if needed).

## Problem

The workflow guard hook (`.claude/hooks/block-main-writes.sh`) blocks the
`shipped/<slug>` **tag** push that `/close` is documented to perform — making the
skill's own merge recipe fail in its normal post-merge state.

Concretely, `/close` step 5 does (remote path):

```
gh pr merge <PR#> --merge --delete-branch …   # GitHub merges; --delete-branch leaves HEAD on `main`
…
git push origin "shipped/<slug>"              # push the convenience tag
```

After `--delete-branch`, the local checkout is left on the base branch `main`.
The guard's `push` rule then fires:

```python
if sub == "push":
    forced = …                                  # force-flag detection
    if forced: deny("no force-push …")
    if current_branch(cdir) in BASE_BRANCHES:   # ← keys on "am I on main?"
        deny("don't push to the base branch …")
```

The check keys on **"is the current branch a base branch?"**, not **"does this
push update a base branch?"**. A `shipped/<slug>` push targets a **tag ref**, not
the base branch's tree — it is explicitly sanctioned by `/close` doctrine ("the
only writes to base are the merge commit itself and the `shipped/<slug>` tag (a
ref, not a tree commit)"). But because HEAD is on `main`, the hook denies it.

**Impact:** every remote `/close` that follows the documented step order hits
`BLOCKED by workflow guard: don't push to the base branch …` at the tag step. It
was worked around twice this session (PRs #14 and #15) by pushing the tag from a
detached HEAD so `current_branch` resolves empty. The skill's documented recipe is
effectively broken without that undocumented manual dance.

This is **distinct from the decided-against OPS-6**: OPS-6 proposed *hardening* the
guard to catch more bypasses; BUG-5 is the guard being *too aggressive* and
blocking a legitimate, doctrine-sanctioned push.

## Solution (design)

Make the hook precise about tag pushes — an **additive exemption**, leaving every
other decision exactly as today:

In the `push` branch, *after* the existing force-push check (so force always
loses), compute whether the push is **tag-only** and, if so, skip the
base-branch block:

- **tag-only** ⇔ `--tags` is present in the push args, **or** there is at least
  one refspec and **every** refspec resolves to a tag. A refspec resolves to a tag
  when its source side (the part before any `:`, with a leading `+` stripped)
  either starts with `refs/tags/` or `git -C <dir> rev-parse --verify --quiet
  refs/tags/<src>` succeeds. At `/close` time the local `shipped/<slug>` tag has
  just been created, so it resolves.
- Refspecs are the non-option positional args **after** the remote (the first
  positional). Options are skipped; a leading `+` (force refspec) is already
  caught by the force check above.

Behaviour table (current → after):

| command (cwd) | current | after |
|---|---|---|
| `git push origin shipped/x` on `main`, tag `shipped/x` exists | **deny** | **allow** ✅ |
| `git push --tags origin` on `main` | deny | allow ✅ |
| `git push origin main` on `main` | deny | deny (unchanged) |
| bare `git push` on `main` | deny | deny (unchanged) |
| `git push --force origin shipped/x` on `main` | deny | deny (force wins, unchanged) |
| `git push origin +shipped/x` on `main` | deny | deny (force `+` wins, unchanged) |
| `git push origin HEAD` on a feature branch | allow | allow (unchanged) |

The fix is purely additive: it only *adds* an allow path for non-force tag-only
pushes. It does **not** loosen anything else, and it does **not** try to close the
pre-existing gap where `git push origin main` from a *feature* branch is not
caught (that refspec-precision work is the decided-against OPS-6 — out of scope).

With the hook corrected, `/close`'s documented `git push origin "shipped/<slug>"`
works directly from `main`; the detached-HEAD workaround is no longer needed. No
change to the `/close` skill text is required (it never documented the workaround).

## In scope

- **`.claude/hooks/block-main-writes.sh`** — add the tag-only exemption in the
  `push` branch as described, after the force-push check.
- **`tests/guard_test.sh`** — add cases proving: a tag push from `main` is allowed;
  `--tags` from `main` is allowed; a branch/bare push from `main` is still blocked;
  a force tag push from `main` is still blocked. Requires creating a tag in the
  test base repo (extend the fixture setup with one empty commit + a `shipped/…`
  tag, using inline `-c user.email=… -c user.name=…` so no global git identity is
  needed).

## Non-goals

- **No `BACKLOG.md` / `CHANGELOG.md` edits.** Moving BUG-5 → Done and the changelog
  entry are a *separate* bookkeeping story, per the `bookkeeping-pr*` precedent.
- **No `/close` (or other skill) text change** — the documented recipe becomes
  correct once the hook is fixed.
- **No broadening of the guard** to catch explicit base-branch refspec pushes from
  non-base branches (decided-against OPS-6; pre-existing, not load-bearing here).
- Force-push, `--no-verify`, and commit handling unchanged.

## Acceptance criteria

1. **Tag push from a base branch is allowed.** With a tag `shipped/x` present, a
   non-force `git push origin shipped/x` run with cwd on `main` makes the hook exit
   `0` (allowed).
2. **`--tags` push from a base branch is allowed.** `git push --tags origin` on
   `main` exits `0`.
3. **Branch / bare pushes to base still blocked.** `git push origin main` on `main`
   and a bare `git push` on `main` still exit `2`.
4. **Force still wins over the tag exemption.** A force tag push from `main`
   (`git push --force origin shipped/x` and the `+shipped/x` refspec form) still
   exits `2`.
5. **Pre-existing behaviour preserved.** The existing 19 guard-test cases still
   pass unchanged.
6. **Gate green.** `bash tests/guard_test.sh` passes with the added cases.
7. **Scope containment.** `git diff --name-only main...HEAD` shows only
   `.claude/hooks/block-main-writes.sh`, `tests/guard_test.sh`, and
   `reviews/guard-allow-tag-push.md`.

## Test notes

- AC1–AC4: new `run` cases in `tests/guard_test.sh` (expected exit `0` for the
  allow cases, `2` for the still-blocked cases), exercising a base repo that has a
  real `shipped/…` tag created in fixture setup.
- AC5: the pre-existing cases remain in the file untouched; the run still reports
  them ok.
- AC6: `bash tests/guard_test.sh` → `ALL GUARD TESTS PASSED`, `failed=0`.
- AC7: `git diff --name-only main...HEAD` lists only the three enumerated files.
- Manual sanity (out of repo, evidence not gate): on the *next* real `/close`, the
  documented `git push origin "shipped/<slug>"` from `main` succeeds without the
  detached-HEAD workaround. (This story's own `/close` will itself exercise it once
  the fixed hook is deployed via `install.sh`.)

## Open questions

1. **Tag detection method.** Resolve "is this refspec a tag?" via
   `git rev-parse --verify refs/tags/<name>` (plus accepting an explicit
   `refs/tags/…` prefix and `--tags`). This relies on the tag existing locally at
   push time — true for `/close`, which creates `shipped/<slug>` immediately
   before pushing. Acceptable, or do you want a name-pattern allowance (e.g. treat
   any `shipped/*` refspec as a tag even if not yet created)? Recommending the
   resolve-based check — it keys on what the ref actually *is*, not on a naming
   convention.
2. **Self-`/close` ordering.** This fix only takes effect once the rebuilt hook is
   deployed to `~/.claude` (via `install.sh`). I'll deploy during this story's
   `/close` *before* the tag push so it dogfoods the fix; if anything is off I fall
   back to the detached-HEAD workaround. Just flagging the sequence.

## Build note (2026-06-14)

AC → file map:

- **AC1** (tag push from base allowed) → `.claude/hooks/block-main-writes.sh`,
  `tests/guard_test.sh`
- **AC2** (`--tags` allowed) → `.claude/hooks/block-main-writes.sh`,
  `tests/guard_test.sh`
- **AC3** (branch/bare push to base still blocked) →
  `.claude/hooks/block-main-writes.sh`, `tests/guard_test.sh`
- **AC4** (force still wins) → `.claude/hooks/block-main-writes.sh`,
  `tests/guard_test.sh`
- **AC5** (existing 19 cases preserved) → `tests/guard_test.sh`
- **AC6** (gate green) → `tests/guard_test.sh`
- **AC7** (scope containment) → `.claude/hooks/block-main-writes.sh`,
  `tests/guard_test.sh`, `reviews/guard-allow-tag-push.md` only
