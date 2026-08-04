#!/usr/bin/env bash
# ── Documentation-consistency linter for the pluggable-reviewer seam ──
# THIS IS A LINTER, NOT A BEHAVIORAL GATE. Read this before adding to it.
#
# The reviewer seam (resolution, override parsing, dispatch, the second-backend stop) is
# *instructions Claude follows in Markdown skills*, not code. There is no
# function to call, no exit code, no output — so there is NO oracle, and this
# file CANNOT verify the seam's runtime behavior. All it can do is catch
# wording/typo drift: that the key phrases and the codex command tokens still
# exist where the skills expect them.
#
# Real verification of the seam lives elsewhere, by design:
#   • the independent reviewer's diff review (codex reads the actual change), and
#   • a human reading the skill instructions.
#
# DO NOT grow this into a pseudo-behavioral suite (per-block parsers, git-diff
# whitelists, exhaustive example enumeration). That is theater: it adds machinery
# and wording-coupling without adding an oracle. If you need a REAL gate, extract
# the thing into executable code and unit-test THAT.
#
# THAT FORCING EVENT HAS NOW HAPPENED, in part. The fireworks backend put context
# assembly, fan-out, the join, and artifact promotion into a real module, so those
# now have real oracles in tests/fireworks_runner_test.sh — put behavioral checks
# for anything the runner owns THERE, not here. What stays here is (a) the
# backend RESOLVER, which is still instructions plus a config value, exercised
# behaviorally in the first block below, and (b) drift pins on the skills' prose.
# The codex backend remains entirely prose, so it remains drift-only.
#
# Keep that split. A behavioral-looking check on Markdown is still theater.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REVIEW="$ROOT/.claude/skills/review/SKILL.md"
FRAME="$ROOT/.claude/skills/frame/SKILL.md"
AGENTS="$ROOT/AGENTS.md"
PROTOCOL="$ROOT/.claude/workflow-protocol.md"
WF="$ROOT/.claude/workflow.json"
BACKLOG="$ROOT/BACKLOG.md"

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
this_repo="$(resolve "$(cat "$WF")")"
case "$this_repo" in
  *"fireworks fireworks") ok "this repo routes correctness+hidden-failure to fireworks" ;;
  ERR) bad "this repo's reviewer value does not resolve: $this_repo" ;;
  *) bad "this repo's correctness altitude is not on fireworks: '$this_repo'" ;;
esac

echo "== drift: resolution rule + override are still documented =="
has "missing/empty ⇒ codex" "$REVIEW" "A missing or empty \`reviewer\` field ⇒ \`codex\`"
has "value set {codex, fireworks}" "$REVIEW" "one of \`{codex, fireworks}\`"
has "precedence override>config>default" "$REVIEW" "**beats** the default \`codex\`"
has "override documented" "$REVIEW" "Reviewer override (bare arg, order-independent)"
has "selection is per pass" "$REVIEW" "**Backend selection is per pass.**"
has "bare-string form still valid" "$REVIEW" "that backend for *every* pass"
has "absent pass ⇒ codex" "$REVIEW" "A pass absent from the map ⇒ \`codex\`"

echo "== drift: an unwired (pass, backend) pair is a loud stop, not a silent fallback =="
has "unwired stop message" "$REVIEW" "is not wired for the"
has "no codex fallback" "$REVIEW" "Do **not** fall back to codex"
has "stop is scoped to unwired, not to non-codex" "$REVIEW" "**Selecting a backend for a pass it is not wired for is a loud STOP**"
has "frame routes unwired design backend to stop" "$FRAME" "not wired for the design pass"
has "override cannot conjure wiring" "$REVIEW" "the override changes the selection, never the wiring"
absent "no dangling llm backend (review)" "$REVIEW" "\`llm\`"
absent "no dangling llm backend (frame)" "$FRAME" "\`llm\`"
# The retirement spans every doc that describes CURRENT behavior, not just the
# skills — README and ARCHITECTURE both documented `llm` as the second backend.
# (BACKLOG's OPS-11 analysis is a dated record and keeps its text, annotated.)
absent "README drops the retired backend" "$ROOT/README.md" "\`llm\`"
absent "ARCHITECTURE drops the retired backend" "$ROOT/ARCHITECTURE.md" "\`llm\`"
has "README documents the wired second backend" "$ROOT/README.md" "fireworks"
has "ARCHITECTURE documents the wired second backend" "$ROOT/ARCHITECTURE.md" "fireworks"
has "README shows the per-pass map form" "$ROOT/README.md" '"correctness": "fireworks"'
has "ARCHITECTURE states resolution is per pass" "$ROOT/ARCHITECTURE.md" "resolved **per pass**"

