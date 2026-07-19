Date: 2026-07-19 · Branch: claude/deep-audit-plan · Status: approved

# deep-audit-plan — recon → audit-plan consult (OPS-13 first slice)

## Problem

OPS-13 decided the shape of the whole-app multi-lens audit: a **compiled-plan fleet** whose every
run starts from a declarative, human-approved **audit plan** (altitudes × lenses × depth × cost,
each row carrying its why). Nothing produces that plan today. This story builds the **steering
interface only** — the recon that compiles the plan and the consult that approves it. It is
standalone-valuable before any engine exists: "what would a comprehensive audit cost on this repo?"
becomes a one-page, priced decision. The execution engine (fleet, adversarial verification,
synthesis) is a later story behind a **loud not-yet-built stop** — the same pattern as the `llm`
reviewer backend.

## In scope

- A **new skill dir** `.claude/skills/deep-audit/` — `SKILL.md` (`/deep-audit [path] [overrides…]`)
  plus `plan-schema.json` (the canonical plan contract, v1) — **plan stage only**:
  - Step-0 stand-down (`docs/ai-protocol.md`), as in every global skill.
  - **Detection by reference:** run `/dev-audit`'s detection (its steps 1–2) against the target —
    no duplicated Table A or detection lists.
  - The **altitude ladder** (L0 lines · L1 units · L2 subsystems · L3 application) defined in-skill.
  - A **lens catalog v1** — per lens: one-line charter, applicable altitudes, and the OPS-12
    standing rule restated (every critic owns its schema + artifact). The prompts and schemas
    themselves are the **engine story's** scope, not this one.
  - A **deterministic rule table** (Table P): exact signal predicates with thresholds (fixed 90-day
    churn window), stable row identity `(lens, altitude, scope)`, highest-depth-wins collision rule
    with accumulated whys, and a defined **override grammar** ("told" beats the table, and is
    recorded as such). Prose carries zero plan judgment.
  - **Plan compile — JSON canonical:** `reviews/audit-plan-<date>.json` (per `plan-schema.json` v1)
    is the plan; `reviews/audit-plan-<date>.md` is a **derived** consult view. Every row carries its
    resolved unit count, run count, token estimate, and **omission risk**; totals are the sum of
    rows; wall-clock derives from concurrency-bounded batches; all figures labeled ESTIMATE with the
    assumptions printed.
  - **Consult stop:** present the plan per the consult-presentation rule; Thomas edits/approves;
    record the approved plan; then **STOP loudly** — "execution engine not yet built (follow-up
    story)" — no partial execution, no silent fallback.
- `install.sh`: one `ARTIFACTS` entry shipping `skills/deep-audit`.
- `tests/deep_audit_plan_test.sh` — a drift-only linter for the new skill (same charter as the
  existing linters), wired into `.claude/workflow.json` `testCommand` and the `ci.yml` gate line.
- `BACKLOG.md`: OPS-13's first-slice line updated to point at this story file as the build.

## Non-goals

- **Not the execution engine** — no fleet, no critics, no verification, no synthesis, no workflow
  runs. The skill's terminal state this story is the approved plan + the loud stop.
- **Not the lens prompts/schemas** — the catalog names lenses and charters only.
- **Not** any change to `/dev-audit`, the review loop skills, `AGENTS.md`, or the reviewer-backend
  seam.
- **Not** estate/multi-repo scope — one repo per invocation (target = `[path]` or current repo,
  exactly like `/dev-audit`).

## Acceptance criteria

1. `/deep-audit [path]` exists at `.claude/skills/deep-audit/SKILL.md` with `name` + `description`
   frontmatter only (the OPS-9 convention) and the step-0 stand-down.
2. Detection is **by reference** to `/dev-audit` steps 1–2 — the new skill contains no duplicated
   detection tables or ecosystem lists.
3. The skill defines the **L0–L3 altitude ladder** and a **lens catalog v1**, each lens carrying a
   one-line charter + applicable altitudes, with the per-critic own-schema rule restated and lens
   prompts/schemas explicitly deferred to the engine story.
4. **Deterministic compile:** all profile→plan decisions live in a rule table (Table P) — exact
   predicates and thresholds, a fixed 90-day churn window, row identity `(lens, altitude, scope)`,
   a highest-depth-wins collision rule with accumulated whys — plus a defined override grammar
   whose unknown tokens are a reported error, never guessed. Same repo state + same overrides ⇒
   same plan; prose adds no judgment.
