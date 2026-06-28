Date: 2026-06-27 · Branch: claude/pluggable-reviewer · Status: approved

# pluggable-reviewer — make the independent reviewer selectable (codex | agy)

## Problem

The system hardwires **Codex** as the independent reviewer. It is named or invoked in three
call sites — `/frame` (design review of the sketch), `/review` approach pass, `/review`
correctness pass — plus `codexModel` in `.claude/workflow.json`, "You are Codex…" prompt
preambles, and "Claude↔Codex" branding across the docs. Thomas wants to be able to use
**antigravity (`agy`)** as an alternative reviewer.

This story does **not** wire agy. It lands the *seam*: a tool-neutral notion of "the independent
reviewer," selectable per-repo and per-invocation, with **codex as the only wired backend**.
agy is a follow-up (see Non-goals), because research shows agy is materially different from codex
and cannot be integrated as a flag swap.

### What the research found (why this is a seam, not a rename)

`agy` exists and has a non-interactive `agy -p "<prompt>"` mode, `--model`, and auto-reads
`AGENTS.md`. But versus `codex exec` it has three hard gaps:

| Need (codex) | agy today | Consequence for the seam |
|---|---|---|
| `-s read-only` file sandbox | **none** (sandbox isolates only terminal/network) | read-only must be a per-backend *guarantee*, not a shared flag |
| `--output-schema` (schema-valid JSON) | **none** — prose only | a backend must *produce* schema-valid JSON however it can (codex natively; agy later via prose→JSON) |
| `-o <file>` + `</dev/null` | stdout only; non-TTY can drop output → needs PTY (`script -qec …`) | output capture is per-backend, not shared |

So the seam's contract is **inputs** = (which pass, schema, output path, prompt) → **guarantees**
= (read-only execution, schema-valid JSON at the output path), with the *how* owned by each
backend. A naive "just change `codex` to `agy`" would silently lose read-only safety and structured
output. Sources captured in `## Research notes` below.

## In scope

- Add a **`reviewer`** selector to `.claude/workflow.json` (`"codex" | "agy"`, default `"codex"`).
- Add a **per-invocation override** on `/review` (e.g. `/review agy`, `/review codex`) that beats the
  config default and composes with the existing `approach` / `correctness` bare-args.
- Make the three reviewer call sites refer to "the configured reviewer / independent reviewer"
  rather than hardcoding Codex, with **codex behavior byte-for-byte preserved**.
- Selecting `agy` **fails loudly** ("agy backend not yet wired — follow-up story") — never a silent
  half-run or a wrong-but-quiet result.
- Neutralize **role language**: prompt preambles and docs say "the independent reviewer" for the
  *role*; "codex" stays only where the *specific tool* is meant.
- Keep the existing artifact filenames (`reviews/<slug>.codex.json`, `.approach.json`, `.design.json`)
  this story (see Open questions).

## Non-goals

- **Wiring the agy backend** (PTY wrapper, prose→JSON normalization, read-only-via-throwaway-worktree,
  auth) — a separate follow-up story once agy's shape is pinned. This story only ensures the seam can
  accept it.
- Adding any agy-specific config keys (e.g. `agyModel`) — they land with the agy backend.
- Renaming existing review artifacts or migrating the historical `reviews/*.codex.json` trail.
- Changing the gate, the hook, or the three human gates.

## Acceptance criteria

1. `.claude/workflow.json` supports a `reviewer` field with values `codex` | `agy`; a **missing or
   empty** field resolves to `codex` (back-compat for every existing repo).
2. `/review` accepts a bare-arg reviewer override (`codex` | `agy`) that beats the config default and
   composes with `approach` / `correctness` (e.g. `/review approach agy`); an invalid value is rejected
   with a clear message, not silently ignored.
3. All three reviewer invocations (`/frame` design review, `/review` approach, `/review` correctness)
   resolve the backend through the selector rather than naming `codex` unconditionally. `/frame` and
   `/close`-time re-review use the config default (no per-invocation override surface there — deliberate).
