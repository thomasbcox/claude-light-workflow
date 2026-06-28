# Backlog

Outstanding work for the light workflow skills (`frame`, `review`, `close`) and their
deployment tooling. One line per item with a stable id so story files, commits, and
`reviews/<slug>.md` trails can reference it.

**Lifecycle:** a line here → `/frame` writes `reviews/<slug>.md` (spec + audit trail) →
`/review` → `/close`. As part of the merge, `/close` moves the item to **Done** here and
adds the `CHANGELOG.md` entry *on the feature branch*, so both ride in on the merge commit.
The backlog is the staging area in front of the loop; don't delete a landed item — move it
to **Done** and reference it as `PR #N / merge: <slug>` (never a raw SHA — derive it with
`git log <base> --oneline --grep "^merge: <slug>"`). **No bookkeeping-only stories:** records
land with the story they describe; open a follow-up only for a real defect or a new decision,
never solely to reconcile a previous story's records.

Three kinds of item, tracked separately:
- **BUG-** — skill-behavior / workflow-correctness defects (change what the skills *do*).
- **OPS-** — deployment, drift, and tooling ergonomics (change how the skills are *shipped*).
- **AUDIT-** — findings graduated from a `/dev-audit` run (missing safeguards, best-practice gaps).
  Added only on an explicit instruction; the item text carries its `from /dev-audit <date>` provenance.

---

## Skill-behavior bugs

