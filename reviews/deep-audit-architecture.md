# deep-audit subsystem — architecture (design, pre-build)

Written before building `compile-plan` / `check-plan`. Captures the shape decided across the
`deep-audit-engine` review journey (the pivot: extract the deterministic core to a tested shell
library) and the two subcommands about to be built. Diagrams are Mermaid (text, version-controlled).

**One idea:** every *deterministic* rule lives once, in `deep-audit-lib.sh`, enforced by a behavioral
test. The LLM keeps only *judgment* — detection, narrative, orchestration, the consult, and the
judgment-tier adjudication. `plan.json` / `report.json` are the contracts between them; the lib is the
single validator (no separate `plan-schema.json`).

---

## A. The deterministic / LLM boundary — who owns what

```mermaid
flowchart LR
  subgraph llm["LLM / prose — JUDGMENT only"]
    direction TB
    l1["detection profile<br/>(ecosystems, domain)"]
    l2["narrative fields<br/>(omissionRisk, why prose)"]
    l3["the consult<br/>(Thomas edits / approves)"]
    l4["orchestration: Workflow<br/>fan-out, finder/verifier prompts<br/>(engine story)"]
    l5["judgment-tier adjudication<br/>(engine story)"]
  end
  subgraph lib["deep-audit-lib.sh — DETERMINISTIC, tested"]
    direction TB
    d1["fingerprint · resolve-units"]
    d2["compile-plan (Table P)"]
    d3["check-plan (shape + complete + consistent)"]
    d4["build-manifest · check-report<br/>· adjudicate/mechanical<br/>(engine story)"]
  end
  llm <-->|"JSON in · exit status out"| lib
```

---

## B. Data flow — this story (plan side) and the engine story (execute side, dashed)

```mermaid
flowchart TB
  target[("target repo (audited)")]
  subgraph story["THIS story — plan side"]
    direction TB
    s1["/deep-audit: detect profile"]
    s2["lib compile-plan(target, profile, patches)"]
    s3[["plan.json"]]
    s4{"consult — Thomas edits / approves"}
    s5["lib check-plan(plan) ⇒ exit 0"]
    s6(("plan approved, recorded"))
    s1 --> s2 --> s3 --> s4 -->|approve| s5 --> s6
  end
  subgraph engine["ENGINE story — execute side (later, same lib)"]
    direction TB
    e1["/deep-audit-run: lib check-plan"]
    e2["lib build-manifest → run records + ledger"]
    e3["Workflow fleet: finder agents"]
    e4["verify: cross-model, claim-blind"]
    e5["lib adjudicate (mechanical tier)<br/>+ LLM judgment tier"]
    e6["lib check-report"]
    e7[["report.json"]]
    e1 --> e2 --> e3 --> e4 --> e5 --> e6 --> e7
  end
  target -.reads.-> s2
  s6 -.-> e1
```

---

## C. `compile-plan` — the Table-P compiler (the piece being built next)

Inputs: `target root` · `profile.json` (the LLM detection) · optional `patches`. Everything else is
**derived from the target itself** (LV-1) so a plan can never be validated against its own echoed
inputs.

```mermaid
flowchart TB
  in[/"compile-plan(target, profile, patches)"/]
  in --> fp["fingerprint(target)<br/>⇒ source.contentFingerprint"]
  in --> um["unit-map (from target):<br/>git ls-files → group by top-level dir<br/>chunk files over 400 LOC into sub-units<br/>code ecosystems (profile) → codeUnitIds"]
  um --> sg["signals per group (from target):<br/>churn-high · sensitive · untested<br/>· legacy · non-code"]
  sg --> pa["Phase A — emit<br/>P1 to P7 candidate rows"]
  pa --> pb["Phase B — resolve<br/>P8/P9 upgrades, max-wins depth"]
  pb --> pc["Phase C — transforms<br/>(none in v1)"]
  pc --> px["apply patches (in order):<br/>exclude/only · set-depth · add · remove"]
  px --> rr["per row:<br/>unitIds = resolve-units(depth, codeUnitIds)<br/>runs = units × depth factor (deep = 2x)<br/>estTokens = runs × tokensPerRun"]
  rr --> tt["totals · coverage · assumptions"]
  fp --> out
  tt --> out[["plan.json (structural + narrative)"]]
```

---

## D. `check-plan` — the canonical validator (shape + completeness + consistency)

The crux of the whole pivot: completeness is proven by **recompiling from the target**, not by
trusting the plan's own numbers.

```mermaid
flowchart TB
  cin[/"check-plan(plan.json)"/]
  cin --> shape{"shape valid?<br/>required · types · enums<br/>· additionalProperties"}
  shape -->|no| fail(("exit ≠ 0<br/>(reject)"))
  shape -->|yes| fpchk{"target still matches<br/>source.contentFingerprint?"}
  fpchk -->|no: source drift| fail
  fpchk -->|yes| recomp["recompile from TARGET:<br/>compile-plan(plan.target, plan.profile, plan.overrides)"]
  recomp --> cmp{"recompiled structural rows<br/>== plan's rows?"}
  cmp -->|"no: omitted / suppressed<br/>/ misapplied / thinned"| fail
  cmp -->|yes| cons{"consistency:<br/>unique ids · totals = Σ<br/>runs = units × depth factor<br/>estTokens = runs × tokensPerRun<br/>unitIds = exact resolution"}
  cons -->|no| fail
  cons -->|yes| okk(("exit 0<br/>(valid)"))
```

---

## Scope legend

| Built in **THIS** story (`deep-audit-lib`) | Deferred to the **engine** story |
|---|---|
| `fingerprint` ✓ · `resolve-units` ✓ (done, tested) | `build-manifest` · `check-report` · `adjudicate` (mechanical tier) |
| `compile-plan` · `check-plan` (next) | the lens×altitude capability table |
| `/deep-audit` refactored to call the lib; `plan-schema.json` removed | `/deep-audit-run` orchestration (Workflow, prompts, verify, synthesis) |
| behavioral test suite (`tests/deep_audit_lib_test.sh`) | judgment-tier adjudication (prose) |

**Contract invariants (enforced by the lib, tested):** JSON in / exit-status out; deterministic
derivation from the target only; one canonical validator (no second schema copy); every tampered
input is rejected by a test.
