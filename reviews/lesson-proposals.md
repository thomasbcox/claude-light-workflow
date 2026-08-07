Date: 2026-08-06 · Branch: claude/lesson-proposals · Status: approved

# Workflow lesson proposals — a safeguard-activation trigger at `/close`

## Problem

Workflow-level defects — ones about the *process* rather than the product — reach `BACKLOG.md` only
when Thomas notices a pattern across stories. That has already failed once in recorded history:
`frame-falsification-plan` shipped an author-written falsification plan, `thin-the-loop` measured it
against one story's six real defects, found it caught **none** of them, and cut it back. That
measurement happened **because Thomas noticed**. Nothing scheduled it. OPS-22 exists to avoid
relying on noticing twice, and states plainly that nothing mechanically forces it either.

Claude is positioned to notice earlier — it sees the reviewer's findings, the dispositions, the gate
results, and every fail-closed path as they happen. What is missing is not capability but an
**obligation to write the observation down at a named moment**, on a bar low enough to be honest and
high enough not to generate noise.

**This is not a governance gap.** The human-approved path from observation to workflow change already
exists and is complete: a `BACKLOG.md` item → `/frame` → `/review` → `/close`, with human approval at
scope, design, each finding, and merge. This story adds a **trigger**, a **required shape**, and an
**independent check on the proposal**. It adds no approval machinery.

**What this story can honestly claim.** It *reduces* reliance on Thomas noticing. It does not remove
it — see AC1 and the stated limit in *Non-goals*: two of the four activation sources are observable
only inside the session where they occurred.

## In scope

### 1. The trigger — a re-derivable check, a session-observed class, and one bounded question

**1a. Re-derivable at `/close` (runs on demand, deterministic).**
- `install.sh --check` reports drift.

**1b. Session-observed (only catchable when `/close` runs in the session where it happened).**
- The guard hook blocked a command. **It writes nothing durable** — it denies with a reason on
  stderr and exits 2, leaving no log, file, or marker.
- A fail-closed path in the reviewer runner refused to promote a result (schema violation, truncated
  completion, unparseable body, missing or empty declared context input, oversized payload). Refusal
  means **no artifact is written**, so the durable trace is an *absence* — indistinguishable from a
  pass that never ran.

**1c. The bounded question (default no).** Where an activation occurred, exactly one question decides
whether anything is proposed:

> **Did the activation reveal something not already known** — a control absent, bypassed, misleading,
> or mis-sized, or a failure mode not already documented?

A control that simply caught the ordinary problem it was built to catch is **the system working**,
and proposes nothing.

**1d. "Already known" means cited, not remembered.** The proposal must cite the repository evidence
it checked — the `workflow-protocol.md` section, the skill, the `BACKLOG.md` item, the prior story
trail, **or a prior rejection in the rejected register (§6)** — or state that it searched and found
none. **No cited evidence of novelty, no proposal.** This follows the repo's existing rule that an
extent is derived from its authoritative source rather than retyped from memory.

### 2. The proposed lesson's required shape

- what happened, and where it first became visible;
- the activation, which class (1a or 1b) it came from, and what it revealed that was not already
  known — **with the citations from 1d**;
- the evidence, each item citing its source: a story slug, an artifact path, or a command output;
- **material evidence consulted but excluded, named with the reason for excluding it** (bounded to
  what was consulted — not an inventory of everything not looked at);
- whether it appears isolated or systematic, and on what basis;
- the candidate lesson;
- **at least one competing explanation**, or a statement that none was found and why;
- **what future evidence would weaken, narrow, or disprove it**;
- what should **not** be generalized from this case;
- **workflow or product** — does this apply to future work across repositories, or only to this
  product, branch, or technical problem? Product-specific findings are ordinary backlog items, not
  workflow lessons.

### 3. Independent review before Thomas sees it

The proposal goes to the independent reviewer and is presented alongside its assessment. Claude is
normally the party whose briefing, context assembly, or routing produced the failure; a diagnosis
authored and evidenced by that party, going straight to the decider, is the single-head coupling
OPS-20 treats as a defect class.

**This needs its own pass and its own schema.** The runner's `PASSES` table binds each pass to a
purpose, a schema, and a prompt, and its own comment states a new critic is *an entry there plus an
`ALTITUDES` line — not new orchestration*. There is **no non-schema path**: `load_schema` deliberately
refuses any schema permissive enough to accept the empty object. Forcing this assessment into
`design-review-schema.json` would mean filling `reversibility`, `standing`, and `regressions` fields
that do not apply — which would make the independent check ceremonial, and the check is the reason to
build this rather than let Claude file backlog items directly.

The assessment asks: did a trigger truly fire, and did it reveal a weakness rather than a control
working; does the evidence support the lesson; was material contrary evidence omitted; does the
diagnosis confuse symptom with cause; is a competing explanation stronger; is this about the shared
workflow or the product under development; is the generalization too broad.

**The durable copy is the proposal file, written before the pass runs.** `/close` writes the
proposal to `.aar/proposals/<slug>.md` **first**, and the runner reads it from there as a declared
context input. That file — not the assessment artifact — is what §4's re-presentation rule points at.

Round 2 required this invariant to be stated where the artifact is defined, and offered two ways to
satisfy it: a verbatim echo field in the schema, or a paired file written alongside. **The paired
file is the one built**, and the schema deliberately carries no echo field. A model asked to
reproduce a long proposal paraphrases or truncates it, so an echo would silently degrade exactly the
document the durability rule exists to preserve — and the proposal file is the original, never
round-tripped through a model. `lesson-review-schema.json`'s own description records this.

**If the lesson-review pass fails** — provider error, malformed output, context limit, schema
violation, abnormal completion — the merge is **never** affected. The failure is named at the consult
and the proposal is presented **explicitly marked un-reviewed**, so Thomas decides with that fact in
front of him. Accepted tradeoff, stated rather than silent: he may approve a diagnosis the
independent head never saw.

### 4. Lifecycle

- **Before disposition** nothing enters `BACKLOG.md`. The lesson pass writes its assessment artifact
  under `reviews/` like every other review pass — that is the loop's normal bookkeeping, not a leak.
- **On approval** the proposal becomes an ordinary `BACKLOG.md` item, written on the feature branch
  so it arrives with the merge commit, as all release records here do.
- **On rejection** the proposal is preserved **in full, with Thomas's reason**, in the rejected
  register (§6). See §6 for why erasure was rejected as a design.
- **On deferral** the proposal is preserved in full in the story file, marked deferred. Reject and
  defer remain different acts: rejection judges the claim wrong, deferral judges it unresolved.
- **Re-presentation after an interrupted session** is permitted **only from the durable proposal
  file** `.aar/proposals/<slug>.md`, written before the lesson pass runs. Where that file does not
  exist the proposal is **gone**, and must not be reconstructed from memory: reconstructed citations are
  exactly what 1d exists to prevent, and a real lesson's mechanism will fire again.
- **The lesson decision never gates the merge.** Rejecting or deferring leaves an otherwise-approved
  branch mergeable.

### 5. Volume control

At most one proposal per `/close`: the highest-leverage qualifying lesson. Others are **not** named —
they have had no evidence assembly and no independent review, and naming them would plant unreviewed
diagnoses in the consult. Never propose a lesson already present in `BACKLOG.md` **or already
rejected in the register (§6)**.

### 6. The rejected register — retain with the reason, read at one named moment

Rejected proposals are **kept, not erased**, in `.aar/rejected-lessons.md` — an append-only file in
a **dot-directory**, each entry carrying Thomas's stated reason. The file only ever grows.