5. Running the skill compiles **canonical** `reviews/audit-plan-<date>.json` (validating against
   `plan-schema.json` v1, parse-checked before use) and **derives** `reviews/audit-plan-<date>.md`
   from it, with fixed sections: target profile · unit map · plan rows (lens × altitude × scope ×
   depth × units × runs × est-tokens × omission-risk × why) · overrides applied · cost estimate +
   assumptions · coverage & exclusions (explicit not-covered list) · plan status. On divergence the
   JSON wins and the view is regenerated.
6. The **consult stop** is mandatory and terminal this story: the plan is presented for
   edit/approval; the approved plan is recorded; the skill then stops with the loud
   engine-not-built message. Approval of a plan never triggers execution — there is nothing to
   execute, and the skill says so rather than improvising.
7. **Posture inherited verbatim from `/dev-audit`:** read-only against the target except the plan
   artifact(s); `BACKLOG.md` only on explicit instruction; the secret-redaction rule restated
   (recon surfaces secret *signals*, never values).
8. `install.sh` ships the skill; `tests/deep_audit_plan_test.sh` exists as a drift-only linter and
   is wired into both `.claude/workflow.json` `testCommand` and the `.github/workflows/ci.yml` gate
   line; the full gate is green.
9. `BACKLOG.md` OPS-13's first-slice line references `reviews/deep-audit-plan.md` as the build.
10. **Scope containment:** the diff touches only `.claude/skills/deep-audit/` (new — `SKILL.md` +
    `plan-schema.json`), `tests/deep_audit_plan_test.sh` (new), `install.sh`,
    `.claude/workflow.json`, `.github/workflows/ci.yml`, `BACKLOG.md`, and files under `reviews/`.

## Test notes

- **AC1–AC7** — the skill is Markdown instructions (same nature as the whole loop): verified by the
  new drift linter (token/phrase presence), the codex correctness pass reading the actual diff, and
  a human read. No behavioral oracle is invented (the established linter charter).
- **Smoke check (post-implementation, recorded in the story):** run `/deep-audit .` against this
  repo itself and confirm the plan artifact appears with all AC5 sections and the consult stop +
  loud engine stop both fire.
- **AC8** — run the full `testCommand`; inspect that `ci.yml` and `workflow.json` both name the new
  linter; confirm the linter is `has`/`absent` lines only.
- **AC9** — read OPS-13's build-note bullet; it links this story file.
- **AC10** — run `git diff --name-only main...HEAD` and verify no files appear beyond those AC10
  enumerates.

## Open questions — resolved 2026-07-19 (Thomas, frame consult)

1. **New skill vs a `/dev-audit` mode** → **new skill `/deep-audit`** — separate charter
   (plan-and-consult vs recon-and-report); `/dev-audit` stays lean (the OPS-11 every-line-costs
   lesson); reuse is by reference.
2. **Lens catalog v1** → **all four**: hidden-failure (L1), security-data-loss (L1+L3),
   test-adequacy (L1), architecture-coherence (L2/L3, reusing the design-review lens). Explicitly
   *not* simplicity/reinvention (the approach pass owns it — the OPS-12 boundary); dead-code not in
   v1 (two-way, add later).
