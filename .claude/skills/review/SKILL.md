---
name: review
description: Step 2 of the lightweight Claude↔Codex review loop. Run the test gate, then have Codex independently review the feature branch via read-only `codex exec` — an approach pass (the shape, vs. best practice) gating a correctness pass (the diff) — with structured-output schemas, capture the findings, and present a decision menu for Thomas. Use after code is implemented and committed on the feature branch.
---

# /review — independent critique by Codex

Step 2 of the loop. Codex is the **independent** reviewer: it critiques and classifies; it never fixes or merges (it runs under `-s read-only` and has no commit authority here). Contract: `AGENTS.md`. Doctrine: `~/.claude/workflow-protocol.md`.

## Hard constraints
- Tests must be **green** before you call Codex. Never ask Codex to review a red build.
- You do not act on findings here — you collect them and present the menu. Thomas decides per finding.
- Do not edit Codex's output. Append it verbatim (plus a readable digest) to the story file.

## Steps
0. **Defer to native workflow.** If `docs/ai-protocol.md` exists at the repo root (resolve via `git rev-parse --show-toplevel`), STOP immediately — this repo runs its own heavier workflow. Tell the user to use its native review skill (e.g. `/prepare-codex-review`) instead of this one, and do nothing else.
1. **Load config** from `.claude/workflow.json`; identify `<slug>`, branch, `baseBranch`, `testCommand`, `codexModel`.
2. **Build note.** Append to `reviews/<slug>.md` a `## Build note (<date>)` section: the AC→file map only. Do not include a gate result (proven implicitly by the Codex review existing) or a `git diff --stat` block (derivable from git; causes self-referential staleness).
3. **Gate.** Run `testCommand`. If it fails, fix until green (mechanical self-fixes are allowed to reach green) and record the result. A red gate stops the loop.
4. **PR (only if a remote + `gh` exist).** Ensure a PR targets `baseBranch` and its checks are `SUCCESS` on the current HEAD. Local-only repos skip this entirely.
5. **Choose the passes (round-keyed default + overrides).** The review runs in two passes — an **approach pass** (the shape, best-practice lens) that **gates** a **correctness pass** (the diff). Decide which run this round:
   - **First review of the branch** (base = `<baseBranch>`), or any round **following an accepted redesign**: run **both**, approach first.
   - **Re-review that only verifies approved fixes** (base = the last-reviewed SHA, no redesign last round): **correctness only.**
   - **Overrides (bare args):** `/review approach` forces the approach pass on; `/review correctness` forces it off (correctness only). An override beats the default.

   Choose the diff base as today: first review → `<baseBranch>`; re-review → the last-reviewed SHA recorded in the story file. (If step 5 selects correctness-only, skip steps 6–7 and go straight to step 8.)
6. **Approach pass.** Codex judges the *shape*, licensed to go beyond the diff. Reads `AGENTS.md` automatically, runs read-only:
   ```bash
   codex exec -s read-only \
     --output-schema "$HOME/.claude/skills/review/design-review-schema.json" \
     -o reviews/<slug>.approach.json \
     ${codexModel:+-m "$codexModel"} \
     "You are Codex doing an APPROACH review per AGENTS.md — judge the SHAPE, not lines. Read reviews/<slug>.md (the spec) FIRST and sketch how YOU would satisfy the ACs. THEN read the FULL changed files (use \`git diff <base>...HEAD\` and \`git log --oneline <base>..HEAD\` for orientation, but read whole files) and the dependency manifest — not just the diff. Ask: does this reinvent what a dependency already does, or hand-roll what one declarative construct would cover? Is it larger/more complex than the problem? Could it be deleted and handed to the framework? You are licensed to cite simpler designs and CODE THAT SHOULD NOT EXIST. Apply the best-practice lens + three guardrails from AGENTS.md. Tag each finding with reversibility (one-way/two-way) and standing. Return at most the 3 HIGHEST-LEVERAGE concerns strictly per the provided JSON schema, each with alternative + win; empty findings array if the shape is sound." \
     </dev/null
   ```
   (Same `</dev/null` guard and absolute-schema / repo-relative-`-o` split as step 8 — see the notes there.) Read `reviews/<slug>.approach.json`; append a `## Codex approach review (<date>, base <base>, HEAD <sha>)` section: the `verdict`, then findings grouped by severity with their reversibility × standing tags, `alternative`, and `win`. Commit the story file + the `.approach.json`.
