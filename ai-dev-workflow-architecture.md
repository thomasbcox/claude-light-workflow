# AI-Assisted Development Workflow Architecture

> **⚠️ Historical / parent reference — not this repository.** This document describes the heavier
> **parent** system, *AI Protocol v3*, from which `claude-light-workflow` was trimmed down. It is
> kept as background on the lineage and the reasoning. It refers to machinery that does **not** exist
> in this repo (`docs/ai-protocol.md`, `/start-story`, dbt/DuckDB gates, `.github/workflows/test.yml`,
> the broader hook/script suite). **For what this repo actually is and does, see
> [`ARCHITECTURE.md`](ARCHITECTURE.md);** the normative rules are in
> [`.claude/workflow-protocol.md`](.claude/workflow-protocol.md).

> A reference description of the custom Claude Code skill suite that drove development on the parent
> project. Written so a reader could reverse-engineer an equivalent system for their own repo.
>
> Order: **Purpose** → **Approach** → **Details**. In the parent system the normative rules lived in
> `docs/ai-protocol.md` and `AGENTS.md`; this document explains *why* that system was shaped the way
> it was and *how* the pieces fit together.

---

## 1. Purpose

### 1.1 The failure mode we are designing against

The default way people use an AI coding agent is: one model invents the spec, writes the code,
reviews its own code, declares success, and ships. Every step is performed by the same biased actor.
A Builder — human or AI — is structurally inclined to see its own work as complete. The result is
plausible-looking work that drifts from intent, skips edge cases, and accumulates silent regressions
that nobody independent ever challenged.

### 1.2 What this system is

The parent project ran **AI Protocol v3**: a human-controlled, spec-driven, multi-agent development
loop. (This repo, `claude-light-workflow`, runs a trimmed-down port of it — see
[`ARCHITECTURE.md`](ARCHITECTURE.md).)
The skills are the *executable encoding* of that protocol — each one is a Markdown "skill file" that
Claude Code loads on demand and follows step-by-step. Together they turn a casual request from the
owner into a reviewed, tested, independently-audited pull request, without the owner having to write
structured specs, run the tests, or babysit the mechanics.

The single design goal: **separate doing from judging**, and keep a human as the only decider.

### 1.3 Who it is for

- **Thomas** — the owner/decider. Speaks casually; never has to scribe, run CI, or remember workflow
  mechanics. Makes every scope, architecture, and merge decision.
- **Claude** — the Builder/Scribe/Chief-of-Staff. Turns intent into structured artifacts, writes code
  and docs, prepares review prompts, records decisions, coordinates the loop.
- **Codex** — the Independent Reviewer. Reviews committed branches/PRs and classifies findings. Does
  not fix and does not merge.
- **CI / tests** — the non-LLM mechanical judge. Objective pass/fail.
- **MemPalace** — durable working memory across sessions (continuity, not source of truth).
- **The repo** — the governed product record; the one shared reality.

---

## 2. Approach

### 2.1 Core doctrine (five lines)

1. **One shared reality** — the repo is authoritative for everything that affects the product.
2. **Many helpers** — multiple specialised agents, each with a narrow role.
3. **One human decider** — Thomas owns all scope, architecture, and merge decisions.
4. **No human scribing** — Claude produces the structured artifacts so the human doesn't have to.
5. **No AI grades its own homework** — the actor that builds is never the actor that approves.

### 2.2 The design principles that follow from the doctrine

**Repo-first source of truth.** Requirements, assertions, roadmap, architecture decisions, tests, and
major rationales live as version-controlled files. MemPalace stores *summaries and pointers*, never
the sole copy of a major decision. If the two disagree, the repo wins.

**Skills as encoded process.** Rather than trusting the model to "remember the workflow," each phase
of the loop is a skill file with hard constraints, numbered steps, and exact shell commands. The model
loads the relevant skill and executes it. This makes the process inspectable, versionable, and
diff-reviewable like any other code.

**Hooks as physics.** The most important rules are enforced by shell hooks wired into the agent's tool
lifecycle, not by prose the model might ignore. A hook can *block* a tool call (e.g. a push to `main`).
Turning doctrine into physics means a tired operator or a regressed prompt physically cannot violate a
core rule without first editing the hook file — and that edit is diff-visible.

