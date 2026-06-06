Date: 2026-06-05 · Branch: claude/harden-merge-and-guard · Status: approved

# harden close merge and guard enforcement

> Approved by Thomas 2026-06-05: "approved. implement and then review please." Open questions resolved with the recommended defaults: (1) harden the matcher **and** soften the absolute doc claim; (2) wire the new guard test in as the real gate; (3) express mergeability (AC3) as a concise `gh pr view --json mergeStateStatus` check.

## Problem
The workflow's safety model rests on two mechanisms, and both have holes:

1. **`/close` can merge a stale remote PR head.** The remote recipe ([close/SKILL.md:27](../.claude/skills/close/SKILL.md:27)) runs `gh pr merge` with no prior push and no head check. `/close` step 3 commits fixes locally but never pushes, while `/review`'s PR check ran at review time — so the approved-fix commits are exactly the ones the remote head won't have. The reviewed/fixed code may not ship.

2. **The base-branch guard can be bypassed with normal Git forms, and over-blocks benign ones.** The guard ([block-main-writes.sh](../.claude/hooks/block-main-writes.sh)) pattern-matches raw command text instead of parsing argv. Consequences:
   - `git -C <repo> commit` and `git -c user.name=… commit` slip past the commit block (regex requires `git` immediately followed by `commit`, [:46](../.claude/hooks/block-main-writes.sh:46)).
   - `git push origin +HEAD:main` from a **feature branch** defeats base protection entirely: the `+refspec` force form isn't caught ([:35](../.claude/hooks/block-main-writes.sh:35)) **and** the base-push block only fires when the *local* branch is `main` ([:48](../.claude/hooks/block-main-writes.sh:48)).
   - The same naive matcher blocks read-only commands that merely contain a blocked verb as an argument (observed live: a `grep` whose pattern string contained `git push` was blocked).

3. **Docs advertise the retired `codex exec review` flow.** [review/SKILL.md:29](../.claude/skills/review/SKILL.md:29) explicitly says *not* to use that subcommand (its `-o` ignores `--output-schema` and writes prose). But the canonical doctrine ([workflow-protocol.md:12](../.claude/workflow-protocol.md:12), [:18](../.claude/workflow-protocol.md:18)) and the README ([:15](../README.md:15), [:18](../README.md:18), [:47](../README.md:47)) still point users at it.

## In scope
- Harden `/close`'s remote merge recipe: push the fix HEAD, verify the PR head matches, wait for mergeability, merge with `--match-head-commit`.
- Harden the guard hook against the bypass forms (`git -C`, `git -c`, `+refspec`) and resolve the target repo before the branch check.
- Avoid introducing new false-positives: benign read-only git commands must stay unblocked.
- Update docs/doctrine to stop advertising `codex exec review`.
- Add scripted payload checks (test fixtures) covering the bypass and false-positive cases.

## Non-goals
- Replacing the PreToolUse Bash hook with real Git hooks or server-side branch protection (noted as the structurally correct fix, but a larger change — out of scope here).
- Reworking the `/frame` or `/review` flows beyond the doc string change.
- Changing the local-only merge recipe (the stale-head risk is remote-specific).

## Acceptance criteria
1. `/close`'s remote recipe pushes the current feature-branch HEAD **before** merging.
2. `/close` captures the intended local fix SHA and verifies the PR `headRefOid` equals it **before** merge (fails loudly on mismatch).
3. `/close` waits for required checks / mergeability to settle before invoking `gh pr merge`.
4. `/close` merges with `gh pr merge --match-head-commit <sha>`, where `<sha>` is the local fix SHA captured in AC2 (not the post-merge oid).
5. The guard blocks base-branch commits via `git commit`, `git -C <repo> commit`, and `git -c k=v commit`, resolving the target repo before the branch check.
6. The guard blocks force pushes to base via `--force`, `--force-with-lease`, `-f`, and `+refspec` (e.g. `git push origin +HEAD:main` from a feature branch is denied).
7. A benign read-only git command that contains a blocked verb only as an argument (e.g. `grep 'git push' file`) is **not** blocked.
8. README and `workflow-protocol.md` no longer advertise `codex exec review`; they point to the schema-validated `codex exec -s read-only --output-schema …` form (or to the canonical command in `review/SKILL.md`).
9. A test/fixture harness exercises ACs 5–7 (bypass forms denied, false-positive allowed) with JSON payloads matching the hook's stdin contract.

