# Backlog

Outstanding work for the light workflow skills (`frame`, `review`, `close`) and their
deployment tooling. One line per item with a stable id so story files, commits, and
`reviews/<slug>.md` trails can reference it.

**Lifecycle:** a line here → `/frame` writes `reviews/<slug>.md` (spec + audit trail) →
`/review` → `/close` → `CHANGELOG.md`. The backlog is the staging area in front of the
loop. Move an item to **Done** (with the PR/commit) when it lands; don't delete it.

Two kinds of item, tracked separately:
- **BUG-** — skill-behavior / workflow-correctness defects (change what the skills *do*).
- **OPS-** — deployment, drift, and tooling ergonomics (change how the skills are *shipped*).

---

## Skill-behavior bugs

BUG-D1/D2/D3 were storied in [`workflow-skill-defects.story.md`](workflow-skill-defects.story.md)
and shipped together via PR #2 / `5225bdb`; see [Done](#done).

_(all shipped — see [Done](#done))_

## Deployment & tooling improvements

Not yet storied — smaller, may not each warrant a full `reviews/<slug>.md` story.

| id | Summary | Status |
|---|---|---|
| OPS-1 | No drift detection between repo `.claude/skills` and the `~/.claude` deployment. `install.sh` is a manual one-way push; nothing warns when deployed skills diverge. Package the `diff -rq` check (e.g. a `--check` flag or a `verify.sh`). | Open |
| OPS-2 | No version/provenance stamp on deployed skills — can't tell which repo commit a global copy came from, so staleness is invisible. Consider stamping the source commit into deployed files or a manifest. | Open |
| OPS-3 | `install.sh` propagation is hard-overwrite + manual: an edit to a global copy is silently clobbered with no record. Acceptable by design, but pair it with OPS-1/OPS-2 so drift is at least observable before the clobber. | Open |
| OPS-5 | `/close`'s `autoMergeAllowed` pre-flight is too strict: it aborts whenever `allow_auto_merge` is `false` on the repo, even when there are no required checks and a direct `gh pr merge` would succeed immediately. The check should abort only when auto-merge is disabled *and* the repo has at least one required status check (i.e., there is actually something to delegate timing for). | Open |
| OPS-7 | `/frame` spec template has no guidance against counting files in test notes (e.g. "must show only N files"). File counts are a DRY violation — they restate the AC's file list and go stale on any scope change. Test notes for scope-containment ACs should instead say "run `git diff --name-only`; verify no files appear beyond those listed in the AC." | Open |
| OPS-6 | Guard hook has two confirmed remaining gaps: (1) base-branch name is hardcoded as `main`/`master` — repos using `trunk` or another base get no protection, and `git push origin HEAD:main` from a feature branch is not caught; (2) process-wrapper prefixes (`env git …`, `nice git …`) bypass the tokenizer since `git` is not the first token. Docs and hook comment should be softened to match actual coverage; the hook should read `baseBranch` from `workflow.json` and check destination refspecs on push. | Open |

---

## Done

| id | Summary | Shipped |
|---|---|---|
| OPS-4 | `/close`'s merge step raced GitHub's async mergeability computation (5×5s `mergeStateStatus` poll loop). Fixed: replaced with `gh pr merge --auto`, delegating merge timing to GitHub; added `allow_auto_merge` pre-flight and MERGED-state poll. | PR #6 / `499d6b6` |
| BUG-D1 | `/close` pre-set `Status: merged` speculatively. Fixed (SSOT): header records declared state only (`approved` terminal, never `merged`); shipped state owned by git — authoritatively the merge commit / PR-MERGED, with a best-effort `shipped/<slug>` convenience tag, read back by deriving. | PR #2 / `5225bdb` |
| BUG-D2 | Merge-approval gate was squishy. Fixed: `/close` now states unambiguously that *invoking `/close` is NOT merge authorization* — a distinct in-session "merge" instruction is required after the fork. | PR #2 / `5225bdb` |
| BUG-D3 | Merge could fire without a distinct "merge" instruction (fork skipped). Fixed: the "re-review or merge?" fork is mandatory and non-skippable, even on a clean review with zero fixes. | PR #2 / `5225bdb` |

Shipped together as the `close-gate-and-backlog` story ([reviews/close-gate-and-backlog.md](reviews/close-gate-and-backlog.md)); also added the declared-vs-observed doctrine, the `shipped/<slug>` tag convention, and the `/review` decision-menu consistency tweak.