**Why a dot-directory** (Thomas, 2026-08-06: *"a directory not normally seen by Claude or other
tools"*). `reviews/` is read by the loop on every story, so a register there is in routine context by
construction. A dot-directory is not: `rg` — which backs Claude's own search tool — skips hidden
paths unless `--hidden` is passed, and no skill globs it. It is still **committed**, so the reasoning
survives a clone, and an explicit read of the known path works regardless of any tool's hidden-file
default. That is the whole design: invisible to sweeps, addressable by name.

**Why retention rather than erasure.** An earlier draft required a rejected claim never be written
where Claude reads. That rule was wrong on three counts. It is **inconsistent with this repo's own
practice** — `BACKLOG.md` → *Decided against* keeps rejected items expressly "so the reasoning
survives," in a file read on every session. It **loses the more useful half**: the rejection *reason*
is what distinguishes a control working from a control being weak, which is the single judgment this
whole trigger turns on. And it **guarantees re-proposal** — an invisible rejection means the same
lesson returns on every future activation of the same control.

**What is actually being managed.** Contamination comes from a **bare claim**, not a labeled one: a
diagnosis alone reads as an assertion, the same diagnosis with "proposed, rejected, because X" reads
as a constraint. The surviving rule from the earlier draft is therefore narrower and still binding:
**never record a claim without its disposition and reason.** A one-word rejection is not a valid
disposition — it leaves nothing to dedup against and the loop returns.

**How exposure is bounded.** The register is **low-traffic, not sealed**: it sits in a dot-directory
no tool sweeps by default, no skill loads it, nothing auto-reads it, and it is read at exactly
**one** named moment — the 1d novelty check, before a
proposal is assembled. The residual risk is stated rather than denied: a keyword grep can surface any
file in this repo, and repeated exposure to a claim raises its perceived truth faster than its label
decays. That is the argument for keeping it out of routine context; it is not an argument for
erasure.

**Relationship to `BACKLOG.md` → *Decided against*.** Different stage, not a second register: that
section holds *backlog items* considered and not done; this holds *lessons* rejected before they ever
became items. Deliberately not merged into it, because that file is high-traffic and merging would
put every rejected claim into routine context.

### 7. Containment and the prune rule

No file in `install.sh`'s `ARTIFACTS` array and no `.claude/workflow.json` changes **as a result of a
lesson being proposed or approved at runtime**. Any change that follows runs the normal loop, adds no
approval step, **restates no existing rule — it points at the rule instead — and removes any
instruction it supersedes.**

## Build note (2026-08-06)

AC → file map.

| AC | Where it lives |
|---|---|
| 1–5, 7, 8, 10–14, 17 | `.claude/skills/close/SKILL.md` — step 3b (detect, bounded question, cited novelty, assemble, independent check, interrupted-round rule) and step 4 (disposition: approve → `AAR-` item, reject → register with reason, defer → proposal file; never gates the merge) |
| 6 | `.claude/skills/review/lesson-review-schema.json` (new); `fireworks_runner.py` — `lesson_proposal` context source, `PASSES["lesson"]`, `ALTITUDES`, `KNOWN_PURPOSES`; `fireworks-models.json` — the `lesson` route; `tests/fireworks_runner_test.py` — own-schema and no-vestigial-field assertions |
| 9 | `.claude/skills/close/SKILL.md` step 5(b) — the `AAR-` item is written on the feature branch; `BACKLOG.md` — the `AAR-` family declaration |
| 15 | `.claude/skills/close/SKILL.md` (the single read moment); `.aar/rejected-lessons.md` (the register); `tests/reviewer_test.sh` — the `/close`-names-it check plus the every-deployed-path leak scan |
| 16 | `.claude/skills/close/SKILL.md` step 3b/4; `tests/reviewer_test.sh` — negative assertion over the lesson block |
| — | `BACKLOG.md` — `OPS-27` (hook durability), `OPS-28` (the deferred runtime containment observation) |

The `lesson` pass is wired but has **never run on a real proposal** — no safeguard has activated
since it was built. Schema conformance is asserted; live behaviour is unproven. Recorded in
`fireworks-models.json` under that route's `verify` key, and `OPS-28` is where it first runs.


## Non-goals

- **Full detector coverage.** Class 1b is best-effort by construction. A `/close` in a fresh or
  resumed session cannot see a hook trip or a runner refusal from an earlier session. **Stated limit,
  not an oversight** — see Open question 1 for the change that would close it and its cost.
- **Stories that never reach `/close`.** A trigger hanging off `/close` can only ever see stories that
  close. Abandoned and cancelled work is a **structural blind spot** of hanging the trigger there.
- **New evidence for an existing lesson.** A qualifying activation that strengthens a `BACKLOG.md`
  item already filed produces nothing in this version. Named blind spot.
- **A recurrence trigger.** Deferred to its own story: it needs a two-story evidence rule,
  same-mechanism (not same-symptom) matching, citations to both trails, and a dedup check.
- **Learning from unusually successful patterns.** Detecting and preserving what went unusually right
  is outside this story.
- **Asking a reviewer to explain itself.** Both backends are stateless per call — `fireworks` is one
  pushed request with schema-enforced output, `codex` is a process that exits. There is no session to
  interrogate; a follow-up is a fresh instance reconstructing another's reasoning.
- **A "lesson check completed — no trigger" audit line.** A line written on every close in every repo
  forever to record that nothing happened, and an attestation rather than a check: a run that skipped
  the step writes it just as easily. The instruction lint is the check.
- **A new store for approved lessons.** `BACKLOG.md` remains the staging area. The **rejected**
  register (§6) is a new per-repo file under `.aar/` — named here rather than smuggled in, and
  deliberately not a second home for approved work.
- **Erasing rejected lessons.** Considered and rejected as a design; see §6 for the reasoning.
- **A second approval track, or a separate remedy-approval step.**
- **Scheduled retrospectives.**
- **Any change to existing reviewer schemas, or to the shared reviewer contract.**

## Acceptance criteria

1. `/close` runs the re-derivable check (1a) once per story at a named step, and evaluates the
   session-observed class (1b) from what it can see in-session.
2. Where an activation occurred, `/close` applies the single bounded question (1c) before proposing
   anything, and proposes nothing when the answer is no.
3. A proposal cites the repository evidence checked for prior knowledge, or states that a search
   found none; a proposal lacking that citation is not made (1d).
4. Where no activation occurred, or the bounded question answers no, `/close` proposes nothing and
   writes nothing about lessons — including no "check completed" line.
5. A proposal presented at the consult carries every element required by scope item 2.
6. The proposal reaches the independent reviewer before Thomas sees it, via **its own pass and its own
   schema**; no existing schema is repurposed and the shared reviewer contract is unchanged.
7. A failed lesson-review pass does not block the merge; the failure is named at the consult and the
   proposal is presented marked un-reviewed.
8. Nothing enters `BACKLOG.md` before Thomas disposes of the proposal. The lesson pass's assessment
   artifact under `reviews/` is the loop's own bookkeeping and is **not** a violation.
9. On approval the proposal becomes an ordinary `BACKLOG.md` item on the feature branch, arriving with
   the merge commit.
10. On rejection the proposal is preserved **in full, with Thomas's stated reason**, in
    `.aar/rejected-lessons.md`. A rejection recorded **without** a reason is not a valid
    disposition — it leaves nothing to dedup against. On deferral the proposal is preserved in full in
    the story file, marked deferred.
11. A rejected or deferred lesson never blocks a merge Thomas would otherwise approve.
12. Re-running `/close` on the same story creates no duplicate `BACKLOG.md` item. An undisposed
    proposal is re-presented **only** from the durable proposal file `.aar/proposals/<slug>.md`;
    where none was written the proposal is gone and is never reconstructed from memory.
13. At most one proposal per `/close`; other qualifying lessons are not named.
14. `/close` **reads** `.aar/rejected-lessons.md` at the novelty check, so a lesson Thomas has
    already rejected is not proposed again. The register itself is **append-only with no uniqueness
    check on writes** (Thomas, 2026-08-06: *"just append rejected lessons and don't worry about
    uniqueness"*) — the same lesson rejected twice yields two dated entries, which is a recurrence
    signal, not a defect.
15. The rejected register is read at exactly **one** moment — the novelty check (1d) before a proposal
    is assembled. No skill loads it, nothing auto-reads it, and no instruction directs Claude to it at
    any other point.
16. **At runtime**, proposing or approving a lesson modifies no file in `install.sh`'s `ARTIFACTS`
    array and no `.claude/workflow.json`. This constrains the *behavior this story builds*, not the
    branch implementing it — which necessarily modifies deployed artifacts.
17. A change arising from an approved lesson runs the normal loop, adds no approval step, restates no
    existing rule, and removes any instruction it supersedes.

## Test notes

**Regressions are not written here.** They are sourced from the step-6 design review, which proposes
them from the criteria before any test or implementation exists. An author's own regressions and an
author's own tests fail the same way together.

| AC | Oracle | Mechanism |
|---|---|---|
| 1–5, 7, 8, 10–14, 17 | **reviewer** | **Reassigned from `gate` during implementation, and this is a deliberate reversal of what was ratified — recorded rather than done quietly.** `tests/reviewer_test.sh` carries a charter: it was cut from ~91 wording pins to ~30 by `thin-the-loop`, on the evidence that those pins caught **none** of six real defects, and it states that "a behavioral-looking check on Markdown is still theater" and that re-growing the set undoes work done on evidence. Adding ~12 wording pins here would be a 50% increase in exactly the class that was measured and cut. These criteria are therefore judged by the independent reviewer reading the diff, and by a human reading the instructions — the file's own stated answer for this seam. Two checks *do* clear its bar and are kept (rows below). |
| 5 (content quality) | **reviewer** | Whether a filed proposal's evidence, competing explanation, and disconfirmation are *substantive* is not machine-checkable. The independent reviewer judges it. Named honestly rather than dressed as a gate check. |
| 6 | **gate** | `tests/fireworks_runner_test.sh` asserts the new pass exists in `PASSES` with its own schema file, that the schema is rejected by `load_schema` if it accepts the empty object, and that `workflow-AGENTS.md` is byte-identical to base. |
| 9 | **gate** | On a branch where a lesson was approved, the `BACKLOG.md` item is present on the feature branch **before** the merge commit — derived from git, not from the file's own claim. |
| 15 | **gate** | `tests/reviewer_test.sh` asserts the `/close` text names the register and its single read moment, **and then loops over every deployed text path** asserting no other file references `.aar/rejected-lessons.md`. A one-file lint is relocation-blind: the realistic leak is a pointer grown later in the review skill, `workflow-protocol.md`, or a skill description, which puts the register into routine context while a `/close`-only check stays green. Shares one deployed-path enumeration with the AC18 row. |
| 16 | **gate** | A **negative assertion** that the `/close` text contains no instruction to write to any `ARTIFACTS` path or `.claude/workflow.json` at proposal or approval time — this can go red. The **observational** half (`./install.sh --check` plus the restricted `git diff` on a branch where a lesson actually ran) cannot run here: on *this* branch the restricted diff is non-empty by construction, so running it now would verify a fixture rather than the behavior. It is therefore **filed as `OPS-28` in this story's own diff**, not left as an intention — a story whose thesis is that unscheduled intentions fail must not ship one. |
> **The line-count ceiling was dropped** (Thomas, 2026-08-06: *"don't keep count"*). A number the
> author sets and can also raise is not a constraint, and a count measures bulk rather than clarity —
> it can reward cramped prose. **AC17's prune rule is what actually controls growth** and it stays:
> a change must not restate an existing rule, it points at it, and it deletes what it supersedes.

### Demonstrate-red results (2026-08-06)

Each gate criterion's ratified regression was applied, the gate run, the named check observed
failing, and the change reverted. No dead assertions.

| Criterion | Regression applied | Result |
|---|---|---|
| 15 | A pointer to `.aar/rejected-lessons.md` added to `review/SKILL.md` | **red** — `deployed file references the rejected register outside /close` |
| 16 | The lesson step given an instruction naming `workflow-protocol.md` | **red** — `lesson step references a deployed/config path` |
| 6 | `reversibility` added to `lesson-review-schema.json` (the structural-clone regression) | **red** — `no vestigial design-review field: reversibility` |
| 6 | The lesson pass re-pointed at `design-review-schema.json` | **red** — `the lesson pass does not reuse an existing schema` |

**Criterion 9** (an approved lesson lands on the feature branch before the merge commit) has no
regression to apply yet: no lesson has been approved, so there is nothing on a branch to observe.
It is exercised the first time `/close` approves one — the same branch `OPS-28` names.

**A method note worth keeping.** The first demonstrate-red attempt reverted with
`git checkout -- <file>` while the implementation was still **uncommitted**, which discarded the
work instead of the regression. Commit first, then demonstrate red.

Scope containment for this story's own diff: `git diff --name-only main...HEAD -- . ':(exclude)reviews/'`
should show only the files named in the design sketch.

### Proposed regressions — round 2 (ratified at step 7, executed at step 9)

Each pairs with the oracle its criterion already carries above. All 18 criteria covered; 38 entries.

- **AC1** — The named step exists and runs install.sh --check, but the instruction never connects its output to the bounded question: drift is reported as routine gate output and dropped, so the check ran (letter) without ever functioning as an activation source (intent). Equivalently, the step is placed after the merge consult, so a drift finding cannot inform any proposal.
- **AC1** — The 1b evaluation is implemented as a scan of durable artifacts only — which by construction do not exist for hook denials and runner refusals — so it returns 'no activation' on every story. The letter (it evaluated what it could see) holds while the intent (scan the session itself for denials and refusals) is never attempted, and because AC4 forbids any record of the empty result, the always-silent evaluation is invisible.
- **AC2** — The question is named in the instruction but framed with the default inverted — 'unless this is obviously already known, propose' — so the question is asked and answered (letter) while the default-no discipline that keeps volume down (intent) is reversed and every activation qualifies.
- **AC2** — The question is sequenced after proposal assembly: /close drafts the proposal, then applies 1c as a review of the draft. Applied in the presence of sunk work, it rationalizes rather than gates — the letter (question applied before anything is proposed to Thomas) is satisfied while the intent (a cheap default-no filter applied before evidence assembly) is defeated.
- **AC3** — The proposal carries a plausible boilerplate citation block ('checked BACKLOG.md, workflow-protocol.md — no match') as a formatting requirement; an instruction lint sees citations present (letter) while the underlying searches never ran (intent: cited, not remembered) — the exact confabulation 1d exists to prevent, laundered through compliance with the citation format.
- **AC3** — Citations are at whole-file granularity — 'BACKLOG.md', 'workflow-protocol.md' — with no section, item, or story trail named. Something is cited (letter) but nothing specific enough to verify or to dedup a future proposal against (intent).
- **AC4** — Nothing is written to any file, but /close adds a standing 'lessons: none' line to the merge consult output on every story. The letter (nothing written) holds while the forbidden attestation reappears in consult text (intent) — a line a run that skipped the step writes just as easily, which is why the design banned it.
- **AC4** — When 1c answers no, the question and its justification are recorded in the story file 'for the trail' — a written record of a non-proposal, created in the name of auditability, violating 'writes nothing about lessons'.
- **AC5** — Every required element appears as a heading with content that is present but hollow: 'competing explanation: none found' with the why omitted; 'future evidence that would weaken it: unclear'; and 'excluded evidence: none' achieved by consulting only supporting evidence so there is nothing to exclude. All elements carried (letter); the elements that exist to discipline the diagnosis (intent) are functionally empty.
- **AC5** — The workflow-or-product element is answered 'workflow' for what is actually a product-specific defect (e.g., a parser bug in this repo's own runner), routing an ordinary backlog item through the lesson machinery. The element is present and answered (letter); the classification it exists to force is dishonest (intent).
- **AC6** — The new schema is created by copying design-review-schema and renaming fields, so the pass has its own schema file (letter) while forcing the assessor into the design-review concepts — reversibility, standing, regressions — that the story itself says make the check ceremonial (intent).
- **AC6** — workflow-AGENTS.md stays byte-identical (letter) but the new pass's prompt silently redefines standing reviewer behavior — instructing the reviewer to approve, or to treat Claude's citations as already verified — so the effective contract drifts while the file does not (intent: no drift in what the reviewer is asked to be).
- **AC7** — The failure is named in a form that erases the information: 'lesson review unavailable' with no failure class, and the un-reviewed marking rendered as a footnote while the proposal is presented with the same prominence as a reviewed one. The failure was named (letter); Thomas deciding with that fact genuinely in front of him (intent) is undermined.
- **AC7** — On failure /close retries the pass until some schema-valid output emerges, then presents the proposal as reviewed. The merge was never blocked (letter) while a degraded assessment — possibly produced under a truncated or abnormal completion — is laundered into a reviewed one (intent: fail-closed artifact, honestly marked).
- **AC8** — The pre-disposition proposal is staged in BACKLOG.md as an HTML comment, a 'pending' entry, or a struck-through line — arguably not an 'item' (letter) while the unreviewed claim is carried into the high-traffic file read every session (intent: nothing enters it before disposition).
- **AC8** — The proposal is written before disposition into a different routinely read file — ROADMAP.md, or the story file's header — so BACKLOG.md is technically untouched (letter) while the unreviewed diagnosis still lands in routine context (intent).
- **AC9** — The item is committed only after the merge — /close merges, then appends the BACKLOG item on main or in a follow-up commit — so it sits near the merge in history (loose letter) while the merge commit itself does not carry the release record (intent: arrives with the merge, as all release records here do).
- **AC9** — The item is added verbatim in diagnosis form — 'Claude believes the hook is mis-sized because…' — rather than as an ordinary actionable backlog entry. An item exists on the branch (letter) but it is the preserved proposal, not an ordinary item (intent), smuggling the single-head framing into the backlog.
- **AC10** — The rejection is recorded with a reason Claude writes on Thomas's behalf, inferred from a one-word answer ('rejected: not a workflow issue'). A reason string exists (letter) but it is not Thomas's stated reason (intent), and the fabricated rationale becomes the thing future novelty checks dedup against.
- **AC10** — 'In full' is satisfied for the claim but not the proposal: the register keeps the candidate-lesson line and drops the evidence, exclusions, and disconfirmation. A record with a reason exists (letter) while a future 1d check has nothing substantive to compare a re-phrased re-proposal against (intent).
- **AC10** — Deferral: the proposal is preserved in the story file, but the story file is later pruned per repo housekeeping, or the 'deferred' marker is dropped in a later edit — technically preserved at the moment of deferral (letter), gone by the time it matters (intent).
- **AC11** — The consult presents one combined question — 'approve merge + lesson? y/n' — so declining or deferring the lesson mechanically withholds merge approval. The instruction text states the decisions are separate (letter as linted) while the interaction couples them (intent).
- **AC11** — Deferral leaves the story file carrying an unresolved marker that a later step treats as incompleteness, so a deferred lesson delays closure of the current or a future story — never a formal block (letter), a practical one (intent).
- **AC12** — Dedup compares the candidate-lesson text; a re-run re-derives the same lesson with different wording and files a second BACKLOG item. No exact duplicate exists (letter); a semantic duplicate does (intent).
- **AC12** — Re-presentation reads the durable artifact but 'refreshes' it before the consult — re-citing sources, filling gaps from session memory — so the artifact was consulted (letter) while the re-presented proposal is partly reconstructed (intent: only from the artifact).
- **AC12** — Where no artifact exists, /close treats the interrupted proposal as never having existed and re-derives the same 1b lesson fresh from the new session's view of scrollback — not 'reconstruction of the proposal' in name (letter) while being exactly that in substance (intent).
- **AC13** — One proposal is presented, but the consult narration adds 'also observed, not proposed: possible issues with X and Y.' One proposal was made (letter); the unreviewed diagnoses were planted anyway (intent: others are not named, precisely because they have had no evidence assembly or review).
- **AC13** — Two aspects of one systematic failure are split so the highest-leverage one is proposed and the other rides along as an 'evidence' bullet inside the proposal — a second, unreviewed lesson embedded in the first (letter: one proposal; intent: one lesson, reviewed).
- **AC14** — The novelty search matches on surface wording: a claim rejected last month returns with different phrasing and passes. Both files were searched and the search cited (letter) while the same-mechanism re-proposal the register exists to prevent sails through (intent).
- **AC14** — The reverse: the check matches too broadly, suppressing any genuinely new lesson that shares a keyword with a rejected one as 'already known.' The dedup ran (letter) while the silence-direction failure the design must not cause becomes systematic and, per AC4, invisible (intent).
- **AC15** — The /close text is clean, but a different deployed file — the review skill, workflow-protocol.md, a skill description — grows a pointer ('past rejections: .aar/rejected-lessons.md'), putting the register into routine context through a file the gate never lints. /close contains no such instruction (letter); the register is read at many moments (intent).
- **AC15** — The novelty-check instruction is written as a general rule — 'before proposing anything, check BACKLOG.md and the rejected register' — that also fires during /frame or ad-hoc backlog grooming, so the register is read at several named moments (letter: each read is part of a check; intent: exactly one named moment).
- **AC16** — The instruction never says 'write to a deployed path,' but a step's side effect does: recording the disposition routes through a helper that updates .claude/workflow.json state, or approval triggers an immediate 'capture the lesson' edit to the close skill framed as part of the approval flow. The negative lint passes (letter) while runtime lesson handling modifies a deployed artifact (intent).
- **AC16** — The observational half of the check is deferred and never scheduled, so the only standing check is the instruction lint. AC16 as-tested is satisfied (letter) while the runtime-behavior containment the criterion names is verified zero times, ever (intent).
- **AC17** — The follow-on change runs the normal loop with no added approval step (letter) but its implementation 'reminds' the reader by restating the existing rule inline — 'as rule X says, …' — instead of pointing at it (intent). The AC17 instruction lint cannot catch this because the restatement lands in a different, future story's diff.
- **AC17** — 'Removes any instruction it supersedes' is satisfied by deleting more than the superseded text — a neighboring rule caught in the deletion — or the old instruction is left in place alongside the new one on the grounds it was 'not exactly superseded.' The diff shows a removal or an addition (letter) while the rule set drifts into contradiction or loss (intent).
- **AC18** — The ceiling is counted as net lines: the step adds forty lines of instruction and deletes forty lines of unrelated existing text in the same file, netting under the ceiling (letter) while total instruction weight grows by the full amount (intent: bounded instruction text in deployed artifacts).
- **AC18** — The line-count test counts only the files the story names — despite the test-notes warning — so instruction text relocated into an unnamed deployed file escapes the ceiling entirely; every named file is within budget (letter) while deployed instruction weight is not (intent). Or: the ceiling number is never settled, the test asserts a placeholder, and Open question 5's pointer to 'AC17' records the number against the wrong criterion.

> Round-1 regressions removed: they were proposed against the superseded draft, never
> ratified, and several are moot under the redesign. Round 2's list replaces them.

## Open questions

1. **~~Should the guard hook leave a durable record?~~ — BACKLOGGED (Thomas, 2026-08-06).** Filed as
   `OPS-27`. The stated limit stands for this story: class 1b is caught only when `/close` runs in the
   originating session.
2. **~~Prefix~~ — DECIDED (Thomas, 2026-08-06): `AAR-`, for After Action Review.** A **fourth**
   `BACKLOG.md` item family alongside `BUG-` / `OPS-` / `AUDIT-`. One-way door, ratified: every future
   lesson item copies it. Recommendation at the consult was to reuse `OPS-`; Thomas chose a distinct
   prefix, which keeps lessons legible as their own class and does not answer the roadmap's open
   taxonomy question by side effect.
3. **~~Where the trigger text lives~~ — DECIDED (Thomas, 2026-08-06): the `/close` skill.**
4. **Is one bounded question a strong enough guard, and does the mechanism go quiet?** The 1c/1d pair
   is what keeps this cheap. Worth a stated revisit after a handful of activations — an OPS-22-style
   lookback, filed rather than enforced. **It must sample both directions.** Drift toward "yes"
   reintroduces noise and is visible in the proposals themselves. Drift toward **silence** — never
   proposing, which is also the cheap, conflict-free answer for the party being observed — leaves no
   artifact at all, because AC4 forbids one. So the lookback also samples stories where a control
   fired and *no* proposal emerged, and audits whether 1c/1d were honestly applied. Without that half,
   a mechanism that silently never fires is indistinguishable from one that correctly never fires.
5. **~~The ceiling number~~ — DECIDED (Thomas, 2026-08-06): no count.** The criterion and its test
   are dropped; AC17's prune rule carries the growth constraint on its own.
6. **Does the rejected register need pruning?** It only grows — by design, and by Thomas's
   instruction. A register nobody prunes eventually costs more to search than it saves, and the
   novelty check reads it every time. No answer proposed — flagged so it is a decision later rather
   than a discovery later.

## Design sketch — HOW

**Files touched.** `.claude/skills/close/SKILL.md` (the new step — Thomas's decision, not
`workflow-protocol.md`), `.claude/skills/review/fireworks_runner.py` (one `PASSES` entry + one
`ALTITUDES` line), `.claude/skills/review/lesson-review-schema.json` (new),
`.claude/skills/review/fireworks-models.json` (a route for the new pass), `tests/reviewer_test.sh` and
`tests/fireworks_runner_test.sh` (assertions), and `BACKLOG.md` (the `AAR-` family plus `OPS-27` and
`OPS-28`). The `review` skill directory is already deployed wholesale by `install.sh`, so the new
schema needs no `ARTIFACTS` entry. **No change to `workflow-AGENTS.md`.**

**The step.** One block near the end of `/close`, after the gate is green and before the merge
consult. It runs `install.sh --check`, notes any in-session activation, and in the common case does
nothing.

**When it fires.** Apply the bounded question with its citation requirement; search `BACKLOG.md`
**and `.aar/rejected-lessons.md`** for an existing match — this is the register's single read
moment; assemble the proposal from artifacts already on disk — the story file, the reviewer's JSON
outputs, gate and runner output — with every source cited by path.

**The rejected register.** `.aar/rejected-lessons.md` — per-repo, append-only, created lazily on
first rejection, and **not a deployed artifact** (it ships with no repo but the one that wrote it).
The dot-directory is the containment mechanism: `rg` skips hidden paths by default, so routine
searches never surface it, while an explicit read of the known path still works. Entry shape follows
`BACKLOG.md` → *Decided against*: the claim, the date, and Thomas's reason, kept so the reasoning
survives.

**The review call.** A new `lesson` pass in the runner's declarative `PASSES` table: purpose (routing
to a model via `fireworks-models.json`), its own `lesson-review-schema.json`, and its prompt. This is
the extension path the runner documents — a table entry, not new orchestration. Routing follows the
existing per-pass `reviewer` map; the `codex` path gets the equivalent prompt block so the two
backends do not disagree about the contract.

**Error model.** Follows the runner's existing fail-closed shape for the *artifact* (no partial
promotion), but **not** for the caller: a failed lesson pass is caught by `/close`, named at the
consult, and never propagated as a merge blocker. This is a deliberate divergence from the
correctness/approach passes, where a failed review stops the round — those gate a decision about the
code; this one does not.

**Presentation.** The proposal and its assessment go into the existing merge consult, where every
option already carries its cost and its risk, and where the lesson decision is put **separately** from
the merge decision.

No new artifact class, no new state machine, no new store, no new approval track.

## Fireworks design review — round 2 (2026-08-06)

**Verdict.** Round 2 confirms the redesign absorbed round 1's three findings in substance: §4/AC12 now bind re-presentation to the durable assessment artifact and forbid memory reconstruction; AC16's static half is a genuine negative assertion that can go red (the tautological fixture is gone); OQ4's lookback now samples both directions, including non-firings. The shape remains the right one: one instruction block in /close, one PASSES entry plus one ALTITUDES line (the runner's documented extension path), one new schema (repurposing design-review-schema would make the check ceremonial, and load_schema forecloses a permissive fallback), no new store, no new approval track, deployment reach respected (register not deployed, contract byte-identical). Nothing reinvents a dependency or a declarative construct. Oracle critique: the instruction-lint gates for ACs 1–5, 7, 8, 10–14, 17 are derived from the implementation surface (deployed instruction text), not from behavior — the test notes name this limit honestly, so it is accepted, and the regressions below lean on exactly that gap. AC6's PASSES/load_schema assertions are mechanism-shaped but the criterion is itself mechanism-shaped and can fail. AC9's git-derived check can genuinely fail. AC18's every-deployed-path count is the right shape — and its own rationale (relocation defeats a named-files-only count) is the argument for finding 2, which applies identical logic to AC15's one-file lint. AC5's reviewer oracle for substance is the honest assignment. Three residuals, none fatal: (1) the redesign points re-presentation at an artifact whose required content is never specified — if the assessment artifact does not embed the proposal verbatim, AC12's honest path has no implementation; (2) AC15's gate lints only /close text while the criterion's hazard surface is every deployed file; (3) AC16's observational half is deferred with nothing scheduling it — the same reliance-on-noticing this story exists to fix. Minor doc slip: Open question 5 cites 'the ceiling number in AC17', but the ceiling is AC18 — worth correcting when the number is settled so the ceiling isn't recorded against the wrong criterion. The self-identified one-way doors (prefix OQ2, ceiling number OQ5, hook record OQ1) remain correctly reserved for Thomas.

