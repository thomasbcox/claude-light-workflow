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
- **Pin the snapshot first:** capture the **source identity** — `revision` (`git rev-parse HEAD`)
  and a `dirty` flag (`git status --porcelain` non-empty) — and the `evaluatedAt` cutoff. **For a
  clean tree, `evaluatedAt` = the bound revision's committer timestamp** (`git show -s
  --format=%cI HEAD`), so recompiling the same committed source yields the same cutoff, the same
  churn window, and the same plan — reproducibility comes from the source, not the wall clock. For
  a **dirty tree**, fall back to the wall-clock instant and note it: an uncommitted tree is not
  uniquely reproducible (the `dirty` boolean does not capture *what* changed — the content-level
  fingerprint that would is the engine story's, per OPS-13). **Every time-relative predicate
  derives from the stored `evaluatedAt`, never from run time.** All three land in the `source`
  block (step 6).
- **Scope filter first:** `exclude=<glob>` / `only=<glob>` patches (step 4) apply **here, before
  unit-map compilation** — they filter the `git ls-files` list itself, so group membership is
  addressable at file granularity.
- **Units and unit IDs:** the (filtered) tracked files, grouped by top-level directory; files at
  the repo root form the **`(root)`** group; a group with > 200 files splits by second-level
  directory. Every unit gets a **stable unit ID**: a file's ID is its repo-relative path; a file
  > 400 LOC splits into `ceil(LOC/400)` chunk-units with IDs `path#1..#n`. Each group's
  lexicographically **ordered `unitIds` list is stored in the plan's `unitMap`** — it is the ID
  registry the rows and the engine address; `chunkUnits = |unitIds|` by construction. (L2/L3
  scopes are their own single unit: `subsystem:<dir>` / `app`.)
- **Code vs non-code is a per-UNIT property, not per-group** (the classification granularity must
  match the scheduling granularity — L1 rows schedule *units*). A unit is **code** iff its file
  belongs to a detected **code** ecosystem — a step-1 / Table A row that carries a linter/analyzer
  (e.g. shell `*.sh`, Python, JS/TS, Go…); Markdown-docs and data/config-only files (`*.md`,
  `*.json`, `*.yml`, `.gitignore`, lockfiles) are **non-code**. Each group stores its ordered
  **`codeUnitIds`** (the code subset of `unitIds`) in `unitMap`. A group whose `codeUnitIds` is
  **empty** is the `non-code` shortcut — it emits no L1/L2 rows. Non-code units inside a **mixed**
  group are **not scheduled** and are summarised in `coverage.notCovered` (so `README.md` sitting
  next to `install.sh` is excluded exactly as it would be in a docs-only directory).
- **Signals** (fixed predicates, evaluated per group):
  - `churn-high` — ≥ 20 commits touching the group in the **90 days ending at `evaluatedAt`**
    (`git log --since='<evaluatedAt − 90d>' --until='<evaluatedAt>'`).
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

**Phase C — named post-resolution transforms (declared order): _none in v1_.**

The phase exists as the declared extension point: a transform that *lowers* depth cannot be
expressed as a Phase-B upgrade (a max-wins reducer can never resolve downward), so any future
downgrade belongs here, numbered, running **after** resolution — never as new collision semantics.
**v1 ships no transforms**: the only candidate (`mature-downgrade`, keyed on `/dev-audit` Table B's
maturity tier) consumed an input this skill's recon boundary does not produce — Table B is
`/dev-audit` **step 5**, while step 1 here reuses only its **steps 1–2**. Rather than widen the
boundary to fetch a tier, the rule was dropped: **every Table P predicate now reads only signals
this skill computes itself** (step-2 unit-map signals) plus the steps 1–2 profile. Lightening a
well-maintained repo remains available as an explicit `<lens>:<depth>` override patch (step 4) —
a human judgment rather than a maturity heuristic.

**Scope rules:** Phase A L1 rules (P1/P2/P4/P5) and the P6 L2 rule apply only to groups with **≥1
code unit** (empty-`codeUnitIds` groups emit nothing). An emitted L1 row covers **only the scope's
`codeUnitIds`**, never its non-code units (step 5 resolves the exact set); `untested` and other
signals are still evaluated per group.

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
- **`unitIds` — the units this row will actually run.** For an **L1** row, resolve from the scope's
  **`codeUnitIds`** (never the full `unitIds` — non-code units are out of scope, per step 3):
  **standard** / **deep** → the full ordered `codeUnitIds`; **light** → the **pinned sample**: every
  3rd entry of that ordered list (indices 0, 3, 6, …). For **L2/L3** the row's single synthetic unit
  is its scope (`subsystem:<dir>` / `app`). The sampling input (the ordered list) lives in `unitMap`,
  so the selection is reproducible from the artifact alone — the engine runs exactly `unitIds`,
  never re-chooses.
