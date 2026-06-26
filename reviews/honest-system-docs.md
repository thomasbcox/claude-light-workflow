Date: 2026-06-25 · Branch: claude/honest-system-docs · Status: approved

## Problem

A fresh read-only pass surfaced two documentation-truthfulness defects:

1. **Guard docs overclaim what the hook blocks.** [README.md:46](../README.md) says the hook
   "blocks commits/pushes to **the base branch**." The hook
   ([block-main-writes.sh](../.claude/hooks/block-main-writes.sh)) actually only blocks when the
   **current branch** is a literal member of `{main, master}` (line 67), checked for `commit`
   (line 138) and `push` (line 134). It therefore does **not** cover:
   - a configured non-standard base branch (e.g. `trunk` from `.claude/workflow.json`) — the set is hard-coded, not read from config;
   - a target-refspec push from a feature branch (`git push origin HEAD:main`) — only the current branch is checked, not the destination ref;
   - `env git commit …` — `env` is not in the wrapper-strip set, so `seg[0] != "git"` and the segment is skipped;
   - nested shells (`bash -lc "git commit …"`) — the inner `git` is a quoted argument to `bash`, not a top-level git invocation.

   The README's "bypassing the hook still takes a diff-visible edit to it or settings.json" caveat
   *undersells* these gaps: several ordinary-looking commands slip through without touching the hook.

2. **Parent architecture doc reads as live doctrine.**
   [ai-dev-workflow-architecture.md](../ai-dev-workflow-architecture.md) says "This repo runs **AI
   Protocol v3**" (line 24) and "the custom Claude Code skill suite that drives development on this
   project" (line 3), and points at machinery that does not exist here (`docs/ai-protocol.md`,
   `/start-story`, dbt/DuckDB gates, `.github/workflows/test.yml`). The CHANGELOG records this as
   intentional parent-protocol material, but the document itself still claims to describe *this*
   repo, so a reader can't tell it apart from live doctrine.

Separately, the owner wants a single doc that describes what the **light** workflow actually is and
does — requirements through intended implementation — rather than leaving that scattered across the
README and inferred from skill files.

## In scope

- **Correct the guard overclaim in the docs** so they describe the hook's *actual* behavior: it
  trips on `commit`/`push` while you are *currently on* `main`/`master`, plus `--no-verify` and
  force-push; and it is a cooperative tripwire that does **not** catch configured non-standard base
  branches, destination-refspec pushes from a feature branch, `env`-wrapped, or nested-shell git.
  Touch points: [README.md](../README.md) Guardrail section, the header comment in
  [block-main-writes.sh](../.claude/hooks/block-main-writes.sh) (comment-only; no behavior change),
  and the **deployed source-of-truth** surfaces that `install.sh` ships to `~/.claude`:
  `.claude/workflow-protocol.md` rule 5, and the guard-enforcement parentheticals in
  `.claude/skills/frame/SKILL.md` and `.claude/skills/close/SKILL.md`. In those three, soften only the
  *enforcement attribution* — the rule "never commit/push to the base branch directly" stays (it is a
  rule Claude follows); the hook is described as a cooperative `main`/`master` tripwire, not as
  enforcement of the configured base branch. Historical CHANGELOG/backlog entries are left untouched.
- **Re-frame [ai-dev-workflow-architecture.md](../ai-dev-workflow-architecture.md) as historical /
  parent-only**: a prominent top banner stating it describes the heavier *parent* AI Protocol v3
  (not this repo), and correction of the inline first-person "this repo / this project" claims so
  they read as the parent system. Minimal edits — no rewrite of the body.