4. With `reviewer` = `codex` (or unset), every reviewer run preserves the **codex command envelope**:
   `codex exec -s read-only --output-schema <abs> -o <repo-rel> ${codexModel:+-m …} … </dev/null` — same
   flags, absolute-schema / repo-relative-`-o` split, `${codexModel}` handling, artifact names, and
   `</dev/null` guard. The **prompt body** is explicitly excluded from this invariant (its role wording
   changes under AC6).
5. With `reviewer` = `agy`, the skill **stops with a clear, actionable message** naming this story as the
   follow-up that wires it — no codex fallback, no partial run, no empty/garbage artifact written.
6. Reviewer **role** language is tool-neutral: prompt preambles read "You are the independent reviewer…"
   and the docs (`ARCHITECTURE.md`, `README.md`, `.claude/workflow-protocol.md`, `AGENTS.md`) describe the
   role neutrally, retaining "codex" only where the concrete tool/CLI is meant. The "Claude↔Codex"
   branding decision is recorded (see Open questions), not silently changed.
7. **Scope containment:** the diff touches only the files this story enumerates, **plus** the workflow's
   own `reviews/pluggable-reviewer.*` trail artifacts (the story file + the design/approach/correctness
   JSON the loop writes), which are exempt — they are produced by `/frame` and `/review`, not product code.

## Test notes

- **AC1:** gate asserts **observable** resolution against fixtures — a `workflow.json` with no
  `reviewer` resolves to `codex`; `"agy"` resolves to `agy`; an invalid value errors. The seam stays in
  the skills (no deployed resolver helper); the gate proves the *rule*, not an internal unit.
- **AC2:** gate asserts override precedence (`/review agy` over a `codex` config) and arg composition
  (`approach agy` parses to {pass: approach, reviewer: agy}), order-independent; invalid override rejected.
- **AC3/AC4:** confirm the codex command **envelope** in `review/SKILL.md` is unchanged — the flags,
  the absolute-schema / repo-relative-`-o` split, `${codexModel:+…}`, the artifact names, and `</dev/null`
  all still present and unaltered. The prompt body is *not* part of this compare (AC6 changes its wording).
- **AC5:** with `reviewer=agy`, the resolver/guard returns the "not wired" stop; assert no `*.json`
  artifact is created on that path.
- **AC6:** grep the prompt preambles and docs — role mentions are neutral; remaining literal "codex"
  occurrences are tool-specific (the CLI command, the `codexModel` key, the `.codex.json` filename).
- **AC7:** `git diff --name-only main...HEAD` shows nothing beyond the Design-sketch file list plus the
  `reviews/pluggable-reviewer.*` trail artifacts. The gate enforces this whitelist, **self-limited** to
  this story's branch (it only runs when the story file is in the diff), so it is a no-op on other
  branches and after merge — a permanent gate can't carry a per-story whitelist otherwise.

## Open questions

> **All resolved at the 2026-06-27 frame consult — see `## Design decisions` below.**


1. **Seam mechanism — the central one-way-door (see Design sketch).** Light seam (config + neutral
   prose + a documented backend extension point, *no new script*) vs. heavy seam (a
   `.claude/lib/run-reviewer.sh` dispatcher now). I **recommend the light seam** — building dispatch
   machinery for a single backend, before agy's real shape (PTY, prose→JSON) is known, risks building
   the wrong adapter; the agy story should drive it. Needs your ratification.
2. **Artifact filenames.** Keep `reviews/<slug>.codex.json` (tool-named; will read oddly for an agy run)
   or move to a neutral `.review.json` now? Recommend **keep** this story — renaming churns the trail,
   breaks `/review` + `/close` references, and is reversible later. Decide when agy lands.
3. **"Claude↔Codex" branding.** Skill `description:` lines and docs say "Claude↔Codex review loop."
   Generalize to "Claude↔reviewer" / "independent-reviewer loop," or leave the brand and only neutralize
   role prose? Recommend **leave the headline brand, neutralize role prose** (minimal churn).