**Findings.**

- **[IMPORTANT] AC12's re-presentation rule depends on an artifact whose required content is never specified** — `two-way` × `standard` · locus: Lifecycle §4 (re-presentation rule); Scope §3; Design sketch — 'The review call'
  - **Claim:** Round 1's re-presentation fix moved the durability requirement onto 'the durable assessment artifact' — but nothing in the story says that artifact must contain the proposal. Every other review pass's artifact is the reviewer's JSON output; the proposal is the pass's input. If the lesson artifact is only the assessment (a paraphrase and a verdict), then after an interrupted session the honest path AC12 names — re-present only from the artifact — cannot be executed: the proposal itself would have to be reconstituted from the assessment's summary plus session memory, which is the confabulation channel the redesign explicitly set out to close. The lifecycle rule and the artifact's content invariant are in different sections and never meet.
  - **Alternative:** State the invariant where the artifact is defined: the lesson pass's durable artifact embeds the proposal verbatim (an echo field in lesson-review-schema.json, or a paired proposal file written atomically with the assessment under reviews/). One line in §3 or the sketch; the schema is new and nothing depends on it yet, so this is free now.
  - **Win:** Eliminates the last post-hoc reconstruction path the redesign reintroduced via the artifact channel, and gives AC12 a gate-able property — 'the artifact contains the full proposal' — that a test can actually assert, instead of a rule whose honest implementation is impossible under one reading of the spec.

