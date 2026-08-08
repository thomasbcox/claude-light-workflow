Date: 2026-08-07 · Branch: claude/dependency-cost-rule · Status: approved

> **This spec was written after the implementation, not before it.** The work was done
> directly from `BACKLOG.md` OPS-26 on an instruction to "add the rule", so `/frame` never
> ran and no story file existed when `/review` was called. Recorded here rather than left
> implicit, because a retroactive spec normally cannot fail a correctness pass — the author
> writes it to match what they built, and the check becomes self-confirming (`BACKLOG.md`
> OPS-20's defect class, arriving from the spec direction).
>
> **What breaks that coupling here:** the acceptance criteria below are **not** derived from
> the diff. They are OPS-26's own criteria, filed by Thomas on 2026-08-05 in his own words,
> quoted verbatim. They predate the implementation and were not edited to fit it. The
> *design sketch* and *test notes* are retroactive and should be read with the usual
> suspicion; the criteria should not.

## Problem

The reviewer treats "it would be a dependency" as self-evidently decisive. In
`txl-assessment-collector` a hand-rolled URL-state module was blessed because *"adding one
for two small consumers would lose the concrete dependency-free win"* — reasoning that
named no cost, only a proxy. That module shipped a user-visible bug (multi-word filter
terms could not be typed) which **passed all four of that story's review passes** and was
caught two stories later by a differently-framed one. `nuqs` covers roughly 70% of it
declaratively.

## In scope

- A rule in the shared reviewer contract requiring a dependency rejection to name a
  concrete cost, and requiring the reviewer to weigh dependencies that could be *added*.

## Non-goals

- Any change to what the reviewer does with the answer. This constrains the *reasoning* a
  rejection must show, not the disposition.
- Re-litigating `txl-assessment-collector`'s parked `nuqs` evaluation. That is that repo's
  call and is already recorded there.
- Machinery to enforce the rule. It is prompt text, judged by a model, like the three
  guardrails beside it.

## Acceptance criteria

Quoted verbatim from `BACKLOG.md` OPS-26 (filed 2026-08-05).

1. A review that rejects an available dependency states a **specific cost** — upgrade
   coupling, surface area, maintenance posture, or licence. A rejection resting only on
   dependency *count* is incomplete, and reads as incomplete to the person deciding.
2. *"No installed dependency does this"* is **not** a sufficient answer to *"does this
   reinvent something."* The reviewer weighs dependencies that **could be added**, not only
   those already present.
3. Where a candidate library exists, the reviewer **names it**, so the decision is a trade
   between two concrete options rather than an abstraction.
4. *"Too small to justify a dependency"* is not accepted on its own, because it is true at
   every increment — the reviewer says **what would change the answer** (e.g. a third
   consumer).
5. The change lands in the workflow's reviewer-contract template and **reaches repos that
   already hold a copy**.

**AC5 is now a sequencing requirement, not a distribution one.** OPS-26 records this: once
`user-level-contract` shipped, the contract is shared rather than copied, so an amendment
reaches every repo on the next `./install.sh` with no per-repo path. The item states it
should therefore be built *after* the OPS-25 migration, or it inherits the staleness AC5
names. That ordering held — the migration was carried to 3 of 4 repos immediately before
this (see OPS-25); `sudoku-hints` remains outstanding and is tracked there.

## Test notes

**ACs 1–4 have no mechanical oracle, and inventing one would be dishonest.** They govern
what a language model writes in a review. No gate in this repo can observe that. Naming the
oracle plainly rather than manufacturing a check that cannot fail:

- **AC1–AC4 → `reviewer` + `manual`.** The rule's presence and wording is what ships; its
  effect is visible only in future reviews. The nearest honest mechanical check —
  "the contract contains a fourth numbered guardrail" — asserts the edit landed, not that
  the rule works, and would pass on any text placed there. Recorded as an accepted limit.
- **AC5 → `gate`.** `tests/reviewer_test.sh` already derives the deployed artifact set from
  `install.sh`'s ARTIFACTS block and asserts the contract the runner reads is the contract
  install deploys ("install deploys exactly the contract the runner reads, and no
  AGENTS.md"). An amendment to `workflow-AGENTS.md` inherits that path with no new check.

**Regression the criteria invite, not covered by any check above.** A guardrail worded as
an absolute ("never reject a dependency") would satisfy the letter of AC1–AC4 while making
the reviewer argue *for* dependencies it should refuse — the mirror of the failure OPS-26
describes. Guardrail 1 ("never churn working code to chase a trend") is the existing
counterweight; the wording must not override it. **This is a reviewer-judged criterion and
is exactly what the approach pass should be asked to attack.**

## Open questions

None outstanding. One decision was taken during implementation and is called out for veto
in the design sketch below.

## Design sketch — HOW

**Where.** A fourth numbered item on the existing *Best-practice assessment* lens in
`workflow-AGENTS.md`. OPS-26 names this home: the lens is delivered whole to every pass at
both altitudes, so the rule reaches all four passes and both backends with no per-prompt
edit. One item, not four, because the criteria are one argument.

**The one judgment call, flagged for veto.** The count *"Three guardrails keep this
honest"* was restated in five live places — the contract, `frame/SKILL.md`,
`review/SKILL.md`, and `fireworks_runner.py` twice — and two of those also re-enumerated
all three guardrails verbatim. Adding a fourth falsifies every one. **The count was dropped
rather than incremented**, per `workflow-protocol.md` → *Stated once, assembled per call*:
each of those readers receives the full contract and can follow a pointer, so they should
reference the rule rather than reproduce it. Incrementing three→four would leave the
identical trap for a fifth guardrail. **This widened the diff beyond the rule itself** —
that is the trade, and it is reversible.

**What was deliberately not done.** No `{{contract:...}}` marker was added for the new
guardrail. Markers exist so schema `description` fields carry rule text without storing a
copy; no schema field is about dependency rejection, so a marker would have no consumer.
The existing marker on guardrail 1
(`{{contract:Best-practice assessment#Concrete win, not novelty.}}`) still resolves — the
resolver selects by bold lead-in, and a new item after guardrail 3 does not disturb it.

## Build note (2026-08-07)

| AC | Where it landed |
|---|---|
| 1–4 | `workflow-AGENTS.md` — guardrail 4 on the *Best-practice assessment* lens |
| 5 | No new file. `install.sh`'s ARTIFACTS already maps `workflow-AGENTS.md::workflow-AGENTS.md`, so the amendment ships on the next `./install.sh` |

Carried by the same change, not by any AC — the dropped guardrail count (see the design
sketch's flagged judgment call): `.claude/skills/frame/SKILL.md`,
`.claude/skills/review/SKILL.md`, `.claude/skills/review/fireworks_runner.py` (two prompt
strings).

## Fireworks approach review (2026-08-07, base main, HEAD 1472abf)

**Verdict:** approve

No findings. No regressions proposed.

*Noted for weight, not as a finding:* the verdict is a single word. Prior rounds in this
repo returned a paragraph of reasoning in that field (see `single-source-rules.design.json`),
so this pass gives less evidence of engagement than its clean result suggests. It clears the
step-7 gate as written — empty findings blesses the shape — and that is recorded rather than
overridden.
