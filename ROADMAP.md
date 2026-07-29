# Roadmap

**Direction and open decisions only.** This file deliberately carries *no lifecycle status* — that is
owned elsewhere and read from there, per the repo's declared-vs-observed doctrine:

- **Shipped capability** → git (`merge:` history) + the [README](README.md) feature map.
- **Operational items** (`BUG-` / `OPS-` / `AUDIT-`) → [`BACKLOG.md`](BACKLOG.md), the loop's staging area.
- **In-flight / parked detail** → the per-branch story files under `reviews/`.

What follows is the durable layer those authorities don't own: where each theme is *headed*, and the
choices that are still open. It needs no update when a merge lands or a backlog item moves.

## Direction

- **The loop** (`/frame` · `/review` · `/close`) stays deliberately **lightweight** — new capability
  must earn its cost against that identity. Its active area of evolution is the **reviewer layer**:
  divided parallel critics, and diversifying the reviewer **backend** beyond the single wired one.
- **Recon** (`/dev-audit` · `/deep-audit`) complements the diff-scoped loop: `/dev-audit` sizes up an
  unfamiliar repo before the loop; `/deep-audit` aims at the occasional **whole-app, multi-lens** sweep
  the loop cannot give. Its deterministic core is being pushed toward tested code rather than prose.
- **Deployment** is **global-by-design** — authored here, `install.sh` → every project — with drift
  detection and a CI gate. The standing tension it manages is *reach* vs. the *lightweight* identity.

## Open decisions

1. **deep-audit: core / plugin / park.** deep-audit is a heavy subsystem (a full run of even a small
   repo prices near a million tokens) that global deploy would reach every project. Is it **core**
   (documented + budgeted, everywhere), an opt-in **plugin** (decoupled from the light loop), or
   **parked**? Unresolved; it gates further engine work.
2. **The `OPS-` prefix taxonomy.** A growing cluster of *reviewer-architecture* evaluate-and-decide
   items sits under a prefix that nominally means shipping/tooling ergonomics. Whether they deserve
   their own prefix is a one-way door left open (see `BACKLOG.md`).

For current status of anything above, follow the pointers at the top — not this file.
