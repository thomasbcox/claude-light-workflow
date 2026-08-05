# claude-light-workflow — repo context

## What this repo ships

The product here is **tooling that runs inside other repos**. Every path listed in `install.sh`'s
`ARTIFACTS` array is deployed verbatim to `~/.claude/` and read by every project on this machine —
the four skills, the guard hook, `workflow-protocol.md`, and the reviewer-contract template.

Those consumer repos span many languages, stacks, and conventions. **None of them are visible from
inside this one** — not on the filesystem you are reading, not in the diff, not in the gate output.

## Before you judge, open the mapping

**Read `install.sh`'s `ARTIFACTS` block before ranking a technique, scoring a fit, or setting a
severity.** If the artifact under review is in that mapping, its blast radius is every repo, and
this repo's own language mix, test surface, and file layout are **not a representative sample** of
where it runs. A technique that fits poorly here may fit most consumers well, and a gap that looks
minor here may be estate-wide.

If you are nonetheless reasoning repo-locally — because the change genuinely is local, or because
local evidence is all you have — **say so explicitly** rather than letting a local conclusion pass
as a general one.

This is not hypothetical. It has failed in recorded history: see `BACKLOG.md` OPS-20, whose first
filing ranked four testing techniques by this repo's own Python/Markdown mix and had to be re-scoped
the same day.

## Related, stated elsewhere — don't restate

- The *reach vs. lightweight* tension this creates → `ROADMAP.md` → **Direction**.
- Why rules restated in several places drift → `BACKLOG.md` OPS-17.
- Why a change and its tests coming from one head is a defect class → `BACKLOG.md` OPS-20.
