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
7. **Scope containment:** the diff touches only the files this story enumerates.

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
- **AC7:** run `git diff --name-only main...HEAD` and verify no files appear beyond those enumerated in
  the Design sketch's file list.

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
