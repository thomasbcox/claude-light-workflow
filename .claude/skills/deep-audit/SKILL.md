---
name: deep-audit
description: OPS-13 first slice — compile a priced, deterministic whole-app audit plan (altitudes × lenses × depth × cost) for one repository, present it for Thomas's edit/approval, and stop. Plan stage only; the execution engine (critic fleet, adversarial verification, synthesis) is a follow-up story and this skill stops loudly at that boundary. Use when sizing or commissioning a comprehensive multi-lens audit of a repo.
---

# /deep-audit — compile the audit plan, consult, stop

Front door of the OPS-13 whole-app multi-lens audit. This skill is the **steering interface only**:
detect → unit map → deterministic compile → priced consult → **STOP**. It answers "what would a
comprehensive audit of this repo cost, and where would it look?" as a one-page approved plan the
future engine will execute exactly.

Invoked `/deep-audit [path] [overrides…]`. Target = `[path]` if given, else the current repo.

## Hard constraints
- **Plan stage only — the execution engine is not yet built** (follow-up story: the OPS-13 engine
  slice). After the consult, STOP with: *"The deep-audit execution engine is not yet built. The
  approved plan is recorded at reviews/audit-plan-<date>.json; the engine story will execute exactly
  that artifact."* Do **not** improvise execution — no critics, no workflow runs, no partial sweeps,
  no fallback. (The `llm`-backend loud-stop pattern applied to a missing engine.)
- **Read-only against the target** except the two plan artifacts. `BACKLOG.md` only on explicit
  instruction. Install nothing.
- **Redact secret evidence** (the `/dev-audit` rule, verbatim): detection may surface secret
  *signals* — report detector/type · path:line · count only, **never a value**, in chat and in both
  artifacts.
- **Determinism:** every profile→plan decision lives in **Table L** (lens catalog) and **Table P**
  (plan rules) — prose adds no judgment. Same repo state + same overrides ⇒ same plan.
- **JSON is canonical:** `reviews/audit-plan-<date>.json` (contract: `plan-schema.json` v1, shipped
  in this skill dir) **is** the plan; the `.md` is a derived consult view. On any divergence the
  JSON wins — regenerate the view, never hand-edit it apart.

## Altitude ladder
- **L0 — lines:** function/block-level correctness. Reserved (no v1 lens; engine may add later).
- **L1 — units:** per-file (or per-chunk) judgment on a single reviewable unit.
- **L2 — subsystems:** cross-file patterns within a module (layering, error-model coherence).
- **L3 — application:** systemic, whole-app questions (authz coverage, data-flow, whether the
  architecture can surface its own failures).

## Table L — lens catalog v1
Per the OPS-12 standing rule, every lens critic — when the engine is built — owns **its own schema
and its own artifact**. Lens prompts and schemas are the **engine story's scope**; this catalog
carries only charter + altitudes.

| Lens | Charter | Altitudes |
|---|---|---|
| `hidden-failure` | Swallowed / absorbed / silently-degrading error handling (AGENTS.md "Hidden failure") | L1 |
| `security-data-loss` | Authn/authz, injection, secret handling, destructive-path safety; at L3: authz coverage + data-flow | L1, L3 |
| `test-adequacy` | Do the tests actually exercise what the unit claims to do | L1 |
| `architecture-coherence` | Cross-file patterns, layering, error-model coherence — reuses the design-review lens (`AGENTS.md` + `design-review-schema.json`, the dev-audit Table A precedent) | L2, L3 |

*Not* a lens: simplicity/reinvention — the review loop's approach pass owns it (the OPS-12
boundary). Dead-code: not in v1 (two-way; add as a later catalog row).

## Steps

### 0. Stand-down
Resolve the target root: `git -C <path|.> rev-parse --show-toplevel`. If **`docs/ai-protocol.md`**
exists there, STOP — that repo runs its own heavier workflow; use its native tooling. No reads for
a report, no writes.

### 1. Detect (by reference)
Run **`/dev-audit` steps 1–2** against the target (languages/ecosystems, framework files, test
setup, CI config, secret patterns, domain context — and its Table A toolset selection for the
profile record). Carry the profile forward; do **not** duplicate its detection lists here.

### 2. Unit map (deterministic)
- **Scope filter first:** `exclude=<glob>` / `only=<glob>` patches (step 4) apply **here, before
  unit-map compilation** — they filter the `git ls-files` list itself, so group membership is
  addressable at file granularity.
