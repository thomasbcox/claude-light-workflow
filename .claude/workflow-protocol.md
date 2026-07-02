# Lightweight Claude↔Codex Review Protocol

A small, human-controlled development loop. One idea above all:
**the actor that builds is never the actor that approves.**

> This is the deploy source. The live copy every app reads is `~/.claude/workflow-protocol.md`
> (placed there by `install.sh`). Keep them in sync via the installer.

## Actors
- **Thomas** — owner / decider. Approves scope **and high-level design**, ratifies one-way-door decisions, decides each finding's disposition, approves the merge.
- **Claude** — builder / scribe. Writes the spec, the design sketch, the code, and the audit trail; calls the reviewer; applies approved fixes; merges on Thomas's word. Never self-approves scope, design, or merge.
- **The reviewer** — independent reviewer with a **selectable backend** (`reviewer` in `.claude/workflow.json`, default `codex`; a `/review` override can switch it per run). **Codex is the only wired backend today** — `codex exec -s read-only` with a structured-output schema; the canonical resolution rule + commands live in `review/SKILL.md` (→ *Reviewer backend*) and `frame/SKILL.md`. Selecting `llm` (the designated second source) stops as "not yet wired." Reviews at **two altitudes** — design/approach (the *shape*, judged against modern best practice) and correctness (the *diff*). Critiques and classifies; never fixes or merges. The role contract is the tool-neutral `AGENTS.md`, read automatically by whichever backend runs.
- **Tests / gate** — the mechanical judge. Objective pass/fail. Green never implies business approval.
- **The repo** — the one source of truth; the per-branch story file `reviews/<slug>.md` is the audit trail.

## The loop
1. **`/frame`** — Thomas states a need → Claude drafts a spec **and a design sketch** on a feature branch → the reviewer design-reviews the sketch (best-practice lens, always-on) → **one consult: Thomas approves scope, ratifies one-way-door decisions, decides best-practice flags** → Claude implements AC-by-AC.
2. **`/review`** — gate goes green → the **approach pass** (the shape, best-practice lens) gates the **correctness pass** (the diff): one-way-door / major-violation findings block (→ redesign + re-review); minor two-way kludges are advisory; correctness runs only on a shape that cleared approach review → Claude presents the decision menu → **Thomas decides per finding**.
3. **`/close`** — Claude applies only approved fixes → gate green → re-review (Thomas's call; an accepted redesign always re-reviews) or **Thomas approves merge** → record the release on the branch (CHANGELOG if the repo keeps one, BACKLOG-Done if a tracked item — else nothing beyond the merge commit) → merge + cleanup.

Loop 2 ↔ 3 as many rounds as needed.

## Rules (the whole thing in five lines)
1. The repo is authoritative; `reviews/<slug>.md` is the trail (spec → build → findings → decisions, appended).
2. Claude builds and self-fixes to green; the reviewer judges; Thomas decides.
3. **The human decides the one-way doors at every altitude** — consulted on requirements, high-level design, and implementation tradeoffs (plus the merge). Reversible (two-way) calls default to Claude and are logged for veto; a prior general "yes" never counts for merge. (See *Consult model* below.)
4. No AI grades its own homework — the builder is never the approver.
5. No direct commits/pushes to the base branch; the feature-branch + merge path is the only way in. (The guard hook is a cooperative backstop — it trips on commits/pushes while you're on `main`/`master` — but this rule holds regardless of what the hook mechanically catches.)

## Consult model (the two dials)

This replaces "decide twice." The human is consulted at three design altitudes — **requirements** (scope, in `/frame`), **high-level design** (the design sketch, in `/frame`), and **implementation tradeoffs** (the approach pass, in `/review`) — plus the **merge** authorization (in `/close`). Two independent dials govern *how* each consult works:

- **Blocking = reversibility (block narrow).** Only **one-way-door** decisions stop Claude and need Thomas: architecture, data model, public contract, a new dependency, or a **cross-cutting pattern future code will copy** (locally reversible, globally not). **Two-way** decisions default to Claude and are logged for veto.
- **Assessment = best practice (assess broad).** The reviewer **always** judges every notable decision against modern idiom *and* the repo's conventions, and **flags** nonstandard / dated / kludgy choices **regardless of reversibility.** Guardrails: a flag must name a concrete win (not novelty); internal consistency can outweigh ecosystem fashion; the repo's conventions are the local standard.

Disposition follows the two tags (reversibility × standing): **one-way door OR a major best-practice violation → block/consult; two-way + minor → advisory/log.** The builder is still never the approver (rule 4) — adding altitudes changes how many altitudes get a decision, never who decides.

> **Records ride with the merge, not after it.** `/close` writes any release records — the
> `CHANGELOG.md` entry *if the repo keeps a changelog*, the `BACKLOG.md` Done-move *if a tracked item
> was resolved* — on the feature branch *after* the merge instruction, so they arrive on the base
> branch as part of the merge commit. When neither applies, there is **no record commit** (the merge
> commit + story file are the ship record). Never a separate post-merge base write, never speculative
> (a re-review choice never reaches them; the story header is never set to `merged`).
> **No bookkeeping-only stories:** open a follow-up only for a real defect or a new decision, never
> solely to reconcile a previous story's records.

## Status & shipped-state (single source of truth)
The story-file header records only **declared** state — `proposed → approved`, with `approved`
as the terminal value. It never stores **observed** state. "Did it merge/ship?" is owned by git,
not the file. The shipped signal is the merge commit (`merge: <slug>`, with a `Story:` trailer) /
the PR's `MERGED` state — atomic: it exists or it doesn't, and it is the **single** source of
truth. Derive a shipped check with `git log <base> --oneline --grep "^merge: <slug>"` (or
`gh pr view --json state`); list everything shipped by dropping the `<slug>`. The header can never
drift from reality because it never holds the merge fact — the same discipline as Kubernetes
`spec` (declared) vs `status` (observed).

## Per-repo artifacts
- `reviews/<slug>.md` — the story file / audit trail.
- `reviews/<slug>.design.json` — frame-time design-sketch review (`design-review-schema`).
- `reviews/<slug>.approach.json` — review-time approach-pass output (`design-review-schema`).
- `reviews/<slug>.codex.json` — review-time correctness output per round (`finding-schema`).
- `.claude/workflow.json` — config: `baseBranch`, `branchPrefix`, `testCommand`, `reviewer`, `codexModel`.
- `AGENTS.md` — the (tool-neutral) reviewer contract (tunable per repo).

## Global (installed once, shared by every app)
- `~/.claude/skills/{frame,review,close}/` — the three skills (+ `review/finding-schema.json` and `review/design-review-schema.json`).
- `~/.claude/hooks/block-main-writes.sh` — the guard hook, wired in `~/.claude/settings.json`.
- `~/.claude/workflow-protocol.md` — this document.
- `~/.claude/workflow-AGENTS-template.md` — the contract template `/frame` copies into new repos.