7. **Approach menu + gate (the short-circuit).** Present the approach findings **before** the correctness pass, each with a recommended disposition derived from its tags:
   - **one-way door OR a major best-practice violation → block:** recommend *fix* (a redesign).
   - **minor two-way kludge → advisory:** recommend *accept* (Claude may tidy it) or *defer*; it never forces a redesign.

   Ask Thomas to decide per finding. **Never re-raise** anything deferred/rejected earlier. Then gate:
   - **If Thomas approves any shape-changing fix** (a redesign): **STOP — do NOT run the correctness pass this round.** Record decisions (step 9), then route to `/close`: Claude applies the redesign and the result comes back for a fresh review (the next round re-runs the approach pass on the new shape).
   - **If he rejects/defers all approach findings, or the approach pass was clean** (empty findings): the shape is **blessed** — continue to step 8 **in the same round.**

   **Invariant:** the correctness pass only ever runs on a shape that has cleared approach review.
8. **Correctness pass.** Codex judges the *lines* against the spec. Run read-only (`-s read-only` — it cannot edit the repo):
   ```bash
   codex exec -s read-only \
     --output-schema "$HOME/.claude/skills/review/finding-schema.json" \
     -o reviews/<slug>.codex.json \
     ${codexModel:+-m "$codexModel"} \
     "You are Codex, the independent reviewer in AGENTS.md. Review ONLY this branch's changes versus <base>: run \`git diff <base>...HEAD\` and \`git log --oneline <base>..HEAD\`, and read reviews/<slug>.md for the spec. Judge the change against that spec. Return your result strictly per the provided JSON schema (severities BLOCKER / IMPORTANT / QUESTION / NIT; ground every finding in the actual diff; return an empty findings array if there are no issues)." \
     </dev/null
   ```
   **Keep the `</dev/null`:** without it `codex exec` reads stdin ("Reading additional input from stdin…") and blocks forever when stdin isn't a TTY (background / non-interactive runs), hanging the review. The redirect binds to `codex exec`, so appending `2>&1 | tail` when you run it stays correct (`codex … </dev/null 2>&1 | tail`).
   **Why `--output-schema` is absolute but `-o` is relative:** the schema is a *skill-local* file installed at the user level (`install.sh` deploys it to `$HOME/.claude/skills/review/`), so it must be addressed there — a repo-relative path resolves against the project being reviewed, which doesn't carry the skill, and `codex` aborts ("Failed to read output schema file … No such file or directory"). The `-o reviews/<slug>.codex.json` output, by contrast, is meant to land *in the reviewed project*, so it stays repo-relative. Don't "normalise" the two to the same form. (Both Codex passes share this rule — `design-review-schema.json` too is addressed absolutely.)
   **Do NOT use the `codex exec review` subcommand here:** its `--base` flag conflicts with a custom prompt, and its `-o` output ignores `--output-schema` (it writes prose, not JSON). Also note both schemas mark every property `required` with the optional keys nullable — the strict structured-output backend rejects schemas with truly optional keys.
   Read `reviews/<slug>.codex.json`; append a `## Codex review (<date>, base <base>, HEAD <sha>)` section: the `summary`, then findings grouped by severity. Commit the story file + the `.codex.json`.
9. **Decision menu + record & route.** Present the correctness findings grouped by severity, each with a recommended disposition (**fix / defer / reject / answer**). Ask Thomas to decide per finding. **Never re-raise** anything he deferred or rejected in an earlier round. Append a `## Decisions (<date>)` section quoting Thomas's call per finding (both passes' decisions this round); commit it. **Deciding fix/defer/reject is not a merge decision** — the merge gate is separate and lives in `/close`, which **stops at its re-review/merge fork** before any merge (the fork is conditional — a redesign re-reviews rather than offering merge). Then run `/close` to apply the approved fixes and reach the merge fork — routing to `/close` does NOT authorize a merge; `/close` still requires a distinct merge instruction.