- **Units and unit IDs:** the (filtered) tracked files, grouped by top-level directory; files at
  the repo root form the **`(root)`** group; a group with > 200 files splits by second-level
  directory. Every unit gets a **stable unit ID**: a file's ID is its repo-relative path; a file
  > 400 LOC splits into `ceil(LOC/400)` chunk-units with IDs `path#1..#n`. Each group's
  lexicographically **ordered `unitIds` list is stored in the plan's `unitMap`** — it is the ID
  registry the rows and the engine address; `chunkUnits = |unitIds|` by construction. (L2/L3
  scopes are their own single unit: `subsystem:<dir>` / `app`.) A group containing no file of any
  detected code ecosystem (step-1 profile — e.g. only md/json/yml) is marked **`non-code`**: it
  emits no L1/L2 rows and is listed under `coverage.notCovered`.
- **Signals** (fixed predicates, evaluated per group):
  - `churn-high` — ≥ 20 commits touching the group in `git log --since='90 days ago'`.
  - `sensitive` — any path matching (case-insensitive) `auth|payment|billing|secret|crypto|token|session|pii`, or the detection profile flags an auth/payments/PII domain.
  - `untested` — no file in the group matches the detection's test patterns.
  - `legacy` — the group's newest commit is older than the target's `reviews/` directory birth
    commit (no `reviews/` ⇒ older than 1 year). "Never passed through the loop."

### 3. Compile rows — Table P (phased, deterministic)
Row identity = **`(lens, altitude, scope)`**; scope = a unit-group path, `subsystem:<dir>` (L2), or
`app` (L3). Depth ∈ `light | standard | deep`. The compile runs **three declared phases — emit,
resolve, transform — in that order**; each phase's result is mechanically determined before the
next runs (no rule ever needs procedural interpretation).

**Phase A — emit (baseline candidate rows):**

| # | Predicate | Row emitted | Depth |
|---|---|---|---|
| P1 | always | (`hidden-failure`, L1, each unit-group) | standard |
| P2 | group `sensitive` | (`security-data-loss`, L1, that group) | deep |
| P3 | any `sensitive` group OR sensitive domain in profile | (`security-data-loss`, L3, `app`) | standard |
| P4 | group `untested` | (`test-adequacy`, L1, that group) | standard |
| P5 | group not `untested` | (`test-adequacy`, L1, that group) | light |
| P6 | ≥ 2 top-level groups | (`architecture-coherence`, L2, each `subsystem:<dir>` with ≥ 5 files) | standard |
| P7 | always | (`architecture-coherence`, L3, `app`) | standard |

**Phase B — resolve (upgrades; max wins):**

| # | Predicate | Upgrade | Depth |
|---|---|---|---|
| P8 | group `legacy` | that group's `hidden-failure` L1 row | deep |
| P9 | group `churn-high` | that group's `hidden-failure` + `security-data-loss` L1 rows | one step deeper |

One row per identity; the **highest** depth wins (`light < standard < deep`); every firing rule's
*why* accumulates on the row (`"why": ["P1: baseline", "P8: legacy — never passed through the
loop"]`). An upgrade to a row Phase A did not emit is a **no-op**.

**Phase C — named post-resolution transforms (declared order):**

| Order | Transform | Predicate | Effect |
|---|---|---|---|
| 1 | `mature-downgrade` | dev-audit Table B tier = `mature` AND no `sensitive` groups | every L1 row one step lighter (floor `light`) |

Transforms run **after** resolution, so a downgrade has one mechanically determined result; future
transforms append to this table with an explicit order, never as new collision semantics.

**Scope rules:** Phase A L1 rules (P1/P2/P4/P5) and P6 apply to **code groups only** — `non-code`
groups go to `coverage.notCovered`, not the plan.

### 4. Overrides — the told **patch model** (a discriminated union by `op`)
Every consult-time edit — a CLI token **or** a direct row change at the step-7 consult — normalizes
to one patch from a **discriminated union**; the schema rejects any op/payload mismatch:

- **`remove`** / **`restrict`** — `{token, selector: {lens|*, altitude|*, scope|*}, op, source}` —
  selector only, **no depth field**. `restrict` drops rows **not** matching.
- **`set-depth`** — `{token, selector, op, depth, source}` — **depth required**, applied to every
  row the selector matches.
- **`add`** — `{token, rowIntent: {lens, altitude, scope, depth}, op, source}` — a **complete
  row-intent** (no selector); the row's `unitIds`, `units`, `runs`, `estTokens`, and `omissionRisk`
  derive **deterministically** from the intent via steps 2 and 5, so nothing about an added row
  rests on fresh judgment at replay time.

