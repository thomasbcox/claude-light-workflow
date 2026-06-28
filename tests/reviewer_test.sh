#!/usr/bin/env bash
# Gate test for the pluggable-reviewer seam (reviews/pluggable-reviewer.md).
# The seam lives in the Markdown skills + workflow.json, not in deployed code, so
# the gate asserts OBSERVABLE fixtures: the config field, the documented resolution
# rule + every documented example, the /review override, the agy loud-stop, the
# neutral role language, and the byte-preserved codex command envelope (asserted
# PER command block, so a flag dropped from one block can't be masked by another).
# (Codex design finding 1: prove the rule via fixtures, not a test-only resolver unit.)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REVIEW="$ROOT/.claude/skills/review/SKILL.md"
FRAME="$ROOT/.claude/skills/frame/SKILL.md"
AGENTS="$ROOT/AGENTS.md"
WF="$ROOT/.claude/workflow.json"

pass=0 fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; }

# has <label> <file> <literal-substring>     — passes if present
has()  { grep -qF -- "$3" "$2" && ok "$1" || bad "$1 (missing: $3)"; }
# absent <label> <file> <literal-substring>  — passes if NOT present
absent() { grep -qF -- "$3" "$2" && bad "$1 (should be gone: $3)" || ok "$1"; }

# block_has <label> <file> <anchor> <token>...
# Extracts the ```fenced block that contains <anchor> and asserts every <token>
# is inside THAT block — so an envelope flag missing from one command block is
# caught even if another block still carries the substring (AC4 false-green fix).
block_has() {
  local label="$1" file="$2" anchor="$3"; shift 3
  local blk
  blk=$(awk -v a="$anchor" 'BEGIN{inf=0;buf=""}
    /^[[:space:]]*```/ { inf=!inf; if(!inf){ if(index(buf,a)) printf "%s",buf; buf="" } next }
    inf { buf = buf $0 "\n" }' "$file")
  if [ -z "$blk" ]; then bad "$label (no fenced block contains: $anchor)"; return; fi
  local miss="" t
  for t in "$@"; do printf '%s' "$blk" | grep -qF -- "$t" || miss="$miss [$t]"; done
  [ -z "$miss" ] && ok "$label" || bad "$label (missing in block:$miss)"
}

echo "== AC1: config carries a valid reviewer; missing⇒codex + value-set documented =="
rv=$(/usr/bin/env python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("reviewer",""))' "$WF" 2>/dev/null)
case "$rv" in codex|agy) ok "workflow.json reviewer is '$rv' (valid)";; *) bad "workflow.json reviewer invalid/absent: '$rv'";; esac
has "missing/empty ⇒ codex documented"      "$REVIEW" "A missing or empty \`reviewer\` field ⇒ \`codex\`"
has "value validated to {codex, agy}"        "$REVIEW" "one of \`{codex, agy}\`"
has "invalid config value ⇒ stop"            "$REVIEW" "anything else is an error — say so and stop"

echo "== AC1/AC2: precedence + override examples (both token orders, invalid errors) =="
has "precedence: override beats config"      "$REVIEW" "**beats** \`reviewer\` in"
has "precedence: config beats default codex" "$REVIEW" "**beats** the default \`codex\`"
has "override documented (bare arg)"         "$REVIEW" "Reviewer override (bare arg, order-independent)"
has "example pass→reviewer"                  "$REVIEW" "/review approach agy"
has "example reviewer→pass (other order)"    "$REVIEW" "/review agy approach"
has "example reviewer-only"                  "$REVIEW" "/review agy"
has "example reviewer→correctness"           "$REVIEW" "/review correctness codex"
has "order-independent stated"               "$REVIEW" "in either order"
has "invalid override token errors"          "$REVIEW" "is an error — report it and stop"

echo "== AC5: agy is recognized but stops loudly — no fallback, no artifact =="
has "agy dispatch is a STOP"                 "$REVIEW" "**\`agy\`** *(not yet wired)* — **STOP**"
has "agy loud-stop message"                  "$REVIEW" "selected but not wired yet"
has "no codex fallback / no artifact"        "$REVIEW" "Do **not** fall back to codex"
has "frame routes agy to the stop"           "$FRAME"  "if it is \`agy\`, STOP per that section"

echo "== AC4: codex command envelope preserved — asserted PER command block =="
block_has "approach block envelope"    "$REVIEW" "-o reviews/<slug>.approach.json" \
  "codex exec -s read-only" \
  '--output-schema "$HOME/.claude/skills/review/design-review-schema.json"' \
  "-o reviews/<slug>.approach.json" '${codexModel:+-m "$codexModel"}' "</dev/null"
block_has "correctness block envelope" "$REVIEW" "-o reviews/<slug>.codex.json" \
  "codex exec -s read-only" \
  '--output-schema "$HOME/.claude/skills/review/finding-schema.json"' \
  "-o reviews/<slug>.codex.json" '${codexModel:+-m "$codexModel"}' "</dev/null"
block_has "frame design block envelope" "$FRAME" "-o reviews/<slug>.design.json" \
  "codex exec -s read-only" \
  '--output-schema "$HOME/.claude/skills/review/design-review-schema.json"' \
  "-o reviews/<slug>.design.json" '${codexModel:+-m "$codexModel"}' "</dev/null"

echo "== AC6: reviewer role language is tool-neutral in prompts + contract =="
has "approach prompt neutral"        "$REVIEW" "You are the independent reviewer doing an APPROACH review"
has "correctness prompt neutral"     "$REVIEW" "You are the independent reviewer defined in AGENTS.md"
has "design prompt neutral"          "$FRAME"  "You are the independent reviewer doing a DESIGN review"
absent "no 'You are Codex' in review"  "$REVIEW" "You are Codex"
absent "no 'You are Codex' in frame"   "$FRAME"  "You are Codex"
absent "no 'have Codex' role phrase"   "$REVIEW" "have Codex"
absent "no 'Codex independently review'" "$REVIEW" "Codex independently review"
has "AGENTS.md neutral title"        "$AGENTS" "independent reviewer contract"
absent "AGENTS.md drops 'You are Codex'" "$AGENTS" "You are **Codex**"

echo "== frame bootstrap writes the reviewer field for new repos =="
has "bootstrap seeds reviewer=codex" "$FRAME" '"reviewer": "codex"'

echo "== AC7: scope containment (self-limiting — only on this story's branch) =="
# Runs the whitelist only when the pluggable-reviewer story file is in the diff, so
# this permanent gate is a no-op on every OTHER branch and after merge. The workflow's
# own reviews/pluggable-reviewer.* trail artifacts are exempt (they are written by the
# loop, not enumerated as product files). Base ref is resolved from baseBranch and
# accepts <base> OR origin/<base>; if NEITHER resolves we refuse to false-green.
base=$(/usr/bin/env python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("baseBranch","main"))' "$WF" 2>/dev/null); base=${base:-main}
base_ref=""
for cand in "$base" "origin/$base"; do
  if git -C "$ROOT" rev-parse --verify -q "$cand" >/dev/null 2>&1; then base_ref="$cand"; break; fi
done
if [ -z "$base_ref" ]; then
  bad "AC7 cannot resolve base ref ('$base' or 'origin/$base') — scope unverifiable, refusing to skip-as-pass"
else
  changed=$(git -C "$ROOT" diff --name-only "$base_ref"...HEAD 2>/dev/null)
  if printf '%s\n' "$changed" | grep -qx "reviews/pluggable-reviewer.md"; then
    WL='^(\.claude/skills/(frame|review|close)/SKILL\.md|\.claude/workflow\.json|\.claude/workflow-protocol\.md|AGENTS\.md|ARCHITECTURE\.md|README\.md|tests/reviewer_test\.sh|reviews/pluggable-reviewer\..*)$'
    extra=$(printf '%s\n' "$changed" | grep -vE "$WL" || true)
    if [ -z "$extra" ]; then ok "diff ⊆ whitelist ∪ reviews/pluggable-reviewer.* (base $base_ref)"; else bad "AC7 out-of-scope files:
$extra"; fi
  else
    ok "AC7 scope check skipped (not the pluggable-reviewer branch)"
  fi
fi

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL REVIEWER TESTS PASSED"
