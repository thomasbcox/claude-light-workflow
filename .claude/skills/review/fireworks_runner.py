#!/usr/bin/env python3
"""Fireworks reviewer backend for the lightweight Claude↔reviewer loop.

This module is the *backend boundary* for one review altitude. It owns context
assembly, the concurrent fan-out across that altitude's passes, schema-enforced
model calls, and artifact promotion. The calling skill keeps a thin invocation
rather than a copied command block.

Why this is executable code and not skill prose: `tests/reviewer_test.sh` is a
documentation linter with no oracle, and says so in its own charter — the second
backend was expected to force the orchestration into code that a real gate can
test. This is that code.

Fail-closed by construction. Every failure mode — missing dependency, missing or
empty context input, oversized payload, API error, truncated completion,
unparseable body, schema violation — takes the same path: a message naming the
cause, no artifact written, non-zero exit. A failed *review* never publishes
anything, and a failed round never leaves a prior round's artifact standing as
its result. See promote() for the precise publication guarantee — it is
per-file atomic, not a single transaction across files.

Unlike the agentic `codex` backend, this one cannot explore the repo: context is
*pushed*, so anything the reviewer is not given, it cannot see. That is why the
required inputs are declared per pass and verified present and non-empty before
any request is made.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROUTES_FILE = HERE / "fireworks-models.json"
BASE_URL = "https://api.fireworks.ai/inference/v1"

# Output budget reserved for the model's reply, and the fraction of a model's
# context we are willing to fill. Both feed the pre-flight size guard so an
# oversized payload is refused locally rather than clamped by the provider.
#
# 8k was the first value tried and it truncated a real review of a ~1,500-line
# diff — the runner correctly refused to promote it, which is how we found out.
# A correctness pass over a large branch legitimately emits many findings, each
# with a claim, an alternative, and a win, so the reply is long by design.
# Verified accepted up to 131,072 on the routed model; 32k is chosen as ample for
# a review while still far below any routed model's context, so the size guard
# below is never dominated by this reservation.
MAX_OUTPUT_TOKENS = 32000
CONTEXT_HEADROOM = 0.90

# Deliberately conservative: real text runs nearer 4 bytes/token and code denser
# still, so dividing by 3 OVER-estimates tokens and trips the guard early. This
# is a guard against obvious overrun, not a token count.
BYTES_PER_TOKEN = 3


class RunnerError(Exception):
    """Any condition that must stop the round. Carries the message the user sees."""


# ── Context sources ───────────────────────────────────────────────────────────
# Each declared input names a *place the review must be grounded in*. A pushed
# reviewer sees exactly this and nothing else.


def _git(args: list[str], root: Path) -> str:
    proc = subprocess.run(
        ["git", *args], cwd=root, capture_output=True, text=True, check=False
    )
    if proc.returncode != 0:
        raise RunnerError(f"git {' '.join(args)} failed: {proc.stderr.strip()}")
    return proc.stdout


CONTEXT_SOURCES = {
    "contract": {
        "title": "AGENTS.md — the reviewer contract",
        "get": lambda ctx: (ctx["root"] / "AGENTS.md").read_text(),
    },
    "story": {
        "title": "The story file — spec, acceptance criteria, falsification plan",
        "get": lambda ctx: (ctx["root"] / "reviews" / f"{ctx['slug']}.md").read_text(),
    },
    "diff": {
        "title": "git diff (base...HEAD) — the change under review",
        "get": lambda ctx: _git(["diff", f"{ctx['base']}...HEAD"], ctx["root"]),
    },
    "log": {
        "title": "git log (base..HEAD) — the commits on this branch",
        "get": lambda ctx: _git(
            ["log", "--oneline", f"{ctx['base']}..HEAD"], ctx["root"]
        ),
    },
}


# ── Pass table ────────────────────────────────────────────────────────────────
# Declarative: each pass binds a purpose (which routes to a model), a schema, the
# context it requires, and its artifact. Wiring the design and approach passes is
# an entry here plus a dispatch line — not new orchestration.
#
# NOTE ON ARTIFACT NAMES: `<slug>.codex.json` is the correctness artifact the
# loop already reads at review/SKILL.md step 9, so this backend writes to it too
# rather than forking the read path. The name is a misnomer once a second backend
# writes it; renaming touches the codex block and is out of this story's scope.

PASSES = {
    "correctness": {
        "purpose": "correctness",
        "schema": "finding-schema.json",
        "artifact": "reviews/{slug}.codex.json",
        "context": ["contract", "story", "diff", "log"],
        "prompt": (
            "You are the independent reviewer defined in AGENTS.md. Review ONLY this "
            "branch's changes versus the base. The diff, the commit log, the reviewer "
            "contract, and the story file (with its spec) are all provided below — you "
            "cannot run commands, so judge from what you are given. Judge the change "
            "against that spec. Return your result strictly per the provided JSON schema "
            "(severities BLOCKER / IMPORTANT / QUESTION / NIT; ground every finding in "
            "the actual diff; return an empty findings array if there are no issues)."
        ),
    },
    "hidden-failure": {
        "purpose": "hidden-failure",
        "schema": "hidden-failure-schema.json",
        "artifact": "reviews/{slug}.hidden-failure.json",
        "context": ["contract", "story", "diff", "log"],
        "prompt": (
            "You are the independent reviewer per AGENTS.md doing a CORRECTNESS review "
            "SCOPED TO ONE LENS: hidden failure / weak error handling (AGENTS.md's "
            "'Hidden failure' bullet) ONLY — a parallel correctness critic covers "
            "everything else, do NOT duplicate it. The diff, commit log, contract, and "
            "story file are provided below; you cannot run commands, so judge from what "
            "you are given. Report ONLY findings where the diff swallows, absorbs, or "
            "silently degrades on error: bare/blind except|catch, catch-log-continue "
            "where propagating is correct, silent fallbacks, deleted assertions/safety "
            "checks — anything that lets code continue in a degraded state nothing "
            "surfaces. Ground every finding in the diff; empty findings array if none. "
            "Return strictly per the provided JSON schema."
        ),
    },
}

# Which passes run concurrently at one altitude. Parallelism policy is INHERITED
# from OPS-12, not redesigned here: passes at one altitude ask *different*
# questions, so their findings partition by concern and may run at once. The
# approach→correctness gate stays sequential and lives in the skill, not here.
ALTITUDES = {
    "correctness": ["correctness", "hidden-failure"],
}

# The full review vocabulary, including purposes not yet wired to a pass above.
# The routing table is allowed to route ahead of use — `design` and `approach`
# are routed so the follow-up story is a dispatch change — but it may not route a
# purpose that is not a review purpose at all, which would be a silent typo.
KNOWN_PURPOSES = {"design", "approach", "correctness", "hidden-failure"}


# ── Routing ───────────────────────────────────────────────────────────────────


def load_routes() -> dict:
    """Read the routing table. No model id is ever hardcoded in this module."""
    try:
        table = json.loads(ROUTES_FILE.read_text())
    except FileNotFoundError:
        raise RunnerError(f"routing table not found: {ROUTES_FILE}")
    except json.JSONDecodeError as exc:
        raise RunnerError(f"routing table is not valid JSON ({ROUTES_FILE}): {exc}")
    routes = table.get("routes")
    if not isinstance(routes, dict) or not routes:
        raise RunnerError(f"routing table has no 'routes' object: {ROUTES_FILE}")
    return routes


def resolve_route(purpose: str, routes: dict) -> dict:
    """Resolve one purpose to its model. An unknown purpose is an error, never a default."""
    route = routes.get(purpose)
    if route is None:
        known = ", ".join(sorted(routes)) or "(none)"
        raise RunnerError(
            f"no route for purpose '{purpose}' in {ROUTES_FILE.name} (routed: {known})"
        )
    model = route.get("model")
    ctx_len = route.get("contextLength")
    if not model:
        raise RunnerError(f"route '{purpose}' has no model id")
    if not isinstance(ctx_len, int) or ctx_len <= 0:
        raise RunnerError(
            f"route '{purpose}' has no positive integer contextLength — "
            "the size guard would have nothing to check against"
        )
    return {"model": model, "contextLength": ctx_len}


# ── Context assembly ──────────────────────────────────────────────────────────


def assemble_context(inputs: list[str], ctx: dict) -> str:
    """Build the pushed payload from declared inputs, failing closed on any gap.

    Assembled ONCE per altitude and handed identically to every pass, so the
    concurrent critics differ only in the question they are asked.
    """
    parts = []
    for name in inputs:
        source = CONTEXT_SOURCES.get(name)
        if source is None:
            raise RunnerError(f"unknown context input '{name}' in the pass table")
        try:
            body = source["get"](ctx)
        except FileNotFoundError as exc:
            raise RunnerError(f"required context input '{name}' is missing: {exc}")
        except OSError as exc:
            raise RunnerError(f"required context input '{name}' is unreadable: {exc}")
        if not body or not body.strip():
            raise RunnerError(
                f"required context input '{name}' is empty — refusing to review "
                "against material the reviewer cannot see"
            )
        parts.append(f"# {source['title']}\n\n{body.rstrip()}\n")
    return "\n".join(parts)


def check_size(context: str, prompt: str, schema: dict, ctx_len: int, purpose: str) -> None:
    """Refuse an oversized payload locally, before any request is made."""
    payload_bytes = len(context) + len(prompt) + len(json.dumps(schema))
    est_tokens = payload_bytes // BYTES_PER_TOKEN
    budget = int(ctx_len * CONTEXT_HEADROOM) - MAX_OUTPUT_TOKENS
    if est_tokens > budget:
        raise RunnerError(
            f"context for '{purpose}' is too large: ~{est_tokens:,} tokens estimated "
            f"against a budget of {budget:,} (model context {ctx_len:,}, "
            f"{MAX_OUTPUT_TOKENS:,} reserved for output). Narrow the diff or route "
            "this purpose to a larger-context model."
        )


# ── Model call ────────────────────────────────────────────────────────────────


def build_client(api_key: str):
    """Import lazily so a missing dependency fails closed with an actionable message."""
    try:
        from openai import OpenAI
    except ImportError:
        raise RunnerError(
            "the 'openai' package is not available to this interpreter. Bootstrap the "
            "runner environment:\n"
            "  python3 -m venv ~/.claude/fireworks-venv && "
            "~/.claude/fireworks-venv/bin/pip install -r "
            f"{HERE / 'requirements.txt'}"
        )
    return OpenAI(api_key=api_key, base_url=BASE_URL)


def validate(payload: dict, schema: dict, purpose: str) -> None:
    """Second enforcement layer. API-side json_schema is grammar-constrained but not
    a guarantee across model versions, and this check costs nothing. Deliberately
    not hand-rolled — AGENTS.md's guardrail is not to reimplement what one
    declarative construct already covers."""
    try:
        import jsonschema
    except ImportError:
        raise RunnerError(
            "the 'jsonschema' package is not available to this interpreter — refusing "
            "to write an unvalidated review artifact. Bootstrap the runner environment:\n"
            "  python3 -m venv ~/.claude/fireworks-venv && "
            "~/.claude/fireworks-venv/bin/pip install -r "
            f"{HERE / 'requirements.txt'}"
        )
    try:
        jsonschema.validate(instance=payload, schema=schema)
    except jsonschema.ValidationError as exc:
        raise RunnerError(
            f"'{purpose}' returned JSON that violates its schema at "
            f"{'/'.join(str(p) for p in exc.absolute_path) or '(root)'}: {exc.message}"
        )


def run_pass(name: str, context: str, ctx: dict, routes: dict) -> dict:
    """Run one pass end to end and return its validated body. Never writes."""
    spec = PASSES[name]
    purpose = spec["purpose"]
    # An override must supply a COMPLETE route — id and context length together.
    # Taking the id from the flag while the guard kept using the table's number
    # sourced one model contract from two records: a smaller override passed a
    # preflight sized for the routed model's larger window and failed only at the
    # API. main() rejects --model without --context-length, so these move as one.
    route = resolve_route(purpose, routes)
    model = ctx["model_override"] or route["model"]
    context_length = ctx["context_length_override"] or route["contextLength"]

    schema_path = HERE / spec["schema"]
    try:
        schema = json.loads(schema_path.read_text())
    except FileNotFoundError:
        raise RunnerError(f"schema for '{name}' not found: {schema_path}")
    except json.JSONDecodeError as exc:
        raise RunnerError(f"schema for '{name}' is not valid JSON ({schema_path}): {exc}")

    check_size(context, spec["prompt"], schema, context_length, purpose)

    client = build_client(ctx["api_key"])
    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": spec["prompt"]},
                {"role": "user", "content": context},
            ],
            response_format={
                "type": "json_schema",
                "json_schema": {"name": purpose.replace("-", "_"), "schema": schema},
            },
            # The provider default is 'truncate', which clamps max_tokens to fit and
            # surfaces as a mangled body blaming the wrong cause. Ask for the honest error.
            extra_body={"context_length_exceeded_behavior": "error"},
            max_tokens=MAX_OUTPUT_TOKENS,
        )
    except Exception as exc:
        raise RunnerError(f"'{name}' API call failed: {exc}")

    if not getattr(response, "choices", None):
        raise RunnerError(
            f"'{name}' returned no choices — the API produced no completion at all"
        )
    choice = response.choices[0]

    # Only `stop` means the model finished saying what it had to say. Everything
    # else is the model telling us the reply is not what it would have been, and a
    # truncated or filtered body can still be valid JSON that satisfies the schema
    # — so validation cannot catch it. Ignoring the signal would promote a degraded
    # review as a clean one, which is the same shape as the `{}` defect that
    # motivated this backend. `length` keeps its own message because its fix is
    # specific (raise the output budget); everything else shares the general one.
    if choice.finish_reason == "length":
        raise RunnerError(
            f"'{name}' response was cut off at the output limit "
            f"({MAX_OUTPUT_TOKENS:,} tokens) — the review is incomplete, not clean"
        )
    if choice.finish_reason != "stop":
        raise RunnerError(
            f"'{name}' completion ended abnormally (finish_reason="
            f"{choice.finish_reason!r}) — the model signalled its reply was altered "
            "or suppressed (e.g. content filtering). It may still parse and satisfy "
            "the schema, which is exactly why this is checked: a filtered review is "
            "not a clean review. Nothing promoted."
        )

    body = choice.message.content
    try:
        parsed = json.loads(body)
    except (TypeError, json.JSONDecodeError) as exc:
        raise RunnerError(f"'{name}' did not return parseable JSON: {exc}")

    validate(parsed, schema, name)
    return parsed


# ── Promotion ─────────────────────────────────────────────────────────────────


def promote(results: dict, ctx: dict) -> list[Path]:
    """Write every artifact, or none. Reached only once all passes have validated.

    Two phases, deliberately. STAGE writes and fsyncs every payload to a unique
    temp beside its destination; anything that can realistically fail —
    serialization, permissions, a full disk — fails here, where the cleanup
    promotes nothing. COMMIT then does renames only: same-filesystem, atomic per
    file, and needing no new space.

    Interleaving the two (rename as you go) is what the first version did, and
    both correctness critics caught it: a failure on the second file would leave
    the first already promoted and the round half-reviewed.

    NOT a true multi-file transaction — POSIX has no such primitive. A process
    killed between two renames can leave one artifact new and one stale. Thomas
    accepted that window on 2026-08-03 (approach-review BLOCKER): the `codex`
    backend's two sequential `mv`s share it, so closing it means a round-directory
    or pointer scheme for BOTH backends, deferred to its own story. What IS
    guaranteed: a failed review publishes nothing, and no reader ever catches a
    partial *file*.
    """
    staged: list[tuple[Path, Path]] = []
    try:
        for name, payload in results.items():
            dest = ctx["root"] / PASSES[name]["artifact"].format(slug=ctx["slug"])
            dest.parent.mkdir(parents=True, exist_ok=True)
            fd, tmp = tempfile.mkstemp(dir=dest.parent, prefix=f".{dest.name}.")
            with os.fdopen(fd, "w") as handle:
                json.dump(payload, handle, indent=2)
                handle.flush()
                os.fsync(handle.fileno())
            staged.append((Path(tmp), dest))
    except Exception:
        for tmp, _ in staged:
            tmp.unlink(missing_ok=True)
        raise

    written = []
    for tmp, dest in staged:
        os.replace(tmp, dest)
        written.append(dest)
    return written


# ── Modes ─────────────────────────────────────────────────────────────────────


def check_models(routes: dict, api_key: str) -> int:
    """Verify every routed id is live AND that the stored context length matches.

    Deliberately outside the local gate: it needs network and a credential, and
    the estate rule is to keep local gates dependency-light.
    """
    client = build_client(api_key)
    try:
        live = {m.id: m for m in client.models.list().data}
    except Exception as exc:
        raise RunnerError(f"could not list models: {exc}")

    problems = 0
    for purpose in sorted(routes):
        route = routes[purpose]
        model = route.get("model", "")
        stored = route.get("contextLength")
        if model not in live:
            print(f"  DEAD      {purpose:16} {model} — not served on this account")
            problems += 1
            continue
        actual = getattr(live[model], "context_length", None)
        if actual is None:
            print(
                f"  UNKNOWN   {purpose:16} {model} — live metadata reports no context "
                f"length; stored {stored:,} cannot be confirmed"
            )
            problems += 1
        elif actual != stored:
            print(
                f"  DRIFT     {purpose:16} {model} — stored {stored:,}, live {actual:,}"
            )
            problems += 1
        else:
            print(f"  ok        {purpose:16} {model} ({actual:,} ctx)")
    print()
    if problems:
        print(f"✗ {problems} route(s) need attention in {ROUTES_FILE.name}")
        return 1
    print(f"✓ all {len(routes)} route(s) live and context lengths match")
    return 0


def run_altitude(altitude: str, ctx: dict, routes: dict) -> int:
    """Assemble once, fan out concurrently, join all-or-nothing, then promote."""
    names = ALTITUDES[altitude]
    inputs = []
    for name in names:
        for src in PASSES[name]["context"]:
            if src not in inputs:
                inputs.append(src)
    context = assemble_context(inputs, ctx)

    results = {}
    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(names)) as pool:
        futures = {
            pool.submit(run_pass, name, context, ctx, routes): name for name in names
        }
        for future in concurrent.futures.as_completed(futures):
            name = futures[future]
            try:
                results[name] = future.result()
            except RunnerError as exc:
                failures.append(f"{name}: {exc}")
            except Exception as exc:  # a bug here must still stop the round
                failures.append(f"{name}: unexpected error: {exc}")

    if failures:
        for line in failures:
            print(f"FAIL: {line}", file=sys.stderr)
        print(
            f"Round stopped — no artifact promoted. {len(names) - len(failures)} of "
            f"{len(names)} passes succeeded, which is not a review. Rerun /review.",
            file=sys.stderr,
        )
        return 1

    for dest in promote(results, ctx):
        print(f"→ {dest.relative_to(ctx['root'])}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fireworks reviewer backend — schema-enforced, fail-closed."
    )
    parser.add_argument(
        "--altitude", choices=sorted(ALTITUDES), help="review altitude to run"
    )
    parser.add_argument("--slug", help="story slug (reviews/<slug>.md)")
    parser.add_argument("--base", help="base branch or ref to diff against")
    parser.add_argument(
        "--model",
        help="explicit model id, overriding the routing table for this run; "
        "requires --context-length so the size guard applies to the model actually called",
    )
    parser.add_argument(
        "--context-length",
        type=int,
        help="context window of --model, in tokens (required with --model)",
    )
    parser.add_argument(
        "--check-models",
        action="store_true",
        help="verify every routed model is live and its stored context length matches",
    )
    args = parser.parse_args()

    try:
        routes = load_routes()

        api_key = os.environ.get("FIREWORKS_API_KEY")
        if not api_key:
            raise RunnerError(
                "FIREWORKS_API_KEY is not set. Non-interactive shells do not read "
                "~/.zshrc — export it from ~/.zshenv so scripted runs can see it."
            )

        if args.check_models:
            return check_models(routes, api_key)

        # An override is a complete route or it is not an override. Accepting a bare
        # --model would leave the preflight guard checking the routed model's window
        # against a different model's payload.
        if args.model and not args.context_length:
            raise RunnerError(
                "--model requires --context-length (the override model's context window "
                "in tokens). Without it the size guard would check the routed model's "
                "window against a model that is not being called. For a lasting change, "
                f"edit {ROUTES_FILE.name} instead."
            )
        if args.context_length and not args.model:
            raise RunnerError("--context-length is only meaningful with --model")
        if args.context_length is not None and args.context_length <= 0:
            raise RunnerError("--context-length must be a positive number of tokens")

        missing = [
            flag
            for flag, value in (
                ("--altitude", args.altitude),
                ("--slug", args.slug),
                ("--base", args.base),
            )
            if not value
        ]
        if missing:
            raise RunnerError(f"missing required argument(s): {', '.join(missing)}")

        rev = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=False,
        )
        if rev.returncode != 0 or not rev.stdout.strip():
            raise RunnerError(
                "not inside a git repository (git rev-parse --show-toplevel failed): "
                f"{rev.stderr.strip() or 'no output'}"
            )
        root = Path(rev.stdout.strip())
        ctx = {
            "root": root,
            "slug": args.slug,
            "base": args.base,
            "api_key": api_key,
            "model_override": args.model,
            "context_length_override": args.context_length,
        }
        return run_altitude(args.altitude, ctx, routes)
    except RunnerError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:
        # A bug in this module must still read as a stopped round, not a stack
        # trace the caller has to interpret. Still fail-closed: nothing promoted.
        print(f"FAIL: unexpected error in the fireworks runner: {exc!r}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
