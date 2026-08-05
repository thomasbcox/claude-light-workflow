Date: 2026-08-05 · Branch: claude/estate-reach-guardrails · Status: approved

# estate-reach-guardrails — make the deployment reach present at judgment time

## Problem

Reasoning about changes to this repo systematically anchors on **local** evidence, because the
consumer repos are invisible: they are not on the filesystem being read, not in the diff, not in the
gate output. The estate exists only as a **claim in prose** — the global `CLAUDE.md` and the
ROADMAP's "global-by-design". Concrete local observation reliably outweighs a stated abstract fact
at the moment a judgment is formed.

**Two documented instances, both this session, both caught by Thomas rather than by the loop:**

1. **OPS-20's first filing** ranked four testing techniques (property-based, mutation,
   adversarial-first, computed extents) by *this* repo's Python/Markdown mix — concluding two of
   them were weak fits — when the skills those techniques would govern deploy to ~8 repos across
   many languages. Thomas: *"don't critique the test improvements based on the languages used in the
   current repo."* The item was re-scoped estate-wide the same day.
2. **`route-design-hidden-failure`'s review** described the missing `docs_test` coverage for
   `.claude/workflow-protocol.md` as a local gap, when that file is deployed to every project — so
   the gap is estate-wide, and its severity was understated accordingly.

This is the repo's own documented disease twice over: **OPS-17** (a rule that lives only as prose,
with nothing enforcing it, drifts) and **OPS-20** (the judgment is formed by the same head that
gathered the evidence, with nothing independent to challenge it). "Be more careful" is therefore the
wrong shape of fix — it is precisely the class OPS-20's source analysis rejects.

**A third instance, found while framing this very story, and the reason the design sketch below is
not what was originally proposed:** the request was for a line in *this repo's* `AGENTS.md` "not the
deployed template". `install.sh`'s ARTIFACTS maps `AGENTS.md::workflow-AGENTS-template.md` — **this
repo's AGENTS.md *is* the deployed template.** The proposed fix for "I forget that things ship
everywhere" had itself forgotten that the file it wanted to edit ships everywhere. That is not an
argument against the fix; it is the strongest available evidence that the constraint has to be made
structurally present rather than remembered.

## In scope

- A **project-level `CLAUDE.md`** at the repo root, stating the deployment reach as a standing fact
  and directing that recommendations must not generalize from this repo's own language mix, test
  surface, or file layout. Loads automatically into every session in this repo.
- A **reviewer-facing directive** carried by `AGENTS.md`, so an *independent* reader checks for the
  same failure at every pass — subject to the template-coupling question below.