3. **Plan artifact** → **JSON canonical + derived md view** (= design finding 2's fix): the `.json`
   is the versioned plan pinned by `plan-schema.json`; the `.md` derives from it — the C-ledger
   layout stub OPS-13 mandates, honored now.
4. **Cost-estimate method** → **per-row static arithmetic** (= design finding 3's fix): each row
   priced from its resolved scope with stated constants; refine constants from observed engine runs
   later.

## Design sketch — HOW

**One new skill file** (`.claude/skills/deep-audit/SKILL.md`), structured exactly like the existing
global skills — frontmatter (`name`, `description`), **Hard constraints** (read-only; report-first;
redaction; the loud engine stop), then **Steps**:

- **0 Stand-down** — `docs/ai-protocol.md` check, verbatim pattern from `/dev-audit`.
- **1 Detect (by reference)** — "run `/dev-audit` steps 1–2 against the target"; carry its profile
  forward (ecosystems, frameworks, tests, CI, secrets-signals, domain).
- **2 Unit map** — enumerate reviewable units from `git ls-files` grouped by top-level dir/module;
  per-unit size (file count, LOC) and **risk signals**: churn (`git log --since` counts),
  domain-sensitive paths (auth/payment/PII markers from detection), test-coverage presence. Large
  files noted as chunk-split candidates. This is where OPS-13's "B-borrowing" lives: risk signals
  set **depth at plan time** (deep/standard/light per unit group), not at runtime.
- **3 Suggest (Table P, deterministic)** — a numbered rule table: each rule = an exact predicate
  over step-2 signals/profile (thresholds pinned: churn window 90 days, high ≥ 20 commits, large
  file > 400 LOC, etc.) → an emitted/upgraded row keyed `(lens, altitude, scope)` with depth ∈
  {light, standard, deep}. **Collision rule:** one row per identity, highest depth wins, whys
  accumulate. **Override grammar** (applied after Table P, recorded before→after): `<lens>:off`,
  `<lens>:light|standard|deep`, `L2:off`/`L3:off`, `exclude=<glob>`, `only=<glob>`; an unknown
  token is a reported error, never guessed (the reviewer-override precedent).
- **4 Price & compile (JSON canonical)** — per-row: resolved `units` (chunk-adjusted), `runs`
  (units × depth factor: light ⅓ sampled, standard 1, deep 2), `estTokens` (runs × stated per-run
  constant), `omissionRisk` (one line: what goes unexamined if cut). Totals = Σ rows; wall-clock =
  batches at the stated concurrency cap. Write `reviews/audit-plan-<date>.json` conforming to
  `plan-schema.json` v1 (all fields required; parse-checked before use), then **derive** the `.md`
  consult view from the JSON — the JSON is canonical; on divergence regenerate the view.
- **5 Consult STOP** — present per the consult-presentation rule (every row: what it costs, what it
  risks); Thomas edits/approves; record the approved plan (status line in the artifact).
- **6 Loud stop** — "execution engine not yet built (follow-up story: OPS-13 engine slice)"; point
  at the approved plan artifact as the hand-off. No fallback, no partial run — the `llm`-stop
  pattern applied to a missing engine.

**Test linter** `tests/deep_audit_plan_test.sh`: `has`/`absent` drift lines for — stand-down
present; detection-by-reference phrase; ladder tokens (`L0`–`L3`); matrix header; artifact path
token `audit-plan-`; consult-stop phrase; loud engine-stop phrase; redaction restated; install.sh
ships it; ci.yml + workflow.json name it. Same "linter, not a behavioral gate" preamble as the
existing test files.

**Wiring:** `install.sh` gains one `ARTIFACTS` line; `.claude/workflow.json` `testCommand` and the
`ci.yml` gate line each gain `&& bash tests/deep_audit_plan_test.sh`.

**Backlog:** OPS-13's build-note bullet gains the link to this story file (AC9).

## Codex design review (2026-07-19)

**Verdict:** The overall shape is sound — a separate plan-only skill, detection reused by reference,
declarative steering, drift-only linting, existing wiring conventions, and a loud terminal stop all
fit OPS-13 and this repository. Not ready to build: the "compiler" lacks deterministic rule
resolution and a canonical machine-readable plan contract, and the priced consult is not represented
in the plan rows themselves.

### BLOCKER
- **The suggestion matrix is declarative in name but not deterministic in operation** — *one-way ·
  kludgy* · locus: sketch steps 2–3 + AC4. The spec promises same-profile → same-plan, but its
  inputs stay judgment calls: `git log --since` has no fixed window; "weak tests," "large,"
  "recent large refactor," "small mature repo," "never-reviewed mass" have no predicates or
  thresholds; overlapping signals can propose conflicting depths for one lens/altitude/scope; and
  "told" overrides have no declared syntax or replacement key. An agent following this prose can
  compile different plans from the same repo — violating the central compiled-plan invariant the
  engine will inherit. **Alternative:** one normalized rule table — exact signal predicates and
  thresholds, stable plan-row identity `(lens, altitude, scope)`, an explicit collision rule
  (highest depth wins, reasons accumulate), a fixed churn window, and a small override grammar
  (include/exclude/depth). All profile→plan decisions live in that construct. **Win:** eliminates
  per-run judgment from compilation, makes AC4 testable by inspection, gives the engine one stable
  steering rule.

### IMPORTANT
- **The JSON ledger stub has no canonical schema or source of truth** — *one-way · nonstandard* ·
  locus: OQ3 + sketch step 4. "md + JSON compiled together" is not yet a consistency design: the
  only compiler is an instruction-following agent, the JSON's keys/version are unspecified, and
  neither artifact is canonical — an approved md plan could silently diverge from the JSON the
  engine consumes. This is a one-way data contract, not a disposable companion. **Alternative:**
  ratify **JSON as the canonical, versioned plan artifact** with required fields + row identity in a
  JSON Schema; derive/validate the md consult view from that data. (Or ship md-only and stop calling
  it the C-ledger stub.) **Win:** one authoritative approved plan; no human-view/engine-view drift;
  the engine story doesn't reverse-engineer a shipped contract.
- **Plan rows don't carry the priced tradeoffs the consult requires** — *one-way · kludgy* · locus:
  AC5 + OQ4 + sketch steps 4–5. Rows hold lens/altitude/scope/depth/why, but the consult rule
  demands cost + risk per row — forcing a second ad-hoc presentation outside the artifact Thomas
  approves. The `units × rows` arithmetic is also wrong for scoped rows (not every row hits every
  unit; depths cost differently; wall-clock is concurrency-batched, not a Cartesian product).
  **Alternative:** each canonical row carries resolved unit count, run count, depth-specific token
  assumption, marginal cost, and inclusion/omission risk; totals = sum of scoped rows; wall-clock
  from concurrency-bounded batches; the consult presents those same stored rows. **Win:** approval
  and pricing centralized in one artifact; estimates tied to what the engine will actually schedule.

## Design decisions (2026-07-19)

Scope **approved** by Thomas at the frame consult (structured rulings on every axis); the shape
below is binding on implementation.

- **F1 BLOCKER — non-deterministic matrix → FIX.** All profile→plan decisions live in Table P:
  exact predicates and thresholds, fixed 90-day churn window, row identity `(lens, altitude,
  scope)`, highest-depth-wins collision with accumulated whys, defined override grammar (unknown
  token = reported error). Prose adds no judgment. AC4 and the sketch amended.
- **F2 IMPORTANT — no canonical contract → FIX** (confirmed alongside the OQ3 ruling). JSON is the
  canonical, versioned plan artifact, pinned by `plan-schema.json` v1 shipped in the skill dir; the
  md consult view derives from the JSON; JSON wins on divergence. AC5/AC10 amended.
- **F3 IMPORTANT — unpriced rows → FIX.** Every row carries resolved units, runs, token estimate,
  and omission risk; totals are summed from rows; wall-clock from concurrency-bounded batches.
  Resolves OQ4 as per-row static arithmetic. AC5 amended.
- **OQ1 → new `/deep-audit` skill.** `/dev-audit` untouched; detection reused by reference.
- **OQ2 → lens catalog v1 = all four** (hidden-failure L1 · security-data-loss L1+L3 ·
  test-adequacy L1 · architecture-coherence L2/L3); dead-code deferred (two-way).
- **OQ3 → JSON canonical + derived md** (= F2). **OQ4 → per-row arithmetic** (= F3).

## Smoke run (2026-07-19)

Ran the compile against this repo itself. Result: `reviews/audit-plan-2026-07-19.json` (canonical,
status `proposed`) + derived `.md` view — all AC5 sections present. Parse-check passed; **full
JSON-Schema validation against `plan-schema.json` passed** (jsonschema module present); totals
cross-check: Σ rows = 78 runs / 4.68M est. tokens = the totals block. Deterministic inputs recorded:
3 code groups (`(root)`, `.claude`, `tests` — all churn-high), 2 non-code groups (`.github`,
`reviews` → notCovered), 0 sensitive paths → no security rows, with the coverage block naming the
override to add them. Consult stop and loud engine stop confirmed as the terminal texts.

Dogfooding value: the smoke surfaced three determinism gaps pre-commit — root-level files had no
group, non-code groups drew nonsense L1 rows, and the `untested` predicate carried an undecidable
"covers it" clause — all fixed in the skill (the `(root)` group rule, the `non-code` scope rule,
and the simplified predicate) before this commit.

**Artifact-tracking note:** `.gitignore` ignores `reviews/audit-*.md` (its comment targets
`/dev-audit` *reports* as untracked local artifacts). The smoke plan's derived `.md` view is caught
by that glob and left **untracked — deliberately coherent** with the F2 design: the canonical
`.json` is committed (it is the plan and the engine's input); the view is regenerable from it on
demand. If Thomas wants plan *views* tracked while reports stay ignored, that is a one-line
`.gitignore` narrowing (e.g. `audit-????-??-??.md`) — out of AC10 scope, flagged for the review
round rather than silently expanding the diff.
