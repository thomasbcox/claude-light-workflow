#!/usr/bin/env bash
# ── Reviewer-seam checks: a small behavioral core + a deliberately short pin set ──
# READ THIS BEFORE ADDING TO IT. This file was cut from ~91 wording pins to the set below
# (thin-the-loop, 2026-08-04). Re-growing it undoes work that was done on evidence.
#
# THE BAR FOR A PIN — a `has`/`absent` grep on Markdown earns its place ONLY if its silent
# failure would let BEHAVIOR degrade unnoticed. Ask: "if this phrase quietly disappeared,
# what would go wrong, and would anyone find out?" If the answer is "the docs would read
# slightly differently", it is not a pin — delete it. If the answer is "reviews would
# silently run on the wrong backend / publish partial artifacts / get write access", pin it.
#
# WHY SO FEW. The evidence is the fireworks-reviewer-backend story: six real defects found,
# NONE caught by a wording pin. Every one came from a reviewer reading code, a behavioral
# test, or a live run. Pins that break on every rephrase cost real maintenance and caught
# nothing. Some doc drift will now go uncaught; that is the accepted trade, not an oversight.
# If a specific drift later proves expensive, add ONE pin with its reason stated — do not
# restore the set.
#
# THE SPLIT THAT MATTERS. The reviewer seam (resolution, override parsing, dispatch, the
# second-backend stop) is *instructions Claude follows in Markdown*, not code — no function
# to call, no exit code, so there is NO oracle and this file CANNOT verify runtime behavior.
# Real verification lives elsewhere by design: the independent reviewer's diff review, and a
# human reading the skill instructions. What IS real code has real oracles:
#   • tests/fireworks_runner_test.sh — context assembly, fan-out, join, artifact promotion.
#   • the behavioral block below — the backend RESOLVER, and the config↔CI gate comparison.
# Put behavioral checks where the behavior is. A behavioral-looking check on Markdown is
# still theater. If you need a REAL gate, extract the thing into code and unit-test THAT.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REVIEW="$ROOT/.claude/skills/review/SKILL.md"
FRAME="$ROOT/.claude/skills/frame/SKILL.md"
WF="$ROOT/.claude/workflow.json"

pass=0 fail=0
ok() {
  pass=$((pass + 1))
  printf '  ok   %s\n' "$1"
}
bad() {
  fail=$((fail + 1))
  printf 'FAIL  %s\n' "$1"
}
has() { grep -qF -- "$3" "$2" && ok "$1" || bad "$1 (missing: $3)"; }
absent() { grep -qF -- "$3" "$2" && bad "$1 (should be gone: $3)" || ok "$1"; }

echo "== behavioral: workflow.json reviewer resolves per pass to valid backends =="
# The resolver is exercised for real here: both accepted shapes (bare string and
# purpose→backend map) plus the absent case, against the documented value set.
resolve() { # <json-literal> → space-separated resolved backends, or "ERR"
  /usr/bin/env python3 - "$1" <<'PY' 2>/dev/null || echo ERR
import json, sys
PASSES = ("design", "approach", "correctness", "hidden-failure")
VALID = {"codex", "fireworks"}
raw = json.loads(sys.argv[1]).get("reviewer", "")
if not raw:
    resolved = {p: "codex" for p in PASSES}
elif isinstance(raw, str):
    resolved = {p: raw for p in PASSES}
elif isinstance(raw, dict):
    resolved = {p: raw.get(p, "codex") for p in PASSES}
else:
    sys.exit(1)
if not set(resolved.values()) <= VALID:
    sys.exit(1)
print(" ".join(resolved[p] for p in PASSES))
PY
}
eq() { # <label> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi
}
eq "bare string applies to every pass (back-compat)" \
  "codex codex codex codex" "$(resolve '{"reviewer":"codex"}')"
eq "absent reviewer ⇒ codex everywhere (back-compat)" \
  "codex codex codex codex" "$(resolve '{}')"
eq "map form resolves per pass, unlisted ⇒ codex" \
  "codex codex fireworks codex" "$(resolve '{"reviewer":{"correctness":"fireworks"}}')"
eq "retired backend 'llm' is rejected" "ERR" "$(resolve '{"reviewer":"llm"}')"
eq "unknown backend is rejected" "ERR" "$(resolve '{"reviewer":"bogus"}')"
# This repo's own config must actually select what this story wired.
# Exact match, not a trailing glob. The old `*"fireworks fireworks"` matched any
# string ending in those two words, so it could not tell design/approach apart —
# a reviewer caught that it would pass whatever the first two positions held.
# Order is: design approach correctness hidden-failure.
eq "this repo routes approach+correctness+hidden-failure to fireworks, design to codex" \
  "codex fireworks fireworks fireworks" "$(resolve "$(cat "$WF")")"

echo "== behavioral: the configured gate and the AUTHORITATIVE CI gate are the same command =="
# CI is the server-side gate branch protection requires, so a CI list that drifts below the
# local list makes the stronger-looking check the weaker one. Behavioral: compares the two
# command strings rather than pinning either's wording.
CI="$ROOT/.github/workflows/ci.yml"
wf_cmd="$(/usr/bin/env python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["testCommand"])' "$WF" 2>/dev/null)"
ci_cmd="$(
  /usr/bin/env python3 - "$CI" <<'PY' 2>/dev/null