- `units` — the scope's schedulable count: L1 → `|codeUnitIds|`; L2/L3 → 1.
- `runs` — `|unitIds| ×` (deep ? 2 : 1); equivalently light `ceil(units/3)`, standard `units`,
  deep `2×units`.
- `estTokens` — `runs × 60k` (assumption: ≈ 60k tokens per critic-run, all-in; refine from observed
  engine data).
- `omissionRisk` — one line: what goes unexamined if this row is cut.
- **Totals** = Σ rows; **wall-clock** ≈ `ceil(totalRuns / 8) × 3 min` (assumptions: concurrency 8,
  ≈ 3 min/run). Print every assumption in the plan's `assumptions` block.

### 6. Write the artifacts (JSON canonical → md derived)
**Artifact identity — one stamp per invocation.** Mint `compiledAt` (the compile instant) **once**,
at the start of this invocation, and write to
**`reviews/audit-plan-<YYYY-MM-DD>T<HHMMSS>.json`** (compact, colon-free so it is filesystem- and
shell-safe, and sorts chronologically as plain text). Because every invocation gets its own path, a
later run **can never overwrite an earlier — approved — plan**; collisions are impossible by
construction rather than guarded against. The accumulating series is the target's plan history.
**Consult edits do NOT re-mint the stamp:** a step-7 edit recompiles into the *same* file, so one
invocation leaves exactly one plan and "which plan was approved" is never ambiguous. (`compiledAt`
is *when compiled*; `source.evaluatedAt` is *the signal cutoff* — for a clean tree the bound
revision's commit time. Different facts; both recorded.)
The artifact conforms to **`plan-schema.json` v1** (all fields
required; the schema also pins per-lens altitude pairings, positive counts, and the date format),
including the **`source` block** — `{revision, dirty, evaluatedAt}` from step 2 — which records the
code state and signal window the plan was compiled against. The plan **identifies** its source; the
engine's exact **verification policy** — how it confirms the target still matches `source.revision`
(note the plan artifact lives *in* the audited repo, so committing it advances HEAD past the bound
revision; the engine operates on `source.revision` itself, excluding generated plan/review
artifacts), and how it fingerprints a dirty tree — is the **engine story's** (OPS-13, with the
deferred executability gate). This story records the binding; it does not define the check.
**Parse-check it** (`jq -e . file` or `python3 -c 'import json;json.load(...)'`), then run the
**plan semantic check** — the named contract check Draft-7 cannot express: (1) row identities
`(lens, altitude, scope)` are **unique**; (2) `totals.runs = Σ rows[].runs` and
`totals.estTokens = Σ rows[].estTokens`; (3) per unit-map group, `chunkUnits = |unitIds|` and
`codeUnitIds ⊆ unitIds` (order-preserved); (4) per row, `runs = |unitIds| × (deep ? 2 : 1)`; (5)
**every L1 row's `unitIds` are drawn from its scope's `codeUnitIds`** — standard/deep = the full
`codeUnitIds`, light = the pinned every-3rd sample of it — so no non-code unit is ever scheduled.
Schema validation **plus** the semantic check is the
canonical contract gate — on any failure STOP loudly; never present a view of an invalid plan.
Then **derive** the sibling `reviews/audit-plan-<YYYY-MM-DD>T<HHMMSS>.md` (same stamp) from the
JSON, fixed sections in order: **Source · Target profile ·
Unit map · Plan rows** (lens / altitude / scope / depth / units / runs / est-tokens /
omission-risk / why) **· Overrides applied · Cost estimate + assumptions · Coverage & exclusions**
(explicit **not covered** list: excluded globs, dropped altitudes/lenses, L0 reserved) **· Plan
status**.

### 7. Consult — STOP for Thomas
Present the plan rows **from the artifact** per the consult-presentation rule — each row already
carries its cost (`estTokens`) and risk (`omissionRisk`); read them, don't improvise a second
narrative. Thomas edits — every edit, token or direct, becomes a **recorded patch** (step 4,
`source: consult`); re-run steps 4–6 on any edit (JSON first, view re-derived) — **rewriting this
invocation's existing artifacts, never minting a new stamp** — or approves. On
approval set `"status": "approved"` in the JSON and regenerate the view. **Approval approves the
plan, not execution.**

### 8. Loud stop (terminal)
*"The deep-audit execution engine is not yet built (follow-up story: the OPS-13 engine slice). The
approved plan is recorded at `reviews/audit-plan-<date>.json` — the engine story will execute
exactly that artifact."* Nothing else runs.
