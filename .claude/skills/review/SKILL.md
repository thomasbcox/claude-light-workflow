---
name: review
description: Step 2 of the lightweight Claude↔Codex review loop. Run the test gate, then have the configured independent reviewer review the feature branch read-only (codex backend → `codex exec`) — an approach pass (the shape, vs. best practice) gating a correctness pass (the diff) — with structured-output schemas, capture the findings, and present a decision menu for Thomas. Use after code is implemented and committed on the feature branch.
---

# /review — independent critique

Step 2 of the loop. The **independent reviewer** critiques and classifies; it never fixes or merges (it runs read-only and has no commit authority here). Which tool plays the reviewer is selectable — see **Reviewer backend** below. Contract: `AGENTS.md`. Doctrine: `~/.claude/workflow-protocol.md`.

## Hard constraints
- Tests must be **green** before you call the reviewer. Never ask the reviewer to review a red build.
- You do not act on findings here — you collect them and present the menu. Thomas decides per finding.
- Do not edit the reviewer's output. Append it verbatim (plus a readable digest) to the story file.

## Reviewer backend (the selection seam)

The independent reviewer is **selectable**. This section is the canonical resolution rule; `/frame` and `/close` reference it.

**Resolve the reviewer once (precedence):** a per-invocation **override** (this skill only — see step 5) **beats** `reviewer` in `.claude/workflow.json`, which **beats** the default `codex`. A missing or empty `reviewer` field ⇒ `codex` (back-compat for every existing repo). The value must be one of `{codex, llm}`; anything else is an error — say so and stop, do not guess. The set is **extensible**: add a backend by adding its name here and a dispatch block below.

**Dispatch by backend** at each reviewer invocation (steps 6 and 8 here; the design review in `/frame`):
- **`codex`** *(the only wired backend)* — run the `codex exec` command shown at that step, unchanged.
- **`llm`** *(the designated second source — not yet wired)* — **STOP** with: *"The `llm` reviewer backend is selected but not wired yet (follow-up story). Set `reviewer` to `codex` in .claude/workflow.json, or pass `/review codex`."* Do **not** fall back to codex, run a partial review, or write any `*.json` artifact. Wiring `llm` is a follow-up story: unlike codex it is **non-agentic** (it cannot run `git diff` or explore the repo itself), so the harness assembles the context — `git diff <base>...HEAD` + the spec — and pipes it to `llm --schema <finding-schema>`; in exchange it is **inherently read-only** (no file tools, so no sandbox/worktree needed) and emits schema-valid JSON natively. This seam only has to route to it.

The reviewer **role contract** is `AGENTS.md` — tool-neutral and read automatically by whichever backend runs.

## Steps
0. **Defer to native workflow.** If `docs/ai-protocol.md` exists at the repo root (resolve via `git rev-parse --show-toplevel`), STOP immediately — this repo runs its own heavier workflow. Tell the user to use its native review skill (e.g. `/prepare-codex-review`) instead of this one, and do nothing else.
1. **Load config** from `.claude/workflow.json`; identify `<slug>`, branch, `baseBranch`, `testCommand`, `codexModel`, and `reviewer` (see **Reviewer backend** below — resolve it once here and use it at every invocation in this skill).
2. **Build note.** Append to `reviews/<slug>.md` a `## Build note (<date>)` section: the AC→file map only. Do not include a gate result (proven implicitly by the review existing) or a `git diff --stat` block (derivable from git; causes self-referential staleness).
3. **Gate.** Run `testCommand`. If it fails, fix until green (mechanical self-fixes are allowed to reach green) and record the result. A red gate stops the loop.
4. **PR (only if a remote + `gh` exist).** Ensure a PR targets `baseBranch` and its checks are `SUCCESS` on the current HEAD. Local-only repos skip this entirely.
5. **Choose the passes (round-keyed default + overrides).** The review runs in two passes — an **approach pass** (the shape, best-practice lens) that **gates** a **correctness pass** (the diff). Decide which run this round:
   - **First review of the branch** (base = `<baseBranch>`), or any round **following an accepted redesign**: run **both**, approach first.
   - **Re-review that only verifies approved fixes** (base = the last-reviewed SHA, no redesign last round): **correctness only.**
   - **Overrides (bare args):** `/review approach` forces the approach pass on; `/review correctness` forces it off (correctness only). An override beats the default.
   - **Reviewer override (bare arg, order-independent):** a `codex` or `llm` token selects the reviewer backend for this run, beating `.claude/workflow.json` (see **Reviewer backend** above). It composes with the pass override — `/review approach llm` (pass→reviewer), `/review llm approach` (reviewer→pass), `/review llm`, and `/review correctness codex` all parse (pass token and reviewer token in either order). An unrecognized token, or a reviewer value outside `{codex, llm}`, is an error — report it and stop, don't silently ignore it.

   Choose the diff base as today: first review → `<baseBranch>`; re-review → the last-reviewed SHA recorded in the story file. (If step 5 selects correctness-only, skip steps 6–7 and go straight to step 8.)
