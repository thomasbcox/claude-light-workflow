# adversarial-falsification-extents — reviewer-sourced regressions + computed-extents doctrine

Date: 2026-08-05 · Branch: claude/adversarial-falsification-extents · Status: approved

## Problem

`BACKLOG.md` OPS-20 roots a real defect: the regression list a test must catch and the tests that
catch it come from the **same head at the same time**, so a test can be confidently wrong in
exactly the way the change is wrong, and nothing in the loop notices. `frame-falsification-plan`
(2026-08-02) tried to close this with an author-written falsification plan per AC, judged by the
reviewer only after the author had already written it. `thin-the-loop` (2026-08-04) measured that
plan against six real defects found in one story and found it caught **none** of them — every one
came from the reviewer reading code, a behavioral test, or a live run — so it cut the plan down to
plain demonstrate-red and kept only the part shown to have teeth.

OPS-20's Option 3 argues the fix isn't "write the plan harder," it's **move authorship to a head
that isn't the one writing the change**: have the independent reviewer generate the regression list
itself, from the spec alone, before any test exists, and have the author write tests against the
reviewer's list instead of its own. This is a different mechanism from what `thin-the-loop` cut, not
a retry of it — the source moves from author to reviewer, which is also what lets it reach
untestable product (config, docs-as-contract, CI YAML) and work unchanged in a language the loop
never anticipated, since the reviewer is reading prose, not syntax.

Option 4 is a smaller, unrelated doctrine gap in the same guidance: an AC that quantifies over a
real, enumerable source ("every deployed skill", "each pass") today gets that extent hand-typed by
the story's author instead of derived from the actual source, and a hand-typed list drifts silently
the moment the source changes. This repo already has both a correct precedent for deriving it
(`docs_test.sh` parses `install.sh`'s `ARTIFACTS` block; the BUG-6 suite loops `PASSES`/`ALTITUDES`)
and a live violation of it (`tests/reviewer_test.sh`'s `resolve()` reimplements the reviewer backend
resolution rule instead of deriving from it) — evidence the rule is both followable and forgettable.

Both options edit the same guidance in the same file (`frame/SKILL.md` step 5's `## Test notes`
bullet), and the backlog's own lean treats them as a pair ("3 first, 4 alongside it — both Tier 1,
both ship everywhere"), so this is one story, not two.

## In scope

- `.claude/skills/frame/SKILL.md` — steps 5, 6, 7, 9 (the `## Test notes` guidance, the design-review
  call's ask, the write-back that populates Test notes, the consult, and demonstrate-red's wording).
- `.claude/skills/review/design-review-schema.json` — one new field carrying the reviewer's proposed
  regressions, shared by the frame-time design pass and the review-time approach pass that reuses
  this schema.
- `.claude/skills/review/fireworks_runner.py` — the `"design"` pass's inline prompt string gains the
  same ask given to the `codex` backend in `frame/SKILL.md`.
- `tests/reviewer_test.sh` — minimal new drift pins for the load-bearing phrases this story adds,
  following the file's existing minimal-pin convention; the existing TIER-1 and TIER-2 pins stay
  green, unmodified.
- `BACKLOG.md` — one new `OPS-` item recording the lookback commitment (design finding 3, resolved
  at the consult in favour of filing rather than enforcing).

## Non-goals

- **Options 1 and 2** (property-based testing, mutation testing) — Tier 2 per OPS-20's own framing,
  routed through `/dev-audit` Table A as a per-repo detection/recommendation, not a loop mandate.
  Not this story.
- **Fixing `tests/reviewer_test.sh`'s `resolve()` reimplementation.** OPS-20 names it as illustrative
  evidence for why Option 3 matters, explicitly not a reason to scope the fix here: "that is local
  evidence the rule is followable and forgettable — the case for writing it down, not a reason to
  scope it here." Left for whoever next opens that file under OPS-17.
- **Pinning `fireworks_runner.py`'s prompt strings *in general*.** *(Narrowed at the consult —
  design finding 2 accepted; the original blanket form was wrong.)* The one sentence **this story
  adds** to the `"design"` prompt gets a pin (AC8), because this repo routes its `design` pass to
  `fireworks` and leaving that copy unprotected while pinning the `codex` copy protects only the
  variant that never runs here. What stays out of scope is retrofitting pins onto the **existing,
  unpinned** prompt text of all four passes — a larger decision about how prompt-code is guarded,
  which belongs with OPS-15, not here.
