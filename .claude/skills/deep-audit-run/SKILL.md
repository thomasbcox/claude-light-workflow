---
name: deep-audit-run
description: OPS-13 engine slice 1 — execute an APPROVED /deep-audit plan end-to-end for the hidden-failure L1 lens: verify source identity (recompute the plan's contentFingerprint) + plan executability, expand a run manifest, run the critic fleet, adversarially verify every finding with a claim-blind cross-model verifier + mechanical-first adjudication, and synthesize a precision-first report with coverage accounting. Report-first; stops loudly on any failure or on an unapproved plan. Use after /deep-audit has produced and Thomas has approved a plan.
---

# /deep-audit-run — execute the approved audit plan

The **execution engine** `/deep-audit` stops loudly in front of. `/deep-audit` compiles, prices, and
gets a whole-app audit plan approved; this skill **runs it** and hands back a verified findings
report. Invoked `/deep-audit-run <plan.json>` — the target repo is the plan's `target`.

**This is engine slice 1 (OPS-13): the `hidden-failure` lens at L1 only**, built end-to-end through
every pipeline stage. Lenses 2–4 (`security-data-loss`, `test-adequacy`, `architecture-coherence`)
are follow-on slices — plan rows outside this slice are **ledgered omitted and named in the coverage
account**, never silently skipped. The one-way-door contracts here (the run manifest, the claim-blind
verify + adjudication, the execution ledger) are what those lenses will copy.

## Hard constraints
- **Executes only an APPROVED plan.** A plan whose `status` is not `approved` stops loudly,
  unexecuted. There is no "run it anyway."
- **Read-only against the target** except the engine's own output artifacts under `reviews/`. Install
  nothing. `BACKLOG.md` (`AUDIT-` graduation) only on an **explicit** instruction — report-first.
- **Fail-closed everywhere, and failure ≠ planned omission.** A *failure* — a critic crash, an
  unparseable artifact, a verify/adjudication error, or a source/executability gate mismatch —
  **stops the round loudly and writes no findings report**, but records a durable **failure
  diagnostic** (`reviews/audit-run-<date>.failed.json`, AR-3) so the failure is observable and
  distinct from a run that never began; a partial sweep is **never** presented as a whole one (the
  exact hidden-failure disease this audit exists to catch). A *planned omission* (an out-of-slice
  lens, L0) is coverage data. The two are never conflated (see step 5 vs step 6).
- **Cross-model, claim-blind verification is a contract, not a per-lens choice** (the OPS-13
  echo-chamber evidence: same-model panels validate each other's hallucinations). Every future lens
  inherits it verbatim.
- **Redact secret evidence** (the `/dev-audit` rule, verbatim): if a unit surfaces a secret *signal*,
  report detector/type · path:line · count only, **never a value**, in chat and in the report.
- **JSON is canonical:** `reviews/audit-report-<date>.json` (contract: `audit-report-schema.json` v1,
  in this skill dir) **is** the report; the `.md` is a derived view. On divergence the JSON wins.

## Steps

### 0. Stand-down
Resolve the target root from the plan's `target` (or `git -C <target> rev-parse --show-toplevel`). If
**`docs/ai-protocol.md`** exists there, STOP — that repo runs its own heavier workflow. No reads for
a report, no writes.

### 1. Load + approval guard
Read `<plan.json>`; validate it against `plan-schema.json` (the `/deep-audit` contract) and re-run
the **plan semantic check** (step 3 below folds this into the executability gate). If `status` is not
`approved`, **STOP loudly**: *"this plan is not approved (status: <x>) — approve it via /deep-audit
before running."* Never execute a `proposed` plan.

### 2. Source-identity gate (deferred AC c — fail closed)
The plan was priced against a specific code state; the engine confirms the target **still matches it**
before spending a token, by recomputing the plan's **`source.contentFingerprint`** — the one digest
the plan records for clean **and** dirty trees alike (AR-1), computed over the **non-`reviews/**`
tracked working-tree content**:
```bash
fp() { # recompute the plan's contentFingerprint — the SAME canonical stream as /deep-audit step 2
  # (<exec-bit> <working-tree-content-hash> <path>, non-reviews tracked; exec-bit = x|- from the
  # WORKING TREE via test -x, so even an unstaged chmod registers, RR2-3), byte-for-byte identical.
  git -C "$T" ls-files -z -- ':!reviews/' \
    | while IFS= read -r -d '' p; do
        if [ -x "$T/$p" ]; then x=x; else x=-; fi
        printf '%s %s %s\0' "$x" "$(git -C "$T" hash-object -- "$p" 2>/dev/null || printf DELETED)" "$p"
      done | LC_ALL=C sort -z | shasum -a 256 | cut -d' ' -f1; }
```
Require `fp()` **equal** `source.contentFingerprint`. Excluding `reviews/**` is what stops the plan's
own in-repo commit from **self-invalidating** the binding (committing the plan touches only
`reviews/`, so the audited-code digest is unchanged); computing over **working-tree content** is what
lets a **dirty** plan be verified too — the digest captures the uncommitted content the `dirty`
boolean cannot, so there is **no dirty-plan refusal**, one mechanism covers both. If `fp()` ≠
`source.contentFingerprint`, the audited code has changed since the plan was priced — **STOP loudly**
(*"target has changed since this plan was compiled — recompile /deep-audit"*). No silent "run anyway."
(`revision`/`dirty` are provenance; `contentFingerprint` is the identity. The plan records it; this
is the engine's **check** — the responsibility `/deep-audit` step 6 defers here.)

### 3. Executability gate (deferred AC b — fail closed)
Before any critic runs, re-run the **plan semantic check** against the loaded artifact — the same
named contract check `/deep-audit` writes, re-verified on consumption:
1. row identities `(lens, altitude, scope)` are **unique**;
2. `totals.runs = Σ rows[].runs` and `totals.estTokens = Σ rows[].estTokens`;
3. per unit-map group, `chunkUnits = |unitIds|` and `codeUnitIds ⊆ unitIds` (order-preserved);
4. per row, `runs = |unitIds| × (deep ? 2 : 1)`;
5. every L1 row's `unitIds` are drawn from its scope's `codeUnitIds`;
6. per row, `estTokens = runs × tokensPerRun` (the plan's structured pricing constant), so a
   malformed-price plan is rejected here — not silently accepted (RR2-2).

Plus a **scope registry**: every row's `unitIds` resolve in `unitMap` — an L1 row's units appear in
some group's `unitIds`; an L2/L3 row's synthetic scope (`subsystem:<dir>` / `app`) is well-formed.
Any failure **STOPS loudly** — never partial execution of an unsound plan.

### 4. Run manifest → fleet (AC4, DR-3)
**Materialize the run manifest first — do not iterate `unitIds`.** Depth lives in `runs`, not in
`unitIds` (a `deep` row carries the *same* unit list as a `standard` one but `runs = 2×|unitIds|`), so
iterating `unitIds` once would launch **half** a deep row's priced runs. Instead expand every
**in-scope** row (`hidden-failure` L1) into run-records:

> for each in-scope row, for each `unitId` in `row.unitIds`, for `pass` in `1..(deep ? 2 : 1)` →
> one record `{ runId, lens, altitude, scope, unitId, pass }` — `runId` carries the **full row
> identity** `<lens>::<altitude>::<scope>::<unitId>::p<pass>` (RR2-1), so run IDs, stable artifacts,
> finding IDs, and report provenance **never collide across lenses** when lenses 2–4 run the same
> scope+unit.

**Validate the manifest before spawning:** (i) **cardinality** — the record count for each row
equals that row's `runs`, and the manifest total equals **the sum of the in-scope rows' `runs`**;
(ii) **est-cost (AC4, RR2-2)** — assign each manifest record its `tokensPerRun` cost, then require the
**manifest-record cost sum** (`|records| × tokensPerRun`) to equal the approved plan's in-scope
`estTokens` subtotal. This recomputes cost from record-count × the **structured constant** — **not** a
re-sum of `row.estTokens` against itself (the old tautology) — so a plan whose `estTokens` ≠ `runs ×
tokensPerRun` is caught (step 3 pins that same identity per row). (Once all four lenses are built,
both cardinality and cost equal the plan's `totals`; in slice 1 they are the hidden-failure
subtotals.) A mismatch on **either** is a build error — **STOP** (and record it per the failed-run
rule, step 6).

Then **author a Workflow** that fans the fleet over exactly those records (orchestration on the
session harness's Workflow engine — the OPS-13 build-note substrate; concurrency per the plan's
assumption). Each record → one **finder** agent that reads the whole unit and applies the
`hidden-failure` charter (`AGENTS.md` "Hidden failure", grounded in the unit's **current** contents,
not a diff), returning strictly per **`hidden-failure-unit-schema.json`** (its **own** schema, OPS-12).
**Fail-closed promotion**, keyed by `runId` (the `review/SKILL.md` parallel-critic template, scaled):
each finder writes a **fresh temp** promoted to its stable artifact **only** on {clean exit AND valid
JSON}; **any finder failing stops the round** (report suppressed, step 6). On a `deep` row the two
passes are independent finder runs; union their findings and **de-duplicate by `(unitId, file:line)`**
before verification. The engine assigns each surviving candidate a stable `findingId` (`runId` +
index).

### 5. Adversarial verify — mechanical confirmation + honest judgment (AC5, DR-1, AR-2)
Every candidate finding is checked in two parts that keep verification honest:

- **Claim-blind, cross-model verifier.** Spawn a verifier that is **a different model from the
  finder** (echo-chamber defense) and is given the **code location + the lens charter but NEVER the
  finder's claim/argument** (context asymmetry). It reads the cited code fresh and returns a
  **structured evidence record** per **`evidence-schema.json`** — observed control flow, how errors
  there are actually handled, reachable outcomes, and its uncertainty — running **mechanical
  confirmation first** wherever the claim class is mechanically checkable (e.g. grep/AST the cited
  block for a bare `except`/`catch`). Because it never sees the proposition, it cannot merely echo it.
  (Model split is enforced by the orchestration: finders and verifiers use different models — codex
  is the ready cross-vendor verifier, reusing the review loop's read-only harness; a different Claude
  tier is the in-engine fallback. Different **vendor** is preferred over different tier.)
- **Adjudication — mechanical tier first, then honest judgment (AR-2).** The join point, keyed by
  `findingId`/`evidenceId`, scores the **stored finder claim** against the evidence in two tiers; the
  engine **does not claim blanket-deterministic adjudication** — determinism holds only where it is
  real:
  - **Mechanical tier — deterministic where it fires.** Where the claim class is mechanically
    checkable, the evidence's **enum facts decide** by a fixed rule, reproducibly and with **no
    model**: `locationConfirmed=false` or a `mechanicalChecks` result of `not-found` → **refute**; a
    `confirmed` mechanical check whose `errorHandling` is `swallowed` with `uncertainty=low` →
    **promote**. This tier is the reproducible, inspectable gate.
  - **Judgment tier — where the mechanical tier does not settle it.** A **cross-model, kill-mandate,
    evidence-grounded adjudicator** judges the claim against the evidence record — **honest model
    judgment, explicitly NOT claimed deterministic** — and **defaults to REFUTED** on any uncertainty
    (evidence absent, `uncertainty` medium/high, nearby-but-different behaviour). It is grounded in
    the *independent* evidence, never the finder's argument.

  What closes the echo chamber is **upstream** — the claim-blind, cross-model verifier — **not** the
  adjudicator; the mechanical tier keeps determinism exactly where it is real, and the judgment tier
  is honest about being judgment.

A finding reaches the report **only if its adjudication tier promotes it**; refuted or uncertain
findings are dropped (precision-first — protect the human triage budget). Keep verifier/adjudicator
teams **small (3–4)** with hierarchical summarization as the repo-scale context substrate.

### 6. Synthesis off an execution ledger (AC6, DR-2)
Build the **per-row execution ledger** — one entry for **every** plan row, in a distinct state:
- `executed` — the row ran to completion (survivors may be **zero**: a clean negative result, still
  **covered**);
- `omitted` — out of this engine slice (any non-`hidden-failure`-L1 row), `reason` recorded (e.g.
  *"lens not built in engine slice"*).

`failed` is **never persisted in the report**: a failed row means the findings report is suppressed
(step 4 / the fail-closed constraint) — so a *written* `audit-report` is always complete. **But the
failure is not silent (AR-3):** before stopping, write a durable
**`reviews/audit-run-<YYYY-MM-DD>T<HHMMSS>.failed.json`** — the plan ref, the stage that failed, and
each in-scope row's reached state (`planned` / `executed` / `failed`) — so a run that **failed
midway** is mechanically distinguishable from one that **never began**. This diagnostic carries **no
findings** (it is not the report) and is parse-checked, not schema-pinned (a minimal failure record,
per the "core only" scope). Then, for a clean run, write
**`reviews/audit-report-<YYYY-MM-DD>T<HHMMSS>.json`** (mint the stamp once; **if the path already
exists, STOP loudly** rather than overwrite — the plan's collision guard) conforming to
`audit-report-schema.json`, carrying: the echoed `source` binding, `engineSlice`, the ledger, the
**verified findings only** (each with its `runId`/`pass`/`evidenceId` provenance), and the coverage
account. **Derive coverage from the ledger, never from finding yield:** `notCovered` = `omitted` rows
+ out-of-slice altitudes/lenses (L0 reserved, lenses 2–4); an `executed` row with zero survivors goes
under `covered`. Parse-check the JSON, then **derive** the sibling `.md` view (fixed sections: Source
· Engine slice · Verified findings · Execution ledger · Coverage & exclusions · Assumptions). On any
divergence the JSON wins.

### 7. Report-first stop (terminal)
Present the report from the artifact (precision-first: verified findings, then the explicit coverage
account — what ran and **what was not covered**). **Do not** graduate findings to `BACKLOG.md` as
`AUDIT-` items unless Thomas **explicitly** instructs it (the `/dev-audit` posture). The report is the
deliverable; the loop (`/frame`) is where any resulting fix becomes work.

## Contract handling (AC8)
Slice 1 **extends `plan-schema` v1 in place** (permitted — v1 has no other consumers): it adds
**`source.contentFingerprint`**, the single digest that identifies the audited code for clean **and**
dirty trees (AR-1), so every approved plan is engine-verifiable through one mechanism. The report is
its **own** contract (`audit-report-schema.json` v1). Only the differential **C-ledger** mode will
bump a `planVersion`/`reportVersion`; slice 1 stubs the C-ledger report fields (`disposition`,
`priorReportRef`). JSON stays canonical; the plan semantic check moves in lockstep with the added
field.
