# user-level-contract — one home for the reviewer contract; repo `AGENTS.md` becomes local-only

Date: 2026-08-05 · Branch: claude/user-level-contract · Status: approved

## Problem

The reviewer contract is **copied** into each repo and then never updated. `/frame` step 1 copies
`~/.claude/workflow-AGENTS-template.md` into a project **only "If `AGENTS.md` is absent"** — so a
repo bootstrapped at any past moment keeps that generation of the contract forever. There is no
version marker in the file and nothing anywhere detects staleness.

**Measured, not suspected.** A read-only survey of `~/Projects` (2026-08-05) found six repos running
this loop. One is the source. Of the other five, **all five are stale** — three by one generation,
two by two generations. Concretely:

- **A live functional gap, not documentation drift.** `review/SKILL.md`'s hidden-failure critic is
  told to work from *"AGENTS.md's 'Hidden failure' bullet ONLY"*. That bullet entered the contract
  2026-07-15. **Every stale repo predates it**, so in five of six repos one of the two correctness
  critics has been pointed at a section of the contract that does not exist there.
- Two repos (`ruleset-sim`, `txl-assessment-collector`) predate selectable backends entirely and
  open with a hardcoded *"You are **Codex**"* — false whenever `fireworks` runs.
- Two repos carry ~70 and ~95 lines of genuine hand-authored local doctrine (one edited three days
  before the survey), so "just overwrite them all" would silently destroy maintained work.

Every candidate fix considered — a version marker, a `/frame` staleness check, a sync script,
marker-delimited managed regions — is machinery for **keeping copies in agreement**. This story
removes the copies instead. Four of the six repos store nothing but a redundant duplicate of a file
that should have one home; that is the same defect OPS-20's computed-extents rule names, applied to
a document rather than a test.

## In scope

- **`AGENTS.md` → `workflow-AGENTS.md`** in this repo: the shared contract's source file is renamed,
  freeing the name `AGENTS.md` in *every* repo — including this one — to mean "local guidance only."
- `install.sh` — the `ARTIFACTS` mapping deploys the renamed source to `~/.claude/workflow-AGENTS.md`
  (no longer `…-template.md`; it is no longer a template).
- `.claude/skills/review/fireworks_runner.py` — the `contract` context source reads the user-level
  file; a new **optional** `contract_local` source reads the repo's `AGENTS.md` using the existing
  stated-absence pattern.
- `.claude/skills/frame/SKILL.md` and `.claude/skills/review/SKILL.md` — every codex prompt names
  the user-level contract explicitly (codex auto-reads only the repo file), and step 1's
  copy-the-template bootstrap is removed.
- **Migration guard** — a repo `AGENTS.md` that is actually a stale full copy of the contract is
  detected and refused, rather than pushed alongside the real one as if it were local guidance.
- `.claude/workflow-protocol.md`, `README.md`, `ARCHITECTURE.md` — the artifact lists and contract
  description follow the change.
- `tests/reviewer_test.sh`, `tests/fireworks_runner_test.py` — behavioural coverage for the new
  resolution and the migration guard.
- `BACKLOG.md` — close out OPS-21 (this removes its premise) and record the estate migration as a
  tracked follow-up.

## Non-goals

- **Migrating the other repos' files.** This story ships the mechanism and a documented procedure;
  actually editing five other repositories is manual work outside this diff, and outside a
  scope-containment AC that only governs this repo.
- **Changing what the contract says.** This is about where it lives, not its content. The known
  content drift (`AGENTS.md` documenting "two altitudes" when three passes run) stays with OPS-23.
- **`hw-biz-model`** — it runs a different, heavier protocol (`start-story` / `prepare-codex-review`)
  with its own contract lineage. Out of scope, confirmed by the survey.
- **`~/.codex/AGENTS.md`** — codex's own user-level file, holding personal preferences unrelated to
  reviewing. Not touched, not used to carry the contract: it is codex-specific, so `fireworks` could
  never read it.
- **A sync script, version marker, or staleness check.** All are made unnecessary by construction;
  building any of them alongside this would be paying for the problem twice.

## Acceptance criteria

1. The shared contract has exactly **one** source file in this repo (`workflow-AGENTS.md`), and
   `install.sh`'s `ARTIFACTS` deploys it to `~/.claude/workflow-AGENTS.md`. No file named
   `AGENTS.md` is deployed anywhere, and this repo's own `AGENTS.md` no longer carries the portable
   contract.
2. The `fireworks` runner reads the **shared contract from the user-level path** as a **required**
   context input: if it is missing or empty the round stops closed, exactly as other required inputs
   do. The path is resolvable in tests without writing to the real `~/.claude`.
3. The runner reads the repo's `AGENTS.md` as an **optional** `contract_local` input, following the
   existing optional-input contract: when absent, the payload **states the absence** rather than
   omitting it silently. **The optional-input contract is fixed centrally** (design note, accepted):
   `assemble_context` treats a missing file for an `optional` source as stated absence, instead of
   every getter separately working around a `FileNotFoundError` that today is raised regardless of
   the flag.
4. Both contract inputs are declared on **every** reviewer pass, verified against a pass list
   anchored **outside** the runner's own `PASSES` table, so a pass wired elsewhere fails the check
   loudly rather than being invisible to it. *(Amended per the design review: the original
   PASSES-derived extent could not fail for a pass living outside PASSES.)*