**An append-only audit trail.** Every meaningful handoff writes a timestamped note to `docs/ai-log/`.
The notes are the paper trail: what was specified, what Thomas approved, what Codex found, what was
fixed. Anyone can reconstruct why any change happened from git history + the ai-log.

**Materiality-based routing.** After a fix, the system asks: did this change something that matters
(money, reporting, security, business logic, data loss, or the workflow's own gates/authority)? If so
it is *material* and returns to independent review; if it is merely *mechanical* (typos, formatting,
test skeletons) it proceeds toward merge. This keeps the loop fast without letting risky changes skip
review.

**Mechanical judgment is separate from human judgment.** CI catches what is objectively broken; Claude
may self-fix mechanical failures until CI is green. CI passing never means the *business decision* is
approved — that is always Thomas's call.

### 2.3 The shape of the loop

```
Thomas states a need (casually)
        │
        ▼
  /start-story ──────────► spec package + Thomas approval gate
        │
        ▼
  /implement-story ──────► code/docs on a branch, quality gate, CI green
        │
        ▼
  /prepare-codex-review ─► open PR, verify CI green, brief Codex (independent review)
        │
        ▼
  /triage-review ────────► group findings, decision menu, Thomas decides
        │
        ▼
  /apply-approved-fixes ─► implement only approved items → material? back to review : forward
        │
        ▼
  /close-story ──────────► Thomas approves merge → merge → sync → cleanup → record
```

Each arrow is a Thomas-visible checkpoint. The loop can iterate (review → fix → re-review) any number
of times before merge.

---

## 3. Details

### 3.1 Actors and authority

| Actor | Role | May do | May never do |
|---|---|---|---|
| Thomas | Owner / Decider | Approve scope, architecture, merges; decide tradeoffs | — |
| Claude | Builder / Scribe | Write code/docs, self-fix mechanical failures, run the loop | Self-approve scope/product/architecture/merge; push to `main` |
| Codex | Independent Reviewer | Review a branch/PR; write one review note | Fix code; approve; merge; edit another actor's file |
| CI / tests | Mechanical judge | Pass/fail objectively | Replace human judgment |
| MemPalace | Working memory | Store summaries, pointers, continuity | Be the sole record of a major decision |
| Repo | Product record | Hold governed truth | — |

The asymmetry is the whole point: the Builder has broad authority over *making* but zero authority
over *approving*.

### 3.2 The v3 development loop (canonical 11 steps)

1. Thomas states the need casually.
2. Claude starts a specification package (`/start-story`).
3. Thomas approves or clarifies scope.
4. Claude implements on a branch (`/implement-story`).
5. CI runs mechanical checks.
6. Codex reviews independently (`/prepare-codex-review` opens the PR + briefs Codex).
7. Claude translates the review into a decision menu (`/triage-review`).
8. Thomas decides — and may *partially* approve (approve some, defer some, reject some).
9. Claude acts only on approved items (`/apply-approved-fixes`); material changes return to step 6.
10. Thomas explicitly approves merge (a prior general approval does not count).
11. Claude merges and updates state (`/close-story`).

The skills map onto these steps; the step number is named at the top of each skill file.

### 3.3 The six skills

Each skill is a Markdown file at `.claude/skills/<name>/SKILL.md`. The model loads it when the owner
types `/<name>`, then follows it literally. Every skill opens with **Hard constraints**, then numbered
**Steps** with the exact shell commands to run. Common shape: *declare before acting* → *do the work*
→ *run a gate* → *write an audit note* → *route to the next skill*.

#### 3.3.1 `start-story` — intake → spec (loop step 2)
- **Trigger:** Thomas describes any need.
- **Does:** queries MemPalace for context (retrieval hints only); reads the repo source-of-truth docs;
  checks/creates the `claude/<topic-slug>` branch; emits a **declaration** (what it will and won't
  touch); drafts a spec (problem statement, non-goals, user story, acceptance criteria, assertions,
  test cases, open questions); presents it for approval; writes a `claude_spec` note with
  `Status: proposed`; on approval flips it to `Status: approved` and appends Thomas's decision.
- **Outputs:** a `*_claude_spec_*.md` ai-log note; possibly new requirement/assertion/eval files.
- **Key constraint:** writes no product files until Thomas approves the spec (the proposed-spec note is
  the one allowed pre-approval write).

#### 3.3.2 `implement-story` — spec → implementation (loop step 4)
- **Trigger:** an approved spec exists.
- **Does:** declares story type (code vs workflow) and the AC→file mapping; checks out the story branch
  and verifies it is not behind `origin/main`; implements **AC by AC** (minimum change, no
  gold-plating); updates supporting artifacts (tests, assertions, ROADMAP) only when the governed truth
  actually changed; runs the **quality gate**; commits and writes a `claude_action-note`.
- **Outputs:** code/doc commits + an action note. Branch is CI-green and ready for review.
- **Notable subchecks (code stories):** assertion-coverage (every touched invariant has a real test —
  BL-005/WF-003) and CI-self-contained sources (no dbt source reads a gitignored path — WF-004).

#### 3.3.3 `prepare-codex-review` — request independent review (loop step 6)
- **Trigger:** implementation done, quality gate passed.
- **Does:** ensures a PR targeting `main` exists; enforces the **PR-CI green gate** (every check
  `SUCCESS` *and* run against the PR's current HEAD — never ask Codex to review a red or stale build);
  determines review type (first review = `full`; re-review = `diff-only since <hash>`, overridden back
  to `full` if the diff is high-risk); assembles a briefing prompt that points Codex at `AGENTS.md`.
- **Two modes:**
  - *Manual* (default): emits the prompt in chat; Thomas pastes it into an interactive Codex session.
  - *Auto* (`CODEX_AUTO=1`): writes a `claude_codex-instruction` note and invokes
    `scripts/codex/run_review.sh`, which runs Codex non-interactively, waits for the review note,
    audits it, and lands it (see "Key constraint") — then Claude continues triage inline.
- **Key constraint:** this skill does not itself review or merge; in auto mode the orchestration script
  owns the git authority and audit/push discipline. It either commits the untracked Codex note itself,
  or *adopts* a clean Codex self-commit — but only after the same audit passes (filename, size,
  exactly-one-file, single commit, and the whole push range being exactly that one commit), then pushes
  with exact-path git.

#### 3.3.4 `triage-review` — review → decision menu (loop step 7)
- **Trigger:** a Codex review note exists for the branch.
- **Does:** reads the review; groups findings by severity (BLOCKER / IMPORTANT / QUESTION / NICE TO
  HAVE / IGNORE); presents a **decision menu** with a recommended path; drafts a `thomas-approval`
  note but does **not** commit it until Thomas confirms each disposition; never re-raises findings
  Thomas previously deferred/rejected.
- **Outputs:** a committed `thomas-approval` note recording approved / deferred / rejected per finding.
- **Routing:** approved fixes → `apply-approved-fixes`; nothing to fix → `close-story`; an unresolved
  BLOCKER or unanswered QUESTION halts the loop.

#### 3.3.5 `apply-approved-fixes` — implement approved items (loop step 9)
- **Trigger:** a `thomas-approval` note with approved fixes (and newer than the review it answers).
- **Does:** implements **only** the approved items (deferred/rejected are untouchable); runs the
  quality gate; commits; then **classifies the change set as material or mechanical-only** and routes:
  material → back to `prepare-codex-review` for another review cycle; mechanical-only → forward to
  Thomas's merge approval.
- **Key constraint:** implementing a deferred or rejected finding without new explicit approval is
  forbidden.

#### 3.3.6 `close-story` — merge + cleanup (loop step 11)
- **Trigger:** Thomas explicitly approves merge **in the current session**.
- **Does:** verifies PR state and that local == remote; merges with `--delete-branch` (the merge is the
  *only* write to `main`); syncs local `main` with `fetch --prune` + `merge --ff-only`; deletes the
  local feature branch safely (`-d`, never `-D` without confirmation); runs an optional **post-close
  housekeeping** sweep for stale branches/worktrees; updates MemPalace.
- **Key constraint:** never runs `gh pr merge` without Thomas's explicit current-session confirmation;
  the housekeeping sweep is explicitly non-blocking — an error there never reopens or blocks the close.

### 3.4 Canonical workflow definitions

Several concepts are referenced by multiple skills. To prevent them drifting apart, the definitions
are centralised in **one** place (`docs/ai-protocol.md` → *Workflow Definitions*) and the skills point
at it rather than restating it. The four definitions:

- **High-risk change** — touches money/fees/revenue, reporting/metrics, security/auth/permissions,
  business logic anywhere, or data-loss risk. A high-risk diff always forces a **full** Codex
  re-review regardless of the briefing. (Used by `prepare-codex-review` and `AGENTS.md`.)
- **Material vs mechanical change** — *material* = high-risk **OR** a change to hard constraints,
  routing, quality gates, approvals, commands, or authority in skill/protocol files. *Mechanical-only*
  = naming/comments/imports/formatting, test skeletons, and typo/whitespace edits to process docs that
  change none of the above. Material → re-review; mechanical → merge. (Used by `apply-approved-fixes`.)
  Note the deliberate containment: **high-risk ⊂ material** — they are related but distinct, so the
  re-review trigger and the routing trigger stay independent.
- **Story type** — *code story* touches `app/`, `models/`, `seeds/`, `tests/`, `scripts/`, or data;
  *workflow story* touches `.claude/skills/`, `docs/ai-protocol.md`, `AGENTS.md`, or process docs. The
  story type selects the quality gate. (Used by `implement-story` and `apply-approved-fixes`.)
- **Builder prohibitions** — the five things Claude must never do in any skill: (1) expand scope beyond
  what Thomas approved; (2) commit/push directly to `main`; (3) self-approve product/architecture/
  scope/business decisions; (4) implement a deferred/rejected finding without new approval; (5) merge
  without Thomas's explicit current-session approval. Every skill's *Hard constraints* references this
  canonical list rather than restating it.

### 3.5 The ai-log (audit trail)

`docs/ai-log/` is a flat directory of timestamped Markdown notes. Filenames encode everything needed
to filter them:

```
YYYY-MM-DD_HHMM_<actor>_<type>_<topic>.md
```

| Note type | Written by | When |
|---|---|---|
| `claude_spec` | Claude | start-story; `Status: proposed` then overwritten to `approved` |
| `claude_action-note` | Claude | implement-story / apply-approved-fixes — what was done + gate result |
| `claude_codex-instruction` | Claude | auto-mode review briefing (audit trail) |
| `codex_review` | Codex | the independent review, grouped by severity |
| `thomas-approval` | Claude (on Thomas's word) | triage decisions, committed only after Thomas confirms |

Every note begins with a header: `Date / Actor / Topic / Branch` (and `Status` for spec notes). Notes
are found by a shared helper rather than copy-pasted grep recipes:

```bash
scripts/workflow/find_ai_log_note.sh <type> [branch]   # latest note of <type> for a branch
```

A Claude Code `PreToolUse`/`Write` hook (`validate-ai-log-filename.sh`, wired in `.claude/settings.json`)
blocks any Write to `docs/ai-log/` whose filename doesn't match the convention before it is created; the
auto-mode orchestrator (`run_review.sh`) additionally re-validates the filename during its post-Codex
audit. **Merges are deliberately *not* logged** — the
merge is already recorded by git, the PR, the approval note, and the MemPalace status fact; a post-
merge log note would require a forbidden write to `main`.

### 3.6 Hooks (the guardrails)

Hooks live in `.claude/hooks/` and are wired in `.claude/settings.json` to fire on tool-lifecycle
events. They are the load-bearing enforcement layer.

| Hook | Event / trigger | Effect |
|---|---|---|
| `block-push-to-main.sh` | any `git push` targeting `main` | blocks (the PR merge is the only path to `main`) |
| `block-commit-on-main.sh` | `git commit` while on `main` | blocks |
| `block-no-verify-force.sh` | `--no-verify` / `--force` on commit/push/PR | blocks |
| `require-feature-branch.sh` | commit on a non-`claude/<slug>` branch | blocks (catches harness-spawned branch names) |
| `validate-ai-log-filename.sh` | write to `docs/ai-log/*.md` with a bad name | blocks with a format hint |
| `auto-prune-after-fetch.sh` | `git fetch origin` without `--prune` | reactively re-fetches with `--prune` |
| `session-start-branch-state.sh` | session start | prints branch state + `[hygiene]` warnings |
| `_branch_hygiene.sh` | library (sourced) | shared stale-branch / orphan-worktree / tombstone detection |

There is no env-var or sentinel bypass by design: disabling a hook requires editing the hook or
`settings.json`, which is diff-visible and reviewable.

### 3.7 Helpers and scripts

- **`scripts/workflow/find_ai_log_note.sh`** — single source of truth for the branch-scoped
  "latest note of type X" lookup. Thin, tested wrapper over `grep -rl "Branch: $B" docs/ai-log/ |
  grep <type> | sort | tail -1`. Exits non-zero on no-match; rejects unknown types.
- **`scripts/codex/run_review.sh`** — the auto-mode review orchestrator. Preflight (branch ≠ `main`,
  clean worktree, `fswatch` present) → invoke Codex via `codex exec --sandbox workspace-write` →
  wait (filesystem poll is the source of truth; `fswatch` is a fast-path) for the review note →
  audit (filename, size, exactly-one-file, single commit, full push range) → land it with exact-path
  discipline. Exit codes are a contract: `0` success, `1` Codex/CLI failure, `2` timeout, `3` preflight
  refusal, `4` audit failure. The script owns git authority: it either commits the untracked note
  itself, or **adopts** a clean Codex self-commit only after re-running that audit — so its audit gates
  everything that reaches origin.
- **`scripts/scenario-coverage/audit.py`** — hard-fails CI if any canonical taxonomy value, assertion
  ID, or eval ID lacks a row in the scenario-corpus coverage matrix.
- **`scripts/docs/check_references.py`** — hard-fails CI if any path reference in the authoritative doc
  tier points at a file that no longer exists (catches doc drift at PR time).

### 3.8 The quality gate (CI parity)

The skills' quality gate mirrors `.github/workflows/test.yml` exactly, so "green locally" predicts
"green in CI." The five checks, in order:

1. `pytest tests/ -v`
2. `dbt build` against fixture data (`--vars '{"data_root": "tests/fixtures/anonymized"}'`)
3. `dbt build` against the scenario corpus (`--vars '{"data_root": "data/scenarios"}'`)
4. `python3` `scripts/scenario-coverage/audit.py`
5. `python3` `scripts/docs/check_references.py`

`implement-story` and `apply-approved-fixes` share the identical checklist. A story may **narrow** it
only when the omitted gates cannot be affected by its diff — e.g. a workflow-only story (skills/docs,
no `models/seeds/app/scripts` code) may skip the two dbt builds and the scenario audit but must still
run pytest and the docs-reference check, and must justify the narrowing in its action note.

### 3.9 MemPalace and its fallback

MemPalace is a knowledge-graph + drawer memory used for cross-session continuity: story status, repo
pointers, open loops, decisions. Skills query it first (as *hints*, never as truth) and write to it at
the end (story drafted, fixes landed, story merged). Because it must never be load-bearing, every skill
that touches it states an explicit fallback: **if MemPalace is unavailable, proceed on repo
source-of-truth, record that a sync is pending, and never let MemPalace be the sole record of a major
decision.** The repo always already holds the authoritative copy.

### 3.10 Branch and git conventions

- Story branches are named `claude/<topic-slug>` (lowercase, hyphenated, 2–4 words).
- New branches are created from current `origin/main` (`git checkout -b claude/<slug> origin/main`).
- No direct commits or pushes to `main` — ever. The PR merge is the only write.
- Merge is `--merge --delete-branch`; local cleanup is `fetch --prune` + `merge --ff-only` + safe
  `branch -d`.
- **Abandoned stories** are not deleted — they are tombstoned: the spec note's `Status` becomes
  `abandoned`, an annotated `abandoned/<slug>` tag preserves the history, and the branch is removed
  once the tag is confirmed on origin. `git branch -a` stays clean; the tag is the audit trail.

### 3.11 A worked trace (one full loop)

A representative single iteration:

1. Thomas: "the skill suite has drifted; tidy it up." → `/start-story` reads the repo, drafts a spec
   with acceptance criteria, gets Thomas's approval, commits `…_claude_spec_…md` (proposed → approved).
2. `/implement-story` makes the edits AC-by-AC on `claude/<slug>`, runs the (narrowed) gate, commits,
   writes `…_claude_action-note_…md`.
3. `/prepare-codex-review` opens a PR, waits for CI green on HEAD, and (with `CODEX_AUTO=1`) runs Codex
   via `run_review.sh`; Codex writes `…_codex_review_…md`.
4. `/triage-review` (inline) turns the review into a decision menu; Codex flagged one IMPORTANT issue;
   Thomas approves the fix; a `…_thomas-approval_…md` note is committed.
5. `/apply-approved-fixes` implements just that fix, re-runs the gate, classifies it **material**, and
   routes back to step 3 for a diff-only re-review.
6. The re-review comes back clean; Thomas approves merge; `/close-story` merges PR, syncs `main`,
   deletes the branch, updates MemPalace.

The value shows up exactly where independent review catches something the Builder missed — which is
the entire reason the doer and the judge are different actors.

### 3.12 Reverse-engineering this for your own project

A minimal port needs the following pieces. None require the parent project's domain (dbt/DuckDB); swap
the quality gate for your stack. (`claude-light-workflow` in this repo is one such minimal port.)

1. **A protocol document** — write down the roles, the loop steps, the severity labels, and the
   source-of-truth rule. This is your `ai-protocol.md`. Everything else references it.
2. **A skill per phase** — one Markdown file each for: intake→spec, implement, request-review,
   triage-review, apply-fixes, close. Give each: hard constraints, numbered steps, exact commands, an
   audit-note template, and an explicit "route to next" decision. Keep them small and surgical.
3. **An independent reviewer** — a *different* agent (different model/session) with a standing contract
   (your `AGENTS.md`): it reviews and classifies, it never fixes or merges, it writes exactly one note.
4. **An audit trail** — a flat, timestamped notes directory with a strict filename convention and a
   tiny helper to fetch "the latest note of type X for branch Y."
5. **Hooks as physics** — block direct commits/pushes to your main branch, block `--force`/`--no-verify`,
   and validate your note filenames, at the tool-call layer. Make bypass require a diff-visible edit.
6. **A mechanical judge** — CI that runs your tests on every push/PR, plus a gate the skills run locally
   that mirrors CI exactly. Let the Builder self-fix until CI is green; never let CI passing imply
   business approval.
7. **Materiality routing** — define "material" vs "mechanical" for *your* domain and route post-fix
   changes accordingly (material → re-review; mechanical → merge).
8. **A human gate at two points** — spec approval and merge approval. Make the merge approval
   session-specific: a prior general "yes" never counts.
9. **(Optional) continuity memory** — a place to stash cross-session context, with a hard rule that it
   is never the sole record of anything that matters.

The throughline to preserve: **the actor that builds is never the actor that approves, and the rules
that protect that separation are enforced mechanically, not by good intentions.**

---

## Appendix — file map

| Path | Role |
|---|---|
| `docs/ai-protocol.md` | Normative protocol: roles, loop, severity labels, canonical definitions |
| `AGENTS.md` | Codex's standing contract (read first by the reviewer) |
| `.claude/skills/<name>/SKILL.md` | The six phase skills |
| `.claude/hooks/*.sh` + `.claude/settings.json` | Guardrail hooks and their wiring |
| `docs/ai-log/*.md` | Append-only audit trail of specs, reviews, approvals, action notes |
| `scripts/workflow/find_ai_log_note.sh` | Branch-scoped ai-log lookup helper |
| `scripts/codex/run_review.sh` | Auto-mode Codex orchestration |
| `scripts/docs/check_references.py` | Doc-reference CI gate |
| `scripts/scenario-coverage/audit.py` | Canonical-coverage CI gate |
| `.github/workflows/test.yml` | CI: the mechanical judge |
| `BACKLOG.md` | Parked work items (BL-NNN), graduated to specs when their time comes |
