#!/usr/bin/env python3
"""deep_audit_lib — the tested deterministic core of the deep-audit subsystem.

One CLI library both /deep-audit and (later) /deep-audit-run call, so every deterministic
rule — the source fingerprint, the exact unit-resolution, Table-P compilation, and the plan
validator — exists exactly ONCE, in code, with a real behavioral test suite
(tests/deep_audit_lib_test.sh). This is the substrate that replaces prose-asserted
algorithms: a rule is enforced here or it is not enforced.

Contract: JSON in, exit status out. A subcommand exits NONZERO on any violation; the
skills' prose is "run deep_audit_lib.py <cmd> …; nonzero ⇒ STOP loudly."

Constraints (binding, per the story's design decisions):
  * stdlib only — no pip dependencies (this deploys to every repo; the estate is non-admin).
  * one file, subcommand-dispatched.
  * exit codes: 0 = ok, 2 = usage/violation.

Subcommands (plan-side slice; execute-side lands with the engine story):
  fingerprint <root>                     source digest (mode-aware, NUL-safe)
  resolve-units <depth> <codeUnitId…>    exact unit resolution
"""

from __future__ import annotations

import argparse
import hashlib
import os
import subprocess
import sys

EXIT_VIOLATION = 2


def die(msg: str) -> "typing.NoReturn":  # noqa: F821 - annotation only
    print(f"deep_audit_lib: {msg}", file=sys.stderr)
    raise SystemExit(EXIT_VIOLATION)


def _git(root: str, *args: str, stdin: bytes | None = None) -> bytes:
    """Run a git plumbing command in `root`, returning stdout bytes."""
    return subprocess.run(
        ["git", "-C", root, *args],
        input=stdin,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=True,
    ).stdout


def fingerprint(root: str) -> str:
    """Content digest identifying the audited source state.

    Canonical NUL-terminated stream of "<exec-bit> <content-hash> <path>" records over the
    non-reviews/** tracked files, byte-sorted, SHA-256'd:

      * exec-bit (x|-) is read from the WORKING TREE, so even an UNSTAGED chmod registers
        (the index mode would not).
      * content-hash is `git hash-object` of the WORKING-TREE file, so unstaged edits
        register; a removed working file hashes as DELETED.
      * reviews/** is excluded so an in-repo plan/report commit cannot self-invalidate the
        binding it is recording.
    """
    try:
        listing = _git(root, "ls-files", "-z", "--", ":!reviews/")
    except (subprocess.CalledProcessError, FileNotFoundError):
        die(f"fingerprint: not a git repo: {root}")

    paths = [p for p in listing.split(b"\0") if p]
    if not paths:
        return hashlib.sha256(b"").hexdigest()

    # One batched call instead of one subprocess per file: git reads paths on stdin and
    # emits one OID per line, in input order.
    hashes = _git(
        root, "hash-object", "--stdin-paths", stdin=b"\n".join(paths) + b"\n"
    ).split()

    records = []
    for path, oid in zip(paths, hashes, strict=False):
        full = os.path.join(root, os.fsdecode(path))
        bit = b"x" if os.access(full, os.X_OK) else b"-"
        oid_or_deleted = oid if os.path.exists(full) else b"DELETED"
        records.append(b"%s %s %s" % (bit, oid_or_deleted, path))

    records.sort()  # bytewise, matching LC_ALL=C sort
    stream = b"".join(r + b"\0" for r in records)
    return hashlib.sha256(stream).hexdigest()


def resolve_units(depth: str, unit_ids: list[str]) -> list[str]:
    """The EXACT resolution the compiler and the engine both use.

    standard/deep run the full ordered list; light runs the pinned every-3rd sample
    (indices 0, 3, 6, …). Pinning the sample here — rather than re-choosing at execution —
    is what makes a light row's schedule reproducible from the plan alone.
    """
    if depth in ("standard", "deep"):
        return list(unit_ids)
    if depth == "light":
        return list(unit_ids[::3])
    die(f"resolve-units: unknown depth '{depth}' (want light|standard|deep)")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="deep_audit_lib.py", add_help=True)
    sub = parser.add_subparsers(dest="cmd")

    p_fp = sub.add_parser("fingerprint", help="source digest for a target repo")
    p_fp.add_argument("root")

    p_ru = sub.add_parser("resolve-units", help="exact unit resolution for a depth")
    p_ru.add_argument("depth")
    p_ru.add_argument("unit_ids", nargs="*")

    # An unknown/absent subcommand is a violation, not a silent no-op.
    args, extra = parser.parse_known_args(argv)
    if extra or args.cmd is None:
        die(
            "usage: deep_audit_lib.py {fingerprint|resolve-units} …"
            + (f" (unrecognized: {' '.join(extra)})" if extra else "")
        )

    if args.cmd == "fingerprint":
        print(fingerprint(args.root))
    elif args.cmd == "resolve-units":
        for unit in resolve_units(args.depth, args.unit_ids):
            print(unit)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
