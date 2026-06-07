---
name: frame
description: Step 1 of the lightweight Claude↔Codex review loop. Turn a casual request into a short, approved spec on a fresh feature branch, then implement it AC-by-AC. Use when Thomas describes a new piece of work to build. Stops for human scope approval before any product code is written.
---

# /frame — intake → spec → implement

Step 1 of the lightweight Claude↔Codex review loop. Doctrine: `~/.claude/workflow-protocol.md`.

## Hard constraints
- Write NO product code before approval. The ONLY file you may write before Thomas approves the spec is the story file `reviews/<slug>.md`.
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
   - The `Status` field records only *declared* state: `proposed → approved`. `approved` is terminal — it never becomes `merged`. Whether it shipped is *observed* state owned by git (the merge commit + `shipped/<slug>` tag), read back by deriving, never written into the header.
   - `## Problem` — what and why.
   - `## In scope` / `## Non-goals`.
   - `## Acceptance criteria` — numbered, each testable.
   - `## Test notes` — how each AC will be checked. For a scope-containment AC (one that limits which files the diff may touch), do **not** restate a file count ("must show only N files") — that duplicates the AC's file list and goes stale on any scope change. Instead say: run `git diff --name-only <baseBranch>...HEAD` and verify no files appear beyond those the AC enumerates.
   - `## Open questions` — anything for Thomas to decide.
6. **Approval gate.** Present the spec. **STOP.** Ask Thomas to approve or adjust scope. Do not write code until he approves.
7. **On approval:** set `Status: approved`, append a line quoting Thomas's decision, then commit only the story file:
   `git add reviews/<slug>.md && git commit -m "spec: <slug>"`.
8. **Implement** the spec **AC by AC** — minimum change, no gold-plating. Commit on the feature branch. When done and committed, tell Thomas to run `/review`.