## Test notes
- **AC1–4:** No live remote merge in the gate. Verify by reading the revised `close/SKILL.md` recipe: push precedes merge; a `headRefOid == localSha` check precedes merge; `--match-head-commit <localSha>` is present; mergeability wait is present. (Recipe is doctrine, not executable here, so review is by inspection.)
- **AC5–7, 9:** A shell test feeds crafted JSON payloads (`{"tool_input":{"command":"…"}}`) to `block-main-writes.sh` on stdin and asserts exit code: 2 (blocked) for the bypass/force forms, 0 (allowed) for the benign read-only command. Run on a checked-out base branch to exercise the branch case, and with `git -C` pointing at a feature-branch repo.
- **AC8:** `grep -rn "codex exec review"` over README.md and `.claude/workflow-protocol.md` returns nothing (the deny-note in `review/SKILL.md:29`, which references the subcommand to warn against it, is exempt).
- **Gate:** `testCommand` (currently a placeholder) must stay green; the new shell test should be runnable standalone and, ideally, wired so the gate actually exercises it.

## Build note (2026-06-05)

AC → file map:
- AC1–4 (`/close` stale-head): [.claude/skills/close/SKILL.md](../.claude/skills/close/SKILL.md) — remote recipe now captures `localSha`, pushes HEAD, polls `mergeStateStatus`, asserts `headRefOid == localSha`, merges with `--match-head-commit "$localSha"`.
- AC5–7 (guard): [.claude/hooks/block-main-writes.sh](../.claude/hooks/block-main-writes.sh) — rewritten to tokenize the command, isolate real `git` invocations, walk global options (`-C`/`-c`/…) to the true subcommand, resolve the target repo before the branch check, and detect `+refspec`/`--mirror`/`-f` force forms. Fails open on unparseable input.
- AC8 (docs): [README.md](../README.md), [.claude/workflow-protocol.md](../.claude/workflow-protocol.md) — `codex exec review` replaced with `codex exec -s read-only --output-schema …`; `review/SKILL.md:29` warn-note left intact.
- AC9 (test/gate): [tests/guard_test.sh](../tests/guard_test.sh) — 17 JSON-payload cases (bypass forms denied, benign/native-defer allowed); wired in as `testCommand` in [.claude/workflow.json](../.claude/workflow.json).

`git diff --stat main...HEAD`: 7 files, +280/−53 (hook +172/−… is the bulk). Gate `bash tests/guard_test.sh`: 17 passed / 0 failed.

## Codex review (2026-06-05, base main, HEAD 58a02ff)

**Summary:** Reviewed `git diff main...HEAD`, `git log`, and the spec. The close recipe and docs mostly match the spec, but the guard still misses a standard `--force-with-lease=<ref>` form. (Codex's own full guard-test run was blocked by its read-only sandbox's `mktemp`; it confirmed the bypass via targeted hook payloads instead.)

**BLOCKER — Guard misses `--force-with-lease` value form** · `.claude/hooks/block-main-writes.sh:127`
AC6 requires blocking `--force-with-lease`, but the detector only matches exact tokens in `FORCE_FLAGS`. Git also accepts `--force-with-lease=<ref>` / `--force-with-lease=<ref>:<expect>`; `git push --force-with-lease=main origin main` exits 0 from a feature branch — a real bypass.
*Suggestion:* block long force options on exact match **or** `--force-with-lease=` prefix; add a fixture for `git push --force-with-lease=main origin main`.

## Decisions (2026-06-05)

- **BLOCKER — Guard misses `--force-with-lease` value form:** **FIX.** Thomas: "fix please." Block long force options on exact match or `--force-with-lease=` / `--force-if-includes=` prefix, and add a guard-test fixture.

## Fixes (2026-06-05)

- **BLOCKER — `--force-with-lease` value form (FIXED):** added `FORCE_EQ_PREFIX = ("--force-with-lease=", "--force-if-includes=")` to [.claude/hooks/block-main-writes.sh](../.claude/hooks/block-main-writes.sh) and OR'd a `t.startswith(FORCE_EQ_PREFIX)` clause into the force-push detector. Added two fixtures to [tests/guard_test.sh](../tests/guard_test.sh): `--force-with-lease=main origin main` and `--force-with-lease=main:abc123 origin main`. Gate now 19/19.

## Build note (2026-06-05, re-review round 2)

Diff-only re-review, base = last-reviewed `58a02ff`. Delta = the BLOCKER fix only: `+FORCE_EQ_PREFIX` clause in the guard, 2 force-with-lease fixtures. `git diff --stat 58a02ff...HEAD`: 4 files, +31. Gate: 19/19 green.

## Open questions
1. **Guard severity / approach:** harden the string-matcher in place (faster, still fragile), or accept the report's framing that the doc overclaim ("bypass requires a diff-visible edit") is itself the defect and soften that claim alongside a best-effort harden? I propose: harden the known forms **and** soften the absolute claim, since string-matching can't be made airtight.
2. **Gate wiring:** the repo's `testCommand` is a placeholder (`echo … && true`). Do you want the new guard test wired in as the real gate, or left as a standalone script invoked manually?
3. **Mergeability wait (AC3):** acceptable to express this as a `gh pr view --json mergeStateStatus` poll in the recipe, or do you want a fixed simple "checks SUCCESS" check to keep the doctrine short?
