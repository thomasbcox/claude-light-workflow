Date: 2026-07-17 · Branch: claude/ops12-begun · Status: approved

# ops12-begun — mark OPS-12 begun (not done)

## Problem

OPS-12's status line read "shape decided; build imminent." Its **first build shipped** on 2026-07-17
(the hidden-failure critic — `merge: parallel-critic`, PR #32). "Imminent" is now stale, and the item
is neither still-pending nor fully done: further lenses and `llm`-backend source diversity remain.
Thomas's call (2026-07-17): mark OPS-12 **begun, not done**.

## In scope

- Update OPS-12's status wording in `BACKLOG.md` to **BEGUN (not done)** — first build shipped, layer
  continuing — with a pointer to `merge: parallel-critic` / PR #32.

## Non-goals

- **Not** moving OPS-12 to **Done** — future lenses + `llm` source diversity are unbuilt.
- **Not** touching any other backlog item or any product code.

## Acceptance criteria

1. OPS-12's header and closing log line read **begun / not done**, citing the shipped first build
   (`merge: parallel-critic`, PR #32).
2. OPS-12 **stays in the active list**, not under Done.
3. **Scope containment:** the diff touches only `BACKLOG.md` and `reviews/ops12-begun.md`.

## Test notes

- **AC1/AC2** — read the OPS-12 entry; confirm "begun"/"not done" wording and that it is not under the
  Done section.
- **AC3** — `git diff --name-only main...HEAD` lists only `BACKLOG.md` and `reviews/ops12-begun.md`.
- Full gate (`bash tests/guard_test.sh && bash tests/reviewer_test.sh && bash tests/dev_audit_test.sh`)
  stays green — this change touches no code.

## Design sketch — HOW

N/A — mechanical (a documentation status edit; no new structure, pattern, or dependency). The
frame-time design review is a noted skip.
