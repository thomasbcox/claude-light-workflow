---
name: deep-audit-run
description: OPS-13 engine slice 1 — execute an APPROVED /deep-audit plan end-to-end for the hidden-failure L1 lens: verify source identity + plan executability, expand a run manifest, run the critic fleet, adversarially verify every finding with a claim-blind cross-model verifier, and synthesize a precision-first report with coverage accounting. Report-first; stops loudly on any failure or on an unapproved/dirty plan. Use after /deep-audit has produced and Thomas has approved a plan.
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
  **stops the round loudly and writes no report**; a partial sweep is **never** presented as a whole
  one (the exact hidden-failure disease this audit exists to catch). A *planned omission* (an
  out-of-slice lens, L0) is coverage data. The two are never conflated (see step 5 vs step 6).
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
The plan was priced against a specific code state; the engine must confirm the target **still matches
it** before spending a token.
- **Refuse a dirty-tree plan.** If `source.dirty` is `true`, STOP loudly: *"this plan was compiled
  against a dirty tree and is not reproducibly verifiable — recompile /deep-audit on a clean tree."*
  (The plan records only `dirty: true`, not the uncommitted content, so there is nothing to verify
  against. Dirty-tree support — which needs a recorded content fingerprint — is a follow-on with
  lenses 2–4.)
- **Fingerprint the audited file set, excluding generated plan/review artifacts.** Compute a content
  fingerprint of the tracked files **excluding `reviews/**`** at both the current working tree and at
  `source.revision`, and require them **equal**. Excluding `reviews/**` is what stops the plan's own
  in-repo commit from self-invalidating the bound revision (committing the plan touches only
  `reviews/`, so the audited-code fingerprint is unchanged). Reference:
  ```bash
  fp() { # $1 = revision; hash the non-reviews tracked tree at that revision
    git -C "$T" ls-tree -r "$1" --format='%(path) %(objectname)' \
      | grep -v '^reviews/' | LC_ALL=C sort | shasum -a 256 | cut -d' ' -f1; }
  wt() { # current WORKING-TREE content of non-reviews tracked files (catches uncommitted edits)
    git -C "$T" ls-files | grep -v '^reviews/' | LC_ALL=C sort \
      | while IFS= read -r f; do printf '%s ' "$f"; git -C "$T" hash-object "$f"; done \
      | shasum -a 256 | cut -d' ' -f1; }
  ```
  If `wt` ≠ `fp(source.revision)`, the audited code has moved since the plan was priced — **STOP
  loudly** (*"target has changed since this plan was compiled — recompile /deep-audit"*). No silent
  "run anyway." (The plan artifact **identifies** its source; this is the engine's **check** — the
  responsibility `/deep-audit` step 6 explicitly deferred here.)

### 3. Executability gate (deferred AC b — fail closed)
Before any critic runs, re-run the **plan semantic check** against the loaded artifact — the same
named contract check `/deep-audit` writes, re-verified on consumption:
1. row identities `(lens, altitude, scope)` are **unique**;
2. `totals.runs = Σ rows[].runs` and `totals.estTokens = Σ rows[].estTokens`;
3. per unit-map group, `chunkUnits = |unitIds|` and `codeUnitIds ⊆ unitIds` (order-preserved);
4. per row, `runs = |unitIds| × (deep ? 2 : 1)`;
5. every L1 row's `unitIds` are drawn from its scope's `codeUnitIds`.

Plus a **scope registry**: every row's `unitIds` resolve in `unitMap` — an L1 row's units appear in
some group's `unitIds`; an L2/L3 row's synthetic scope (`subsystem:<dir>` / `app`) is well-formed.
Any failure **STOPS loudly** — never partial execution of an unsound plan.

### 4. Run manifest → fleet (AC4, DR-3)
**Materialize the run manifest first — do not iterate `unitIds`.** Depth lives in `runs`, not in
`unitIds` (a `deep` row carries the *same* unit list as a `standard` one but `runs = 2×|unitIds|`), so
iterating `unitIds` once would launch **half** a deep row's priced runs. Instead expand every
**in-scope** row (`hidden-failure` L1) into run-records:

> for each in-scope row, for each `unitId` in `row.unitIds`, for `pass` in `1..(deep ? 2 : 1)` →
> one record `{ runId, lens, altitude, scope, unitId, pass }` (`runId` = `<scope>::<unitId>::p<pass>`).

**Validate the manifest before spawning:** the record count for each row equals that row's `runs`,
and the manifest total equals **the sum of the in-scope rows' `runs`** (once all four lenses are
built this equals the plan's `totals.runs`; in slice 1 it is the hidden-failure subtotal). A mismatch
is a build error — STOP.

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

### 5. Adversarial verify — evidence record + adjudication (AC5, DR-1)
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
- **Deterministic adjudication.** A separate step — the join point, keyed by `findingId`/`evidenceId`
  — scores the **stored finder claim** against the evidence via an explicit **promote/refute decision
  table**: promote only when the evidence's `errorHandling`/`reachableOutcomes` **corroborate the
  claim's specific mechanism**; **default REFUTED** when evidence is absent, `locationConfirmed` is
  false, a mechanical check returned `not-found`, or `uncertainty` is medium/high. Nearby-but-different
  behaviour never corroborates.

A finding reaches the report **only if adjudication promotes it**; refuted or uncertain findings are
dropped (precision-first — protect the human triage budget). Keep verifier/adjudicator teams **small
(3–4)** with hierarchical summarization as the repo-scale context substrate.

### 6. Synthesis off an execution ledger (AC6, DR-2)
Build the **per-row execution ledger** — one entry for **every** plan row, in a distinct state:
- `executed` — the row ran to completion (survivors may be **zero**: a clean negative result, still
  **covered**);
- `omitted` — out of this engine slice (any non-`hidden-failure`-L1 row), `reason` recorded (e.g.
  *"lens not built in engine slice"*).

`failed` is **never persisted**: a failed row means the whole report is suppressed (step 4 / the
fail-closed constraint) — so a *written* report is always complete. Write
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
Slice 1 consumes `plan-schema.json` **v1 unchanged** — the clean-tree source check recomputes from
`source.revision`, so no new plan field is needed. The report is its **own** contract
(`audit-report-schema.json` v1). Dirty-tree verification (which would need a recorded
`source.fingerprint`) and the differential C-ledger mode are the extensions that will bump a
`planVersion`/`reportVersion`; slice 1 stubs the C-ledger report fields (`disposition`,
`priorReportRef`) but adds no plan field. JSON stays canonical; the semantic checks move in lockstep
with any future bump.