5. **Migration guard, covering both backends** *(amended per design-review BLOCKER)*. A stale full
   copy of the shared rulebook sitting in a repo's `AGENTS.md` is detected and the round **stops
   with a message naming the migration** — via a **preflight in `frame/SKILL.md` and
   `review/SKILL.md` that runs before either backend is invoked**, with the runner's own check kept
   as a backstop for direct runner invocation. Detection uses a **similarity measure**
   (`difflib.SequenceMatcher`, stdlib) against the deployed contract — **not** a sentinel phrase —
   so it catches every stale generation the survey found, including the two that predate selectable
   backends, and cannot silently die the next time the contract is edited.
6. Every codex prompt that invokes the reviewer **carries the shared contract inline**, interpolated
   from the deployed path at invocation, rather than instructing the model to go read a path
   *(amended per design review — the one-way-door decision Thomas ratified)*. Each prompt also
   states that the repo's `AGENTS.md`, when present, carries repo-specific additions only.
7. `/frame` step 1 no longer copies a contract template into a repo; a repo with no `AGENTS.md` is
   the normal, fully-supported case rather than one needing bootstrap.
8. `.claude/workflow-protocol.md`, `README.md`, and `ARCHITECTURE.md` describe the new arrangement:
   the shared contract as a global artifact, and the repo `AGENTS.md` as optional local guidance.