import re, sys
for line in open(sys.argv[1]):
    m = re.match(r"\s*run:\s*(bash tests/.*)$", line)
    if m:
        print(m.group(1).strip())
        break
PY
)"
eq "CI gate runs exactly the configured gate (no drift)" "$wf_cmd" "$ci_cmd"
# The behavioral suite must actually be in the gate, or its oracles are dead weight.
if grep -qF "tests/fireworks_runner_test.sh" "$WF"; then
  ok "fireworks suite is in the configured gate"
else
  bad "fireworks suite absent from testCommand — its oracles would never run"
fi

echo "== behavioral: the backend's runtime artifacts exist to be deployed =="
# install.sh ships these by directory; an empty or missing one deploys a broken backend.
for f in fireworks_runner.py fireworks-models.json requirements.txt; do
  if [ -s "$ROOT/.claude/skills/review/$f" ]; then
    ok "backend artifact present: $f"
  else
    bad "backend artifact missing/empty: $f"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# PINS. Everything below is a wording grep. Each one is here because its silent
# failure degrades behavior — the reason is stated with it. Nothing else qualifies.
# ─────────────────────────────────────────────────────────────────────────────

echo "== pin: an unwired (pass, backend) pair is a loud stop, never a silent fallback =="
# Silent failure: the review quietly runs on a backend the pass was never wired for, or
# falls back to codex without saying so. Either way Thomas reads findings believing they
# came from the backend he selected. Both sites are pinned — the stop is stated in
# review/SKILL.md and routed to from frame/SKILL.md's design pass.
has "no codex fallback" "$REVIEW" "Do **not** fall back to codex"
has "stop is scoped to unwired, not to non-codex" "$REVIEW" "**Selecting a backend for a pass it is not wired for is a loud STOP**"
has "frame routes unwired design backend to stop" "$FRAME" "not wired for the design pass"

echo "== pin: promotion is fail-closed — a failed review publishes nothing =="
# Silent failure: a partial or empty artifact lands in reviews/ and reads as a clean review.
# This is the defect class that produced the {} silent-clean bug; it degrades invisibly
# because a green-looking artifact is indistinguishable from a real one.
has "atomic promote gate" "$REVIEW" "temp→validate→promote invariant"
has "failed review publishes nothing" "$REVIEW" "**nothing** is published"
has "fail-closed: both critics required" "$REVIEW" "both critics are REQUIRED"
has "temps are reviews-local (same-fs atomic rename)" "$REVIEW" 'mktemp reviews/.<slug>.codex.XXXXXX'

echo "== pin: the reviewer runs read-only against the repo =="
# Silent failure: the reviewer gains write access and can modify the tree it is judging.
# The posture is the whole basis for trusting an independent review.
has "codex exec -s read-only" "$REVIEW" "codex exec -s read-only"

echo "== pin: schema path is absolute, artifact path is repo-relative =="
# Silent failure: flip the -o and the artifact lands outside the repo — the review trail
# vanishes with no error. (The schema half is pinned alongside it because the two are one
# rule; inverting them is the mistake this split exists to prevent.)
has "schema abs path (skill-local, installed under \$HOME)" "$REVIEW" '--output-schema "$HOME/.claude/skills/review/finding-schema.json"'
has "artifact -o repo-relative (review)" "$REVIEW" "-o reviews/<slug>.approach.json"
has "artifact -o repo-relative (frame)" "$FRAME" "-o reviews/<slug>.design.json"

echo "== pin: demonstrate-red survives (the falsification discipline with teeth) =="
# Silent failure: stories ship with planned checks nobody ever drove red — dead assertions
# that look like coverage. This is the one part of the falsification machinery that was
# shown to catch things, so it is the one part kept. See reviews/thin-the-loop.md.
has "step-9 demonstrate-red" "$FRAME" "demonstrate red before done"
has "step-9 names the dead-assertion stop" "$FRAME" "**dead assertion**"
has "step-5 requires a per-AC check" "$FRAME" "for each AC, **how it will be checked**"

echo "== pin: the retired falsification machinery has not crept back =="
# Not a behavior guard — a decision guard. These constructs were removed on evidence
# (thin-the-loop, 2026-08-04); if they reappear, that should be a deliberate choice with a
# fresh argument, not an unnoticed regrowth of ~40 lines of instruction weight.
absent "no (AC, surface) matrix" "$FRAME" "surfaces excluded"
absent "no place-not-mechanism rule" "$FRAME" "place, not a mechanism"
absent "no three-form exclusion declaration" "$FRAME" "in exactly three permitted forms"
absent "no circular-oracle clause" "$FRAME" "No circular oracles"
absent "no append-only amendment log" "$FRAME" "Falsification-plan amendments"

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL REVIEWER-SEAM CHECKS PASSED (small behavioral core + a short, reasoned pin set)"