4. **Override surface.** Confine the per-invocation override to `/review` (recommended), or also expose it
   on `/frame`'s design review? `/frame` is invoked with a free-text request, so a bare-arg reviewer there
   is awkward — recommend config-only for frame.

## Design sketch — HOW

**Recommended: the light seam.** Establish *where* the reviewer is chosen and make the coupling
tool-neutral, without building dispatch machinery for a backend that doesn't exist yet.

1. **Selector resolution (one place).** A small, inspectable resolver: `reviewer =
   override-arg ?? workflow.json.reviewer ?? "codex"`, validated against `{codex, agy}`. It is the single
   unit the gate tests (AC1/AC2). Where it lives depends on Q1: in the light seam it's a documented
   resolution rule the skills follow, pinned by a tiny gate helper; in the heavy seam it's a function in
   the dispatcher script.
2. **`/review` arg parsing.** Extend the existing bare-arg handling (`approach` | `correctness`) to also
   recognize a reviewer token (`codex` | `agy`), order-independent, so `/review approach agy` works.
3. **Backend selection at each call site.** At the three invocations, the skill resolves the backend, then:
   - **codex** → emit today's exact `codex exec …` command (unchanged — AC4).
   - **agy** → STOP with the "not yet wired, see reviews/pluggable-reviewer.md follow-up" message (AC5).
   The codex command's hard-won rationale (`</dev/null`, abs-schema / rel-`-o` split, "not the `review`
   subcommand") stays documented in `review/SKILL.md` as the codex backend's notes.
4. **Tool-neutral role language.** Prompt preambles: "You are the independent reviewer per AGENTS.md…"
   (`AGENTS.md` is already neutrally named and stays the contract). Docs describe the *role* neutrally;
   literal "codex" remains for the CLI, the `codexModel` key, and the `.codex.json` artifact.
5. **Config + docs.** Add `reviewer` to `.claude/workflow.json` (default `codex`) and document it in
   `ARCHITECTURE.md §3.3`/§3.4 and `README.md`. `codexModel` stays (codex-specific).
6. **Gate.** Extend `tests/guard_test.sh` (or a sibling test) to cover: default→codex, override precedence,
   arg composition, invalid→error, and agy→loud-stop.

**Alternative (heavier): the dispatcher script.** `.claude/lib/run-reviewer.sh` taking
`(schemaAbs, outRel, prompt)` + `$REVIEWER`, with a codex backend (thin passthrough) and an agy stub; the
three skills call it; `install.sh` deploys + drift-checks it. Centralizes divergence in one file — but
introduces a new `lib/` script pattern (a cross-cutting precedent, against the system's deliberate
"one hook, no script suite" minimalism), and the agy half can't be finalized until agy's shape is known,
so most of its value is deferred regardless. Presented for the design decision; **not** recommended now.

## Codex design review (2026-06-27)

**Verdict:** The light seam is the right shape for this repo. A dispatcher now would add a new
deployed lib/script pattern, install-drift surface, and adapter contract *before* agy's constraints
are known — conflicting with the deliberate one-hook/no-script-suite minimalism. Deferring it does
not create a worse seam *as long as the codex branch stays exact and agy fails loudly*. Sketch is
sound; two AC/test-note tightenings needed so the story doesn't accidentally force the heavy seam or
an impossible golden test.

**IMPORTANT · one-way · kludgy — "Callable resolver requirement smuggles in the heavy seam"**
(`reviews/pluggable-reviewer.md` test notes). The light seam says the selector is a documented rule
the skills follow, but the AC1 test note demands a "callable/inspectable unit." In a Markdown-skill
repo a test-only resolver wouldn't prove the skills use it, and a *deployed* helper would establish
the very script/lib precedent the design avoids.
- *Alternative:* keep the runtime seam in the skills; document the resolver rule once in the skill
  instructions, have each call site branch codex vs agy, and let the gate assert **observable**
  artifacts/text fixtures (default→codex, reviewer-token parsing examples, agy STOP text, unchanged
  codex command envelope). Save a real shared resolver/dispatcher for the agy story.