9. `BACKLOG.md` records: OPS-21 closed (its premise — one file serving as both this repo's contract
   and everyone's template — no longer exists), and a new tracked item for migrating the five
   surveyed repos, carrying the survey's per-repo classification so the work is actionable later.
10. The full gate passes, and the new behaviour in ACs 2/3/5 is covered by **behavioural** tests in
    `tests/fireworks_runner_test.py` (the suite that owns runner behaviour), not by wording pins.
11. Scope containment: the diff touches only `AGENTS.md`, `workflow-AGENTS.md`, `install.sh`,
    `.claude/skills/review/fireworks_runner.py`, `.claude/skills/frame/SKILL.md`,
    `.claude/skills/review/SKILL.md`, `.claude/workflow-protocol.md`, `README.md`,
    `ARCHITECTURE.md`, `tests/reviewer_test.sh`, `tests/fireworks_runner_test.py`,
    `tests/check_contract_wiring.py`, and `BACKLOG.md`.

    *(Amended at implementation, 2026-08-05 — `tests/check_contract_wiring.py` added; logged for
    veto, not a silent widening.* AC1's check must read `install.sh`'s `ARTIFACTS` **and** import the
    runner to compare against `CONTRACT_PATH`, so it is Python. `tests/reviewer_test.sh` is shell and
    already uses inline `python3 - <<'PY'` heredocs; nesting a second one inside the first breaks the
    outer heredoc — I hit exactly that and had to revert a corrupted file. Extracting the check to
    its own script is the working alternative, and it also makes the comparison independently
    runnable. Two-way and trivially revertible.)*

## Test notes

Per AC: the oracle mode and the mechanism. Regressions are **not** written here — they come from the
step-6 design review and are appended below before the consult.

- **AC1** — `gate`. Structural, derived from the authoritative list rather than retyped: parse
  `install.sh`'s `ARTIFACTS` block and assert (a) some entry's destination is `workflow-AGENTS.md`,
  and (b) **no** entry's destination is `AGENTS.md`. Deriving from `ARTIFACTS` is what makes this
  survive an unrelated artifact being added — the same rule `docs_test.sh` already follows.
- **AC2** — `gate`, behavioural: with the user-level contract absent or empty, `run_altitude` must
  fail closed and write no artifact. The test must point the runner at a **temp** user-level path,
  never the real `~/.claude` — the suite already builds temp repos, so this extends that pattern.
- **AC3** — `gate`, behavioural: with no repo `AGENTS.md`, the assembled payload contains the
  stated-absence line for `contract_local` and the round still succeeds. The **renders-nothing case
  is the point of this AC**, so it is the primary assertion, not an afterthought.
- **AC4** — `gate`, derived extent: iterate the runner's own `PASSES` table and assert every pass
  declares both contract inputs. Deriving from `PASSES` rather than naming the four passes is what
  makes a fifth pass fail loudly instead of being silently uncovered. Noted honestly: `PASSES` is
  also what the code reads, so this proves *internal consistency*, not that the set is correct — a
  vacuous-extent risk, stated rather than hidden.
- **AC5** — `gate`, behavioural: a temp repo whose `AGENTS.md` is a copy of the shared contract must
  stop the round with the migration message; a temp repo whose `AGENTS.md` holds only local text
  must proceed. Both directions asserted, since a guard that never fires and a guard that always
  fires are both wrong.
- **AC6** — `gate`, wording pins on the prompt sites. Stated limit: a pin proves the instruction is
  **present**, never that codex obeys it; obedience has no CI-safe oracle (it needs a paid API call)
  and is `manual`, on the first codex-routed review after this ships.
- **AC7** — `gate`, an `absent` pin: the copy-the-template instruction is gone from `frame/SKILL.md`.
- **AC8** — `reviewer`. No mechanical oracle: `docs_test.sh` verifies that deployed skills are named
  as `/commands`, and cannot check whether a sentence is true. Saying so is more honest than adding
  a pin that asserts only that words I typed are still present.
- **AC9** — `manual`: the BACKLOG entries exist and carry the survey's classification.
- **AC10** — `gate`: the full `testCommand` passes.
- **AC11** — `manual`: `git diff --name-only main...HEAD -- . ':(exclude)reviews/'` shows nothing
  beyond the files AC11 enumerates.

## Open questions

1. **Can `codex exec -s read-only` read a file outside the workspace?** This is the one thing that
   could sink the codex half. The skill already passes `--output-schema "$HOME/.claude/…"`, but that
   is the *CLI* reading a file, not the sandboxed model reading one with its own tools. If the
   read-only sandbox scopes reads to the workspace, a prompt saying "read
   `~/.claude/workflow-AGENTS.md`" silently yields a review with no contract — the exact silent
   degradation this repo's doctrine exists to prevent. **Contingency, if so:** the codex prompt
   interpolates the contract inline (`"$(cat ~/.claude/workflow-AGENTS.md)"`), since the prompt is
   already a shell string — the same *push* the fireworks runner does, and it removes the sandbox
   question entirely. I can settle this empirically before implementing; I have not assumed either
   way. **Which way this resolves changes AC6's shape**, so it belongs in the consult.
2. **Should the story file record which contract version judged it?** Option 3's real cost is that a
   repo's review is no longer reproducible from the repo alone — the contract that judged a change
   lives outside it. One line (a hash, in the review section the loop already writes) would restore
   that. It is a genuine scope addition, so it is your call rather than my assumption.
3. **Delete this repo's `AGENTS.md`, or leave it empty-but-present?** After the rename it has no
   portable content. Deleting is cleaner; keeping a stub that says "local guidance goes here" is
   more discoverable and gives this repo the OPS-21 capability immediately. I lean **delete** — an
   empty file that exists only to explain itself is instruction weight with no content.

## Design sketch — HOW

**The rename is what makes the rest work.** Today `AGENTS.md` is one name doing two jobs: this
repo's contract *and* the estate's template. Renaming the source to `workflow-AGENTS.md` frees
`AGENTS.md` estate-wide to mean exactly one thing — local guidance — which is what lets a repo have
none at all.

**Runner (`fireworks`, the backend everything routes to).** Two entries in `CONTEXT_SOURCES`:

- `contract` — currently `lambda ctx: (ctx["root"] / "AGENTS.md").read_text()`. Repoint at the
  user-level path. Stays **required**, so a missing contract stops the round rather than reviewing
  against nothing.
- `contract_local` — new, `"optional": True`, reading `<repo>/AGENTS.md`.

  ⚠️ **A trap the existing code sets:** `assemble_context` catches `FileNotFoundError` and raises
  *regardless of the `optional` flag* — `optional` only governs an **empty** body. `manifest` avoids
  this by walking git output and returning `""` rather than raising. So `contract_local`'s getter
  must return `""` when the file is absent; the naive `.read_text()` would fail the round closed in
  every repo that has no local file, which is most of them.

The user-level path needs to be a **module-level constant**, not an inline `Path.home()` call, so
the test suite (which imports the runner) can point it at a temp directory. That is what makes AC2
and AC5 testable without touching the real `~/.claude`.

**Migration guard.** A repo `AGENTS.md` that still contains a distinctive phrase from the shared
contract is a stale full copy, not local guidance. Detect that in `contract_local`'s getter and
raise `RunnerError` with a message naming the migration. Fail closed, consistent with the runner's
existing posture — the alternative is pushing two contracts, one current and one stale, and letting
the model reconcile them silently.

**Codex.** Codex auto-reads the repo's `AGENTS.md` (which becomes the local layer, for free) but
knows nothing of the user-level file, so each of the four prompts must name it — pending Open
Question 1, which may turn "name the path" into "interpolate the contents."

**`install.sh`.** One `ARTIFACTS` line changes. Because `--check` and `do_install` both derive from
that array, drift detection and deployment follow with no other edit — the computed-extents property
the installer already has.

**Tests.** Behavioural, in `fireworks_runner_test.py`, matching where the survey's evidence says
real defects get caught: temp user-level contract present/absent/empty, temp repo with and without a
local file, and a stale-copy repo hitting the guard. `reviewer_test.sh` gets only the ARTIFACTS
structural check and the prompt pins.

### Reviewer-sourced regressions (2026-08-05, design pass)

Written by the independent reviewer from the criteria alone, before any test exists — the
author writes tests against **this** list, not one of their own. **Coverage check: all 11
criteria received at least one regression; no gaps to carry into the consult.** 24 total.


**AC1** — oracle: gate (ARTIFACTS-derived)

- Satisfy the ARTIFACTS check (a destination workflow-AGENTS.md, none named AGENTS.md) while
  leaving this repo's own AGENTS.md in place still containing the full contract text, relabeled
  as 'local guidance' — the letter (nothing named AGENTS.md is deployed) passes and the intent
  (exactly one source of the contract, in-tree included) is violated. The ARTIFACTS-derived
  check cannot see this; also assert the repo file is gone or content-disjoint from the
  contract, not merely undeployed.
- Let the install destination and the runner's read path be derived independently: the check
  matches the basename 'workflow-AGENTS.md' in ARTIFACTS while the runner's module-level
  constant points at a different parent directory, so the file installed is never the file read.
  Derive the expected destination from the same constant the runner actually uses.

**AC2** — oracle: gate (behavioural)

- Handle 'missing' via FileNotFoundError but never check 'empty' for a required source — the
  sketch itself notes the optional flag is what governs empty bodies, so an empty contract file
  could assemble a review against nothing while 'missing or empty stops the round' is only half-
  implemented. Make the empty case a primary assertion, not an assumed side-effect.
- Let run_altitude raise on the absent contract but have an outer handler catch-log-continue and
  still write the round artifact — 'fails closed' verified by observing an error while the
  degraded round completes and produces output. Assert no artifact exists, not merely that an
  error was raised or logged.
- Inject the temp path via a monkeypatched module constant that was already captured at import
  time (from-import copy or default-argument binding), so the tests silently read the
  developer's real ~/.claude/workflow-AGENTS.md and pass because it exists — isolation's letter
  (tests point at temp) met, its intent (never depend on real user state) violated. Prove
  isolation by asserting the temp file's distinctive content is what reached the payload.

**AC3** — oracle: gate (behavioural)

- Emit the stated-absence line correctly when no local file exists, but wire the present-branch
  to a wrong path or root, so a repo with genuine local guidance has it silently dropped from
  the payload while the absent-case test stays green. The AC's intent is the optional-input
  contract in both directions; assert the present case carries the file's actual content.
- Cross-wire the two getters so an absent local file states absence (letter passes) but a
  present one injects the shared user-level contract a second time as contract_local — two
  contracts in one payload, the very failure AC5 exists to prevent, arriving through the AC3
  code path.

**AC4** — oracle: gate (derived extent)

- Declare both inputs on every pass in PASSES while one pass's prompt template never
  interpolates contract_local — the derived-extent check iterates declarations and passes while
  that altitude reviews without the local layer another altitude saw. Assert on each pass's
  assembled payload, not on its declaration.
- Add a fifth pass outside the PASSES table (wired directly in a skill or another code path):
  the PASSES-derived oracle cannot fail for a pass it cannot see, so it proves internal
  consistency of the table rather than the criterion's 'every reviewer pass'. Anchor the
  expected pass set to something outside the runner, such as the skill invocations.

**AC5** — oracle: gate (behavioural, both directions)

- Implement the guard as exact-match or hash-equality against the current contract text: the
  'current copy stops / local text proceeds' fixture pair passes, while the three older stale
  generations the survey actually found (two predating selectable backends) are waved through as
  local guidance. Fixtures must span the surveyed generations, not just the current file.
- Key detection to a phrase introduced in a recent contract generation (e.g., the 2026-07-15
  hidden-failure bullet): the oldest stale copies lack it and proceed, while a healthy repo
  whose local guidance legitimately quotes one contract line is stopped — both wrong directions
  the AC names, reachable while a two-fixture test drawn only from the current file stays green.
- Let the guard exist only in the fireworks runner so 'the runner stops with a message naming
  the migration' is literally satisfied, while a codex-routed review in the same stale repo
  auto-reads the stale AGENTS.md and is also handed the user-level contract by the prompt — two
  contradictory contracts, silently reconciled, on the backend the guard never touches.

**AC6** — oracle: gate (prompt pins) + manual

- Update one prompt site per file while other sites in the same SKILL.md keep the old 'your
  contract is the repo's AGENTS.md'-era instruction: a file-level presence pin matches the path
  string once and passes with old and new instructions coexisting and contradicting. Pin per
  prompt site, and absence-pin the superseded instruction.
- Ship prompts that correctly name the user-level path while codex's read-only sandbox cannot
  read outside the workspace (open question 1): every pin passes and every review silently runs
  with no contract at all — letter fully satisfied, intent fully violated, and no CI oracle can
  see it. Only removing the read (interpolating the contract into the prompt) closes this.

**AC7** — oracle: gate (absent pin)

- Delete the copy-the-template instruction from step 1 while a later frame step or the review
  flow still assumes a repo AGENTS.md exists (an unconditional read, a 'record the convention in
  AGENTS.md' instruction), so the newly 'fully supported' no-AGENTS.md repo breaks mid-flow. The
  absent-pin on step 1 cannot see downstream assumptions; sweep the whole flow, not the one
  step.
- Remove the skill instruction but leave install.sh deploying workflow-AGENTS-template.md —
  AC1's 'no destination named AGENTS.md' check does not match the …-template.md name, so the
  bootstrap artifact survives for old skill versions and habits to keep copying from. Assert the
  template entry is gone from ARTIFACTS, not just that the prose is.

**AC8** — oracle: reviewer

- Add a 'the contract is global now' passage to each of the three docs while leaving old-
  arrangement procedures elsewhere in the same files (bootstrap step lists, install instructions
  naming the template path), so every document self-contradicts. With no mechanical oracle,
  review by grepping the whole documents for stale tokens (template name, 'copy', 'bootstrap',
  'If AGENTS.md is absent'), not by reading only the edited hunks.
- Describe the intended layout in ARCHITECTURE.md/README while install.sh deploys something
  slightly different — prose artifact lists drifting from ARTIFACTS. Cross-check the documented
  lists against the parsed ARTIFACTS block (the pattern docs_test.sh already follows) rather
  than trusting the prose to match.

**AC9** — oracle: manual

- Close OPS-21 with a bare 'done' and add a migration item reading 'migrate the stale repos'
  carrying none of the survey's cargo — which repos, which generation each carries — so the
  entries exist (letter) but the closure rationale is lost and the work is no more actionable
  than before (intent). Check the entries against the survey's per-repo table, not for line
  presence.
- Write the migration item as a blanket 'overwrite all five with the new arrangement',
  destroying the two hand-maintained local files (~70 and ~95 lines, one edited three days
  before the survey) the survey flagged — repeating in manual form the silent destruction the
  story's problem statement measured.

**AC10** — oracle: gate (full suite)

- Write the AC5 'behavioral' test as an assertion on RunnerError's message text, or as a direct
  call into the getter — a wording pin wearing the behavioral suite's name: renaming the message
  fails it with behavior intact, and any unrelated RunnerError passes it with the guard never
  firing. Assert the observable behavior: the round stops, no artifact is written, and what
  surfaces names the migration.
- Leave isolation incomplete — the user-level path captured at import time, or a fixture
  reaching the developer's real ~/.claude — so the full gate passes on the author's machine
  because the real contract file exists, and fails (or worse, passes by luck) on a clean
  machine. Green must be demonstrated not to depend on real user state.

**AC11** — oracle: manual

- Respect the enumerated file list while smuggling a behavior-relevant change into reviews/ —
  the AC's own ':(exclude)reviews/' carves a hole in its check, so the letter (nothing beyond
  the list outside reviews/) passes while workflow behavior changes inside the blind spot. The
  manual check must eyeball reviews/ as well.
- Create workflow-AGENTS.md fresh and delete AGENTS.md instead of renaming: the touched-path
  list still matches AC11 exactly, but the intent — a maintained document moving house, history
  preserved, the diff reviewable as a move plus edits — is lost. Verify the diff shows a rename,
  not an add-delete pair.

## Fireworks design review (2026-08-05)

**Verdict:** "The core move is right: one home beats five sync mechanisms, and renaming the source so
`AGENTS.md` means exactly one thing estate-wide is the enabling simplification. The test plan's
computed-extents discipline (ARTIFACTS-derived, PASSES-derived, both-directions guard fixtures)
matches the repo's own doctrine. Three shape concerns, in leverage order…"

Smaller notes from the verdict, not raised as findings: the `assemble_context` trap the sketch works
around (`FileNotFoundError` raised regardless of the `optional` flag) deserves **the one-line central
fix** — let `optional` absorb it into stated absence — rather than a per-getter workaround every
future context source must rediscover; and on open question 3, **delete** this repo's `AGENTS.md`,
since an empty self-explaining stub is instruction weight with no content.

### BLOCKER

- **Migration guard exists only on the fireworks path; codex still receives both contracts** ·
  two-way × standard · *locus: Design sketch — 'Migration guard'; AC5*
  The guard lives in `contract_local`'s getter in `fireworks_runner.py`. But codex is wired today,
  this story edits four codex prompts, and codex **auto-reads** the repo's `AGENTS.md` with no runner
  involved. In a stale repo a codex-routed review therefore auto-reads the stale full contract and is
  *then* handed the user-level contract by the prompt — two contracts that may contradict, silently
  reconciled by the model, which is verbatim the failure AC5 exists to prevent.
  **Alternative:** hoist stale-copy detection to the layer that invokes both backends — an explicit
  preflight in `review/SKILL.md` and `frame/SKILL.md`, run before either backend — and keep the
  runner-side `RunnerError` as a backstop for direct runner invocation.
  **Win:** one cheap preflight covers every pass on every backend, instead of a guard that protects
  half the wired surface and gives no signal about the other half.

### IMPORTANT

- **Resolve open question 1 to push-by-default: interpolate the contract into codex prompts** ·
  **one-way** × standard · *locus: Open question 1 / Design sketch — 'Codex'; AC6*
  Pull-from-path has **two** independent silent failure modes, not one: sandbox scoping (what the
  probe tested) *and* the model simply not performing the read — which AC6 already concedes has no
  CI-safe oracle. Even with the probe passing, every codex review still depends on unverifiable
  instruction-following for its most important input, and a contract-free review surfaces nothing.
  **Alternative:** interpolate via `"$(cat "$HOME/.claude/workflow-AGENTS.md")"` — the same *push*
  the fireworks runner already performs — keeping a one-line path mention for provenance.
  **Win:** deletes both silent failure modes by construction, retires AC6's untestable obedience
  check, unifies both backends on one delivery pattern, and bakes the exact contract text into the
  logged prompt — covering most of open question 2's reproducibility want for free.

- **Stale-copy detection by 'distinctive phrase' rots silently and misses the surveyed generations** ·
  two-way × kludgy · *locus: Design sketch — 'Migration guard'*
  The detector is a magic string from a **living** document (the hidden-failure bullet entered
  2026-07-15; OPS-23 will edit it again), so it will drift and then fail silent. Worse, it cannot
  match the measured population: a phrase from the current header is **absent from the two oldest
  copies**, which open with "You are Codex" — so the guard waves through precisely the stalest repos
  during the migration window it exists for.
  **Alternative:** a stdlib `difflib.SequenceMatcher` similarity test against the deployed contract,
  thresholded against the survey's five specimens.
  **Win:** no sentinel to maintain in lockstep with a living contract, catches all three surveyed
  generations, and cannot silently die on the next contract edit. Zero new dependencies.

### On the assigned oracles (verdict-level critique)

- **AC4's PASSES-derived extent is vacuous** — drawn from the implementation's own table, so it
  cannot fail for a pass living outside `PASSES`. Anchor the expected set to the skill invocations
  instead. *(I flagged this risk myself in the Test notes; the reviewer confirms it and names the
  fix.)*
- **AC6's pins are file-level presence tokens** — make them per-site, and pair each with an
  absence-pin for the superseded instruction.
- AC1/2/3/5/7/10 derive from authoritative sources or behaviour and can genuinely fail; AC8/9/11 are
  honestly manual.

## Design decisions (2026-08-05)

Scope approved by Thomas: **"yes that matches, approved — fix all three findings."** The approval
followed a plain-language walkthrough of the end state (rulebook names, storage locations, how each
backend consumes them, how local add-ons are stored and used, and the migration path); that
walkthrough is the approved shape, and this story is bound to it.

- **BLOCKER (guard covered only one backend) → fix.** Detection moves to a preflight in both skills,
  running before either backend is invoked; the runner keeps its own check as a backstop. The
  finding was correct on the facts: codex auto-reads a repo's `AGENTS.md` with no runner involved,
  so a runner-only guard could never see the codex path — the half of the wired surface where the
  two-contradictory-rulebooks failure actually lands. (AC5)
- **IMPORTANT, one-way (pull-from-path vs. push) → fix; ratified as the cross-cutting pattern.**
  Codex prompts now carry the contract **inline**. This **supersedes my own empirical probe**, and
  correctly: the probe proved codex *can* read `~/.claude`, but that only closed one of two silent
  failure modes. The second — whether the model actually performs the read — has no CI-safe oracle
  by AC6's own admission, and a contract-free review is indistinguishable from a good one. Pushing
  removes both modes by construction. Ratified by Thomas as the pattern all four prompt sites and
  every future prompt will copy. (AC6)
- **IMPORTANT (sentinel-phrase detection) → fix.** Replaced with a stdlib `difflib` similarity
  measure. The decisive evidence was concrete rather than theoretical: a phrase taken from the
  current contract header is **absent from the two oldest surveyed copies**, which open with "You
  are Codex" — so the original detector would have waved through precisely the repos it existed to
  catch. (AC5)
- **Verdict-level note (AC4's oracle was vacuous) → fix.** The pass list is anchored outside the
  runner's own `PASSES` table. I had flagged this risk in the Test notes myself; the reviewer
  confirmed it and named the fix. (AC4)
- **Verdict-level note (`assemble_context` optional-input trap) → fix centrally.** `optional` now
  absorbs a missing file into stated absence, rather than each getter rediscovering the workaround.
  (AC3)
- **Open question 1 (can sandboxed codex read outside the workspace?) → resolved, then made moot.**
  Answered empirically before the consult — it **can** (it ran `sed` against `~/.claude/` under
  `-s read-only` and returned the content). Recorded because it was a real unknown, and superseded
  because the push decision removes the dependency entirely.
- **Open question 2 (record which contract judged each review) → dropped.** Interpolating the
  contract into the prompt puts the exact text in the logged prompt, which covers the reproducibility
  want without new machinery. Confirmed as part of the approved walkthrough.
- **Open question 3 (delete this repo's `AGENTS.md`) → delete.** Both the reviewer and I leaned
  this way, and the approved walkthrough lists it explicitly. An empty file existing only to explain
  itself is instruction weight with no content.

**Regression list: accepted in full, no amendments.** 24 reviewer-authored regressions across all 11
criteria, no coverage gaps. This is the first story to run under the mechanism OPS-20 shipped, so it
is **loop 1 of the 5-loop OPS-22 lookback**; the evidence for that lookback starts here.

### Demonstrate-red record (2026-08-05, at implementation)

Each `gate`-oracle regression from the ratified list was applied to the real code, the gate run, the
named check observed failing, and the change reverted.

| Ratified regression (reviewer's wording, abbreviated) | AC | Mutation applied | Result |
|---|---|---|---|
| "never check 'empty' for a required source… an empty contract could assemble a review against nothing" | AC2 | mark `contract` `"optional": True` | **10 checks red** ✓ |
| "let the guard exist only in the fireworks runner" / exact-match detection | AC5 | raise the similarity limit to 99.0 (guard can never fire) | **4 checks red** ✓ |
| "declare both inputs on every pass… while one pass never interpolates contract_local" | AC4 | drop `contract_local` from the design pass | **1 check red** ✓ |
| "emit the stated-absence line correctly… but wire the present-branch to a wrong path" | AC3 | delete the stated-absence branch so an optional source is silently omitted | **3 checks red** ✓ |
| "leave install.sh deploying… assert the template entry is gone from ARTIFACTS" | AC1 | point ARTIFACTS back at a destination named `AGENTS.md` | **1 check red** ✓ |

**One mutation produced no failures, and the reason matters.** Making `_contract_local` *raise*
`FileNotFoundError` on an absent file changed nothing — because AC3's central fix has
`assemble_context` absorb exactly that into stated absence for any `optional` source. It is an
**equivalent mutation**, not a dead assertion: the two code paths are behaviourally identical by
design, which is what the central fix was for. The real regression for that criterion is removing
the stated-absence branch itself, applied above, and it goes red.

**A check strengthened rather than reshaped.** Two existing assertions compared the payload against a
hand-typed token list (`"AGENTS.md"`, `"story file"`, …) and broke on the renamed context titles. The
honest fix was not to swap in new strings — that is the reshape-to-pass this loop forbids — but to
**derive the expectation from each pass's declared inputs**. The rewritten checks are strictly
stronger: they now cover every declared source including `contract_local`, and both of them caught
the AC3 regression above, which the hand-typed version could not have seen.

## Build note (2026-08-05)

AC → file map:

| AC | Files |
|---|---|
| 1 — one source, deployed once | `AGENTS.md` → `workflow-AGENTS.md` (git rename, history preserved); `install.sh` ARTIFACTS |
| 2 — shared contract required, from the user-level path | `fireworks_runner.py` (`CONTRACT_PATH` module constant + the `contract` source) |
| 3 — repo file optional, absence stated; central fix | `fireworks_runner.py` (`_contract_local`, and `assemble_context`'s optional/FileNotFoundError branch) |
| 4 — both inputs on every pass | `fireworks_runner.py` (four `"context"` declarations) |
| 5 — migration guard, both backends | `fireworks_runner.py` (similarity limit, `check_local_contract`, `--check-local-contract`); `frame/SKILL.md` step 1; `review/SKILL.md` step 1 |
| 6 — contract pushed inline to codex | `frame/SKILL.md` (design prompt); `review/SKILL.md` (approach, correctness, hidden-failure prompts) |
| 7 — no contract bootstrap | `frame/SKILL.md` step 1 |
| 8 — docs follow | `.claude/workflow-protocol.md`, `README.md`, `ARCHITECTURE.md`, `install.sh` (closing hint) |
| 9 — backlog | `BACKLOG.md` (OPS-21 closed, OPS-25 filed) |
| 10 — behavioural coverage | `tests/fireworks_runner_test.py` (+22 checks, 113→135), `tests/reviewer_test.sh`, `tests/check_contract_wiring.py` |
| 11 — scope containment | no files — verified by `git diff --name-only` |

Also in this diff, from Thomas's codex-reference sweep: two write-back headings in `review/SKILL.md`
de-hardcoded to `## <Backend> …` (the sibling of a fix `/frame` received last story), and `README.md`'s
role prose neutralised per the 2026-06-27 decision to keep the headline brand and neutralise only
role prose.

## Fireworks approach review (2026-08-05, base main, HEAD b7301cc)

*Process note: this branch removes the per-repo `AGENTS.md` the **deployed** runner still requires,
so the deployed reviewer cannot review it. Rather than `./install.sh` unreviewed skills estate-wide,
this round ran the **branch's own** runner and deployed only the shared contract **data** file
(additive; no deployed skill was overwritten). The new mechanism reviewing itself is the honest test,
and it is recorded here rather than presented as an ordinary round.*

**Verdict:** "The shape is sound. The core move — one home for the contract, no copies — is the right
answer to the measured problem, and the implementation follows through with minimal machinery…
Nothing reinvents a dependency or over-engineers the problem. Three findings, all the same root
cause: the rename freed `AGENTS.md` to mean 'local add-ons only,' but several references to
`AGENTS.md` *as the contract* were not updated when that meaning changed. The codex prompts were
updated; the fireworks prompts, the README's deploy instructions, and the contract file's own header
were not."

### IMPORTANT

- **Fireworks runner prompts still reference 'AGENTS.md' as the contract** · two-way × nonstandard ·
  *locus: `fireworks_runner.py` PASSES table, all four prompts*
  All four still say "per AGENTS.md" and "guardrails from AGENTS.md". After this story that file is
  the **local add-ons**, not the contract. The codex prompts were updated; these were not, so the two
  backends frame the same material differently. In a repo with no `AGENTS.md` — the normal case —
  the fireworks reviewer is told to apply guardrails from a file that does not exist. Sharpest
  instance: the hidden-failure prompt scopes the critic to "AGENTS.md's 'Hidden failure' bullet",
  which now lives in the shared contract, not the file it names.
  **Alternative:** say "the shared reviewer contract" throughout the four prompts, matching the
  context titles the runner already uses.
  **Win:** both backends tell the reviewer to work per the contract it actually receives.

- **README's deploy section still says `/frame` bootstraps `AGENTS.md`** · two-way × dated ·
  *locus: `README.md` → "Test here, then deploy everywhere" step 3; AC8*
  The earlier README sections were updated; this one was not. `install.sh`'s parallel hint **was**
  fixed, so the two now disagree. **This is verbatim the regression the design pass predicted for
  AC8**: *"add a 'the contract is global now' passage to each of the three docs while leaving
  old-arrangement procedures elsewhere in the same files."*
  **Alternative:** match `install.sh`'s updated wording.
  **Win:** the file stops contradicting itself, and the instructions a new user follows match the tool.

### NIT

- **`workflow-AGENTS.md`'s own H1 still reads "# AGENTS.md — independent reviewer contract"** ·
  two-way × dated · *locus: line 1*
  The rename is the enabling move of the story; the title inside the file still announces the old
  name — in a story whose entire point is that `AGENTS.md` no longer means this file.
  **Alternative:** "# The shared reviewer contract", matching the title the runner pushes.
  **Win:** the file's title agrees with its name and with the label the reviewer receives.

## Decisions (2026-08-05)

Round 1 — approach pass returned three findings, one root cause. Thomas decided all three; no
redesign, so the correctness pass runs this same round per `review/SKILL.md` step 7's gate.

**Approach**

- **IMPORTANT — fireworks prompts still referenced `AGENTS.md` as the contract** → **fix**, as
  proposed. Thomas: *"just fix finding 1 as you suggest; no guard added."* The references in the four
  pass prompts now point at **the contract the reviewer was handed**, naming no file at all: `per the shared reviewer contract above`, `guardrails from that contract`, and — the sharpest
  instance — `that contract's 'Hidden failure' bullet`, which had reintroduced in a new place the
  exact dangling-reference defect this story exists to remove. Phrasing chosen so a future rename
  cannot break it again: the prompts describe the *role* of the material, not its filename.
- **IMPORTANT — README's deploy step still promised `/frame` bootstraps `AGENTS.md`** → **fix.**
  Now matches `install.sh`'s hint. This finding was **predicted verbatim by the design pass** before
  any code existed (AC8's regression: *"a 'the contract is global now' passage… alongside
  old-arrangement procedures in the same files"*), and I committed exactly that defect anyway.
- **NIT — `workflow-AGENTS.md`'s own H1 announced the old filename** → **fix.** Now
  `# The shared reviewer contract`, matching the title the runner pushes.

**A guard was offered and declined.** I proposed a check banning contract-framing phrases in the
pass prompts so this class cannot silently recur. Thomas: *"no guard added."* Recorded with its
accepted cost: recurrence is caught by the reviewer, which did catch it this round, and not by the
gate. The counter-argument that lost — such a check cannot distinguish a legitimate future mention
of the local-add-ons file from the bug — stands on the record rather than being re-litigated later.

### Correction to the record (2026-08-05, round 2)

**The paragraph above originally claimed "All five references in the four pass prompts now point at
the contract." That was false when written.** Four were fixed; the correctness pass's prompt still
read *"the independent reviewer defined in AGENTS.md"* and was missed. The wording has been
corrected above and the fifth reference fixed in round 2. The false claim is recorded here rather
than quietly erased — an audit trail that silently rewrites a wrong statement is worth less than one
that shows the correction.

**Why my own verification did not catch it.** I checked the prompts for three phrasings — `per
AGENTS.md`, `from AGENTS.md`, `AGENTS.md's` — and reported "none — all four prompts reference the
contract, not a filename." *"defined in AGENTS.md"* is a fourth phrasing, so that check could not
have failed on the defect that was actually present. It is a dead assertion in the precise sense
this repo's doctrine names, written in the same session that wrote the doctrine into a spec. The
replacement check counts **every** occurrence of the string in every pass prompt and asserts zero,
which cannot be evaded by rephrasing.

**What the reviewer actually caught.** Not just the code — the **discrepancy between the code and
the claim in this file**. It read the Decisions record, read the prompts, and reported that they
disagreed. That is a capability a diff-only check does not have.

**Bearing on the declined guard.** The argument for skipping the anti-recurrence guard was "the
reviewer catches recurrence." It did — but only after the defect *and* a false statement about
having fixed it were both committed. Recorded as evidence for OPS-22's lookback, not as grounds to
reopen a decision Thomas made.

## Decisions (2026-08-05, round 2)

Correctness returned one IMPORTANT; hidden-failure returned none.

**Correctness**

- **IMPORTANT — the correctness prompt still said "defined in AGENTS.md"** → **fix.** Thomas: *"fix
  it and correct the record."* Applied, and this time verified by counting **every** occurrence of
  the string in **every** pass prompt and asserting zero — not by testing the three phrasings I
  happened to think of. See *Correction to the record* above for why the first verification could
  not have failed.

**Hidden-failure** — no findings. Its summary is recorded because it *confirms* design decisions
rather than merely finding nothing: the central `assemble_context` fix "correctly surfaces
missing-file errors for optional sources (previously swallowed by a bare raise of the required-only
message)"; the new guard "fails closed — it raises `RunnerError` on stale copies and any `OSError`
reading the local file"; and the possibly-absent `CONTRACT_PATH` read "safely falls through to `''`
and does not compare; the required `contract` source will independently fail the round." That is the
reasoning written into the code comments, verified by a second head rather than asserted by its
author.

**Filed at Thomas's instruction, outside this story's ACs** — logged rather than folded in silently:
`BACKLOG.md` **OPS-26**, *"A dependency rejection must name its cost"*, in his words. One note added
on top of his text: his AC5 (reaching repos that already hold a contract copy) is **largely
dissolved by this very story** — once the contract is shared rather than copied, an amendment
reaches every repo on the next `./install.sh`. What survives is a **sequencing** requirement: build
OPS-26 after this ships and after the OPS-25 migration, or it inherits the staleness its AC5 names.
