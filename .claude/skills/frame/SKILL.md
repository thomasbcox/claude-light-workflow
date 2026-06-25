---
name: frame
description: Step 1 of the lightweight Claude↔Codex review loop. Turn a casual request into a short, approved spec on a fresh feature branch, then implement it AC-by-AC. Use when Thomas describes a new piece of work to build. Stops for human scope approval before any product code is written.
---

# /frame — intake → spec → implement

Step 1 of the lightweight Claude↔Codex review loop. Doctrine: `~/.claude/workflow-protocol.md`.

## Hard constraints
- Write NO product code before approval. The only files you may write before Thomas approves are the story file `reviews/<slug>.md` (including its design sketch) and the Codex design-review output `reviews/<slug>.design.json`. No product code.
- Never work on the base branch. Create/use a `<branchPrefix><slug>` feature branch (the guard hook will block base-branch commits anyway).
- Do not expand scope beyond what Thomas states. Unknowns go in **Open questions**, never silent assumptions.
- You build; Thomas approves. Never self-approve scope.

## Steps
0. **Defer to native workflow.** If `docs/ai-protocol.md` exists at the repo root (resolve via `git rev-parse --show-toplevel`), STOP immediately — this repo runs its own heavier workflow. Tell the user to use its native skills (e.g. `/start-story`) instead of this one, and do nothing else.
1. **Load config.** Read `.claude/workflow.json`. If it is missing, bootstrap this repo first:
   - Base branch: `git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@'` → else `main` if it exists, else `master`.
   - Ask Thomas for the **test command** (the gate).
   - Write `.claude/workflow.json`: `{ "baseBranch": "...", "branchPrefix": "claude/", "testCommand": "...", "codexModel": "" }`.
   - If `AGENTS.md` is absent, copy it from `~/.claude/workflow-AGENTS-template.md`.
   - Ensure `reviews/` exists.
2. **Understand.** Read the relevant repo files. Restate the need in one paragraph and confirm you have it right.
3. **Slug.** Derive `<slug>`: lowercase, hyphenated, 2–4 words.
4. **Branch.** From an up-to-date base: `git checkout -b <branchPrefix><slug> <baseBranch>` (use `origin/<baseBranch>` if a remote exists). If already on the right feature branch, stay.
5. **Draft the spec** into `reviews/<slug>.md`:
   - Header line: `Date: <YYYY-MM-DD> · Branch: <branch> · Status: proposed`
   - The `Status` field records only *declared* state: `proposed → approved`. `approved` is terminal — it never becomes `merged`. Whether it shipped is *observed* state owned by git (the `merge: <slug>` commit / PR-`MERGED` state), read back by deriving, never written into the header.
   - `## Problem` — what and why.
   - `## In scope` / `## Non-goals`.
   - `## Acceptance criteria` — numbered, each testable.
   - `## Test notes` — how each AC will be checked. For a scope-containment AC (one that limits which files the diff may touch), do **not** restate a file count ("must show only N files") — that duplicates the AC's file list and goes stale on any scope change. Instead say: run `git diff --name-only <baseBranch>...HEAD` and verify no files appear beyond those the AC enumerates.
   - `## Open questions` — anything for Thomas to decide.
   - `## Design sketch — HOW` — the intended approach **before** you code it: the key modules/structures, the libraries or framework features you'll lean on, the central data shapes, and any cross-cutting pattern (validation, error model, retries). A few sentences or bullets, not a design doc. This is what Codex design-reviews in step 6. For a purely mechanical story (typo, doc tweak — no new structure/pattern/dependency) write `N/A — mechanical`, and the step-6 design review is a noted skip.
6. **Codex design review (the high-level-design altitude).** Unless the sketch is `N/A — mechanical`, have Codex review it **before any code exists** (no gate needed — it judges intent, not a diff). Codex reads `AGENTS.md` automatically and runs read-only:
   ```bash
   codex exec -s read-only \
     --output-schema "$HOME/.claude/skills/review/design-review-schema.json" \
     -o reviews/<slug>.design.json \
     ${codexModel:+-m "$codexModel"} \
     "You are Codex doing a DESIGN review per AGENTS.md — judge the SHAPE, not lines (no code exists yet). Read reviews/<slug>.md (the spec + the '## Design sketch — HOW'), then read the surrounding code and the dependency manifest. Ask: is this a sound, MODERN way to satisfy the acceptance criteria? Does it reinvent what a dependency already does, or hand-roll what one declarative construct would cover? Apply the best-practice lens and the three guardrails from AGENTS.md (concrete win not novelty; weigh internal consistency; repo conventions are the local standard). Tag each finding with reversibility (one-way/two-way) and standing. Return strictly per the provided JSON schema; empty findings array if the sketch is sound." \
     </dev/null
   ```
   **Keep the `</dev/null`** (else `codex exec` blocks reading stdin in non-interactive runs). `--output-schema` is **absolute** (skill-local, installed under `$HOME`); `-o` is **repo-relative** (the artifact lands in this project) — the same split as `review/SKILL.md`; don't normalise them. Record a `## Codex design review (<date>)` section in the story file: the `verdict`, then findings grouped by severity, each showing its reversibility × standing tags, `alternative`, and `win`.
7. **Frame consult (scope + design, one stop).** Present together: the spec (requirements), the design sketch, and Codex's design findings. **STOP.** Ask Thomas, in one pass, to **(a)** approve or adjust **scope**; **(b)** ratify any **one-way-door** design decisions (architecture, data model, public contract, a new dependency, or a cross-cutting pattern future code will copy); **(c)** decide each **best-practice flag** — fix / accept / defer. Recommend a disposition per finding (one-way **or** major violation → recommend *fix*; minor two-way kludge → advisory, recommend *accept* or *tidy*). **Tiering:** a sketch with no one-way doors and an empty Codex finding list is a clean pass — present it, but it needs only a scope nod. Write no product code until he approves.
8. **On approval:** set `Status: approved`; append a line quoting Thomas's scope decision and a `## Design decisions (<date>)` block recording his disposition per design finding (the approved shape is now binding on step 9). Commit the story file (and `reviews/<slug>.design.json` if step 6 ran):
   `git add reviews/<slug>.md reviews/<slug>.design.json 2>/dev/null; git add reviews/<slug>.md && git commit -m "spec: <slug>"`.
9. **Implement** the spec **AC by AC**, building the **approved shape** (apply the design decisions; do not silently re-litigate them) — minimum change, no gold-plating. Commit on the feature branch. When done and committed, tell Thomas to run `/review` — and, because this is a **first** review, remind him the approach pass runs by default and he can scope it: **`/review approach`** (force the approach pass) or **`/review correctness`** (skip straight to the line-level pass).
