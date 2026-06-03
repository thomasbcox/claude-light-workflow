---
name: review
description: Step 2 of the lightweight Claude↔Codex review loop. Run the test gate, then have Codex independently review the feature branch via `codex exec review`, capture structured findings, and present a decision menu for Thomas. Use after code is implemented and committed on the feature branch.
---

# /review — independent critique by Codex

Step 2 of the loop. Codex is the **independent** reviewer: it critiques and classifies; it never fixes or merges (`codex exec review` is read-only and Codex has no commit authority here). Contract: `AGENTS.md`. Doctrine: `~/.claude/workflow-protocol.md`.

## Hard constraints
- Tests must be **green** before you call Codex. Never ask Codex to review a red build.
- You do not act on findings here — you collect them and present the menu. Thomas decides per finding.
- Do not edit Codex's output. Append it verbatim (plus a readable digest) to the story file.

## Steps
1. **Load config** from `.claude/workflow.json`; identify `<slug>`, branch, `baseBranch`, `testCommand`, `codexModel`.
2. **Build note.** Append to `reviews/<slug>.md` a `## Build note (<date>)` section: the AC→file map and `git diff --stat <baseBranch>...HEAD`.
3. **Gate.** Run `testCommand`. If it fails, fix until green (mechanical self-fixes are allowed to reach green) and record the result. A red gate stops the loop.
4. **PR (only if a remote + `gh` exist).** Ensure a PR targets `baseBranch` and its checks are `SUCCESS` on the current HEAD. Local-only repos skip this entirely.
5. **Codex review.** Choose the diff base: first review → `<baseBranch>`; re-review → the last-reviewed SHA recorded in the story file. Run:
   ```bash
   codex exec review --base <base> \
     --output-schema .claude/skills/review/finding-schema.json \
     -o reviews/<slug>.codex.json \
     ${codexModel:+-m "$codexModel"} \
     "Review this branch against the spec and Build note in reviews/<slug>.md and the reviewer contract in AGENTS.md. Group findings as BLOCKER / IMPORTANT / QUESTION / NIT. For each: file, line, the claim (what's wrong and why it matters), and a concrete suggestion. Ground every finding in the actual diff."
   ```
6. **Record.** Read `reviews/<slug>.codex.json`. Append a `## Codex review (<date>, base <base>, HEAD <sha>)` section to the story file: the `summary`, then findings grouped by severity. Commit both the story file and the `.codex.json`.
7. **Decision menu.** Present the findings grouped by severity, each with a recommended disposition (**fix / defer / reject / answer**). Ask Thomas to decide per finding. **Never re-raise** anything he deferred or rejected in an earlier round.
8. **Record decisions & route.** Append a `## Decisions (<date>)` section quoting Thomas's call per finding; commit it. Then run `/close`.