BUG-D1/D2/D3 were storied in [`workflow-skill-defects.story.md`](workflow-skill-defects.story.md)
and shipped together via PR #2 / `5225bdb`; see [Done](#done). BUG-4 shipped via PR #14 /
`0504e31`; BUG-5 was obviated by `drop-shipped-tag` (the `shipped/<slug>` tag it depended on
was removed); both in [Done](#done).

_(all shipped — see [Done](#done))_

## Deployment & tooling improvements

Not yet storied — smaller, may not each warrant a full `reviews/<slug>.md` story.

OPS-8 is tracked separately as a spawned task chip. Everything else here has resolved:
OPS-1/2/3 shipped (see [Done](#done)); OPS-6 was [decided against](#decided-against).

OPS-9 — Evaluate whether the three skills (`frame`, `review`, `close`) need any YAML
frontmatter beyond the current `name` + `description` — e.g. `allowed-tools` to scope tool
permissions, or other recognized skill keys. As of 2026-06-12 all three carry only
`name` + `description`; nothing is strictly missing, so this is an evaluate-and-decide
item, not a known gap. (Logged 2026-06-12 alongside BUG-4.)

---

## Done

| id | Summary | Shipped |
|---|---|---|
| OPS-4 | `/close`'s merge step raced GitHub's async mergeability computation (5×5s `mergeStateStatus` poll loop). Fixed: replaced with `gh pr merge --auto`, delegating merge timing to GitHub; added `allow_auto_merge` pre-flight and MERGED-state poll. | PR #6 / `499d6b6` |
| OPS-5 | `/close`'s auto-merge pre-flight aborted whenever `allow_auto_merge` was `false`, even with no required checks. Fixed: three-way merge strategy — auto-merge path when enabled, direct `gh pr merge` when disabled with no required checks, abort only when disabled *and* ≥1 required status check (detected via classic branch protection, degrading to zero on 403/404; rulesets out of scope). | PR #8 / `0406185` |
| OPS-5-fix | Follow-up to OPS-5: the new pre-flight's required-check detection didn't degrade to zero on a 403/404 — an inline `\|\| echo 0` appended to gh's error body, yielding a non-integer that broke the `-gt` test. Fixed: capture on gh success only via a separate-statement fallback, then sanitise to an integer. Surfaced by dogfooding the PR #8 merge. | PR #9 / `1278814` |
| OPS-7 | `/frame` spec template had no guidance against counting files in test notes. Fixed: the `## Test notes` template now warns against restating file counts for scope-containment ACs and directs `git diff --name-only` against the AC's enumerated file list. | PR #8 / `0406185` |
| OPS-1 | No drift detection between repo `.claude` and the `~/.claude` deployment. Fixed: `install.sh --check` is a read-only per-artifact IN SYNC/DRIFT report across the deployed set, exits non-zero on drift. | PR #11 / `b18993e` |
| OPS-2 | No provenance stamp on deployed skills. Fixed: every install writes `~/.claude/workflow-manifest.json` (source commit, dirty flag, timestamp, artifact list); `--check` compares it to repo HEAD and classifies drift as STALE vs HAND-EDITED. | PR #11 / `b18993e` |
| OPS-3 | `install.sh` hard-overwrite was silent. Fixed: a normal install prints a pre-overwrite drift summary (warning when hand-edited artifacts are about to be lost) before clobbering; the hard-overwrite model is unchanged by design. | PR #11 / `b18993e` |
| review-codex-stdin | `/review`'s documented `codex exec` command had no stdin redirect, so codex blocked on stdin and hung the review. Fixed: appended `</dev/null` (+ a keep-it note). Same-session tooling fix, no OPS number. | PR #12 / `706171d` |
| BUG-D1 | `/close` pre-set `Status: merged` speculatively. Fixed (SSOT): header records declared state only (`approved` terminal, never `merged`); shipped state owned by git — authoritatively the merge commit / PR-MERGED, with a best-effort `shipped/<slug>` convenience tag, read back by deriving. | PR #2 / `5225bdb` |
| BUG-D2 | Merge-approval gate was squishy. Fixed: `/close` now states unambiguously that *invoking `/close` is NOT merge authorization* — a distinct in-session "merge" instruction is required after the fork. | PR #2 / `5225bdb` |
| BUG-D3 | Merge could fire without a distinct "merge" instruction (fork skipped). Fixed: the "re-review or merge?" fork is mandatory and non-skippable, even on a clean review with zero fixes. | PR #2 / `5225bdb` |
| BUG-4 | `/review`'s `codex exec` referenced the finding schema by a repo-relative path (`.claude/skills/review/finding-schema.json`) that only resolved from this repo, so `/review` aborted ("Failed to read output schema file … No such file or directory") from every other project repo. Fixed: absolute user-level `"$HOME/.claude/skills/review/finding-schema.json"`; `-o reviews/<slug>.codex.json` kept repo-relative, with a step-5 note on the asymmetry. Also logged OPS-9. | PR #14 / `0504e31` |
| BUG-5 | The guard hook blocked the `shipped/<slug>` **tag** push during `/close` (it keys on "on a base branch?" not "is the refspec a base branch?"), since `gh pr merge --delete-branch` leaves HEAD on `main`. **Obviated by design** rather than fixed: `drop-shipped-tag` removed the tag entirely (the merge commit / PR-`MERGED` is the single ship record), so nothing pushes from `main` and the guard is never engaged — no guard change. The earlier smarter-guard fix (`guard-allow-tag-push`) was abandoned (PR #16 closed unmerged). | PR #17 / `merge: drop-shipped-tag` |

Shipped together as the `close-gate-and-backlog` story ([reviews/close-gate-and-backlog.md](reviews/close-gate-and-backlog.md)); also added the declared-vs-observed doctrine, the `shipped/<slug>` tag convention, and the `/review` decision-menu consistency tweak.

OPS-5 and OPS-7 shipped together as the `ops5-ops7-ergonomics` story ([reviews/ops5-ops7-ergonomics.md](reviews/ops5-ops7-ergonomics.md)); the OPS-5-fix follow-up as `ops5-reqchecks-fallback` ([reviews/ops5-reqchecks-fallback.md](reviews/ops5-reqchecks-fallback.md)) — a same-session bug surfaced by dogfooding the PR #8 merge.

OPS-1/2/3 shipped together as the `install-drift-check` story ([reviews/install-drift-check.md](reviews/install-drift-check.md)); the `review-codex-stdin` fix ([reviews/review-codex-stdin.md](reviews/review-codex-stdin.md)) — a same-session fix to a `/review` codex stdin hang surfaced while reviewing `install-drift-check`.

BUG-4 shipped as the `review-schema-abs-path` story ([reviews/review-schema-abs-path.md](reviews/review-schema-abs-path.md)) — the next defect in the same `codex exec` block as `review-codex-stdin`; also logged OPS-9. Closing its PR surfaced BUG-5 (open above).

---

## Decided against

Items considered and deliberately not done (kept here, not deleted, so the reasoning survives).

| id | Summary | Decided |
|---|---|---|
| OPS-6 | Harden the guard hook (read `baseBranch` from `workflow.json` + catch push refspecs; catch `env git` / `nice git` wrapper-prefix bypasses; soften docs). | 2026-06-08 |

**Why not (OPS-6):**
- The guard hook is a **cooperative** client-side guardrail, not an adversarial sandbox — it's bypassable by editing `settings.json` regardless. Chasing exotic bypasses (`env git` / `nice git` wrapper prefixes) is a category error: you can't harden a cooperative guard into a server-side wall.
- It does **not** duplicate GitHub branch protection — different layer (local/pre-emptive vs server/authoritative), and branch protection is unavailable on a free private repo anyway, so there's nothing to "step on."
- The one genuinely real sub-bug — base branch hardcoded to `main`/`master`, so a repo on a non-`main` base gets no protection even though `workflow.json` already declares `baseBranch` — is **not load-bearing** for this solo, `main`-based setup. **Deferred-until-needed:** revisit only if a non-`main` base is ever adopted.
- **Docs sub-part shipped** (PR #20 / `merge: honest-system-docs`): the "soften docs" half of OPS-6 was delivered separately — the README, hook comment, live protocol, and skill parentheticals now honestly describe the guard as a cooperative `main`/`master` tripwire and name the categories it doesn't catch. The **hardening** half (read `baseBranch`, catch refspecs/`env`/nested-shell) remains decided-against per the reasoning above.
