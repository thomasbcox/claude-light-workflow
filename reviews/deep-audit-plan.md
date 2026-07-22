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
   predicates and thresholds, a churn window fixed at 90 days ending at the recorded `evaluatedAt`,
   row identity `(lens, altitude, scope)`, a highest-depth-wins collision rule with accumulated
   whys — plus a defined override grammar whose unknown tokens are a reported error, never guessed.
   The plan is **replayable**: it records every input it used (source revision, dirty flag,
   `evaluatedAt` cutoff, overrides) and reproduces from those recorded inputs; for a **clean tree**
   the compile is fully reproducible because `evaluatedAt` derives from the bound revision. Prose
   adds no judgment.
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

## Build note (2026-07-19)

AC → file map:
- **AC1** (skill exists, frontmatter, stand-down) → `.claude/skills/deep-audit/SKILL.md`.
- **AC2** (detection by reference, no duplicated tables) → `SKILL.md` step 1.
- **AC3** (L0–L3 ladder · lens catalog v1 · own-schema rule · prompts deferred) → `SKILL.md`
  (Altitude ladder + Table L).
- **AC4** (Table P determinism: predicates/thresholds, row identity, collision + scope rules,
  override grammar) → `SKILL.md` steps 2–4.
- **AC5** (canonical JSON per `plan-schema.json` v1, parse-check, derived md, fixed sections) →
  `SKILL.md` step 6, `.claude/skills/deep-audit/plan-schema.json`; smoke evidence
  `reviews/audit-plan-2026-07-19.json` (+ untracked derived view, per the gitignore note).
- **AC6** (consult stop; approval ≠ execution; loud engine stop) → `SKILL.md` steps 7–8.
- **AC7** (read-only posture, backlog-on-instruction, redaction) → `SKILL.md` Hard constraints.
- **AC8** (deploy + gate wiring) → `install.sh`, `tests/deep_audit_plan_test.sh`,
  `.claude/workflow.json`, `.github/workflows/ci.yml`.
- **AC9** (OPS-13 build link) → `BACKLOG.md`.
- **AC10** (scope containment) → verification only (`git diff --name-only main...HEAD`).

## Codex approach review (2026-07-19, base main, HEAD ea7bfc6)

**Verdict:** The approved high-level shape is sound — plan-only skill, referenced recon, canonical
JSON with a derived consult view, conventional drift linting/wiring, loud engine stop. Revise the
declarative core before treating v1 as the future engine's stable contract: rule precedence is
internally inconsistent, told overrides are not fully expressible or replayable, and the schema does
not enforce several invariants it claims to own.

### IMPORTANT
- **Table P mixes incompatible resolution models** — *two-way · kludgy* · locus: SKILL.md step 3.
  P1–P9 emit/upgrade under highest-depth-wins; P10 *downgrades* — which can never win that reducer,
  so P10 is either a no-op or an unstated ordered-mutation exception. Declarative in appearance,
  procedural in fact. **Alternative:** explicit phases — emit baseline candidates → resolve upgrades
  by max depth → apply named post-resolution transforms (the mature-repo downgrade) in declared
  order; or drop P10 if maturity should never override risk. **Win:** one mechanically determined
  result per rule, no special-case interpretation in any future compiler.
- **The told-override contract cannot express or replay all approved edits** — *one-way ·
  nonstandard* · locus: SKILL.md steps 4/7 + schema `overrides`. `<lens>:<depth>` only sets
  *existing* rows — it cannot enable a lens Table P omitted, yet the smoke artifact itself tells
  Thomas to add absent security coverage exactly that way. Direct consult edits aren't normalized
  into the recorded overrides, so an approved plan stops being reproducible from repo state +
  overrides — weakening the compiled-plan seam the engine inherits. **Alternative:** one normalized
  patch model for every consult edit — selector (lens/altitude/scope) + operation (add/set/remove) +
  depth, expanding over Table L when the selected row is absent; CLI tokens parse into those patches;
  direct edits serialize through the same representation. **Win:** one replayable told seam; the
  documented security opt-in actually works; differential mode can reconstruct why every row exists.