- *Win:* no dead test helper, no new deployed script pattern, while still proving the safety
  invariant (no silent agy fallback, no changed codex invocation).

**QUESTION · two-way · standard — "Byte-for-byte codex preservation conflicts with neutral prompt prose"**
(`reviews/pluggable-reviewer.md` AC4 vs AC6). AC4 asks for a character-equivalent codex command while
AC6 intentionally changes the prompt preamble to neutral language; a golden compare that includes the
prompt string makes the ACs fight.
- *Alternative:* define AC4 as preserving the codex command **envelope** (`-s read-only`, absolute
  schema path, repo-relative `-o`, `${codexModel}`, artifact names, `</dev/null`) and artifact
  semantics — excluding the prompt body, whose wording change is AC6.
- *Win:* removes the test/impl ambiguity without weakening the regression guard on the fragile flags
  and path split.

**Files this story expects to touch (scope containment, AC7):**
- `.claude/skills/frame/SKILL.md` — design-review call site → neutral; backend resolution note.
- `.claude/skills/review/SKILL.md` — approach + correctness call sites; arg parsing; codex-backend notes.
- `.claude/skills/close/SKILL.md` — role-language neutralization (re-review reference).
- `.claude/workflow.json` — add `reviewer` (default `codex`).
- `.claude/workflow-protocol.md`, `ARCHITECTURE.md`, `README.md`, `AGENTS.md` — neutral role language + doc the selector.
- `tests/guard_test.sh` (and/or a sibling test file) — selector + override + agy-stop coverage.
- *(heavy-seam only — NOT chosen)* `.claude/lib/run-reviewer.sh` + `install.sh` — deploy/drift the dispatcher.

## Design decisions (2026-06-27)

Thomas approved scope and design in one pass — *"love it, do it."* The approved shape below is binding
on implementation.

- **Scope:** approved as written (selector + override + neutral role language; **codex the only wired
  backend**; agy a follow-up).