- A **backlog entry** for the deferred structural options B and B′ (Thomas, 2026-08-05: "backlog B
  and B-prime for future consideration"). Added to scope at the consult, after the design review
  established that neither belongs inside this story.

## Non-goals

- **Editing any `SKILL.md`.** They deploy everywhere; encoding a fact about one repo would cost
  reviewer/instruction context in all of them (the OPS-11 every-line-costs lesson).
- **A gate check asserting "the reasoning considered the estate."** Unfalsifiable without a wording
  pin, and `thin-the-loop` just pruned the pin set 91 → 19 on a stated behavioural bar.
- **Adding `docs_test` drift coverage for `workflow-protocol.md` / `AGENTS.md`.** A real gap
  (instance 2 above), but a different concern — drift detection, not reach awareness. Separate item.
- **Retro-fitting past stories or backlog items** with reach analysis.
- **Building OPS-20.** This story is a narrow guardrail, not the falsification programme.

## Acceptance criteria

- **AC-1** — A project-level `CLAUDE.md` exists at the repo root and states (a) that this repo's
  product is tooling deployed by `install.sh` to many repos across many languages, and (b) that a
  recommendation, ranking, or severity judgment must not be derived from this repo's own language
  mix, test surface, or file layout without saying so explicitly.
- **AC-2** — The reviewer contract carries a directive to judge changes for **deployment reach** and
  to flag reasoning that generalizes from the reviewed repo's own stack when the artifact ships
  elsewhere. Wording must satisfy the resolution of Q1 below.
- **AC-3** — Whatever lands in `AGENTS.md` is **true of any repo that receives it as a template**.
  No claim specific to `claude-light-workflow` ships to other repos as their reviewer contract.
- **AC-4** — The gate stays green, and no existing check is weakened to accommodate the change.
- **AC-5** — `BACKLOG.md` carries an item recording options **B** (decouple the template) and **B′**
  (optional repo-local addendum as a runner context source) as deferred structural work, each with
  its cost and its risk, so the analysis is not lost with this session.
- **AC-6** — Scope containment: `git diff --name-only main...HEAD -- . ':(exclude)reviews/'` shows
  exactly `CLAUDE.md`, `AGENTS.md`, `BACKLOG.md` and nothing else.

## Test notes

**This story has almost no mechanical oracle, and saying so is the honest answer** rather than
inventing checks that cannot fail. Both artifacts are prose whose *content* is the deliverable;
pinning their wording would be exactly the pin regrowth `thin-the-loop` argued against, and a
wording pin would pass against text that says the right words and means nothing.

- **AC-1** — *Not mechanical.* Oracle: the design/approach reviewer, named here deliberately.
  **Correction at implementation (step 9):** the plan said a mechanical "`CLAUDE.md` exists at the
  repo root" check. **No such check was added**, and the note is corrected rather than the claim
  quietly dropped. Reason: a bare existence pin fails this repo's stated pin bar — its silent
  failure is a *deleted file*, which every `git diff` and every review already surfaces loudly, so
  the pin would guard nothing that is not already guarded. Adding it would be the pin regrowth
  `thin-the-loop` pruned. **Consequence, stated plainly: no AC in this story is verified by the
  gate.** The gate only proves nothing else broke (AC-4).
- **AC-2** — No mechanical oracle. Oracle: the reviewer, which is also the party the directive is
  addressed to — so it is reading its own instructions, and its verdict is weaker than usual.
  Recorded rather than hidden.
- **AC-3** — **The one AC with a real behavioural check, and only under Q1 option B.** If the
  template is decoupled from this repo's `AGENTS.md`, then `install.sh` must deploy the *template*
  and never this repo's contract; silent failure ships a false contract to every new repo, which is
  a behaviour regression and earns a pin. **Demonstrate red:** point ARTIFACTS back at `AGENTS.md`
  and the check must fail. Under option A the AC is satisfied by construction (one generic file) and
  has no check.
- **AC-4** — Full gate: `bash tests/guard_test.sh && bash tests/reviewer_test.sh && bash
  tests/fireworks_runner_test.sh && bash tests/dev_audit_test.sh && bash tests/docs_test.sh`.
- **AC-5** — Mechanical: the item exists and names both options. Not mechanical: whether the
  analysis is useful. No check; the reviewer is the oracle, as with AC-1/AC-2.
- **AC-6** — the command in the AC.

**Noted:** this story would be a natural first customer for OPS-20's adversarial-first option — the
regression list for *"did the reasoning account for estate reach"* is precisely the list the author
writes badly. That machinery does not exist yet, so the step-6 design review is standing in for it,
and is doing double duty: judging the shape *and* being the only real check on AC-1/AC-2.

## Open questions

**Q1 — `AGENTS.md` is the deployed template. How should AC-2 land?** (The one-way-door decision in
this story; the sketch below assumes **A** pending Thomas's call.)

- **A — Generic wording, one file.** Phrase the directive to be true in any repo: judge deployment
  reach *where the reviewed repo's artifacts are consumed elsewhere*, and flag stack-local
  generalization in that case. **Cost:** near zero, no structural change. **Risk:** generic enough
  that it may not bite hard for this repo, where the reach is unusually total — every artifact, to
  every repo. Would nonetheless have caught both documented instances.
- **B — Decouple the template.** Add a separate template file, repoint `install.sh`'s ARTIFACTS at
  it, and let `AGENTS.md` become repo-specific. **Cost:** a new file, an `install.sh` change, docs
  updates, and a gate check. **Risk:** two contracts that can drift apart (OPS-17's disease, freshly
  created); and it changes the deploy contract, so every future repo sources its template from a new
  place. Structurally the right long-term answer, but it deserves its own story rather than riding
  in on a guardrail change.
- **C — `CLAUDE.md` only; drop AC-2.** **Cost:** zero. **Risk:** loses the independent check
  entirely — `CLAUDE.md` is read by Claude, not by the reviewer — reducing the fix to prose that can
  be under-weighted, which is the exact failure mode being fixed.

**Q2 — Does the `CLAUDE.md` claim need a number?** "~8 repos" will go stale silently and nothing can
verify it from inside this repo. Suggest stating the *property* ("deployed by `install.sh` to every
project on this machine") rather than a count. Confirm.

## Design sketch — HOW

Two prose artifacts. No code, no dependency, no new pattern.

- **`CLAUDE.md`** (new, repo root): short — the deployment-reach fact, the don't-generalize-locally
  rule, and a pointer to `ROADMAP.md`'s *reach vs. lightweight* tension rather than restating it
  (OPS-17: state a rule once, reference it elsewhere). Deliberately **not** deployed by `install.sh`;
  it is repo-local context, and adding it to ARTIFACTS would ship this repo's self-description to
  every project.
- **`AGENTS.md`**: one bullet in the existing best-practice-lens section, worded per Q1's
  resolution. Under **A**, generic: reach is judged *where artifacts are consumed elsewhere*, which
  is a true and useful lens in any repo and a strong one here.

The two are deliberately redundant across *different readers* — `CLAUDE.md` conditions the builder's
context before reasoning starts; `AGENTS.md` gives an independent reader a reason to challenge it
afterwards. That is not the OPS-17 duplication smell (one rule restated in several places that drift
silently); it is one rule addressed to two actors, and neither can substitute for the other.

## Fireworks design review (2026-08-05)

Backend `fireworks`, model `kimi-k3` — the first `/frame` design pass to run on this backend, wired
by `merge: route-design-hidden-failure` earlier the same day.

**Verdict:** the shape is right-sized and honest — two prose artifacts for two distinct readers, no
gate check, no wording pin, no dependency, consistent with `thin-the-loop`'s pin purge and
OPS-17/OPS-20's framing. *"The leverage is in the content shape, not the structure: the story's own
evidence shows the estate already existed as an abstract prose claim (the global CLAUDE.md) and was
under-weighted twice while loaded, so the deliverables only earn their keep if they are concrete and
procedural — anchored to install.sh's ARTIFACTS as the verifiable source of truth and phrased as a
pre-judgment lookup — rather than a second statement of the abstract fact."*

### IMPORTANT · two-way · standard — `CLAUDE.md` re-states the claim that already failed twice

Both documented failures happened with the global `CLAUDE.md`'s estate claim **already loaded**. A
project-level file asserting the same thing at the same abstraction level repeats the shape the story
diagnoses as losing to concrete local evidence — and "every project on this machine" is an
unverifiable world-claim that goes stale exactly like the "~8 repos" count Q2 worried about.
*Alternative:* state reach as a property of the mechanism — every file in `install.sh`'s ARTIFACTS
ships verbatim — and phrase the rule as an **action** performed before judging. *Win:* Q2 dissolves
(no count, no world-claim), and the claim becomes checkable from inside the repo by opening one file.

### IMPORTANT · two-way · standard — the option-A bullet presupposes the knowledge it supplies

*"The sketched generic wording only fires for a reader who already knows whether the reviewed repo's
artifacts are consumed elsewhere. The reviewer runs on AGENTS.md as its contract — codex does not
auto-load CLAUDE.md — so in this repo the reviewer's only reach signal is the bullet itself."* The
independent check would therefore have depended on the very awareness the story exists because
Claude lacked. *Alternative:* word it as a conditional lookup that names its own trigger (an install
script, a template/ARTIFACTS manifest, a published package). *Win:* self-activates where reach
exists, no-ops where it does not, so AC-3 holds with no repo-specific claim shipping.

### QUESTION · two-way · standard — Q1's "one-way door" label is misplaced

A is one rewordable bullet: no deploy-contract change, no second artifact, revisable at any time. **B
is the actual door.** Treating A as needing B's ratification weight risks stalling a narrow guardrail
on a structural decision the story itself defers.

## Design decisions (2026-08-05)

- **Scope** → **approved**, with the backlog entry added at Thomas's instruction: *"go with A, and
  backlog B and B-prime for future consideration."*
- **Q1 / QUESTION finding** → **A ratified as the reversible default.** B and B′ deferred to their
  own backlog item (AC-5), not to this story.
- **IMPORTANT (CLAUDE.md abstraction)** → **FIX.** Recommended at the consult and not contested;
  taken as a two-way call **logged for veto** per the consult model rather than re-asked. `CLAUDE.md`
  will anchor to `install.sh`'s ARTIFACTS and read as a pre-judgment action, not a restated fact.
- **IMPORTANT (AGENTS.md presupposition)** → **FIX**, same basis. The directive names its own trigger
  so it self-activates, and carries no claim specific to this repo — which is what makes AC-3 hold
  under option A at all.

Both IMPORTANTs are two-way and advisory; if either reading is wrong, the fix is one reworded
paragraph in each file.

## Build note (2026-08-05)

| AC | Files |
|---|---|
| 1 | `CLAUDE.md` (new) |
| 2, 3 | `AGENTS.md` |
| 4 | no files — verified by the gate |
| 5 | `BACKLOG.md` (OPS-21) |
| 6 | no files — verified by `git diff --name-only` |

**Demonstrate-red: not applicable, and not skipped quietly.** Step 9 requires a red demonstration
for each AC whose test notes name the gate as its oracle. **No AC here does** — this story adds no
assertion to the gate, by design (see Test notes). The gate's role is AC-4 only: proving the two
prose changes broke nothing. Both design-review IMPORTANTs were applied as decided.

## Fireworks approach review (2026-08-05, base main, HEAD b66d938)

Backend `fireworks`, model `glm-5p2`. **Empty findings.**

> The shape is sound and the implementation faithfully applies both design-review IMPORTANTs.
> CLAUDE.md anchors to install.sh's ARTIFACTS as a verifiable mechanism and phrases the rule as a
> pre-judgment action […] not a restated abstract fact — exactly the fix the design review
> prescribed, and Q2 dissolves by construction (no count, no world-claim). The AGENTS.md bullet
> names its own triggers […] so it self-activates where reach exists and self-disables where it does
> not […] and AC-3 holds because no claim specific to claude-light-workflow ships. OPS-21 records
> both deferred options with costs, risks, and a trigger, satisfying AC-5. […] No higher-leverage
> simplification exists: the two-actor redundancy (builder vs reviewer) is deliberate and justified,
> not OPS-17 drift, because neither reader can substitute for the other.

**Note on this pass's standing:** the runner reads `AGENTS.md` from the *repo*, so this review ran
under the very directive the story adds — the change was live for its own review. That cuts both
ways and is recorded rather than claimed as validation.

## Fireworks correctness review (2026-08-05, base main, HEAD b66d938)

Backend `fireworks`, model `glm-5p2`.

> The branch faithfully implements the spec and applies both design-review IMPORTANTs as decided.
> […] AC-6 scope is clean: only CLAUDE.md, AGENTS.md, and BACKLOG.md change outside reviews/. No
> correctness issues found.

### NIT — `CLAUDE.md` enumerates "the four skills", a count that can go stale silently

*Claim.* The line hard-codes an item count. **The design review's own IMPORTANT — and Q2 — argued
against counts precisely because they go stale with no signal.** The ARTIFACTS reference on the
preceding line is the authoritative source and makes the enumeration redundant; if a skill is added
or removed, the count drifts.

*Suggestion.* Drop the count, or remove the enumeration entirely, since "Every path listed in
`install.sh`'s ARTIFACTS array" already makes the point concretely and verifiably.

## Hidden-failure review (2026-08-05, base main, HEAD b66d938)

Backend `fireworks`, model `deepseek-v4-pro`. **No findings.**

> The diff consists entirely of prose additions […] There are no executable code changes, no
> exception handling, no assertions, and no logic that could silently degrade on error. No
> hidden-failure concerns are present.

## Decisions (2026-08-05)

Thomas, on the round-1 findings: *"fix the nit, then push and open the PR."*

- **Correctness · NIT — `CLAUDE.md` hard-codes "the four skills"** → **FIX.** The count is gone, and
  the line now names the *kinds* of artifact while pointing at `install.sh`'s ARTIFACTS array as the
  authoritative list — with that stated explicitly, so the next editor does not reintroduce a count.
  Taken despite being a NIT because the finding was the artifact contradicting the principle it
  exists to state: the same design-review IMPORTANT (and Q2) that removed the *repo* count from this
  file had left a *skill* count two lines below it.
- **Approach** → clean (empty findings), nothing to decide.
- **Hidden-failure** → no findings, nothing to decide.