- **[IMPORTANT] AC15's gate lints one file while the criterion's hazard surface is every deployed instruction file** — `two-way` × `standard` · locus: Test notes — AC15 row; AC15
  - **Claim:** The criterion is register-wide: 'No skill loads it, nothing auto-reads it, and no instruction directs Claude to it at any other point.' The named gate asserts this only over the /close text. The plausible leak is not in /close — it is a pointer grown later in the review skill, workflow-protocol.md, or a skill description ('past rejections: .aar/rejected-lessons.md'), which puts the register into routine context while the gate stays green. The story already accepts this exact logic for AC18: 'a ceiling counted only on named files is met by relocating text to an unnamed one.' Containment of the register's single-read-moment rule is defeated by precisely the same relocation, and the gate as named cannot see it.
  - **Alternative:** Extend the AC15 negative assertion across every deployed text path — the same enumeration AC18's ceiling test already requires — asserting no deployed file references lessons-rejected.md outside the single /close step. One loop in tests/reviewer_test.sh over a list the AC18 test must also maintain.
  - **Win:** Converts AC15 from a one-file lint into the containment check the criterion actually names, at near-zero marginal cost, using an enumeration the story is already committed to building for AC18 — two load-bearing gates sharing one deployed-path list instead of one of them being relocation-blind.