- **Retroactively applying either discipline** to already-approved or in-flight stories.
- **Building OPS-18** (the /review-side mutation-proposal companion). Its disposition given this
  story's overlap is an open question (below), not a build decision.
- **Enforcing the lookback in software.** A story-count expiry assertion in the gate was weighed and
  **rejected** at the consult in favour of a plain backlog item (see Design decisions). Its accepted
  cost is recorded with the item itself.
- **`AGENTS.md`** — checked; it doesn't reference test notes or falsification today, so it needs no
  edit for either option.
- **Moving OPS-20 to Done in `BACKLOG.md`.** OPS-20 is a four-option evaluate-and-decide entry;
  shipping items 3–4 doesn't resolve items 1–2, and `workflow-protocol.md` puts any BACKLOG-Done move
  at `/close` time on a fully resolved item, not here.

## Acceptance criteria

1. Step 6's design-review call — both backends — asks the reviewer to propose, **per acceptance
   criterion**, at least one plausible regression (a way an implementation could satisfy the
   criterion's letter while violating its intent), derived from the spec alone, before any test or
   implementation exists. For `codex`, this **replaces** the current "critique the spec's test
   notes" sentence in `frame/SKILL.md` (moot once Test notes' regression half no longer exists yet
   at review time — see AC3). For `fireworks`, whose `"design"`-pass prompt in `fireworks_runner.py`
   has no test-notes-critique ask today, this is a net-new sentence.
2. `design-review-schema.json` gains a `regressions` field: an array of `{criterion, regression}`
   entries, `required` per the schema's existing all-required convention, legitimately empty. Its
   `description` states — once, in the schema itself, not repeated in either call site's prompt —
   that it is populated only at the frame-time design pass and returns empty at the review-time
   approach pass that reuses this schema.
3. `frame/SKILL.md` step 5's `## Test notes` guidance is reworded so the author still states, per
   AC, the oracle mode and mechanism (`gate` / `manual` / `reviewer` — unchanged responsibility), but
   the regression content is deferred and sourced from step 6's reviewer output, not authored
   independently. **Exception:** stories whose design sketch is `N/A — mechanical` skip step 6
   entirely (existing rule) and keep today's fully author-authored Test notes — there is no reviewer
   call to source a regression from.
4. Step 6's write-back instruction (which already appends the `## Codex design review` section) also
   appends the reviewer's regression list into Test notes, paired with the oracle mode/mechanism the
   author assigns each — the concrete mechanism that resolves the step-5→step-6 ordering dependency
   without adding a new top-level step. **Coverage check (design finding 1):** before appending, the
   instruction requires checking that every AC received at least one regression; whatever came back
   is appended as-is, and any AC left uncovered — or an entirely empty return — is recorded as an
   explicit gap rather than passed over in silence.
5. Step 7's consult presents the reviewer's regression list per AC alongside scope, one-way-door
   design ratification, and best-practice flags, using the same per-item disposition (accept / amend
   / reject); the ratified list is what step 9 executes against. **Any coverage gap from AC4 is
   presented as its own line item** — an uncovered AC, or an all-empty return, is surfaced for a
   decision (accept the gap / send the design review back), never absorbed into an apparently
   complete list.
6. Step 9's demonstrate-red wording changes only to say the regression comes from the **ratified**
   list rather than the author's own plan; the execute → observe red → revert → record mechanism is
   otherwise unchanged, and the existing pinned phrase `demonstrate red before done` survives intact.
7. `frame/SKILL.md` step 5's Test notes guidance gains the computed-extents doctrine line: an AC that
   quantifies over a real, enumerable source must have its check derive that extent from the actual
   source, not a hand-typed list — stated with the vacuous-extent caveat (an extent read from the
   same source the code under test also reads can pass even when that code is wrong).
