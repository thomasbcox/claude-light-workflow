#!/usr/bin/env bash
# deep-audit-lib.sh — the tested deterministic core of the deep-audit subsystem.
#
# One CLI library both /deep-audit and (later) /deep-audit-run call, so every
# deterministic rule — the source fingerprint, the exact unit-resolution, Table P
# compilation, and the plan validator — exists exactly ONCE, in code, with a real
# behavioral test suite (tests/deep_audit_lib_test.sh). This is the substrate that
# replaces prose-asserted algorithms: a rule is enforced here or it is not enforced.
#
# Contract: JSON in, exit status out. A subcommand exits NONZERO on any violation;
# the skills' prose is "run deep-audit-lib.sh <cmd> …; nonzero ⇒ STOP loudly."
#
# Subcommands (plan-side slice; execute-side lands with the engine story):
#   fingerprint <root>                       source digest (mode-aware, NUL-safe)
#   resolve-units <depth> <codeUnitId…>      exact unit resolution
#   compile-plan <target> <profile.json> …   Table-P compiler (derives from target)
#   check-plan <plan.json>                   canonical shape+semantic validator
set -euo pipefail

die() {
  echo "deep-audit-lib: $*" >&2
  exit 2
}

# ── fingerprint <root> ───────────────────────────────────────────────────────
# Canonical NUL-safe stream: <exec-bit> <working-tree-content-hash> <path>, over
# non-reviews/** tracked files. exec-bit = x|- read from the WORKING TREE (test -x)
# so even an unstaged chmod registers; hash-object captures working-tree content so
# unstaged edits register; DELETED marks a removed working file. Excluding reviews/**
# stops an in-repo plan commit from self-invalidating the digest.
da_fingerprint() {
  local root="${1:?usage: fingerprint <root>}"
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || die "fingerprint: not a git repo: $root"
  git -C "$root" ls-files -z -- ':!reviews/' |
    while IFS= read -r -d '' p; do
      bit=-
      [ -x "$root/$p" ] && bit=x
      printf '%s %s %s\0' "$bit" "$(git -C "$root" hash-object -- "$p" 2>/dev/null || printf DELETED)" "$p"
    done | LC_ALL=C sort -z | shasum -a 256 | cut -d' ' -f1
}

# ── resolve-units <depth> <codeUnitId…> ──────────────────────────────────────
# The EXACT resolution the compiler and the engine both use: standard/deep run the
# full ordered list; light runs the pinned every-3rd sample (indices 0,3,6,…). One
# unit id per output line; empty input → empty output.
da_resolve_units() {
  local depth="${1:?usage: resolve-units <depth> <codeUnitId…>}"
  shift
  case "$depth" in
    standard | deep)
      [ "$#" -gt 0 ] && printf '%s\n' "$@"
      ;;
    light)
      local i=0
      for u in "$@"; do
        [ $((i % 3)) -eq 0 ] && printf '%s\n' "$u"
        i=$((i + 1))
      done
      ;;
    *)
      die "resolve-units: unknown depth '$depth' (want light|standard|deep)"
      ;;
  esac
}

main() {
  local cmd="${1:-}"
  [ "$#" -gt 0 ] && shift
  case "$cmd" in
    fingerprint) da_fingerprint "$@" ;;
    resolve-units) da_resolve_units "$@" ;;
    compile-plan) die "compile-plan: not yet implemented" ;;
    check-plan) die "check-plan: not yet implemented" ;;
    *) die "usage: deep-audit-lib.sh {fingerprint|resolve-units|compile-plan|check-plan} …" ;;
  esac
}

main "$@"