- **[IMPORTANT] AC16's observational half is deferred with nothing scheduling it — the reliance-on-noticing failure this story exists to fix** — `two-way` × `standard` · locus: Test notes — AC16 row
  - **Claim:** The observational half (install.sh --check plus the restricted git diff on a branch where a lesson actually ran) is 'deferred to the first story that is not the implementing one.' The deferral itself is sound — on this branch the restricted diff is non-empty by construction. But nothing files it: no BACKLOG.md item, no pending test case, no tracked follow-up. The story's founding example is exactly this failure — thin-the-loop's measurement happened 'because Thomas noticed. Nothing scheduled it.' If nobody notices, AC16's load-bearing containment property ('no runtime lesson handling ever touches a deployed artifact or workflow.json') rests permanently on the instruction lint alone, and the observational check quietly never exists. A story whose thesis is that unscheduled intentions fail should not ship one.
  - **Alternative:** File the observational check as an ordinary BACKLOG.md item as part of this story's own diff (dogfooding the mechanism: it is a task, not a lesson), or land the test now as a skipped/pending case whose skip message names its precondition — a branch on which a lesson was actually proposed or approved.
  - **Win:** Removes one more unscheduled reliance-on-noticing from a story whose entire premise is that pattern's failure, and guarantees the containment property the story calls load-bearing gets a check that will actually run — at the cost of one backlog line or one pending test.