8. `tests/reviewer_test.sh` gains minimal new drift pins: the new step-6 regression-ask phrase in
   `frame/SKILL.md` (the `codex` copy); **the same ask's sentence in `fireworks_runner.py`'s
   `"design"`-pass prompt** (design finding 2 — this repo routes `design` to `fireworks`, so the
   copy that actually executes here must not be the unprotected one); a structural check that
   `design-review-schema.json` declares `regressions` as `required`; the AC4 coverage-check clause;
   and one covering both the computed-extents rule and its vacuous-extent caveat. All new pins are
   demonstrated red against the pre-change files; the existing TIER-1 pins (`demonstrate red before
   done`, `**dead assertion**`, `for each AC, **how it will be checked**`) and the TIER-2
   absent-pins (retired matrix/exclusions/amendment-log machinery) stay green, unmodified, and the
   full gate passes.
9. `BACKLOG.md` files a new `OPS-` item committing to a **lookback after 5 or more full loops**
   (`/frame → /review → /close`) have run under this mechanism: what to look at (regressions the
   author plausibly would not have written; regressions that drove a real gate red at step 9; how
   often the AC4 coverage check found gaps) and the decision it feeds (keep / amend / cut back to
   demonstrate-red only). The item records that enforcement in software was **considered and
   declined**, and names the accepted cost — nothing mechanically forces the lookback to happen.