- **The canonical schema does not own the catalog and pricing invariants** — *one-way ·
  nonstandard* · locus: plan-schema.json. It accepts hidden-failure@L3, architecture-coherence@L1,
  negative counts, duplicate `(lens, altitude, scope)` identities, and totals unrelated to row sums —
  so passing validation does not establish executability; the real invariants live duplicated in
  prose and ad-hoc smoke checks. **Alternative:** encode what Draft-7 can own (lens-specific
  altitude variants, positive counts, non-empty strings, date format) + one small semantic check for
  uniqueness and row/total arithmetic; that combined validation is the canonical contract check
  before deriving the view. **Win:** malformed schedules rejected before approval; lens
  applicability centralized; the engine sheds defensive branches.

## Decisions (2026-07-19, approach round)

Thomas: **"fix all"** — all three approach findings approved as redesign fixes. Per the step-7
gate, the correctness pass was **deliberately not run** this round; the redesigned shape re-enters
review via a fresh approach pass after `/close` applies:

- **F1 — Table P resolution model → FIX.** Phased compile: (1) emit baseline candidate rows, (2)
  resolve upgrades by max depth (P8/P9), (3) apply **named post-resolution transforms in declared
  order** — P10 becomes the `mature-downgrade` transform. Every rule gets one mechanically
  determined result; P10 stays (maturity may soften risk) but through a declared phase.