**Coverage check.** All 18 acceptance criteria received at least one proposed regression (38 total, none empty). No uncovered criterion, no empty return — no gap to carry into the consult.

## Fireworks design review — round 1 (2026-08-06) · SUPERSEDED

> Judged the **first** draft, whose lifecycle required a rejected lesson's claim never be written
> where Claude reads. That rule was dropped (§6) after Thomas asked whether rejected lessons are worth
> reviewing — it was inconsistent with `BACKLOG.md` → *Decided against*, discarded the rejection
> reason (the more useful half), and guaranteed re-proposal. Its three findings were applied
> provisionally, **pending Thomas's ratification**, and round 2 judges the redesigned story. Kept
> here because the trail is the point.

**Verdict.** The shape is sound and I would build it essentially this way: one instruction block in /close at a named step, one declarative PASSES entry plus one ALTITUDES line (the runner's documented extension path — no new orchestration), one new schema rather than repurpose design-review-schema.json (the story's reasoning is correct: filling reversibility/standing/regressions for a lesson assessment would make the check ceremonial, and load_schema deliberately forbids a permissive fallback), no new store, no durable pre-disposition state, lifecycle handled as consult text plus post-disposition writes. Nothing here reinvents a dependency or an existing construct; the volume control and containment rules reuse the repo's existing BACKLOG.md search and install.sh --check rather than inventing new machinery. Deployment reach is handled correctly: the touched files deploy to every consumer repo via install.sh, and the sketch respects that (AC15 containment, byte-identical contract check in AC6). Oracle critique: the instruction-lint gates for ACs 1–5, 7, 8, 10–14, 16 are derived from the implementation surface (instruction text) rather than behavior — the story names this limit honestly, so it is accepted rather than flagged, but the regressions below lean on it. AC6's PASSES/load_schema assertions match a criterion that is itself mechanism-shaped, AC9's git-derived check can genuinely fail, AC17's line count can fail. AC15's named gate is the one oracle that, as written, risks being unable to fail informatively — flagged below. Three reservations, none fatal: (1) the design audits proposals but the suppression decision (1c answering 'no') is unreviewed and invisible, and the only planned lookback (OQ4) samples the noise direction, not the silence direction; (2) AC12's 'harmless re-presentation' is only true for re-derivable 1a proposals — a 1b proposal cannot survive interruption without confabulated reconstruction; (3) AC15's fixture-based gate verifies a hand-built branch, not the runtime behavior it exists to contain. The story's self-identified one-way doors (prefix OQ2, ceiling OQ5, hook record OQ1) are correctly reserved for Thomas.

**Findings.**

- **[IMPORTANT] AC12's 'harmless re-presentation' only holds for class 1a — a 1b proposal cannot survive interruption** — `two-way` × `standard` · locus: AC12; Lifecycle §4
  - **Claim:** Two stated facts collide in AC12: nothing is written before disposition, and class-1b observations (hook denial, runner refusal) exist only in the session where they happened. So after an interrupted session, an undisposed 1b-derived proposal cannot be re-presented from evidence — there is none durable — it can only be reconstructed from the model's memory, with citations assembled after the fact. That is precisely the confabulation path 1d ('cited, not remembered') exists to block, and AC12 currently blesses it as 'harmless'. The actual outcomes are loss (acceptable) or fabricated re-derivation (the worst failure this design has).
  - **Alternative:** Restrict the re-presentation allowance in AC12 to re-derivable (1a) proposals, and state explicitly that an undisposed 1b proposal is lost with its session and must not be reconstructed — if the lesson is real, its mechanism will fire again.
  - **Win:** Eliminates the single path in the whole design where a proposal's evidence citations could be fabricated post-hoc; costs nothing, because 1a re-derivation already covers the only case that can be re-presented honestly.

- **[IMPORTANT] AC15's named gate is a constructed fixture that cannot fail informatively** — `two-way` × `kludgy` · locus: Test notes — AC15 row
  - **Claim:** 'On a branch where only a lesson was proposed or approved' reads, as written, as a branch the test builds by hand: base plus one BACKLOG.md line. Diffing ARTIFACTS paths on that branch is empty by construction — the oracle verifies the fixture, not the runtime behavior. So the one containment property the story calls load-bearing (no runtime lesson handling ever touches a deployed artifact or workflow.json) gets a check that passes even if the /close instruction grows a runtime write to a deployed path. Every other gate in the table can fail; this one, on the constructed reading, cannot.
  - **Alternative:** Make the check observational instead of constructed: run install.sh --check and the restricted git diff on real branches where a lesson was actually proposed or approved in-session — starting with this story's own branch, which will exercise the mechanism — and keep the instruction lint as the static half, adding an explicit negative assertion that the /close text contains no instruction to write to deployed paths at proposal or approval time.
  - **Win:** Converts a tautology into a check that can actually catch a runtime write to a deployed artifact — same two commands, run against a branch that can fail.