echo "== drift: codex command tokens still present (presence, not per-block) =="
has "codex exec -s read-only" "$REVIEW" "codex exec -s read-only"
has "approach schema abs path" "$REVIEW" '--output-schema "$HOME/.claude/skills/review/design-review-schema.json"'
has "correctness schema abs path" "$REVIEW" '--output-schema "$HOME/.claude/skills/review/finding-schema.json"'
has "approach -o repo-relative" "$REVIEW" "-o reviews/<slug>.approach.json"
has "correctness promoted to its artifact" "$REVIEW" '"$tmp_c" reviews/<slug>.codex.json'
has "codexModel passthrough" "$REVIEW" '${codexModel:+-m "$codexModel"}'
has "stdin guard </dev/null" "$REVIEW" "</dev/null"
has "frame design -o + schema" "$FRAME" "-o reviews/<slug>.design.json"

echo "== drift: the parallel hidden-failure critic is wired (concurrent, fail-closed, own schema) =="
# The correctness altitude now runs two critics at once. These are presence checks only — the seam
# is Markdown, so per this file's charter there is no behavioral oracle to assert.
has "correctness critic writes a temp" "$REVIEW" '-o "$tmp_c"'
has "hidden-failure critic writes a temp" "$REVIEW" '-o "$tmp_h"'
has "hidden-failure schema abs path" "$REVIEW" '--output-schema "$HOME/.claude/skills/review/hidden-failure-schema.json"'
has "hidden-failure critic own artifact" "$REVIEW" "reviews/<slug>.hidden-failure.json"
has "hidden-failure prompt scoped to one lens" "$REVIEW" "SCOPED TO ONE LENS"
has "per-PID join (correctness)" "$REVIEW" 'wait "$pid_c"'
has "per-PID join (hidden-failure)" "$REVIEW" 'wait "$pid_h"'
has "atomic promote gate" "$REVIEW" "temp→validate→promote invariant"
has "temps are reviews-local (same-fs atomic rename)" "$REVIEW" 'mktemp reviews/.<slug>.codex.XXXXXX'
has "hidden-failure temp is reviews-local too" "$REVIEW" 'mktemp reviews/.<slug>.hidden-failure.XXXXXX'
has "trap cleans unpromoted temps" "$REVIEW" "trap 'rm -f"
has "fail-closed: both critics required" "$REVIEW" "both critics are REQUIRED"
has "step-9 presents two labelled groups" "$REVIEW" "two labelled groups"
has "step-9 own Hidden-failure section" "$REVIEW" "Hidden-failure review"
# the dedicated schema ships as its own skill artifact
has "hidden-failure schema exists" "$ROOT/.claude/skills/review/hidden-failure-schema.json" "HIDDEN-FAILURE parallel critic"

echo "== drift: the fireworks dispatch is a THIN invocation, not a copied block =="
# The runner owns assembly/fan-out/join/promotion, so this skill must carry an
# invocation and nothing more. Real behavior lives in tests/fireworks_runner_test.sh;
# these are presence pins on the seam's prose, per this file's charter.
has "fireworks invocation present" "$REVIEW" "fireworks_runner.py"
has "invocation names the altitude" "$REVIEW" "--altitude correctness --slug <slug> --base <base>"
has "runner uses the bootstrapped interpreter" "$REVIEW" 'fireworks-venv/bin/python'
has "invocation passes -B" "$REVIEW" 'fireworks-venv/bin/python" -B'
has "the -B note states the real mechanism, not a wrong one" "$REVIEW" "cheap insurance, not load-bearing here"
# The promotion guarantee is stated at its true strength, not overclaimed. Thomas
# accepted the residual window (approach BLOCKER, 2026-08-03); these pin BOTH halves
# so neither the guarantee nor its limit can quietly disappear.
has "failed review publishes nothing" "$REVIEW" "**nothing** is published"
has "publication limit is stated, not overclaimed" "$REVIEW" "not one transaction across files"
has "the codex path is named as sharing the window" "$REVIEW" "The codex block below shares that window"
has "fireworks writes the same two artifacts" "$REVIEW" "reviews/<slug>.codex.json\`, \`reviews/<slug>.hidden-failure.json"
has "mixed-backend altitude is a stop" "$REVIEW" "Both passes must resolve to the **same** backend"
has "routing table is not restated in the skill" "$REVIEW" "Model routing lives in \`fireworks-models.json\`"
# The runner and its runtime contract must be present to be deployed by install.sh.
for f in fireworks_runner.py fireworks-models.json requirements.txt; do
  if [ -s "$ROOT/.claude/skills/review/$f" ]; then
    ok "backend artifact present: $f"
  else
    bad "backend artifact missing/empty: $f"
  fi