Patches are recorded verbatim in the plan's `overrides` block and apply in given order — glob
patches (`exclude`/`only`) act at **step 2, before unit-map compilation** (file granularity); row
patches act **after Phase C**. The approved plan is **replayable** from repo state + patches; there
is **no second edit path**.

CLI tokens (space- or comma-separated after `[path]`) parse to patches:
- `<lens>:off` → `remove {lens, *, *}` — drop every row of that lens.
- `<lens>:light|standard|deep` → **set-or-add**: `set-depth` on every existing row of the lens; if
  none exist, `add` patches by **Table L expansion** — for each altitude Table L allows the lens:
  L1 → one row-intent per code group, L2 → one per qualifying subsystem, L3 → `app` — at the given
  depth. (This is what makes the coverage block's security opt-in actually expressible.)
- `L2:off` / `L3:off` → `remove {*, L2|L3, *}` — drop an altitude.
- `exclude=<glob>` → `remove {*, *, glob}` · `only=<glob>` → `restrict {*, *, glob}` — both applied
  at step 2 (see above).

Direct consult edits serialize through the **same union** with `source: consult`.
An **unknown token is an error** — report it and stop; never guess (the reviewer-override
precedent).

### 5. Resolve units and price each row (static arithmetic, all figures ESTIMATE)
- `units` — resolved chunk-adjusted unit count in the row's scope (L2: 1 per subsystem; L3: 1).
- **`unitIds` — the units this row will actually run**, resolved from the scope's `unitMap` entry:
  **standard** and **deep** → the group's full ordered list; **light** → the **pinned sample**:
  every 3rd entry of the lexicographically ordered list (indices 0, 3, 6, …). The sampling inputs
  (the ordered list) live in `unitMap`, so the selection is reproducible from the artifact alone —
  the engine runs exactly `unitIds`, never re-chooses.
- `runs` — `|unitIds| ×` (deep ? 2 : 1); equivalently light `ceil(units/3)`, standard `units`,
  deep `2×units`.
- `estTokens` — `runs × 60k` (assumption: ≈ 60k tokens per critic-run, all-in; refine from observed
  engine data).
- `omissionRisk` — one line: what goes unexamined if this row is cut.
- **Totals** = Σ rows; **wall-clock** ≈ `ceil(totalRuns / 8) × 3 min` (assumptions: concurrency 8,
  ≈ 3 min/run). Print every assumption in the plan's `assumptions` block.

### 6. Write the artifacts (JSON canonical → md derived)
Write `reviews/audit-plan-<YYYY-MM-DD>.json` conforming to **`plan-schema.json` v1** (all fields
required; the schema also pins per-lens altitude pairings, positive counts, and the date format).
**Parse-check it** (`jq -e . file` or `python3 -c 'import json;json.load(...)'`), then run the
**plan semantic check** — the named contract check Draft-7 cannot express: (1) row identities
`(lens, altitude, scope)` are **unique**; (2) `totals.runs = Σ rows[].runs` and
`totals.estTokens = Σ rows[].estTokens`; (3) per unit-map group, `chunkUnits = |unitIds|`; (4) per
row, `runs = |unitIds| × (deep ? 2 : 1)`, with light rows' `unitIds` matching the pinned every-3rd
sample of their group's ordered list. Schema validation **plus** the semantic check is the
canonical contract gate — on any failure STOP loudly; never present a view of an invalid plan.
Then **derive**
`reviews/audit-plan-<YYYY-MM-DD>.md` from the JSON, fixed sections in order: **Target profile ·
Unit map · Plan rows** (lens / altitude / scope / depth / units / runs / est-tokens /
omission-risk / why) **· Overrides applied · Cost estimate + assumptions · Coverage & exclusions**
(explicit **not covered** list: excluded globs, dropped altitudes/lenses, L0 reserved) **· Plan
status**.

### 7. Consult — STOP for Thomas
Present the plan rows **from the artifact** per the consult-presentation rule — each row already
carries its cost (`estTokens`) and risk (`omissionRisk`); read them, don't improvise a second
narrative. Thomas edits — every edit, token or direct, becomes a **recorded patch** (step 4,
`source: consult`); re-run steps 4–6 on any edit (JSON first, view re-derived) — or approves. On
approval set `"status": "approved"` in the JSON and regenerate the view. **Approval approves the
plan, not execution.**

### 8. Loud stop (terminal)
*"The deep-audit execution engine is not yet built (follow-up story: the OPS-13 engine slice). The
approved plan is recorded at `reviews/audit-plan-<date>.json` — the engine story will execute
exactly that artifact."* Nothing else runs.