- **[QUESTION] The silence direction has no check — extend the planned OQ4 lookback to non-firings** — `one-way` × `standard` · locus: Scope §1c, AC4, Open question 4
  - **Claim:** Independent review covers only proposals that exist. The 1c decision to propose nothing — made by the same party whose briefing, routing, or context assembly produced the activation — leaves no artifact, and AC4 rightly forbids one. That makes the mechanism's dominant failure mode invisible by construction: Claude rationalizing 'the control worked as designed' is exactly the judgment the bounded question exists to discipline, and nothing can observe it not being asked. Open question 4 already commits to an OPS-22-style lookback, but frames it only around drift toward 'yes' (noise reintroduction). Drift toward silence — never proposing, which is also the cheap, conflict-free answer for the observed party — has no planned check anywhere. The no-record-of-no policy is also a precedent future lesson/audit stories will copy, so settling it now is the one-way part.
  - **Alternative:** Widen the lookback Thomas is already being asked to approve (OQ4) to sample both directions: pick recent stories with observable activations — drift reports, gate failures, hook denials visible in scrollback or CI — where no proposal emerged, and audit whether 1c/1d were honestly applied, alongside the planned audit of proposals that were made. No runtime machinery, no audit line, no new artifact; one extra sampling rule in a lookback that is already on the table.
  - **Win:** The only check on the suppression direction at zero runtime cost. Without it, the story's core claim ('reduces reliance on Thomas noticing') is unfalsifiable in the direction that matters most — a mechanism that silently never fires is indistinguishable from one that correctly never fires.

**Coverage check.** All 17 acceptance criteria received at least one proposed regression (32 total, none empty). No uncovered criterion, no empty return — no gap to carry into the consult.

## Design decisions (2026-08-06)

**Scope — approved.** Thomas, 2026-08-06: *"approved — fix all three, put it in the close skill, use
the prefix AAR- for After Action Review, and store rejected lessons in an ever-growing file in a
directory not normally seen by Claude or other tools. backlog the problem with close having to run in
the same session etc"*

Binding on implementation. Do not re-litigate.

| Round-2 finding | Disposition | Where it landed |
|---|---|---|
| Re-presentation rule depends on an artifact whose content was never specified | **fix** | §3 — the schema must carry the proposal verbatim |
| AC15's gate lints one file while the hazard surface is every deployed file | **fix** | Test notes AC15 — loop over every deployed text path, sharing AC18's enumeration |
| AC16's observational half deferred with nothing scheduling it | **fix** | Test notes AC16 — filed as `OPS-28` in this story's diff |

| Round-1 finding | Disposition | Where it landed |
|---|---|---|
| The silence direction has no check (**one-way**, ratified) | **fix** | Open question 4 — lookback samples non-firings too |
| Re-presentation after interruption blessed confabulation | **fix** | §4 + AC12 — re-present only from the durable artifact, else it is gone |
| AC15's original gate was a tautology | **fix as amended** | Test notes — negative assertion now; observational half filed as `OPS-28` |

**One-way doors ratified.**

1. **`AAR-` as a fourth `BACKLOG.md` prefix.** Every future lesson item copies it; reversing means
   relabelling all of them. Recommendation at the consult was to reuse `OPS-`; Thomas chose a
   distinct prefix. Ratified.
2. **Retention-with-reason as the disposition for rejected lessons**, replacing erasure — the
   precedent every future lesson and audit story copies.
3. **A new shared schema** (`lesson-review-schema.json`) deployed to every repo via the `review`
   skill directory.

