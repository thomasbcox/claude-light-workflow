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
# the resolver/arg-parser/adapter into executable code (the heavy-seam follow-up,
# which the llm backend will force anyway) and unit-test THAT.
#
# Exactly one check below is genuinely behavioral — the workflow.json value parse.
# Everything else is drift detection. Keep it that way.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REVIEW="$ROOT/.claude/skills/review/SKILL.md"
FRAME="$ROOT/.claude/skills/frame/SKILL.md"
AGENTS="$ROOT/AGENTS.md"
PROTOCOL="$ROOT/.claude/workflow-protocol.md"
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

echo "== behavioral: workflow.json reviewer parses to a valid backend =="
rv=$(/usr/bin/env python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("reviewer",""))' "$WF" 2>/dev/null)
case "$rv" in codex | llm) ok "reviewer='$rv' is valid" ;; *) bad "reviewer invalid/absent: '$rv'" ;; esac

echo "== drift: resolution rule + override are still documented =="
has "missing/empty ⇒ codex" "$REVIEW" "A missing or empty \`reviewer\` field ⇒ \`codex\`"
has "value set {codex, llm}" "$REVIEW" "one of \`{codex, llm}\`"
has "precedence override>config>default" "$REVIEW" "**beats** the default \`codex\`"
has "override documented" "$REVIEW" "Reviewer override (bare arg, order-independent)"

echo "== drift: the second backend (llm) is a loud stop, not a silent fallback =="
has "llm stop message" "$REVIEW" "selected but not wired yet"
has "no codex fallback" "$REVIEW" "Do **not** fall back to codex"
has "frame routes non-codex to stop" "$FRAME" "if it is \`llm\` (or any non-codex backend), STOP per that section"

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
has "fail-closed: both critics required" "$REVIEW" "both critics are REQUIRED"
has "step-9 presents two labelled groups" "$REVIEW" "two labelled groups"
has "step-9 own Hidden-failure section" "$REVIEW" "Hidden-failure review"
# the dedicated schema ships as its own skill artifact
has "hidden-failure schema exists" "$ROOT/.claude/skills/review/hidden-failure-schema.json" "HIDDEN-FAILURE parallel critic"

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

echo "== drift: consult-presentation rule stated in doctrine + pointed at from a stop =="
has "doctrine states consult-presentation rule" "$PROTOCOL" "How a consult is presented"
has "a stop points at the rule" "$REVIEW" "consult-presentation rule"

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL REVIEWER-SEAM LINT CHECKS PASSED (drift only — not a behavioral gate)"