done
# The behavioral suite must actually be in the gate, or its oracles are dead weight.
if grep -qF "tests/fireworks_runner_test.sh" "$WF"; then
  ok "fireworks suite is in the configured gate"
else
  bad "fireworks suite absent from testCommand — its oracles would never run"
fi
# ...and in the AUTHORITATIVE one. CI is the server-side gate branch protection requires, so a CI
# list that drifts below the local list makes the stronger-looking check the weaker one. Behavioral:
# compares the two command strings rather than pinning either's wording.
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

echo "== drift: reviewer role language stays tool-neutral =="
has "approach prompt neutral" "$REVIEW" "You are the independent reviewer doing an APPROACH review"
has "correctness prompt neutral" "$REVIEW" "You are the independent reviewer defined in AGENTS.md"
has "design prompt neutral" "$FRAME" "You are the independent reviewer doing a DESIGN review"
absent "no 'You are Codex' (review)" "$REVIEW" "You are Codex"
absent "no 'You are Codex' (frame)" "$FRAME" "You are Codex"
absent "no 'have Codex' role phrase" "$REVIEW" "have Codex"
has "AGENTS.md neutral title" "$AGENTS" "independent reviewer contract"
absent "AGENTS.md drops 'You are Codex'" "$AGENTS" "You are **Codex**"

echo "== drift: the hidden-failure lens is named at both altitudes =="
has "correctness names hidden failure" "$AGENTS" "**Hidden failure:**"
has "design names failure-hiding as a shape flaw" "$AGENTS" "Hiding failure is a shape flaw"

echo "== drift: frame bootstrap seeds the reviewer field =="
has "bootstrap seeds reviewer=codex" "$FRAME" '"reviewer": "codex"'

echo "== drift: frame requires a falsification plan (spec-time, oracle-typed, executed at step 9) =="
# Presence pins only — the plan contract is Markdown instructions; per this file's charter the
# real enforcement is the step-6 reviewer critique and the step-9 demonstrate-red discipline.
has "step-5 per-AC regression required" "$FRAME" "name at least one plausible regression"
has "step-5 oracle modes typed" "$FRAME" 'reserve "the gate goes red" for `gate` oracles'
has "step-5 renders-nothing case" "$FRAME" "include the case where the element renders *nothing*"
has "step-5 mechanical N/A needs a reason" "$FRAME" "silence is not an option"
has "step-6 flags implementation-shaped plans" "$FRAME" "derived from an implementation shape"
has "step-9 demonstrate-red" "$FRAME" "demonstrate red before done"

echo "== drift: falsification rows are keyed (AC, surface), append-only, with declared exclusions =="
has "step-5 surface is a product place" "$FRAME" "where in the product the criterion is observable"
has "step-5 place-not-mechanism rule" "$FRAME" "A surface is a **place, not a mechanism**"
has "step-5 no circular oracles" "$FRAME" "**No circular oracles:**"
has "step-5 exclusions are three-valued" "$FRAME" "in exactly three permitted forms"
has "step-5 exclusions name product surfaces only" "$FRAME" "Exclusions name **product surfaces only**"
has "step-8 spec commit is the frozen baseline" "$FRAME" "falsification plan in this commit is the frozen baseline"
has "step-9 plan is append-only" "$FRAME" "The approved plan is append-only:"
has "step-9 amendment log required" "$FRAME" "## Falsification-plan amendments"
has "step-9 retract never remove" "$FRAME" "retracted, never removed"
has "step-6 flags mechanism-as-surface" "$FRAME" "rather than a place in the product"
has "step-5 mechanical waives detail not extent" "$FRAME" "The mechanical label waives the detail, never the extent claim"
absent "step-6 drops the impossible retraction duty" "$FRAME" "any retraction in the amendment log whose reason does not hold"
has "step-6 defers retractions by phase" "$FRAME" "Amendment-log retractions are **out of scope here**"
has "step-6 names OPS-18 as the retraction owner" "$FRAME" "that duty is OPS-18's"
# The handoff lives at TWO sites — the frame prompt defers it, BACKLOG.md accepts it. Pinning
# only the frame side leaves the receiving end deletable with the gate still green.
has "OPS-18 accepts amendment-log review" "$BACKLOG" "**Also owns amendment-log review**"
has "OPS-18 states the gap until it ships" "$BACKLOG" "Until OPS-18 ships, retraction reasons go unreviewed."

echo "== drift: consult-presentation rule stated in doctrine + pointed at from a stop =="
has "doctrine states consult-presentation rule" "$PROTOCOL" "How a consult is presented"
has "a stop points at the rule" "$REVIEW" "consult-presentation rule"

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL REVIEWER-SEAM LINT CHECKS PASSED (drift only — not a behavioral gate)"