10. **Doc corrections (added at implementation, 2026-08-05 — Thomas approved the scope expansion
    after a drift audit; see Design decisions).** Four factually wrong claims are corrected:
    (a) `AGENTS.md`'s Output section describes `design-review-schema.json` as a `verdict` plus a
    `findings` array — incomplete **as of this branch**, which adds a required `regressions` array.
    Since `AGENTS.md` is pushed verbatim to the reviewer on every `fireworks` review, this is a
    defect **this story introduced**, not inherited drift. (b) `README.md` and `ARCHITECTURE.md`
    state `fireworks` is wired only at the approach and correctness altitudes; it is wired at all
    four (`fireworks-models.json`, `review/SKILL.md`, and this repo's own `workflow.json`), and the
    README's example config embodied the same error. (c) `README.md` and `ARCHITECTURE.md` state
    `/close` **establishes** branch protection; `close/SKILL.md` only ever *reads* it — protection is
    one-time repo setup (`reviews/ci-setup.md`), and `enforce_admins` has never appeared in that
    skill. (d) `AGENTS.md` tells the reviewer the backend is "codex today"; both backends are wired,
    and this repo runs `fireworks` at every pass.
11. **`BACKLOG.md` files the audit's remainder** as an `OPS-` item — the nine MEDIUM, five LOW, and
    seven correct-but-unguarded findings AC10 did **not** fix, plus why `docs_test.sh` caught none of
    them. Filing is not a commitment to build; **when** that work happens stays Thomas's call.
12. Scope containment: the diff touches only `.claude/skills/frame/SKILL.md`,
    `.claude/skills/review/design-review-schema.json`, `.claude/skills/review/fireworks_runner.py`,
    `tests/reviewer_test.sh`, `tests/fireworks_runner_test.py`, `BACKLOG.md`, `AGENTS.md`,
    `README.md`, and `ARCHITECTURE.md` — plus this story's own review-trail artifacts under
    `reviews/adversarial-falsification-extents.*`, categorically exempt per `workflow-protocol.md` →
    *Per-repo artifacts* and never enumerated.

    *(Amended at implementation, 2026-08-05 — `tests/fireworks_runner_test.py` added. **A spec-time
    blind spot, logged for veto, not a silent widening.** AC2 makes `regressions` a required field on
    `design-review-schema.json`, which **both** the design and approach passes bind. Two stub
    reviewer replies in that suite were literals omitting the new field, so the runner's own
    validation correctly rejected them and the design/approach altitude tests went red. The gate
    cannot be green without this, and AC8 requires a green gate, so the fix was mandatory rather than
    optional. What changed is the two stubs, replaced by one named `VALID_DESIGN` constant so the two
    altitudes cannot drift apart — no assertion was weakened, removed, or reshaped, and the suite's
    113 checks all still run. Two-way and trivially revertible; flagged at hand-off so Thomas can
    veto.)*

## Test notes

Per-AC: how it's checked, and the regression that must drive each `gate` oracle red.

- **AC1** — oracle: `gate` for **both** prompt copies (design finding 2): a drift pin on the new
  sentence in `frame/SKILL.md` (the `codex` copy) **and** a drift pin on the same ask in
  `fireworks_runner.py`'s `"design"` prompt. Regression for both: the sentence is deleted or
  weakened back to "critique the notes" phrasing. *Stated limit:* a pin proves the instruction is
  **present**, never that a live reviewer **obeys** it — obedience has no CI-safe oracle (it needs a
  paid API call) and is confirmed `manual`, on the first story framed after this one merges. This
  repo routes `design` to `fireworks`, so that first live run is the next story framed, not this one
  — this story is itself framed under the *old* prompt. Noted, not hidden.
- **AC2** — oracle: `gate` — a structural check (not a text `has`) that `regressions` appears in
  `design-review-schema.json`'s top-level `required` array. Regression: the field is dropped or
  demoted to optional without a deliberate decision.
- **AC3** — oracle: `gate` — drift pin on the reworded bullet's new sourcing clause, and a second
  pin on the mechanical-exception sentence. Regressions: the bullet reverts to implying
  author-authored regressions; the mechanical exception is dropped, leaving `N/A — mechanical`
  stories with no path to complete Test notes.
- **AC4** — oracle: `gate` for the write-back instruction's presence, including the coverage-check
  clause (one pin covering it); `manual`/`reviewer` for confirming the append and the check actually
  happen on a live run — same limit as AC1. Regression: the coverage clause is dropped, so an
  all-empty or partial reviewer return appends silently and the mechanism no-ops undetected.
  *Stated limit:* the coverage check is a **judgment** the writing agent performs (the reviewer's
  `criterion` field is free text and will not always match an AC label verbatim), not a mechanical
  assertion — the gate proves the instruction exists, nothing more.
- **AC5** — oracle: `gate` — pin the new consult-presentation sentence in step 7, specifically its
  gap-as-line-item clause. Regression: step 7 reverts to presenting only the list that came back, so
  a missing AC is invisible at the one stop that could have caught it.
- **AC6** — oracle: `gate` — the existing `demonstrate red before done` pin re-run after this edit;
  no new pin needed beyond confirming the existing one still passes (i.e., the regression *is* this
  edit accidentally breaking that pin).
- **AC7** — oracle: `gate` — two pins: the core computed-extents rule phrase, and the vacuous-extent
  caveat phrase, so a rewrite that keeps the headline but drops the caveat still goes red.
- **AC8** — oracle: `gate`, demonstrated red: every new assertion run against the pre-change files
  (`git show origin/main:<path>`) must fail there before being confirmed to pass on the branch —
  same technique `frame-falsification-plan` used. Existing TIER-1/TIER-2 pins re-verified unchanged.
- **AC9** — oracle: `manual` — the `OPS-` item exists in `BACKLOG.md` and states the trigger (5+
  loops), what to look at, the keep/amend/cut decision, and the declined-enforcement note. No `gate`
  oracle is proposed: a pin on backlog prose would assert nothing this story's other pins don't, and
  the item's *value* is whether it gets read later — which no check in this repo can establish. That
  is the accepted cost of the filed-not-enforced option, recorded rather than papered over.
- **AC10** — oracle: **`reviewer`**, stated plainly rather than dressed up. `docs_test.sh` verifies
  that every deployed skill is named as a `/command` and that no doc names an undeployed one; it
  cannot check whether a *sentence is true*, and no check in this repo can. Each correction was
  instead verified by hand against its ground truth before being written — (a) the schema file,
  (b) `fireworks-models.json` + `review/SKILL.md` + `workflow.json`, (c) `close/SKILL.md`'s three
  `gh api` calls (all reads) plus `git log -S "enforce_admins"` on that file returning nothing,
  (d) `workflow.json`. A grep confirmed no residue of any of the four claims survives. There is
  **nothing to demonstrate red** here, and inventing a phrase pin would assert only that words I
  just typed are still present — a check that cannot fail in the way that matters.
- **AC11** — oracle: `manual` — the `OPS-` item exists and carries the audit's remainder. Same
  honest limit as AC9: a pin on backlog prose would assert nothing, and the item's value is whether
  it gets read later, which nothing here can establish.
- **AC12** — oracle: `manual` — `git diff --name-only origin/main...HEAD -- . ':(exclude)reviews/'`,
  verify no file appears beyond the enumerated set.

**On the "renders nothing" requirement:** every AC above asserting presence (a prompt sentence, a
schema field, a doctrine line) is a binary presence check, and a `has`/structural pin's failure mode
*is* the renders-nothing case — there's no separate empty-vs-absent state to add for Markdown
instruction text or a JSON Schema `required` array, unlike a UI element that can render an empty
state distinct from not rendering at all.

### Demonstrate-red record (2026-08-05, at implementation)

All eight new checks were run against the **pre-change files** (`git show origin/main:<path>`),
where each pinned phrase is genuinely absent and the schema field genuinely missing — the maximal
form of each planned regression, exercised at once rather than as eight delete-and-rerun cycles
(the technique `frame-falsification-plan` established):

| Check | AC | Red on `origin/main` |
|---|---|---|
| `propose at least one plausible regression` (codex copy, `frame/SKILL.md`) | AC1 | ✓ |
| `propose at least one plausible regression` (fireworks copy, `fireworks_runner.py`) | AC1 | ✓ |
| `sourced from the step-6 design review` | AC3 | ✓ |
| `check every AC received at least one` | AC4 | ✓ |
| `send the design review back` | AC5 | ✓ |
| `derive that extent from the source` | AC7 | ✓ |
| `passes vacuously` | AC7 | ✓ |
| `regressions` in the schema's top-level `required` (structural, not a phrase) | AC2 | ✓ (`no`) |

Red on `origin/main` → green on the branch proves all eight are live, not vacuous. The three
existing TIER-1 pins (`demonstrate red before done`, `**dead assertion**`, `for each AC, **how it
will be checked**`) and all five TIER-2 absent-pins were re-verified **green and unmodified** — the
rewording of steps 5, 7 and 9 did not disturb them (AC6's oracle).

**Full gate: green** — guard, reviewer-seam 40, fireworks-runner 113, dev-audit 46, docs 16; zero
failures.

**One check found red for real, not by design.** Adding `regressions` as a required field broke two
design/approach-altitude tests in `tests/fireworks_runner_test.py`, whose stub reviewer replies were
literals omitting it. That is the runner's fail-closed validation behaving correctly, and it is the
one place in this change where a *behavioral* test — not a wording pin — caught a real consequence
the spec had not anticipated. Recorded because it is evidence about which checks in this repo have
teeth, which is exactly what OPS-22's lookback will need. See AC12's amendment note.

## Open questions

1. **OPS-18's disposition.** OPS-20 says Option 3 "re-sequences" OPS-18 (the /review-side
   mutation-proposal companion, judging the *diff* at review time) and that the two should be
   "resolved together, not separately" — but doesn't say how. They sit at different altitudes
   (spec-level, pre-code vs. diff-level, post-code) and aren't the same mechanism, so they could
   coexist. My lean: leave OPS-18 open exactly as it stands (evaluate-and-decide, not committed),
   with a one-line annotation noting Option 3 now exists as a related mechanism at a different
   altitude — and fold the OPS-18 question into the AC9 lookback, so both get judged on the same
   evidence at the same time rather than committing to a second unproven ceremony now. `BACKLOG.md`
   is already in scope for AC9, so this costs one extra line and no new file. If you'd rather decide
   OPS-18's fate outright, say so and I'll act on that instead.

   **Resolved 2026-08-05 — fold into the lookback.** Thomas: *"fold OPS-18 into the lookback."*
   AC9's item carries the extra line; OPS-18 stays open, unchanged in substance, and gets judged on
   the same evidence at the same time.

## Design sketch — HOW

**The re-sequencing, concretely.** Today: step 5 drafts the full spec including author-authored Test
notes; step 6 reviews the sketch and critiques those notes; step 7 consults. The chicken-and-egg
this story has to resolve: step 6 needs the ACs to generate regressions, but the regressions need to
land in Test notes *before* step 7's consult. Resolution — no new top-level step, per your call to
regrow `/frame` correctly this time rather than just bigger:
- Step 5 drafts everything **except** the regression half of Test notes (oracle mode/mechanism per
  AC is still drafted now — that part doesn't depend on step 6).
- Step 6's existing reviewer call gains the regression-generation ask (AC1) and its existing
  write-back gains two more actions: check every AC got covered, then append the returned
  regressions into Test notes paired with the oracle each already has (AC4).
- Step 7 presents the merged result plus any coverage gap as its own line item (AC5) — structurally
  the same consult, with a Test notes section that's now finished later than before.

**Schema shape (recommendation, not a locked contract — refined at implementation).** Extend
`design-review-schema.json` rather than add a second schema file:
```json
"regressions": {
  "type": "array",
  "description": "Proposed only at the frame-time design pass, before any test exists; the review-time approach pass reusing this schema returns an empty array.",
  "items": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "criterion": { "type": "string", "description": "Which AC this targets." },
      "regression": { "type": "string", "description": "A plausible way an implementation could satisfy the criterion's letter while violating its intent." }
    },
    "required": ["criterion", "regression"]
  }
}
```
One call, one artifact, one schema — matches "a call already being made" rather than forking a
second reviewer-output schema (which would restate the "shape of a reviewer's structured output"
concept OPS-17 already flags as prone to drift). Cost: the field is meaningless at the approach-pass
reuse site; mitigated the same way `findings: []` already is — required, legitimately empty, the
constraint stated once in the field's own `description`, not duplicated into both prompts.

**Why the reviewer doesn't also assign oracle mode.** `fireworks`'s design pass is non-agentic and
never sees the repo's tooling (only the contract + story file) — it can propose *what* could go
wrong from the spec, but not reliably judge *how* this repo would mechanically catch it. Keeping
oracle-assignment with the author (who does know the repo) keeps the reviewer's job identical in
every language and toolchain, which is the entire reason Option 3 is Tier 1.

**Option 4 is one sentence, same bullet, no structural change** — added directly after the reworded
regression-sourcing text in step 5's Test notes guidance.

**Pinning posture.** The new pins follow the same minimal, load-bearing-phrase convention
`frame-falsification-plan` used when this doctrine was new, understood as provisional the same way:
`thin-the-loop` later proved which of those pins had earned their place by evidence (what actually
caught a defect) and cut the rest. These are new, unproven instructions too — worth a cheap presence
pin so they can't silently vanish, not a claim that they're permanent. **Both prompt copies get
one** (design finding 2): `tests/reviewer_test.sh` already has a generic `has <label> <file>
<string>` primitive that works against any path, so covering `fireworks_runner.py` needs one new
file variable beside the existing `FRAME`/`REVIEW` ones — no new mechanism, and it protects the
backend this repo actually executes.

**The lookback is filed, not enforced** (design finding 3, Thomas's call). One `OPS-` item in
`BACKLOG.md` naming the 5-loop trigger, the evidence to weigh, and the keep/amend/cut decision. A
gate-side expiry assertion was the alternative and was declined; the item itself records that
nothing mechanically forces the lookback, so the weakness is on the page rather than discovered
later.

## Fireworks design review (2026-08-05)

**Verdict:** "Sound shape — I would satisfy these ACs essentially this way. The re-sequencing
resolves the step-5/step-6 chicken-and-egg without a new top-level step; extending the one shared
schema instead of forking a second reviewer-output schema is the right declarative instinct (and the
story's OPS-17 drift reasoning for it is correct); keeping oracle assignment with the author is
well-justified by the fireworks backend's blindness to repo tooling; the pins follow the repo's
provisional minimal-phrase convention rather than inventing machinery. Non-goals show real scope
discipline. Nothing here reinvents a dependency or is larger than the problem. Three concerns, none
fatal to the approach… Items 1–2 are clause-level fixes; item 3 is Thomas's call as the one-way
door."

### IMPORTANT · two-way × kludgy — Empty or partial reviewer return silently no-ops the new mechanism

*Locus:* Design sketch → 'Schema shape' + AC4 (step-6 write-back); AC2's 'legitimately empty'

**Claim.** The schema blesses `regressions: []` as legitimate (needed for the approach-pass reuse),
but that same value is what a lazy, truncated, or prompt-drifted design-pass return looks like.
Nothing in steps 6–9 distinguishes "reviewer returned nothing" from "nothing to append": the
write-back appends the returned list as-is, an AC left uncovered is not called out anywhere, and step
9 then executes demonstrate-red against a ratified list that may be empty or missing criteria while
the story appears compliant. The loop's new failure-detection mechanism cannot surface its own
failure — the exact hidden-failure class this change exists to fight, one level up.

**Alternative.** Add one clause to step 6's write-back instruction: before appending, check that
every AC has at least one paired regression; append what came, and flag each uncovered AC — or an
all-empty return — as an explicit line item in step 7's consult presentation, so the gap is ratified
or sent back rather than absorbed.

**Win.** Eliminates the silent-degradation path where the mechanism no-ops and the story proceeds on
author intuition alone while looking like it followed the new doctrine; cost is one sentence in an
instruction this story already edits — no new step, no new machinery, an error path closed.

### IMPORTANT · two-way × nonstandard — Pinning asymmetry: the backend this repo actually routes through is the unpinned one

*Locus:* Test notes AC1; Non-goals → 'drift-pin mechanism for fireworks_runner.py'

**Claim.** AC1 drift-pins the new regression-ask sentence in `frame/SKILL.md` (the codex path) but
leaves the identical new sentence in `fireworks_runner.py`'s design-pass prompt to a one-time manual
confirmation — while the story itself notes this repo's `.claude/workflow.json` routes `design` to
fireworks, so the only variant this repo will ever execute is the one with no presence check. The
cited non-goal assumes pinning a Python-embedded prompt means inventing a new mechanism; it doesn't —
`tests/reviewer_test.sh`'s existing grep/`has` primitive applies to any file.

**Alternative.** Add one grep pin on the new fireworks prompt sentence in `tests/reviewer_test.sh`,
in the same load-bearing-phrase style as the SKILL.md pins and demonstrated red the same way; leave
the broader question of pinning fireworks prompts generally genuinely out of scope.

**Win.** One line closes the asymmetry: the sentence this story adds to the prompt this repo actually
runs gets the same can't-silently-vanish protection as the codex variant — no new mechanism, no
live-API dependency in the gate, one silent-deletion path removed.

### QUESTION · one-way × standard — No planned measurement for whether reviewer-sourced regressions earn their place

*Locus:* Story-level doctrine change (steps 5–9); cf. Design sketch → 'Pinning posture' and Open
question 1

**Claim.** This story makes reviewer-authored regressions the default path for every non-mechanical
frame — a cross-cutting pattern future stories will copy, i.e. the one-way door Thomas is actually
ratifying here. The repo's own precedent shows the working discipline: `frame-falsification-plan`
built the ceremony, `thin-the-loop` measured it against six real defects and cut what had no teeth.
Yet nothing in this story says what evidence would validate Option 3 or when it gets rejudged: the
pins are explicitly declared provisional, while the doctrine they guard is not.

**Alternative.** Add one line — in `BACKLOG.md`'s OPS-20 (which stays open regardless) or in this
story's close-out — naming the revisit trigger and the bar: e.g., after N framed stories, count
reviewer-sourced regressions an author plausibly wouldn't have written and reds they actually drove;
keep / amend / cut on that evidence, mirroring `thin-the-loop`.

**Win.** Pre-commits the measurement that will decide whether this ceremony stays, converting a
permanent-feeling doctrine into the same provisional status the story already grants its pins — so
the loop doesn't accumulate another unmeasured process layer; cost is one line.

## Design decisions (2026-08-05)

Scope approved by Thomas: **"approved, fold OPS-18 into the lookback, and also look for all ways the
various docs (readme, etc) have drifted and propose corrections."** The doc-drift sweep is a
**separate proposal**, not part of this story's ACs — findings are presented for his decision, and
any correction he approves lands as its own scoped work rather than being folded into this diff.

- **IMPORTANT (empty/partial reviewer return silently no-ops the mechanism) → fix.** Thomas: *"I
  like fix 1."* Step 6's write-back gains a coverage check before appending; step 7 presents any
  uncovered AC — or an all-empty return — as its own consult line item (AC4, AC5). Accepted limit,
  recorded in Test notes: the check is a judgment the writing agent performs, not a mechanical
  assertion, because the reviewer's `criterion` field is free text; the gate proves the instruction
  exists, nothing more.
- **IMPORTANT (pinning asymmetry — the executed backend was the unpinned one) → fix.** Thomas:
  *"let's fix the drift pin to cover fireworks."* Both copies of the new ask get a pin (AC1, AC8).
  The original blanket Non-goal was wrong on its facts — `tests/reviewer_test.sh`'s `has` primitive
  is file-agnostic, so no new mechanism was needed — and has been narrowed to exclude only
  retrofitting pins onto the four passes' **existing** prompt text (an OPS-15 question).
- **QUESTION (no planned measurement — the one-way door) → accept the finding, decline the
  mechanism.** Thomas: *"don't build in the revisit trigger as software - just file it as a backlog
  item saying we need to do a lookback after 5 or more loops have been run."* Options weighed at the
  consult: a plain backlog item (**chosen**), a story-count expiry assertion in the gate, and an
  SRE-style measured threshold with a pre-committed consequence. The third was ruled out on
  analysis, not cost — its measurement is the author self-assessing whether they would have written
  a given regression anyway, which reproduces the single-head coupling OPS-20 exists to break. The
  second was declined by Thomas. **Accepted cost, recorded in the backlog item itself:** nothing
  mechanically forces the lookback; it happens because someone reads the item.
- **Open question 1 (OPS-18's disposition) → fold into the lookback.** OPS-18 stays open and
  unchanged in substance; AC9's item names it so both are judged on the same evidence at the same
  time, rather than committing to a second unproven ceremony now.

### Scope expansion — doc corrections (2026-08-05, at implementation)

Thomas commissioned a doc-drift audit alongside implementation, then asked: *"any reason not to fix
AGENTS.md, H1, H2, and H3 all right now?"* → **"go."** AC10 and the widened AC12 record it.

The one candidate objection was checked and dissolved: H2 could have meant *correct the docs* **or**
*build the missing capability*, and choosing the first would silently close a gap worth leaving
open. `reviews/ci-setup.md` lists branch protection as a **one-time setup action of that story**, and
`enforce_admins` has never appeared in `close/SKILL.md` — and protection is repo setup, not something
any story would want re-applied on every merge. So the docs are simply wrong and the fix is
unambiguous. Stated costs, accepted: the scope-containment AC widened the diff from 6 files to 9;
none of the four corrections has a mechanical oracle (AC10's Test note says so rather than
inventing one); and the
reviewer now sees two themes in one diff — mitigated for three of the four, which are the *same*
defect this story's own change exhibited (docs describing a one-backend world).

The remaining audit findings — nine MEDIUM, five LOW, plus seven correct-but-unguarded claims —
stay **out of scope** and are being filed as their own story.

## Build note (2026-08-05)

AC → file map:

| AC | Files |
|---|---|
| 1 — design pass asks for regressions, both backends | `.claude/skills/frame/SKILL.md` (step 6, codex prompt); `.claude/skills/review/fireworks_runner.py` (`PASSES["design"]` prompt) |
| 2 — `regressions` field on the shared schema | `.claude/skills/review/design-review-schema.json` |
| 3 — step-5 defers regressions to the reviewer; mechanical exception | `.claude/skills/frame/SKILL.md` (step 5, `## Test notes` bullet) |
| 4 — write-back appends + checks coverage | `.claude/skills/frame/SKILL.md` (step 6, write-back — made backend-neutral, it was codex-only prose) |
| 5 — consult presents the list and any gap as a line item | `.claude/skills/frame/SKILL.md` (step 7) |
| 6 — demonstrate-red runs the *ratified* regression | `.claude/skills/frame/SKILL.md` (step 9) |
| 7 — computed extents + vacuity caveat | `.claude/skills/frame/SKILL.md` (step 5, same bullet) |
| 8 — drift pins, gate green | `tests/reviewer_test.sh` (8 new checks, 2 blocks); `tests/fireworks_runner_test.py` (stub fixtures — see AC12's amendment) |
| 9 — OPS-22 lookback filed | `BACKLOG.md` |
| 10 — four doc-drift corrections | `AGENTS.md` (×2: contract line, Output section); `README.md` (×3: backend wiring, example config, protection claim); `ARCHITECTURE.md` (×2: backend wiring, protection claim) |
| 11 — OPS-23 files the audit remainder | `BACKLOG.md` |
| 12 — scope containment | no files — verified by `git diff --name-only` |

*Numbering note:* an earlier amendment left a gap (the list ran 9 → 11 → 13 with two
references pointing at a vacated number). Renumbered contiguous 1–12 before this review;
no criterion's content changed.