**Backlogged rather than built** (Thomas's instruction): `OPS-27` — the guard hook writes nothing
durable, so a hook trip is only visible when `/close` runs in the originating session.

**Still open, deliberately:** the lookback (Open question 4) is stated, not filed — flagged at the
consult as a recommendation rather than added unilaterally. The ceiling number (Open question 5) is
set from measured actuals during implementation and recorded in the Test notes. Register pruning
(Open question 6) is a decision for later.

## Fireworks approach review (2026-08-06, base main, HEAD 6f3c2d8)

**Verdict.** The shape is sound and I would build it essentially this way. The implementation follows the runner's documented extension path (one PASSES entry, one ALTITUDES line, one KNOWN_PURPOSES addition), creates a purpose-built schema that deliberately avoids design-review-schema's vestigial fields, reads the proposal from a durable file rather than trusting the model to echo it, and adds a well-scoped instruction block to /close with a clean error model (failed lesson pass never blocks the merge). The rejected register's dot-directory containment is the right design, the AC15 leak scan enumerates every deployed path derived from install.sh's ARTIFACTS (not a hand-typed list), and the AC16 negative assertion can genuinely go red. The tests are mechanism-shaped where the criterion is mechanism-shaped and behavioral where behavior can degrade unnoticed. Two concerns: the spec and the implementation disagree on how the durability invariant is implemented (load-bearing for AC12), and the AC16 containment test's sed range excludes step 4's disposition body — the half of the instruction text where a future runtime write to a deployed artifact would most plausibly be added.

**Findings — IMPORTANT.**

- **Spec/implementation mismatch on the durability invariant — the schema doesn't embed the proposal, and AC12 references the wrong durable source** — `two-way` × `standard`
  - **Locus:** reviews/lesson-proposals.md §3 ("The assessment artifact embeds the proposal verbatim"); §4 (re-presentation rule); .claude/skills/review/lesson-review-schema.json (description); .claude/skills/close/SKILL.md step 3b ("re-present a proposal only from .aar/proposals/<slug>.md")
  - **Claim:** The spec (§3) states as a binding invariant: 'lesson-review-schema.json requires a field carrying the full proposal text, not a paraphrase, alongside the assessment.' The round-2 design finding's disposition was 'fix — §3: the schema must carry the proposal verbatim.' But the shipped schema deliberately does NOT carry the proposal — its description says so explicitly, and the implementation instead writes the proposal to .aar/proposals/<slug>.md and tells /close to re-present from that file. AC12 says 're-presented only from the durable assessment artifact' (reviews/<slug>.lesson.json), but the /close instruction says 're-present a proposal only from .aar/proposals/<slug>.md' — a different file in a different directory. The implementation's approach is arguably better (the proposal file is the original document, unmodified by the model, so it is more trustworthy than a model-reproduced echo), but the spec still carries the contradicted requirement, and a reader following the spec would look for the proposal in the assessment artifact and not find it. The two documents were never reconciled.
  - **Alternative:** Update the spec to match the implementation: change §3 to state that the proposal lives in .aar/proposals/<slug>.md (a durable file written before the lesson pass runs) and that re-presentation is from that file, not from the assessment artifact; update AC12 to say 're-presented only from the durable proposal file' rather than 'the durable assessment artifact.' The schema's description already explains the reasoning — the spec just needs to catch up. Alternatively, add a proposal_text field to the schema and have /close write the proposal into the assessment artifact — but this trusts the model to reproduce a long document faithfully, which is exactly the failure the separate-file approach avoids.
  - **Win:** Eliminates a contradiction between the spec and the executable artifact on a load-bearing invariant (AC12's re-presentation rule), so a future reader following either document arrives at the same implementation. Costs one spec edit; the implementation is already correct.

- **The AC16 containment test's sed range excludes step 4's disposition body — the half where a runtime write to a deployed artifact would most plausibly be added** — `two-way` × `standard`
  - **Locus:** tests/reviewer_test.sh — the lesson-block containment check (sed -n '/^3b\. \*\*Lesson check/,/^4\. \*\*Re-review fork/p')
  - **Claim:** The negative assertion extracts text from step 3b through the step 4 header line, then greps that block for deployed/config paths. But step 4's body — where the disposition instructions live (Approved ⇒ write AAR- item to BACKLOG.md, Rejected ⇒ append to .aar/rejected-lessons.md, Deferred ⇒ leave in .aar/proposals/) — is excluded from the range because sed stops at the first line matching '4. **Re-review fork'. The containment property AC16 names ('at runtime, proposing or approving a lesson modifies no file in install.sh's ARTIFACTS array and no .claude/workflow.json') applies to disposition as much as to detection and assembly. A future edit to step 4 that adds an instruction to write to a deployed artifact during approval or rejection — e.g., 'on approval, update workflow.json to record the lesson' — would pass this test green. The static half of the containment check guards only the half of the instruction text where the write is least likely to be added.
  - **Alternative:** Widen the sed range to include step 4's lesson-related content — e.g., extract from step 3b through the end of step 4's disposition bullets (or through the line containing 'Present per the consult-presentation rule'), so the grep covers both detection/assembly (step 3b) and disposition (step 4). One range change in tests/reviewer_test.sh.
  - **Win:** Closes the gap in the load-bearing containment check so a future instruction to write to a deployed artifact during disposition is caught, at the cost of a one-line sed range adjustment. Makes the static half of AC16 actually cover the behavior AC16 names.

`regressions` is empty, as the contract requires at the review-time approach pass.

## Decisions (2026-08-06) — approach pass

Thomas, 2026-08-06: *"fix both, then run correctness"*.

| Finding | Disposition | Applied |
|---|---|---|
| Spec/implementation mismatch on the durability invariant | **fix** | §3 rewritten to name `.aar/proposals/<slug>.md` as the durable copy and to record why the echo option was rejected; AC12 and §4 re-pointed at that file |
| AC16 containment test's range excludes step 4's disposition body | **fix, refined** | `tests/reviewer_test.sh` — see below |

**The second fix needed to be narrower than the alternative proposed.** Widening the range to all of
step 4, as suggested, made the check fail on two **legitimate** lines: step 4 cites
`workflow-protocol.md` for the consult-presentation rule, and the containment sentence itself names
`.claude/workflow.json` in order to forbid writing there. The grep detects a path **mention**, not a
write, so it must see only lines that are actually instructions about where lesson state goes. The
shipped form concatenates two ranges — all of step 3b, plus step 4's three disposition bullets
(approve / reject / defer) — and excludes the surrounding prose.

**Demonstrated red both ways.** A write to a deployed path added to step 4's *Approved* bullet
(`also record it in workflow-AGENTS.md`) fails the new check —
`lesson step references a deployed/config path: workflow-AGENTS.md` — and produces **zero** hits
under the old narrow range, which would have stayed green. The hole the approach pass named was
real, and the check now closes it.

Neither was shape-changing, so the approach verdict stands and correctness runs this round on the
corrected branch.

## Fireworks correctness review (2026-08-06, base main, HEAD 22ca9bf)

**Summary.** The implementation is correct and faithful to the spec across all 17 acceptance criteria. The lesson pass is wired as a declarative PASSES entry with its own purpose-built schema, the /close instruction block covers detection, bounded question, cited novelty, assembly, independent check, interrupted-round rule, and disposition, and the tests are mechanism-shaped where the criterion is mechanism-shaped and behavioral where behavior can degrade. Two minor documentation inconsistencies: the Non-goals section of the story file references the rejected register as being under `reviews/` (stale from an earlier draft; §6 and the implementation correctly use `.aar/`), and the step 3b assemble paragraph omits the explicit class-identification requirement (1a/1b) that scope item 2 calls for.

**Findings — NIT.**

- **Non-goals section says rejected register is 'under reviews/' — stale from earlier draft**
  - **Locus:** `reviews/lesson-proposals.md`:143
  - **Claim:** The Non-goals section states: 'The rejected register (§6) is a new per-repo file under `reviews/`'. But §6 of the same file says `.aar/rejected-lessons.md`, and the implementation correctly creates the file at `.aar/rejected-lessons.md`. This line was not updated when the design moved the register from `reviews/` to a dot-directory (Thomas's decision: 'a directory not normally seen by Claude or other tools'). A reader of the Non-goals section alone would look for the register in the wrong directory.
  - **Suggestion:** Change 'under `reviews/`' to 'under `.aar/`' in the Non-goals section to match §6 and the implementation.

- **Step 3b assemble paragraph omits the class-identification (1a/1b) requirement from scope item 2**
  - **Locus:** `.claude/skills/close/SKILL.md`:33
  - **Claim:** Scope item 2 requires the proposal to carry 'the activation, which class (1a or 1b) it came from, and what it revealed that was not already known — with the citations from 1d'. The step 3b assemble paragraph says 'the activation and what it revealed' but does not explicitly ask for the class (1a or 1b). The class is implicit in the activation description (drift vs hook block vs runner refusal), but scope item 2 calls it out as a distinct element, and omitting it from the instruction means a future proposal could describe the activation without labeling its class, losing the re-derivable-vs-session-observed distinction that affects how the lesson can be verified on re-run.
  - **Suggestion:** Add 'which class (1a or 1b) it came from' to the assemble paragraph's list, e.g. 'the activation, which class (1a or 1b) it came from, and what it revealed'.


## Hidden-failure review (2026-08-06, base main, HEAD 22ca9bf)

**Summary.** The change adds a lesson-check step to the /close skill and a corresponding lesson-review pass in the runner, alongside the rejected-lessons register and supporting infrastructure. No new error-swallowing patterns are introduced. The runner's new context source reads the proposal from a file that must exist per the /close instructions; a missing file will cause a hard failure that the runner's existing fail-closed mechanism will surface, and /close is instructed to present such failures explicitly rather than absorb them. There are no bare except blocks, catch-log-continue paths, silent fallbacks, deleted assertions, or safety checks in the diff. Existing runner conventions disallow silently skipping a missing context source, and the instruction text reinforces surfacing over swallowing.

**Findings.** None — empty array returned.

## Decisions (2026-08-06) — correctness round

Thomas, 2026-08-06: *"fix both"*.

**Correctness (2 findings)**

| Finding | Severity | Disposition |
|---|---|---|
| Non-goals section says the rejected register is under `reviews/` (stale — §6 and the implementation use `.aar/`) | NIT | **fix** |
| Step 3b's assemble paragraph omits the class-identification (1a/1b) element scope item 2 requires | NIT | **fix** |

**Hidden-failure (0 findings)** — clean return, nothing to decide. The critic confirmed the new
context source fails hard on a missing proposal file rather than reviewing an empty one, and that
`/close` is instructed to surface a failed lesson pass rather than absorb it.

Both fixes are applied by `/close`. Neither is shape-changing, so no re-review is implied by these
dispositions — the re-review-or-merge choice remains Thomas's at `/close`'s fork.

## Fixes (2026-08-06)

Both approved correctness findings, applied. No other change.

| Approved finding | What changed |
|---|---|
| Non-goals said the rejected register is under `reviews/` | `reviews/lesson-proposals.md` — Non-goals now says `.aar/`, matching §6, the design sketch, and the built path. Three statements about the register's location, one answer. |
| Step 3b's assemble list omitted the activation's class | `.claude/skills/close/SKILL.md` — the list now asks which class the activation came from, phrased as **re-derivable or session-observed** rather than the spec's internal `1a`/`1b` labels, which mean nothing to a reader of the skill in another repo. The reason it matters is stated inline: a session-observed activation cannot be re-checked on a later run. |

Header stays `Status: approved` — whether this round merges is not known until the fork.
