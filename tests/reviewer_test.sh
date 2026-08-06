#!/usr/bin/env bash
# ── Reviewer-seam checks: a small behavioral core + a deliberately short pin set ──
# READ THIS BEFORE ADDING TO IT. This file was cut from ~91 wording pins to the set below
# (thin-the-loop, 2026-08-04). Re-growing it undoes work that was done on evidence.
#
# THE BAR FOR A PIN — two tiers, and only two.
#
# TIER 1, BEHAVIOR GUARDS — every block below except the last. A `has`/`absent` grep on
# Markdown earns its place ONLY if its silent failure would let BEHAVIOR degrade unnoticed.
# Ask: "if this phrase quietly disappeared, what would go wrong, and would anyone find out?"
# If the answer is "the docs would read slightly differently", it is not a pin — delete it.
# If the answer is "reviews would silently run on the wrong backend / publish partial
# artifacts / get write access", pin it.
#
# TIER 2, DECISION GUARDS — the last block only, and CLOSED. These do NOT guard behavior and
# do not claim to. They guard one thing: that a construct deliberately DELETED on evidence has
# not been pasted back without a fresh argument. Admission requires all three: the construct
# was removed by an approved story; the pin is `absent`, never `has` (it guards a deletion,
# not a wording); and it names that story, so the argument is one link away. "It would be nice
# to know if this changed" is not a decision guard — if you cannot point at an approved
# deletion, you are writing a tier-1 pin and tier 1's bar applies. Tier 2 is also not a
# substitute for review: reworded regrowth gets past it by design.
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
# The design-pass prompt exists in TWO copies — one per backend — and this repo routes its
# design pass to fireworks, so the Python copy is the one that actually executes here.
RUNNER="$ROOT/.claude/skills/review/fireworks_runner.py"
DESIGN_SCHEMA="$ROOT/.claude/skills/review/design-review-schema.json"

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
eq "this repo routes all four passes to fireworks" \
  "fireworks fireworks fireworks fireworks" "$(resolve "$(cat "$WF")")"

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
# PINS. Everything below is a grep on Markdown. TIER 1 (behavior guards) runs from
# here through the demonstrate-red block; the FINAL block is the closed TIER 2 set.
# Every pin states the reason it survived. Nothing outside the two tiers qualifies.
# ─────────────────────────────────────────────────────────────────────────────

echo "== pin: a bad (pass, backend) pairing is a loud stop, never a silent fallback =="
# Silent failure: the review quietly runs on a backend the pass was never wired for, or
# falls back to codex without saying so. Either way Thomas reads findings believing they
# came from the backend he selected. Both sites are pinned — the stop is stated in
# review/SKILL.md and routed to from frame/SKILL.md's design pass.
has "no codex fallback" "$REVIEW" "Do **not** fall back to codex"
has "stop is scoped to unwired, not to non-codex" "$REVIEW" "**Selecting a backend for a pass it is not wired for is a loud STOP**"
# Every pass is wired at both backends as of 2026-08-04, so nothing trips the stop today.
# That is exactly when a rule gets "simplified" away — and the next partially-wired backend
# would then fall back silently instead of stopping. Pin the note that says keep it.
has "unreachable-but-kept is stated, not left to be inferred" "$REVIEW" "there is no unwired pair"
has "frame still routes an unwired design backend to the stop" "$FRAME" "not wired for the design pass, STOP"
# The MIXED-pair stop is a DIFFERENT failure from the unwired one above: there both backends
# are fine but one is not wired for its pass; here both are wired and simply differ, splitting
# ONE altitude's findings across two models with no reconciliation rule. Silent failure: the
# round returns two partial finding sets and reads as a complete review. Restored after the
# thin-the-loop prune dropped it — a hidden-failure critic caught the omission (2026-08-04).
# The resolver check above pins THIS repo's config exactly, but the skill deploys globally, so
# this pin guards the instruction that travels to every project.
has "mixed-backend altitude is a stop" "$REVIEW" "Both passes must resolve to the **same** backend"

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

echo "== pin: regressions come from the REVIEWER, not the author (OPS-20 option 3) =="
# Silent failure: the design pass stops being asked for regressions, or the write-back stops
# checking coverage, and the mechanism no-ops while stories still look compliant — the author
# is back to writing both the regression list and the tests that judge it, which is the exact
# single-head coupling this was built to break. Nothing else would surface that.
# BOTH backend copies of the ask are pinned: this repo routes `design` to fireworks, so
# pinning only the Markdown copy would protect the variant that never runs here.
has "design ask, codex copy" "$FRAME" "propose at least one plausible regression"
has "design ask, fireworks copy" "$RUNNER" "propose at least one plausible regression"
has "step-5 defers regressions to the reviewer" "$FRAME" "sourced from the step-6 design review"
has "step-6 write-back checks coverage" "$FRAME" "check every AC received at least one"
has "step-7 can send a gapped review back" "$FRAME" "send the design review back"
# Round-1 QUESTION: the mechanism-critique half of the old test-notes sentence was dropped when
# the regression ask replaced it — the author still assigns oracle + mechanism at step 5, so that
# critique was never moot. Restored and pinned in BOTH copies, since either backend may run it.
has "mechanism critique, codex copy" "$FRAME" "any criterion whose named oracle cannot fail"
has "mechanism critique, fireworks copy" "$RUNNER" "any criterion whose named oracle cannot fail"