6. **Approach pass.** The reviewer judges the *shape*, licensed to go beyond the diff. **Dispatch by the resolved reviewer** (see **Reviewer backend**): if `llm` (or any non-codex backend), STOP per that section; for `codex`, run — reads `AGENTS.md` automatically, read-only:
   ```bash
   codex exec -s read-only \
     --output-schema "$HOME/.claude/skills/review/design-review-schema.json" \
     -o reviews/<slug>.approach.json \
     ${codexModel:+-m "$codexModel"} \
     "You are the independent reviewer doing an APPROACH review per AGENTS.md — judge the SHAPE, not lines. Read reviews/<slug>.md (the spec) FIRST and sketch how YOU would satisfy the ACs. THEN read the FULL changed files (use \`git diff <base>...HEAD\` and \`git log --oneline <base>..HEAD\` for orientation, but read whole files) and the dependency manifest — not just the diff. Ask: does this reinvent what a dependency already does, or hand-roll what one declarative construct would cover? Is it larger/more complex than the problem? Could it be deleted and handed to the framework? You are licensed to cite simpler designs and CODE THAT SHOULD NOT EXIST. Apply the best-practice lens + three guardrails from AGENTS.md. Tag each finding with reversibility (one-way/two-way) and standing. Return at most the 3 HIGHEST-LEVERAGE concerns strictly per the provided JSON schema, each with alternative + win; empty findings array if the shape is sound." \
     </dev/null
   ```
   (Same `</dev/null` guard and absolute-schema / repo-relative-`-o` split as step 8 — see the notes there.) Read `reviews/<slug>.approach.json`; append a `## Codex approach review (<date>, base <base>, HEAD <sha>)` section: the `verdict`, then findings grouped by severity with their reversibility × standing tags, `alternative`, and `win`. Commit the story file + the `.approach.json`.
7. **Approach menu + gate (the short-circuit).** Present the approach findings **before** the correctness pass, each with a recommended disposition derived from its tags (**present per the consult-presentation rule** — `workflow-protocol.md` → *Consult model* → *How a consult is presented*: every option carries its cost and risk; a recommendation is earned, not reflexive):
   - **one-way door OR a major best-practice violation → block:** recommend *fix* (a redesign).
   - **minor two-way kludge → advisory:** recommend *accept* (Claude may tidy it) or *defer*; it never forces a redesign.

   Ask Thomas to decide per finding. **Never re-raise** anything deferred/rejected earlier. Then gate:
   - **If Thomas approves any shape-changing fix** (a redesign): **STOP — do NOT run the correctness pass this round.** Record decisions (step 9), then route to `/close`: Claude applies the redesign and the result comes back for a fresh review (the next round re-runs the approach pass on the new shape).
   - **If he rejects/defers all approach findings, or the approach pass was clean** (empty findings): the shape is **blessed** — continue to step 8 **in the same round.**

   **Invariant:** the correctness pass only ever runs on a shape that has cleared approach review.