- **One-way door — seam mechanism:** ratified the **light seam**. No `.claude/lib/run-reviewer.sh`
  dispatcher this story; the seam lives in the skill instructions. (Codex's design review concurred.)
- **Codex finding 1** (callable-resolver smuggles the heavy seam) → **FIX:** AC1/AC4 test notes now
  assert observable fixtures, not an internal resolver unit; the seam stays in the skills.
- **Codex finding 2** (envelope vs neutral prose) → **FIX:** AC4 scoped to the codex command envelope,
  prompt body excluded.
- **Artifact filenames** → **keep** `.codex.json` / `.approach.json` / `.design.json` this story.
- **"Claude↔Codex" branding** → **leave the headline brand**; neutralize only role prose.
- **Override surface** → **`/review` only**; `/frame` and `/close`-time re-review use the config default.

## Build note (2026-06-27)

AC → files:
- **AC1** (config `reviewer` + missing⇒codex rule): `.claude/workflow.json`, `.claude/skills/review/SKILL.md` (*Reviewer backend*), `tests/reviewer_test.sh`.
- **AC2** (`/review` override, composes/order-independent/invalid-errors): `.claude/skills/review/SKILL.md` (step 5).
- **AC3** (three call sites dispatch by backend): `.claude/skills/frame/SKILL.md` (step 6), `.claude/skills/review/SKILL.md` (steps 6, 8).
- **AC4** (codex envelope preserved): `.claude/skills/review/SKILL.md`, `.claude/skills/frame/SKILL.md` (commands unchanged but for the neutralized prompt body).
- **AC5** (agy loud stop, no fallback/artifact): `.claude/skills/review/SKILL.md` (*Reviewer backend*), `.claude/skills/frame/SKILL.md` (step 6).
- **AC6** (neutral role language): `.claude/skills/review/SKILL.md`, `.claude/skills/frame/SKILL.md`, `.claude/skills/close/SKILL.md`, `AGENTS.md`, `README.md`, `ARCHITECTURE.md`, `.claude/workflow-protocol.md`.
- **AC7** (scope containment): verified — diff touches only the files above.

## Codex approach review (2026-06-27, base main, HEAD 5ccbb28)

**Verdict:** CLEAN — no approach-level concerns. *"I would satisfy the ACs with the ratified light
seam: add `reviewer` to config, document one selector rule in `review/SKILL.md`, parse `/review`
pass/reviewer bare args order-independently, branch at the existing reviewer call sites, preserve the
codex command envelope, and make `agy` a loud stop until its backend can guarantee read-only and
schema-valid output. That is the shape implemented here. It does not add a dispatcher, dependency, or
new deployed script pattern, and the added test is aligned with this Markdown-skill repo's convention
of guarding instruction fixtures rather than inventing runtime code."*

Findings: none. Shape blessed → proceeded to the correctness pass in the same round.

## Codex review (2026-06-27, base main, HEAD 0a48403)

**Summary:** The reviewer commands keep the codex envelope, but the branch has residual Codex role
language and the new gate has false-green gaps around AC1/AC2/AC4/AC7. (`tests/reviewer_test.sh` passes;
the full configured gate couldn't run in the read-only sandbox because `guard_test.sh` makes temp repos.)

**IMPORTANT findings (4):**
1. **AC6 — residual role language in `review/SKILL.md:3`** (the `description:` frontmatter still says
   "have Codex independently review the feature branch"). Role language, not a tool/CLI/file reference.
   *Fix:* neutralize the phrase (keep `codex exec`/`codexModel`/`.codex.json` and the brand); broaden the
   AC6 test beyond the exact `You are Codex` string.
2. **AC4 — `tests/reviewer_test.sh` false-green** (file-wide greps): the envelope check passes even if one
   command block drops `-s read-only` / `${codexModel:+…}` / `</dev/null` while another block still has the
   substring. *Fix:* assert the envelope **per command block** (approach, correctness, frame-design).
3. **AC1/AC2 — fixtures not exercised**: the test reads the live `workflow.json` and greps prose; it never
   asserts missing⇒codex, `agy`⇒agy, invalid⇒stop, override precedence, both token orders, or invalid
   override. *Fix:* add explicit assertions for each documented example.
4. **AC7 — scope whitelist untested**, and the branch diff includes `reviews/<slug>.*` story artifacts not
   in the enumerated list. *Fix:* add an AC7 check comparing `git diff --name-only main...HEAD` to the
   whitelist, exempting the workflow's own `reviews/<slug>.*` trail artifacts.

## Decisions (2026-06-27)

Approach pass: clean (no findings). Correctness pass — Thomas: **"fix all"** (all 4 IMPORTANT):
1. **AC6 residual role language** (`review/SKILL.md:3` description) → **FIX**: neutralize the role phrase
   (keep the `Claude↔Codex` brand + `codex exec`/`codexModel`/`.codex.json`); broaden the AC6 test.
2. **AC4 per-block envelope** → **FIX**: assert `-s read-only` / abs schema / repo-rel `-o` /
   `${codexModel:+…}` / `</dev/null` for each of the approach, correctness, and frame-design blocks.
3. **AC1/AC2 documented-example coverage** → **FIX**: assert each documented example (missing⇒codex,
   agy⇒agy, invalid⇒stop, override precedence, both token orders, invalid override). Stays grep-of-rule —
   no runtime resolver (honors design finding 1: don't build a deployed/test-only resolver unit).
4. **AC7 whitelist + trail exemption** → **FIX**: add a `git diff --name-only main...HEAD` whitelist check
   exempting the workflow's own `reviews/<slug>.*` artifacts; record that exemption in AC7.

Routed to `/close` to apply these fixes. (Not a merge decision — `/close` stops at its own merge fork.)

## Fixes (2026-06-27)

All 4 approved findings applied:
1. **AC6** — `review/SKILL.md:3` description neutralized: "have Codex independently review" → "have the
   configured independent reviewer review … (codex backend → `codex exec`)" (brand + CLI kept). Test
   broadened: now also asserts absence of "have Codex" and "Codex independently review".
2. **AC4** — `tests/reviewer_test.sh` now asserts the envelope **per fenced command block** via a
   `block_has` helper (approach / correctness / frame-design each checked for `-s read-only`, the right
   absolute schema, repo-relative `-o`, `${codexModel:+…}`, `</dev/null`). A flag dropped from one block
   can no longer be masked by another block's substring.
3. **AC1/AC2** — added an explicit reviewer→pass example (`/review agy approach`) to `review/SKILL.md`,
   and the test now asserts every documented example: missing⇒codex, value-set, invalid-config⇒stop,
   both precedence rungs, both token orders, reviewer-only, invalid-override-errors, and the agy STOP
   dispatch. (Still grep-of-documented-rule — no runtime resolver, per design finding 1.)
4. **AC7** — added a **self-limiting** scope-whitelist block to the gate: it runs only when the story
   file is in `git diff main...HEAD` (no-op on other branches / after merge) and exempts the
   `reviews/pluggable-reviewer.*` trail artifacts. AC7 + its test note updated to record the exemption.

Gate (`guard_test.sh && reviewer_test.sh`): green.

## Build note (2026-06-27, re-review round)

Correctness-only re-review of the approved fixes, base `0a48403` (last-reviewed SHA) → HEAD. Delta:
- `.claude/skills/review/SKILL.md` — AC6 description neutralized; reviewer→pass example added (fixes 1, 3).
- `tests/reviewer_test.sh` — per-block envelope helper, full documented-example coverage, self-limiting AC7 (fixes 2, 3, 4).
- `reviews/pluggable-reviewer.md` — AC7 + test-note exemption recorded.

## Codex review (2026-06-27, re-review, base 0a48403, HEAD 803783e)

**Summary:** The four promised fixes are substantively present and the gate passes, but the new AC7
guard can **false-green in checkouts without a local `main` ref**.

**IMPORTANT — AC7 whitelist silently skips when local `main` is absent** (`tests/reviewer_test.sh`):
the guard enforces only if `git rev-parse --verify -q main` succeeds; otherwise it takes the skip path
and reports OK. On a story-branch checkout with only `origin/main` (or a configured non-`main` base),
the scope check passes without comparing the diff — out-of-scope files could slip despite AC7 promising
a whitelist gate.
- *Suggestion:* resolve the base ref from `.claude/workflow.json` (`baseBranch`), accept `<base>` or
  `origin/<base>`; if the story file is in the diff but no base ref resolves, **fail loudly** instead of
  counting the check as ok.

## Decisions (2026-06-27, re-review round)

Thomas: **fix** the 1 IMPORTANT AC7-guard finding. → resolve base from `baseBranch` (accept `<base>` or
`origin/<base>`); refuse to false-green when no base ref resolves.

## Fixes (2026-06-27, re-review round)

AC7 guard hardened in `tests/reviewer_test.sh`: base ref is now read from `.claude/workflow.json`
(`baseBranch`) and resolved as `<base>` **or** `origin/<base>`; if no base ref resolves the check
**fails loudly** (`bad`) instead of taking a silent skip-as-pass path. Enforcement and the
"not-this-branch" skip are unchanged.

## Research notes

`agy` install: `curl -fsSL https://antigravity.google/cli/install.sh | bash` → `~/.local/bin/agy`.
Non-interactive: `agy -p "<prompt>"` (`--print`); `--model`; auto-reads `AGENTS.md`/`GEMINI.md`.
Gaps vs codex: no read-only file sandbox (`--sandbox` covers terminal/network only); no `--output-schema`
(prose only — `--output-format json` is cited by blogs but absent from the binary); no `-o` (stdout, and
non-TTY can silently drop the final response → PTY wrapper `script -qec 'agy -p …' /dev/null`); auth is
Google login only (no documented API key). Sources: antigravity.google/docs/{cli-install,cli-using,
cli-sandbox,cli-reference,cli-best-practices}; github.com/google-antigravity/antigravity-cli (CHANGELOG,
unverified org); antigravitylab.net headless-CI writeup. The Antigravity **SDK** is a likelier path for
schema-constrained output and is the follow-up's first investigation.