- **Add one design narrative for the light workflow** (`ARCHITECTURE.md` at repo root — see Open
  questions on placement): Requirements (the failure mode it designs against; who it's for) →
  Approach (build / critique / decide; the three decision altitudes; reversibility gating) →
  Intended implementation (the three skills, the one hook and what it really enforces, the
  `reviews/` + `BACKLOG.md` artifact trail, `install.sh` deploy, defer-to-native). Link it from
  the README.

## Non-goals

- **No hook hardening.** This story does *not* change `block-main-writes.sh`'s enforcement logic to
  honor the configured `baseBranch`, catch `HEAD:main` refspecs, `env`, or nested shells. "Fix the
  overclaim" here means *make the docs honest*, not *expand the guard*. Hardening is a separate,
  larger design question (tracked separately as an OPS item if the owner wants it).
- No change to skills, `install.sh`, `workflow.json`, schemas, or tests' behavior.
- No new CI / `.github` workflow.

## Acceptance criteria

1. The README Guardrail section no longer claims the hook blocks pushes/commits "to the base
   branch" in a way that implies the configured `baseBranch` or the destination ref. It states the
   current-branch `main`/`master` trigger, and explicitly names the categories it does **not** catch
   (configured non-standard base branch, destination-refspec push from a feature branch, `env`-wrapped, nested-shell).
2. The header comment of `block-main-writes.sh` matches AC-1's honesty: it states the current-branch
   `main`/`master` check and notes the non-caught categories. No executable line of the hook changes.
3. `ai-dev-workflow-architecture.md` opens with a clearly-marked banner identifying it as a
   historical description of the **parent** AI Protocol v3 (not this repo), and its inline
   "this repo runs / drives development on this project" claims are corrected to refer to the parent
   system. No reader can mistake it for this repo's live doctrine.
4. A design narrative for the light workflow exists and is linked from the README, covering
   Requirements → Approach → Intended implementation, and its description of the guard matches AC-1
   (no overclaim re-introduced).
5. The deployed source-of-truth surfaces no longer attribute base-branch *enforcement* to the hook:
   `.claude/workflow-protocol.md` rule 5 and the `frame`/`close` guard parentheticals describe it as a
   cooperative `main`/`master` tripwire (matching AC-1), while keeping the "never commit/push to base
   directly" rule intact. No skill *step* or executable instruction changes.
6. Scope containment: the diff touches only documentation/comment/prose surfaces — no change to any
   executable code path, skill step logic, hook enforcement, installer, config, schema, or test.

## Test notes

- AC-1/AC-4: read the rendered README Guardrail section and the new narrative; grep for the phrase
  "base branch" near the guard description and confirm it is qualified (current-branch main/master),
  and that the four non-caught categories are named. Cross-check each claim against
  `block-main-writes.sh` lines 67/127–139.
- AC-2: `git diff main...HEAD -- .claude/hooks/block-main-writes.sh` shows only comment lines (`#…`)
  changed; `bash -n .claude/hooks/block-main-writes.sh` passes; `bash tests/guard_test.sh` still
  passes 19/19 (behavior unchanged).
- AC-3: open `ai-dev-workflow-architecture.md`; confirm the top banner and that no remaining inline
  sentence asserts the file describes *this* repo as live.
- AC-5: read `.claude/workflow-protocol.md` rule 5 and the `frame`/`close` parentheticals; confirm
  each describes the hook as a cooperative `main`/`master` tripwire (no "enforces the base branch")
  while the underlying "don't commit/push to base directly" rule remains. Confirm no skill *step*
  numbering or executable instruction changed: `git diff main...HEAD -- .claude/skills/` shows only
  prose/parenthetical edits.
- AC-6 (scope containment): run `git diff --name-only main...HEAD` and verify no files appear beyond
  `README.md`, `ARCHITECTURE.md`, `ai-dev-workflow-architecture.md`, `.claude/hooks/block-main-writes.sh`
  (comment-only), `.claude/workflow-protocol.md`, `.claude/skills/frame/SKILL.md`,
  `.claude/skills/close/SKILL.md`, `reviews/honest-system-docs.md`, and `reviews/honest-system-docs.design.json`.
- Full gate: `bash tests/guard_test.sh`.

## Open questions

1. **Doc-only vs. hardening** — RESOLVED: docs-only. Hardening the hook (honor configured
   `baseBranch`, block `HEAD:main`, strip `env`, recurse into `bash -lc`) is deferred to a separate
   OPS story if desired.
2. **Placement of the new narrative** — RESOLVED: `ARCHITECTURE.md` at repo root.
3. **Fate of `ai-dev-workflow-architecture.md` long-term.** This story only re-frames it as
   historical. Whether it is eventually deleted / moved to `docs/history/` or kept at root is left
   for later (out of scope here).

## Design sketch — HOW

Pure documentation work; no code, dependency, or pattern changes.

- **README guard rewrite (AC-1):** replace the "blocks commits/pushes to the base branch" clause in
  the Guardrail section with an accurate two-part statement — (a) what it trips on: `commit`/`push`
  while currently on `main`/`master`, `--no-verify`, force-push variants; (b) what it does *not*
  catch, named explicitly. Keep the existing "cooperative guardrail, real backstop is server-side
  branch protection" framing but adjust it so it no longer implies editing the hook is the *only*
  bypass.
- **Hook header comment (AC-2):** edit only the `#` banner (lines ~1–20) to mirror AC-1's wording.
  The `BASE_BRANCHES = {"main","master"}` literal and all `deny(...)` logic stay byte-for-byte
  identical, so `guard_test.sh` is unaffected.
- **Historical banner (AC-3):** prepend a blockquote callout to `ai-dev-workflow-architecture.md`
  ("**Historical / parent reference.** This describes the heavier *parent* AI Protocol v3 … not this
  repository. For what this repo runs, see `ARCHITECTURE.md`."). Change the two first-person
  "this repo / this project" sentences (lines 3, 24) to name the parent system. Leave the rest as a
  faithful record of the parent.
- **New narrative (AC-4):** a single Markdown file structured Purpose/Requirements → Approach →
  Intended implementation, written from the actual artifacts in this repo (skills under
  `.claude/skills/`, the hook, `reviews/`, `BACKLOG.md`, `install.sh`, `.claude/workflow.json`,
  `workflow-protocol.md`). Its guard description reuses AC-1's honest wording. README gains one link
  to it.
- **Cross-cutting:** every guard description across the three docs must be consistent — single source
  of truth is the hook's real behavior, restated identically wherever the guard is mentioned.

## Design decisions (2026-06-25)

Thomas approved scope at the frame consult with all three recommendations:
- **Overclaim direction → docs-only.** Make the docs honest about the hook; do **not** change
  enforcement logic. Hook hardening deferred to a possible separate OPS story.
- **Codex IMPORTANT finding (deployed contracts overclaim) → FIX.** Expand scope to soften the
  guard-enforcement attribution in `.claude/workflow-protocol.md` rule 5 and the `frame`/`close`
  parentheticals (rule kept, hook described as a cooperative `main`/`master` tripwire). This shape is
  now binding on implementation.
- **New narrative location → `ARCHITECTURE.md` at repo root**, linked from the README.

## Codex design review (2026-06-25)

**Verdict:** The docs-only / no-hardening direction is sound and matches the repo's settled OPS-6
posture; the root live-architecture narrative is a reasonable shape. One scope gap: the sketch fixes
leaf-facing docs but leaves *deployed* live-protocol/skill surfaces with the same guard-enforcement
overclaim, so the truthfulness goal is incomplete.

**IMPORTANT** · one-way · kludgy — *Update the live protocol and skill guard claims too*
(`reviews/honest-system-docs.md:34`)
- **Claim:** The sketch corrects the README, hook header, and new narrative, but excludes the
  deployed live doctrine and skill instructions. `.claude/workflow-protocol.md` is the deploy source
  every app reads and still says base-branch commits/pushes are *enforced by the guard*; `frame` and
  `close` repeat the same enforcement parenthetical. After `install.sh`, those are the authoritative
  workflow contracts — so the system would still ship false guard claims even after the README is fixed.
- **Alternative:** Keep this doc-only (do not harden the hook), but expand scope/test-notes to update
  every live, non-historical guard-*enforcement* statement: `.claude/workflow-protocol.md` rule 5 and
  the `frame`/`close` hard-constraint parentheticals. Leave historical CHANGELOG/backlog entries
  alone. Phrase the skill rule as a rule Claude must follow, with the hook described only as a
  cooperative `main`/`master` tripwire.
- **Win:** Eliminates the remaining false authoritative statements without touching executable
  behavior, prevents the new `ARCHITECTURE.md` from contradicting the installed protocol, and keeps
  the deployed source-of-truth docs aligned with the hook's actual invariant.

**My recommendation:** *Fix* (accept into scope). Verified the three sites exist and overclaim as
described. The correct edit softens only the *enforcement attribution* (the parentheticals) — the
underlying rule "never commit/push to the base branch directly" stays intact, since that is a rule
*Claude* must follow regardless of what the hook mechanically catches. This expands the scope-
containment file list (AC-5) to include `.claude/workflow-protocol.md`, `.claude/skills/frame/SKILL.md`,
and `.claude/skills/close/SKILL.md` — all comment/prose edits, no logic change; `guard_test.sh` and
skill behavior unaffected.