# Structural, not a phrase: the schema is real code with a real oracle, so read the JSON and
# assert the field is required rather than grepping for text that could drift independently.
schema_requires() { # <field> → yes/no/ERR
  /usr/bin/env python3 - "$DESIGN_SCHEMA" "$1" <<'PY' 2>/dev/null || echo ERR
import json, sys
print("yes" if sys.argv[2] in json.load(open(sys.argv[1]))["required"] else "no")
PY
}
eq "design-review-schema requires 'regressions' (structural)" "yes" "$(schema_requires regressions)"

echo "== pin: computed extents (OPS-20 option 4) =="
# Silent failure: the rule vanishes and future stories hand-type extents that stop covering
# what they name the moment the source grows — the drift is invisible precisely because the
# check still passes. The caveat is pinned separately: a rewrite can keep the headline rule
# and drop the vacuity warning, which is the failure mode that makes a derived extent useless.
has "computed-extents rule" "$FRAME" "derive that extent from the source"
has "vacuous-extent caveat" "$FRAME" "passes vacuously"

echo "== pin: the shared contract has ONE home and is never copied into a repo =="
# Silent failure: a repo-level AGENTS.md becomes the contract again and drift returns — the
# defect this arrangement exists to remove. Structural, and derived from BOTH authoritative
# sources: install.sh's ARTIFACTS for what deploys, and the runner's own CONTRACT_PATH for
# what is read. Comparing the two is the point — a destination that no longer matches what
# the runner reads means the file installed is not the file used.
contract_wiring() {
  /usr/bin/env python3 "$ROOT/tests/check_contract_wiring.py" "$ROOT" 2>/dev/null || echo ERR
}
eq "install deploys exactly the contract the runner reads, and no AGENTS.md" \
  "deployed no-agents-md repo-file-absent" "$(contract_wiring)"

echo "== pin: the rejected-lessons register stays out of routine context =="
# TIER 1, and the reason this pin exists rather than the dozen sibling wording pins that
# were considered and left out (lesson-proposals, 2026-08-06): the register holds claims
# Thomas REJECTED, kept only so their reasoning survives. Its whole containment story is
# that exactly one instruction reads it — the novelty check in /close. A pointer grown
# later in another skill, the protocol, or a skill description would silently put every
# rejected claim back into routine context, and nothing would surface that it had. That is
# behavior degrading unnoticed, which is this file's bar.
#
# Enumerated over EVERY deployed text path, not just /close. A one-file check is
# relocation-blind: the leak is precisely the pointer that appears somewhere else.
REGISTER=".aar/rejected-lessons.md"
CLOSE="$ROOT/.claude/skills/close/SKILL.md"
if grep -qF -- "$REGISTER" "$CLOSE"; then
  ok "the /close lesson check names the register"
else
  bad "/close no longer names $REGISTER — the novelty check cannot read what it is not told"
fi
# Deployed text paths, derived from install.sh's ARTIFACTS rather than retyped: a hand-typed
# list stops covering what it names the moment the artifact set grows.
leak=0
while IFS= read -r rel; do
  [ -e "$ROOT/$rel" ] || continue
  while IFS= read -r f; do
    case "$f" in "$CLOSE") continue ;; esac
    if grep -qF -- "$REGISTER" "$f"; then
      bad "deployed file references the rejected register outside /close: ${f#"$ROOT"/}"
      leak=1
    fi
  done <<EOF
$(find "$ROOT/$rel" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' -o -name '*.json' \) 2>/dev/null)
EOF
done <<EOF
$(sed -n 's/^  "\([^:]*\)::.*/\1/p' "$ROOT/install.sh")
EOF
[ "$leak" = "0" ] && ok "no other deployed file points at the rejected register"

echo "== pin: handling a lesson never writes to a deployed artifact =="
# TIER 1. The containment property lesson-proposals calls load-bearing: at runtime, proposing
# or approving a lesson touches no file install.sh deploys and not .claude/workflow.json. The
# observational half needs a branch where a lesson actually ran and is filed as OPS-28; this
# static half can fail today. Silent failure: /close grows an instruction to edit a deployed
# path during lesson handling, and the loop starts rewriting its own rules estate-wide.
lesson_block="$(sed -n '/^3b\. \*\*Lesson check/,/^4\. \*\*Re-review fork/p' "$CLOSE")"
if [ -z "$lesson_block" ]; then
  bad "cannot locate the /close lesson-check step — the containment check has nothing to read"
else
  writes=0
  for p in "workflow-protocol.md" "workflow-AGENTS.md" ".claude/workflow.json" "hooks/block-main-writes.sh"; do
    printf '%s' "$lesson_block" | grep -qF -- "$p" && { bad "lesson step references a deployed/config path: $p"; writes=1; }
  done
  [ "$writes" = "0" ] && ok "the lesson step names no deployed artifact or workflow config"
fi

echo "== TIER 2 (decision guards): the retired falsification machinery has not crept back =="
# THE CLOSED TIER-2 BLOCK — see the header. Not behavior guards, and they do not claim to be.
# Each construct below was deleted on stated evidence by an approved story (thin-the-loop,
# 2026-08-04, reviews/thin-the-loop.md); if one reappears, that should be a deliberate choice
# carrying a fresh argument, not an unnoticed regrowth of ~40 lines of instruction weight.
# Reworded regrowth gets past these by design — that case is the reviewer's, not a grep's.
absent "no (AC, surface) matrix" "$FRAME" "surfaces excluded"
absent "no place-not-mechanism rule" "$FRAME" "place, not a mechanism"
absent "no three-form exclusion declaration" "$FRAME" "in exactly three permitted forms"
absent "no circular-oracle clause" "$FRAME" "No circular oracles"
absent "no append-only amendment log" "$FRAME" "Falsification-plan amendments"

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL REVIEWER-SEAM CHECKS PASSED (small behavioral core + a short, reasoned pin set)"
