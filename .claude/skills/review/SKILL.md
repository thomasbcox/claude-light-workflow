---
name: review
description: Step 2 of the lightweight Claude↔Codex review loop. Run the test gate, then have Codex independently review the feature branch via a read-only `codex exec` with a structured-output schema, capture the findings, and present a decision menu for Thomas. Use after code is implemented and committed on the feature branch.
---

# /review — independent critique by Codex

Step 2 of the loop. Codex is the **independent** reviewer: it critiques and classifies; it never fixes or merges (it runs under `-s read-only` and has no commit authority here). Contract: `AGENTS.md`. Doctrine: `~/.claude/workflow-protocol.md`.

## Hard constraints
- Tests must be **green** before you call Codex. Never ask Codex to review a red build.
- You do not act on findings here — you collect them and present the menu. Thomas decides per finding.
- Do not edit Codex's output. Append it verbatim (plus a readable digest) to the story file.

## Steps
0. **Defer to native workflow.** If `docs/ai-protocol.md` exists at the repo root (resolve via `git rev-parse --show-toplevel`), STOP immediately — this repo runs its own heavier workflow. Tell the user to use its native review skill (e.g. `/prepare-codex-review`) instead of this one, and do nothing else.
1. **Load config** from `.claude/workflow.json`; identify `<slug>`, branch, `baseBranch`, `testCommand`, `codexModel`.
2. **Build note.** Append to `reviews/<slug>.md` a `## Build note (<date>)` section: the AC→file map and `git diff --stat <baseBranch>...HEAD`.
3. **Gate.** Run `testCommand`. If it fails, fix until green (mechanical self-fixes are allowed to reach green) and record the result. A red gate stops the loop.
4. **PR (only if a remote + `gh` exist).** Ensure a PR targets `baseBranch` and its checks are `SUCCESS` on the current HEAD. Local-only repos skip this entirely.
5. **Codex review.** Choose the diff base: first review → `<baseBranch>`; re-review → the last-reviewed SHA recorded in the story file. Codex reads `AGENTS.md` automatically and runs read-only (`-s read-only` — it cannot edit the repo). Run:
   ```bash
   codex exec -s read-only \
     --output-schema .claude/skills/review/finding-schema.json \
     -o reviews/<slug>.codex.json \
     ${codexModel:+-m "$codexModel"} \
     "You are Codex, the independent reviewer in AGENTS.md. Review ONLY this branch's changes versus <base>: run \`git diff <base>...HEAD\` and \`git log --oneline <base>..HEAD\`, and read reviews/<slug>.md for the spec. Judge the change against that spec. Return your result strictly per the provided JSON schema (severities BLOCKER / IMPORTANT / QUESTION / NIT; ground every finding in the actual diff; return an empty findings array if there are no issues)."
   ```
   **Do NOT use the `codex exec review` subcommand here:** its `--base` flag conflicts with a custom prompt, and its `-o` output ignores `--output-schema` (it writes prose, not JSON). Also note the schema marks every property `required` with `file`/`line`/`suggestion` nullable — the strict structured-output backend rejects schemas with truly optional keys.
6. **Record.** Read `reviews/<slug>.codex.json`. Append a `## Codex review (<date>, base <base>, HEAD <sha>)` section to the story file: the `summary`, then findings grouped by severity. Commit both the story file and the `.codex.json`.
7. **Decision menu.** Present the findings grouped by severity, each with a recommended disposition (**fix / defer / reject / answer**). Ask Thomas to decide per finding. **Never re-raise** anything he deferred or rejected in an earlier round. **Deciding fix/defer/reject is not a merge decision** — the merge gate is separate and lives in `/close`, which stops and asks "re-review or merge?" before any merge.
8. **Record decisions & route.** Append a `## Decisions (<date>)` section quoting Thomas's call per finding; commit it. Then run `/close` to apply the approved fixes and reach the merge fork — routing to `/close` does NOT authorize a merge; `/close` still requires a distinct merge instruction.