- **F2 — told-override contract → FIX.** One normalized **patch model**: selector `(lens, altitude,
  scope)` + operation `add | set | remove` + depth. CLI tokens parse into patches; direct consult
  edits serialize through the same representation; `add` expands over Table L when the selected row
  is absent (making the smoke plan's security opt-in actually expressible). The schema's
  `overrides` block records structured patches, not free-form prose — the approved plan is
  replayable from repo state + patches.
- **F3 — schema invariants → FIX.** `plan-schema.json` gains per-lens altitude pairings (Table L
  encoded), positive counts, non-empty strings, date format; plus a **named semantic check**
  (row-identity uniqueness, totals = Σ rows) that must pass before the md view derives. Validation
  passing = executable under the contract. Contract stays `planVersion: 1` (nothing shipped has
  consumed v1); `/close` re-runs the smoke compile under the revised contract so the evidence
  stays honest.

## Fixes (2026-07-19, approach round)

- **F1 — phased Table P.** Step 3 restructured into three declared phases: **A emit** (P1–P7
  baseline candidates) → **B resolve** (P8/P9 upgrades; highest depth wins, whys accumulate;
  upgrade-to-absent-row is a no-op) → **C named post-resolution transforms in declared order**
  (`mature-downgrade`, the former P10, with floor `light`). Every rule now has one mechanically
  determined result; future transforms append with an explicit order.
- **F2 — told patch model.** Step 4 rewritten: every edit (CLI token or direct consult change)
  normalizes to `{token, selector(lens|*, altitude|*, scope|*), op add|set|remove|restrict,
  depth|null, source cli|consult}`, applied after Phase C in order and recorded in `overrides` —
  the approved plan is replayable from repo state + patches. `<lens>:<depth>` is **set-or-add**
  with **Table L expansion** when no rows exist (the smoke plan's security opt-in is now
  expressible); `only=` is the `restrict` op; consult edits ride the same shape (`source:
  consult`).
- **F3 — contract-owning schema + semantic check.** `plan-schema.json` now pins per-lens altitude
  pairings via `oneOf` (hidden-failure→L1; security-data-loss→L1|L3; test-adequacy→L1;
  architecture-coherence→L2|L3), positive counts, non-empty strings, and the date format;
  `overrides` items are structured patches (free-form token/effect prose removed). Step 6 adds the
  named **plan semantic check** (row-identity uniqueness; totals = Σ rows) — schema + semantic
  check together are the canonical contract gate before the view derives.
- **Evidence refreshed:** the smoke artifact re-validated under the revised contract — schema
  PASSED (content needed no change), semantic check PASSED, and a negative test confirmed
  `hidden-failure@L3` is now **rejected** (it validated under the old schema). Linter updated for
  the new contracts (65 checks green); full gate + shellcheck/shfmt clean.

## Codex approach review — round 2 (2026-07-19, base main, HEAD 4fb7e85)

**Verdict:** The phased Table P redesign is mechanically coherent, and schema + the named semantic
check now own the agreed row/catalog invariants. Two one-way contract gaps remain: the canonical
plan does not identify the exact units an engine must run, and the normalized patch representation
cannot replay every consult edit it claims to support.

### IMPORTANT
- **Canonical rows price units without identifying them** — *one-way · nonstandard* · locus:
  SKILL.md steps 2/5 + schema unitMap/rows. Rows carry aggregate counts, not file identities, chunk
  boundaries, or which units a light-depth sample selected — so the engine cannot "execute exactly
  that artifact"; it would re-derive chunks and re-choose samples, letting one approved plan produce
  different coverage. **Alternative:** stable unit IDs in `unitMap`; each row records its ordered
  resolved unit IDs (or its explicit sample); a pinned deterministic sampling algorithm is
  acceptable if its complete inputs live in the artifact. **Win:** no engine-side scheduling
  judgment; approved coverage reproducible; coverage accounting names exactly what ran.
- **Patch records are not complete edit representations** — *one-way · nonstandard* · locus:
  SKILL.md step 4 + schema overrides. A patch carries selector/op/depth, but a row also carries
  units, pricing, omissionRisk, why — an added row or a direct edit to those fields cannot be
  replayed without fresh judgment; file-level `exclude`/`only` globs cannot address members of an
  aggregate group row; and the schema accepts incoherent forms (`add` with null depth, `remove`
  with depth). **Alternative:** a discriminated patch union — `remove`/`restrict` carry selectors
  only; `set-depth` requires depth; `add`/`replace` carries a complete row-intent payload from which
  pricing derives deterministically; apply file globs before unit-map compilation (or represent unit
  membership); schema rejects invalid op/payload combos. **Win:** every approved edit replayable
  without inference; malformed patch states impossible; one genuinely complete contract for CLI and
  consult edits.

## Decisions (2026-07-19, approach round 2)

Thomas: **"fix both"** — both round-2 findings approved as redesign fixes; correctness pass again
deliberately withheld per the step-7 gate.

- **R2-F1 — unit identity → FIX.** `unitMap` gains stable per-unit IDs (file paths; chunked files
  as `path#1..#n`); every row records its **ordered resolved unit IDs** — for light depth, the
  explicitly selected sample (pinned deterministic selection, inputs stored in the artifact). The
  engine executes exactly the listed units; coverage accounting names exactly what ran.
- **R2-F2 — complete patch union → FIX.** `overrides` becomes a **discriminated union** by `op`:
  `remove`/`restrict` carry selector only (no depth field); `set-depth` requires depth; `add`
  carries a complete row-intent (lens, altitude, scope, depth) from which units/pricing derive
  deterministically via the same step-5 arithmetic. Schema rejects invalid op/payload combinations.
  File-level `exclude`/`only` globs apply **before** unit-map compilation, so group membership is
  addressable. Every approved edit replays without inference.

## Fixes (2026-07-19, approach round 2)

- **R2-F1 — unit identity.** Step 2 now assigns every unit a **stable ID** (file path; chunked
  files `path#1..#n`) and stores each group's lexicographically **ordered `unitIds`** in `unitMap`
  (`chunkUnits = |unitIds|` by construction); step 5 resolves **every row's `unitIds`** — full list
  for standard/deep, the **pinned every-3rd sample** (indices 0,3,6…) for light — so the engine
  runs exactly the listed units. Schema requires `unitIds` on both structures; the semantic check
  gains invariants (3) `chunkUnits = |unitIds|` per group and (4) `runs = |unitIds| × (deep?2:1)`
  per row, with light samples verified against the pinned selection.
- **R2-F2 — discriminated patch union.** Step 4 and the schema now define patches as a union by
  `op`: `remove`/`restrict` are selector-only (**no depth field exists** on that branch);
  `set-depth` **requires** depth; `add` carries a complete **`rowIntent`** (lens/altitude/scope/
  depth, Table L pairings enforced) from which `unitIds`/pricing derive deterministically at replay
  — no selector, no fresh judgment. `exclude`/`only` globs act at **step 2, before unit-map
  compilation**, so file-level membership is addressable. Invalid op/payload combinations are
  schema-rejected.
- **Evidence refreshed (compile re-run, not hand-edit).** Regenerating the smoke surfaced honest
  drift — `reviews/` had grown by this story's own artifacts (86→88 chunk-units; `.claude`/`tests`
  LOC up) — so the unit map was **recomputed from the current tree** (code-group chunk counts
  unchanged ⇒ rows/pricing stand). Full contract gate: schema PASSED; semantic check with the two
  new invariants PASSED; negative test `remove`+depth **REJECTED**; positive test well-formed `add`
  patch **ACCEPTED**. Linter grew pins for unit identity, the union branches, pinned sampling, and
  pre-compile globs.

