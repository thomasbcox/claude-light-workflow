# Roadmap

The **strategic** view: where each part of the workflow is heading, and the open decisions that steer
it. It is deliberately **not** a status dashboard — per this repo's declared-vs-observed doctrine,
current status is owned elsewhere and read from there, not copied here:

- **Shipped capability** → git (the `merge: <slug>` history) and the [README](README.md) feature map.
- **Operational items** (bugs, tooling, audit findings) → [`BACKLOG.md`](BACKLOG.md), the loop's
  staging area (`BUG-` / `OPS-` / `AUDIT-`).
- **In-flight / parked detail** → the per-branch story files under `reviews/`.

This file carries only the layer nothing else owns: **direction** and **unresolved decisions**. It
links to the authorities above rather than re-asserting their state (so it can't drift from them).

---

## Theme: the loop (`/frame` · `/review` · `/close`)

The core is **stable and in daily use** (see the merge history + [`BACKLOG.md`](BACKLOG.md) → Done).
The live area of evolution is the **reviewer layer**: parallel, divided critics (the hidden-failure
lens shipped; further lenses and cross-model source diversity are staged in `OPS-12`), and wiring the
designated **second reviewer backend** (`llm`) beyond the currently-wired `codex`. Direction: keep the
loop *lightweight* — additions must earn their cost against that identity.

## Theme: recon (`/dev-audit` · `/deep-audit`)

`/dev-audit` (pre-loop recon) is shipped and stable. **`/deep-audit` is the estate's most substantial
in-flight bet** and the reason this roadmap exists:

- **Plan stage** — shipped (`→ BACKLOG OPS-13`, `reviews/deep-audit-plan.md`): a priced, deterministic
  whole-app audit plan, approved at a consult.
- **Execution engine** — the prose build is **parked** (`reviews/deep-audit-engine.md`) after a review
  loop surfaced that its guarantees out-ran what prose can enforce; the deterministic core is being
  rebuilt as a **tested shell library** (`reviews/deep-audit-lib.md`, in flight).
- **↳ Open decision (the big one): core / plugin / park.** deep-audit is a heavy subsystem (a full
  run of a small repo is priced near a million tokens) that `install.sh` would deploy to every
  project. Is it **core** (documented + budgeted, deployed everywhere), an **opt-in plugin**
  (decoupled from the lightweight loop), or **parked**? Unresolved; it gates further engine work.

## Theme: deployment & tooling

`install.sh` deploys the skills + hook globally with drift detection + provenance (`OPS-1/2/3`,
shipped); CI enforces the gate + secret scanning. The open work here is the **evaluate-and-decide**
backlog — reviewer-layer and workflow-discipline questions logged as `OPS-` items
(`→ BACKLOG.md`): frontmatter/tooling (`OPS-9`), the anti-pattern lens (`OPS-11`), parallel-critic
growth (`OPS-12`), prompt-code auditing (`OPS-15`), scope-AC and single-source discipline
(`OPS-16` / `OPS-17`), and whether a user story should anchor every cycle (`OPS-14`). Each is a
pointer, not restated here.

---

## Open decisions (the layer this file owns)

1. **deep-audit: core / plugin / park** — see the recon theme above. The largest open call.
2. **The `OPS-` prefix taxonomy** — a growing cluster of *reviewer-architecture* evaluate-and-decide
   items (`OPS-11/12/13/14/15`) sits under a prefix that nominally means shipping/tooling ergonomics.
   Whether they deserve their own prefix is a one-way door left open (`→ BACKLOG.md`, OPS-11's note).

For anything not listed here, the authorities are git (shipped), `BACKLOG.md` (operational), and the
`reviews/` story files (detail).