8. **Correctness pass — two concurrent critics.** The correctness altitude runs **two independent critics at once**: the general **correctness** critic (judges the lines against the spec — everything) and a dedicated **hidden-failure** critic (swallowed / absorbed / silently-degrading error handling ONLY — `AGENTS.md`'s "Hidden failure" bullet). This is **divided parallelism** — different questions, so findings partition by concern; it is *not* the approach→correctness gate (that stays sequential, step 7). **Dispatch by the resolved reviewer** (see **Reviewer backend**): if `llm` (or any non-codex backend), STOP per that section **before launching either** critic; for `codex`, launch both read-only (`-s read-only` — neither can edit the repo). Launch each to a **fresh temp file** with its **PID captured**, `wait` **per-PID** for an **explicit exit status**, then **atomically promote** each temp to its stable artifact **only** on {clean exit AND parseable JSON}:
   ```bash
   # Temps live INSIDE reviews/ so each promotion is a same-filesystem atomic rename. Bare `mktemp`
   # lands in $TMPDIR (often another volume), where `mv` degrades to copy+delete and a reader can
   # catch a partial artifact mid-write — the very stale/partial path this fail-closed join exists to
   # kill. Arm the cleanup trap BEFORE the first mktemp so an interrupt between the two allocations
   # can't leak the first temp; `rm -f` on the still-empty vars is a harmless no-op.
   tmp_c=""; tmp_h=""
   trap 'rm -f "$tmp_c" "$tmp_h"' EXIT
   tmp_c="$(mktemp reviews/.<slug>.codex.XXXXXX)"
   tmp_h="$(mktemp reviews/.<slug>.hidden-failure.XXXXXX)"

   # correctness critic — prompt + finding-schema.json UNCHANGED; -o now a temp, promoted below
   codex exec -s read-only \
     --output-schema "$HOME/.claude/skills/review/finding-schema.json" \
     -o "$tmp_c" ${codexModel:+-m "$codexModel"} \
     "You are the independent reviewer defined in AGENTS.md. Review ONLY this branch's changes versus <base>: run \`git diff <base>...HEAD\` and \`git log --oneline <base>..HEAD\`, and read reviews/<slug>.md for the spec. Judge the change against that spec. Return your result strictly per the provided JSON schema (severities BLOCKER / IMPORTANT / QUESTION / NIT; ground every finding in the actual diff; return an empty findings array if there are no issues)." \
     </dev/null & pid_c=$!

   # hidden-failure critic — its OWN schema; scoped to the hidden-failure lens ONLY
   codex exec -s read-only \
     --output-schema "$HOME/.claude/skills/review/hidden-failure-schema.json" \
     -o "$tmp_h" ${codexModel:+-m "$codexModel"} \
     "You are the independent reviewer per AGENTS.md doing a CORRECTNESS review SCOPED TO ONE LENS: hidden failure / weak error handling (AGENTS.md's 'Hidden failure' bullet) ONLY — the parallel correctness critic covers everything else, do NOT duplicate it. Run \`git diff <base>...HEAD\` and read reviews/<slug>.md for the spec. Report ONLY findings where the diff swallows, absorbs, or silently degrades on error: bare/blind except|catch, catch-log-continue where propagating is correct, silent fallbacks, deleted assertions/safety checks — anything that lets code continue in a degraded state nothing surfaces. Ground every finding in the diff; empty findings array if none. Return strictly per the provided JSON schema." \
     </dev/null & pid_h=$!

   wait "$pid_c"; rc_c=$?
   wait "$pid_h"; rc_h=$?
   # Fail-closed: promote each ONLY on clean exit AND valid JSON; any failure stops the round.
   promote() { { [ "$1" -eq 0 ] && jq -e . "$2" >/dev/null 2>&1; } && mv "$2" "$3" || { echo "FAIL: $4 critic (rc=$1) — round stopped; rerun /review" >&2; return 1; }; }
   promote "$rc_c" "$tmp_c" reviews/<slug>.codex.json          correctness    || exit 1
   promote "$rc_h" "$tmp_h" reviews/<slug>.hidden-failure.json hidden-failure || exit 1
   ```
   **Fail-closed — both critics are REQUIRED.** A nonzero exit **or** an unparseable artifact from *either* critic stops the round right here: do **not** present a decision menu, do **not** route to `/close`; report which critic failed and rerun `/review`. Because each critic writes a **fresh temp** promoted only on success, a failed run can never leave a **prior round's** artifact standing as this round's result (that stale-output path would be the very silent degradation the hidden-failure lens exists to catch). **This concurrency block is the template every future parallel critic copies** — keep the PID-capture + temp→validate→promote invariant; add a critic by adding a third `tmp`/PID/`promote` triple, not by rewriting the join.
   **Keep each `</dev/null`:** without it `codex exec` reads stdin ("Reading additional input from stdin…") and blocks forever when stdin isn't a TTY (background / non-interactive runs), hanging the review. The redirect binds per `codex exec`, so backgrounding with `&` is safe (and appending `2>&1 | tail` to a foreground run stays correct: `codex … </dev/null 2>&1 | tail`).
   **Why each `--output-schema` is absolute but `-o` promotes to a repo-relative path:** each schema is a *skill-local* file installed at the user level (`install.sh` deploys it to `$HOME/.claude/skills/review/`), so it must be addressed there — a repo-relative path resolves against the project being reviewed, which doesn't carry the skill, and `codex` aborts ("Failed to read output schema file … No such file or directory"). The promoted outputs (`reviews/<slug>.codex.json`, `reviews/<slug>.hidden-failure.json`), by contrast, land *in the reviewed project*, so they stay repo-relative. Don't "normalise" the two to the same form. (Every Codex schema shares this rule — `design-review-schema.json` and `hidden-failure-schema.json` too are addressed absolutely.)
   **Do NOT use the `codex exec review` subcommand here:** its `--base` flag conflicts with a custom prompt, and its `-o` output ignores `--output-schema` (it writes prose, not JSON). Also note every schema marks all properties `required` with the optional keys nullable — the strict structured-output backend rejects schemas with truly optional keys.
   Read both artifacts; append a `## Codex review (<date>, base <base>, HEAD <sha>)` section (its `summary`, then correctness findings grouped by severity) **and** a `## Hidden-failure review (<date>, base <base>, HEAD <sha>)` section (its `summary`, then hidden-failure findings grouped by severity). Commit the story file + both artifacts (`.codex.json` and `.hidden-failure.json`).
9. **Decision menu + record & route.** Present the findings in **two labelled groups** — **Correctness** (from `.codex.json`) and **Hidden-failure** (from `.hidden-failure.json`) — each finding grouped by severity, each with a recommended disposition (**fix / defer / reject / answer**). The groups are presented side by side, **not** merged or consensus-voted (divided parallelism → reconciliation is grouping); drop only an obvious same-`file:line`+claim duplicate that appears in both. **Present per the consult-presentation rule** (`workflow-protocol.md` → *Consult model* → *How a consult is presented*): every option carries its cost and risk. **Ground each recommendation in what the finding carries** — both critics emit the same fields (no tags, unlike the approach pass), so derive from `severity` + the finding's `claim`: **BLOCKER / IMPORTANT → recommend *fix*; QUESTION → *answer*; NIT → *accept or defer*** — then let the `claim` adjust anything severity alone doesn't settle. A recommendation is earned this way, never reflexive. Ask Thomas to decide per finding. **Never re-raise** anything he deferred or rejected in an earlier round — tracked **per group**, so a deferred hidden-failure finding stays deferred on re-review just as a correctness one does. Append a `## Decisions (<date>)` section quoting Thomas's call per finding (every critic's decisions this round — approach if it ran, correctness, and hidden-failure); commit it. **Deciding fix/defer/reject is not a merge decision** — the merge gate is separate and lives in `/close`, which **stops at its re-review/merge fork** before any merge (the fork is conditional — a redesign re-reviews rather than offering merge). Then run `/close` to apply the approved fixes and reach the merge fork — routing to `/close` does NOT authorize a merge; `/close` still requires a distinct merge instruction.