**Gate correction (2026-07-19):** the round-2 fix commit was made with the deep-audit linter RED
(3 drift failures: two load-bearing phrases line-wrapped mid-token by the rewrite; one stale
pre-`unitIds` schema pin left beside its successor) — caught immediately after push, against the
loop's own red-gate rule. Fixed in the follow-up commit; the linter's phrase pins did exactly their
job. Process note recorded so the trail is honest.

## Codex approach review — round 3 (2026-07-19, base main, HEAD 7a95260)

**Verdict:** The phased compiler, stable L1 unit IDs, pinned sampling, and discriminated row-patch
payloads are substantial improvements; the overall architecture is sound. v1 is not yet a complete
stable engine contract: approval is not bound to a source snapshot, the patch union does not
structurally distinguish compilation phases, and the semantic gate still permits schedules whose
units or prices cannot be fully verified from the artifact.

### IMPORTANT
- **The approved plan is not bound to a source snapshot** — *one-way · nonstandard*. The artifact
  records a mutable path + calendar date, no git revision/tree, and churn uses time-relative
  `--since='90 days ago'` — so an **unchanged repo compiles differently as time passes** (breaks
  this story's own "same repo state ⇒ same plan"), and the engine could execute changed content at
  the same path after approval. **Alternative:** record revision/tree id, dirty-state policy, and an
  ISO evaluation cutoff; derive the 90-day boundary from the stored cutoff; engine fails closed on
  source mismatch. **Win:** one approval ↔ one code state ↔ one signal window.
- **Patch phase is encoded in prose rather than the union** — *one-way · kludgy*. `exclude=` /
  `only=` (pre-compile file filters) share the `remove`/`restrict` branches with post-compile row
  edits; replay must infer phase from token text (and consult patches may have `token: null`).
  **Alternative:** dedicated branches `{op: exclude-files, glob}` / `{op: only-files, glob}`;
  selector-based `remove`/`restrict` reserved for compiled rows. **Win:** patch order and
  application point determined structurally, no token reparsing.
- **The semantic gate does not prove unit or pricing executability** — *one-way · nonstandard*. It
  verifies group counts, run factors, sampling, uniqueness, and sums — but not standard/deep
  `unitIds` ≡ the scope registry, `units` ≡ scope size, `estTokens` = runs × constant, or the
  wall-clock formula; pricing constants are prose; L2/L3 synthetic IDs (`subsystem:<dir>`, `app`)
  have no registry membership. **Alternative:** one registry for every executable scope (incl.
  subsystem/app membership), structural pricing constants, and a semantic check extended to full
  arithmetic. **Win:** the engine never re-derives or defensively re-validates its input.

## Decisions (2026-07-19, approach round 3)

Thomas: **"fix #1, defer the rest to the engine story"** — bounding the plan-stage contract at this
story's own promises; engine-grade input validation belongs to the story that builds the engine.

- **R3-F1 — source snapshot binding → FIX.** The plan gains source identity: git revision (tree
  state), a dirty-state note, and an ISO **evaluation cutoff**; the churn window derives from the
  stored cutoff (not from run time), restoring "same repo state ⇒ same plan." The engine will fail
  closed on source mismatch.
- **R3-F2 — patch-phase structural ops → DEFER to the engine story** (recorded as an opening AC
  there: dedicated `exclude-files`/`only-files` branches; selector `remove`/`restrict` reserved for
  rows).
- **R3-F3 — full executability semantic gate → DEFER to the engine story** (opening AC there: scope
  registry incl. L2/L3 membership, structural pricing constants, full-arithmetic checks — the
  executor build determines which checks earn their place). `planVersion` 1 has no consumers, so
  the engine story may extend the contract without a version dance.

Per the step-7 gate the correctness pass again waits: the snapshot-binding fix is a contract
change, so the shape re-enters review once more after `/close`.

## Fixes (2026-07-19, approach round 3)

- **R3-F1 — source snapshot binding.** Step 2 now pins the snapshot first: `evaluatedAt` (ISO
  cutoff) + `source.revision` (`git rev-parse HEAD`) + dirty flag; **every time-relative predicate
  derives from the stored cutoff** (churn = the 90 days *ending at `evaluatedAt`*), restoring
  "same repo state ⇒ same plan." Step 6 writes the required `source` block and states the engine's
  obligation: **fail closed on source mismatch**. Schema: `source {revision, dirty, evaluatedAt}`
  required, ISO pattern pinned. Smoke artifact recompiled: source block added, churn honestly
  recounted under the cutoff window ((root) 42 · .claude 47 · tests 24 — thresholds unchanged;
  `reviews` now churn-high too, non-code so no row impact); negative test: a plan **without**
  `source` is now rejected. Deferred R3-F2/R3-F3 recorded as engine-slice opening ACs in OPS-13
  (BACKLOG.md), untouched here per the decisions.

## Codex approach review — round 4 (2026-07-19, base main, HEAD ac1d17d)

**Verdict:** The plan-stage architecture is otherwise sound, and the two engine-story deferrals
remain settled. One source-binding contract gap remains: the new revision-plus-dirty-flag
representation does not uniquely identify the audited source state.

### IMPORTANT
- **The snapshot binding is circular and does not identify dirty content** — *one-way ·
  nonstandard*. Three sub-claims: (1) `source.revision` identifies only HEAD and `dirty` is a mere
  boolean, so distinct dirty trees share one identity; (2) the plan lives *in* the audited repo, so
  committing it advances HEAD — the smoke plan records `53e6a90` but is committed at `ac1d17d`, so a
  naive "revision == current HEAD" check self-invalidates; (3) a fresh compile-time `evaluatedAt`
  means recompiling unchanged source can still shift the churn window, so "same repo state ⇒ same
  plan" is not literally true. **Alternative:** bind to a content fingerprint of the audited file
  set (excluding generated plan artifacts) that the engine recomputes; make `evaluatedAt` an
  explicit replay input or derive it from the bound revision; *or* require a clean tree and keep
  plan artifacts outside the audited revision. **Win:** an actual one-plan-to-one-source invariant,
  no dirty ambiguity, no in-repo self-invalidation, one unambiguous engine comparison — without
  reopening the deferred executability work.

## Decisions (2026-07-19, approach round 4)

Thomas: **"hybrid fix"** — correct only what *this story* over-claims; hand the precise
source-identity *mechanism* to the engine story. Correctness pass again withheld per the step-7
gate (approved fix = redesign). Scope of the fix `/close` will apply, exactly:

- **R4-F1a — honest invariant → FIX (this story).** Downgrade AC4's "same repo state + same
  overrides ⇒ same plan" to the accurate **replayability** property: *the plan records every input
  it used (source revision, dirty flag, `evaluatedAt` cutoff, overrides) and is reproducible from
  those recorded inputs.* Update AC4 and the skill wording to match.
- **R4-F1b — stable cutoff → FIX (this story).** Derive `evaluatedAt` from the **bound revision's
  committer timestamp** for a clean tree (so recompiling unchanged committed source yields the same
  churn window and the same plan); fall back to wall-clock only for a dirty tree, explicitly
  labelled non-reproducible. Skill step 2 + the smoke artifact refresh.
- **R4-F1c — stop over-specifying the engine check → FIX (this story).** Replace the naive
  "engine fails closed if target revision ≠ current HEAD" (self-invalidating for an in-repo plan)
  with: *the plan records source identity; the engine's exact mismatch/verification policy —
  including the self-hosted plan-in-repo case and dirty-tree content identity — is the engine
  story's.* Skill step 6 wording.
- **R4-F1d — precise source fingerprint → DEFER to the engine story.** The content-fingerprint of
  the audited file set (excluding generated plan artifacts) that the engine recomputes, and unique
  dirty-tree identification, fold into OPS-13's existing R3-F3 engine AC (executability gate).

## Fixes (2026-07-19, approach round 4 — hybrid)

- **R4-F1a (honest invariant).** AC4 + the skill now state the accurate **replayability** property —
  the plan records every input (source revision, dirty, `evaluatedAt`, overrides) and reproduces
  from them — instead of the over-claimed "same repo state ⇒ same plan."
- **R4-F1b (stable cutoff).** Step 2: for a **clean tree** `evaluatedAt` = the bound revision's
  committer timestamp (`git show -s --format=%cI HEAD`), so recompiling committed source is fully
  reproducible; a **dirty tree** falls back to wall-clock, explicitly labelled non-reproducible.
- **R4-F1c (stop over-specifying the engine).** Step 6 replaced the self-invalidating "fail closed
  if revision ≠ current HEAD" with: the plan **records** source identity; the engine owns the
  **verification policy** (incl. the in-repo-plan self-reference and dirty-tree fingerprint).
- **R4-F1d (defer the mechanism).** OPS-13's engine AC extended with source-identity verification:
  content fingerprint of the audited set excluding generated plan/review artifacts, dirty-tree
  identity, fail-closed check.
- **Smoke refresh.** Recompiled: `source` block present; because this ran mid-`/close` the tree was
  dirty, so it took the fallback path (honestly recorded). Full contract gate PASSED (schema +
  semantic check); drift linter re-pinned for the reworded contracts.

## Codex approach review — round 5 (2026-07-21, base main, HEAD b2cd5e3)

**Verdict:** The plan-stage architecture is sound overall, and all round 1–4 decisions remain closed.
One lifecycle gap keeps it from being fully ready: the date-only canonical path can silently replace
an already approved plan.

### IMPORTANT
- **Date-only artifact identity can overwrite an approved plan** — *one-way · nonstandard*. Every
  invocation writes `reviews/audit-plan-<YYYY-MM-DD>.json` with no plan identifier or collision
  policy. Consult edits legitimately regenerate the *current proposal*, but a **separate invocation
  the same day** targets the identical canonical path and can **silently replace an approved engine
  handoff** — and the contract cannot distinguish another revision, target state, or override set
  compiled that day. **Alternative:** give each plan an immutable identity (date + short source
  revision + sequence/nonce) recorded in schema and filename; *or* keep the date path for an active
  proposal but **fail closed before replacing an `approved` artifact**, requiring a new uniquely
  named plan.
