#!/usr/bin/env bash
# Workflow guard (the one load-bearing hook).
# Keeps the feature-branch + merge discipline by blocking, at the tool-call layer:
#   - git commit / git push on the base branch (main/master)
#   - --no-verify on any git command
#   - force-push (--force / --force-with-lease / -f / --mirror / +refspec)
# Wired as a PreToolUse hook on the Bash tool. Exit 2 => block; reason on stderr.
#
# It parses the command into real git invocations (argv), rather than substring-
# matching the raw string. That means:
#   - global options are skipped to find the true subcommand, so
#     `git -C <repo> commit` and `git -c k=v commit` are caught, not bypassed;
#   - the target repo is resolved from -C before the branch check;
#   - a non-git command that merely mentions a git verb (e.g. `grep 'git push'`)
#     is NOT blocked.
# It fails OPEN (allows) only when the command can't be parsed at all (unbalanced
# quotes), to avoid blocking legitimate work. Real enforcement belongs in server-
# side branch protection; this is a cooperative guardrail, not an adversarial sandbox.
# Bypassing it still only takes editing this file or settings.json — diff-visible —
# but the easy normal-Git bypasses above are closed.
set -uo pipefail

exec /usr/bin/env python3 -c '
import sys, json, os, re, shlex, subprocess

def allow():
    sys.exit(0)

def deny(msg):
    sys.stderr.write("BLOCKED by workflow guard: " + msg + "\n")
    sys.exit(2)

try:
    data = json.load(sys.stdin)
except Exception:
    allow()

cmd = ((data.get("tool_input") or {}).get("command") or "")
if "git" not in cmd:            # fast path: nothing git-related to enforce
    allow()

# Tokenize, keeping shell operators as their own tokens so we can split into
# the individual simple-commands that make up a pipeline / list.
try:
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=";()<>|&")
    lex.whitespace_split = True
    tokens = list(lex)
except ValueError:
    allow()                    # unbalanced quotes etc. — cannot reason safely

def is_separator(t):
    return t != "" and all(c in ";()<>|&" for c in t)

segments, cur = [], []
for t in tokens:
    if is_separator(t):
        segments.append(cur); cur = []
    else:
        cur.append(t)
segments.append(cur)

ENV_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
WRAPPERS = {"sudo", "command", "nice", "nohup", "time", "builtin", "exec"}
GLOBAL_WITH_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
                   "--super-prefix", "--config-env"}
GLOBAL_EQ_PREFIX = ("--git-dir=", "--work-tree=", "--namespace=", "--config-env=")
BASE_BRANCHES = {"main", "master"}
FORCE_FLAGS = {"--force", "-f", "--force-with-lease", "--force-if-includes", "--mirror"}
FORCE_EQ_PREFIX = ("--force-with-lease=", "--force-if-includes=")  # value forms, e.g. --force-with-lease=main
SHORT_F = re.compile(r"^-[A-Za-z]*f[A-Za-z]*$")   # -f bundled in short flags, e.g. -fv

def git_out(cdir, *a):
    try:
        r = subprocess.run(["git", "-C", cdir or ".", *a],
                            capture_output=True, text=True, timeout=5)
        return r.stdout.strip()
    except Exception:
        return ""

def current_branch(cdir):
    b = git_out(cdir, "symbolic-ref", "--quiet", "--short", "HEAD")
    if b:
        return b
    b = git_out(cdir, "rev-parse", "--abbrev-ref", "HEAD")
    return "" if b == "HEAD" else b

for seg in segments:
    # Strip leading env-assignments and harmless command wrappers.
    i = 0
    while i < len(seg) and (ENV_RE.match(seg[i]) or seg[i] in WRAPPERS):
        i += 1
    seg = seg[i:]
    if not seg or os.path.basename(seg[0]) != "git":
        continue                                   # not a git invocation

    argv = seg[1:]

    # Walk git global options to find -C <dir> and the subcommand.
    cdir, sub, j = None, None, 0
    while j < len(argv):
        a = argv[j]
        if a in GLOBAL_WITH_ARG:
            if a == "-C" and j + 1 < len(argv):
                cdir = argv[j + 1]
            j += 2; continue
        if a.startswith(GLOBAL_EQ_PREFIX) or a.startswith("-c"):
            j += 1; continue
        if a.startswith("-"):                      # any other global flag
            j += 1; continue
        sub = a; break
    rest = argv[j + 1:] if sub is not None else []

    # --no-verify defeats commit/push hooks; never allow it on a git command.
    no_verify = "--no-verify" in argv

    if sub not in ("commit", "push") and not no_verify:
        continue                                   # nothing here to enforce

    # Stand down for repos that run their own heavier protocol (own hooks).
    root = git_out(cdir, "rev-parse", "--show-toplevel")
    if root and os.path.isfile(os.path.join(root, "docs", "ai-protocol.md")):
        continue

    if no_verify:
        deny("remove --no-verify — commit/push hooks must run.")

    if sub == "push":
        forced = any(t in FORCE_FLAGS for t in rest) \
            or any(t.startswith(FORCE_EQ_PREFIX) for t in rest) \
            or any(SHORT_F.match(t) for t in rest) \
            or any((not t.startswith("-")) and t.startswith("+") for t in rest)  # +refspec
        if forced:
            deny("no force-push (covers --force / --force-with-lease / -f / --mirror / +refspec).")
        if current_branch(cdir) in BASE_BRANCHES:
            deny("don'\''t push to the base branch — open a PR / merge a feature branch instead.")

    if sub == "commit":
        if current_branch(cdir) in BASE_BRANCHES:
            deny("don'\''t commit on the base branch — work on a feature branch; the merge is the only path in.")

allow()
'
