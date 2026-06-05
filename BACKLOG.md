# Backlog

Outstanding work for the light workflow skills (`frame`, `review`, `close`) and their
deployment tooling. One line per item with a stable id so story files, commits, and
`reviews/<slug>.md` trails can reference it.

**Lifecycle:** a line here → graduates to a `<slug>.story.md` (background + acceptance
criteria) → `/frame` → `reviews/` trail → `CHANGELOG.md`. The backlog is the staging
area in front of the loop. Move an item to **Done** (with the PR/commit) when it lands;
don't delete it.

Two kinds of item, tracked separately:
- **BUG-** — skill-behavior / workflow-correctness defects (change what the skills *do*).
- **OPS-** — deployment, drift, and tooling ergonomics (change how the skills are *shipped*).

---

## Skill-behavior bugs

Storied in [`workflow-skill-defects.story.md`](workflow-skill-defects.story.md) — these
three are bundled and ready to `/frame` together.

| id | Summary | Status |
|---|---|---|
| BUG-D1 | `/close` pre-sets `Status: merged` speculatively — a branch can carry a `merged` header while still unmerged. Fix (SSOT): header records declared state only (`approved` terminal, never `merged`); merge/shipped state is owned by git — the merge commit + an annotated `shipped/<slug>` tag, read back by deriving. (Story AC1/AC8/AC9) | Open |
| BUG-D2 | Merge-approval gate is squishy — never states whether invoking `/close` itself counts as approval. Add one unambiguous sentence: *invoking `/close` is NOT merge authorization.* (Story AC2) | Open |
| BUG-D3 | Merge can fire without a distinct "merge" instruction — observed `/close` skipping the "re-review or merge?" fork and merging on the command invocation alone. Fork must be mandatory and non-skippable, even on a clean review with zero fixes. (Story AC3) | Open |

Related acceptance criteria from the same story:
- **AC1 resolution** — pick and document how to resolve the "no separate base-branch commit" tension (trailing status commit / merge-commit metadata / `ready`→atomic-`merged`).
- **AC4 (optional)** — guard against trail/merge mismatch: `merged` status and the actual merge must be consistent at every observable point.
- **`/review` matching tweak** — its decision-menu wording may need to align with the tightened gate (flagged out-of-scope-ish in the story, but likely required for a consistent gate).

## Deployment & tooling improvements

Not yet storied — smaller, may not each warrant a full `.story.md`.

| id | Summary | Status |
|---|---|---|
| OPS-1 | No drift detection between repo `.claude/skills` and the `~/.claude` deployment. `install.sh` is a manual one-way push; nothing warns when deployed skills diverge. Package the `diff -rq` check (e.g. a `--check` flag or a `verify.sh`). | Open |
| OPS-2 | No version/provenance stamp on deployed skills — can't tell which repo commit a global copy came from, so staleness is invisible. Consider stamping the source commit into deployed files or a manifest. | Open |
| OPS-3 | `install.sh` propagation is hard-overwrite + manual: an edit to a global copy is silently clobbered with no record. Acceptable by design, but pair it with OPS-1/OPS-2 so drift is at least observable before the clobber. | Open |

---

## Done

_(Move items here with their PR/commit when they land.)_
