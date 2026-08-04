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
- **Recon** (`/dev-audit`) complements the diff-scoped loop by sizing up an unfamiliar repo before
  the loop runs. The **whole-app, multi-lens** sweep the loop cannot give remains a real gap, but the
  subsystem built for it was stood down (see below) — the gap is acknowledged, not staffed.
- **Deployment** is **global-by-design** — authored here, `install.sh` → every project — with drift
  detection and a CI gate. The standing tension it manages is *reach* vs. the *lightweight* identity.

## Open decisions

1. **Whole-app audit: if it returns, in what form?** The core/plugin/park question is **answered —
   parked.** The subsystem was heavy (a full run of even a small repo priced near a million tokens)
   and global deploy would have reached every project; the engine and library were retired 2026-08-03
   and the surviving plan stage 2026-08-04, all preserved as `retired/deep-audit-*` tags. What stays
   open is the underlying need: judgment-level lenses never sweep old, cold code, and nothing covers
   that today. If it returns it should return as an **opt-in plugin**, decoupled from the light loop
   — but that is a direction, not a commitment. Design record: `BACKLOG.md` OPS-13.
2. **The `OPS-` prefix taxonomy.** A growing cluster of *reviewer-architecture* evaluate-and-decide
   items sits under a prefix that nominally means shipping/tooling ergonomics. Whether they deserve
   their own prefix is a one-way door left open (see `BACKLOG.md`).

For current status of anything above, follow the pointers at the top — not this file.
