---
name: dev-audit
description: Pre-loop repo recon. Inspect a repository's languages, frameworks, manifests, tests, CI, and secret-handling, classify its type and maturity, select the right analysis tools (with rationale), run a zero-dependency core plus any installed heavier tools, and return a brief report — findings, risk level, best-practice gaps, prioritized next steps. Report-first; hands findings to the backlog only on an explicit instruction. Use to size up an unfamiliar repo before /frame.
---

# /dev-audit — inspect a repo, choose the right tools, report

A **pre-loop recon** skill, standalone from `frame/review/close`. It detects what a repo *is*,
chooses analysis tools that fit *that* repo instead of a generic checklist, runs what it safely
can, and reports findings + risk + prioritized next steps. It is **read-only** by design: the only
writes are the audit report artifact and — only on an explicit instruction — `BACKLOG.md`.

Invoked `/dev-audit [path]`. The target is `[path]` if given, else the current repo.

## Hard constraints
- **Read-only against the target.** Modify no target-repo code. Install no tools. The sole writes
  are `reviews/audit-<YYYY-MM-DD>.md` and (only when explicitly told) `BACKLOG.md`.
- **Report first, always.** Never append to the backlog automatically — hand-off needs an explicit
  human go-ahead (step 7).
- **Recommend, don't install.** Heavier tools run only if already present; otherwise they are
  listed as *recommended (not installed)* with the rationale. Never `pip install` / `npm i -g` / etc.

## Steps

### 0. Stand-down (run before anything else)
Resolve the target repo root: `git -C <path|.> rev-parse --show-toplevel`. If
**`docs/ai-protocol.md`** exists at that root, STOP — this repo runs its own heavier workflow.
Tell the user to use that repo's native audit/workflow and do nothing else (no reads-for-report,
no writes). This is the same `docs/ai-protocol.md` opt-out the guard hook and the other global
skills honor.

### 1. Detect (repo type + signals)
Inspect by **filename**, not guesswork. Gather:
- **Languages / ecosystems** — presence of manifests: `package.json` (JS/TS), `pyproject.toml` /
  `requirements.txt` (Python), `go.mod` (Go), `Cargo.toml` (Rust), `Gemfile` (Ruby),
  `pom.xml` / `build.gradle` (Java/Kotlin), `composer.json` (PHP), `Dockerfile` / `*.tf` / k8s
  manifests (container / IaC). A repo may match several rows.
- **Framework files** — e.g. `next.config.*`, `vite.config.*`, `django`/`manage.py`, `rails`,
  `spring`, `terraform` providers — to sharpen the domain read.
- **Test setup** — test dirs/patterns (`test/`, `tests/`, `*_test.*`, `*.spec.*`), a configured
  test script, a coverage config.
- **CI config** — `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/`, `azure-pipelines.yml`, etc.
- **Secret patterns** — tracked `.env*` (not git-ignored), common key shapes
  (`AKIA…`, `-----BEGIN … PRIVATE KEY-----`, `ghp_…`, `xox[baprs]-…`, high-entropy assignments),
  secrets in committed history.
- **Domain context** — README, package description, top-level dirs — is this a library, a web
  service, a CLI, infra, data/ML? Note anything security-sensitive (auth, payments, PII).

### 2. Select the toolset — and record *why* (Table A)
Look the detected ecosystem(s) up in **Table A**. For every tool you choose, the report must say
**why** it fits (which detected marker selected it). Choose, don't run, here.

**Table A — ecosystem (detection marker) → toolset**

| Ecosystem (detection marker) | Linter / format | Dependency scan | Security / SAST | Test runner |
|---|---|---|---|---|
| JS/TS — `package.json` | eslint, prettier, `tsc --noEmit` | `npm/pnpm/yarn audit`, osv-scanner | semgrep | jest / vitest / playwright |
| Python — `pyproject.toml`, `requirements.txt` | ruff, black, mypy | pip-audit, osv-scanner | bandit, semgrep | pytest |
| Go — `go.mod` | golangci-lint, `go vet` | govulncheck, osv-scanner | gosec, semgrep | `go test ./...` |
| Rust — `Cargo.toml` | clippy, rustfmt | cargo-audit, cargo-deny | semgrep | `cargo test` |
| Ruby — `Gemfile` | rubocop | bundler-audit, osv-scanner | brakeman, semgrep | rspec |
| Java/Kotlin — `pom.xml`, `build.gradle` | spotless / checkstyle, ktlint | OWASP dependency-check, osv-scanner | spotbugs, semgrep | junit / gradle test |
| PHP — `composer.json` | php-cs-fixer, phpstan | `composer audit` | psalm, semgrep | phpunit |
| Container / IaC — `Dockerfile`, `*.tf`, k8s yaml | hadolint, tflint | trivy (image/fs) | checkov, trivy, semgrep | — |
| Any / cross-cutting | — | osv-scanner | **secrets:** gitleaks / trufflehog · **SAST:** semgrep | — |
| **Architecture review** (all repos) | — | — | reuse the design-review lens: `AGENTS.md` + `design-review-schema.json` (escalate to `/review approach`) | — |

The architecture-review row deliberately **reuses the existing design-review contract** rather
than inventing a parallel prompt set.

### 3. Run the zero-dependency **core** (always)
These use only already-assumed tooling (`git`, `grep`, manifest reads, `python3`/`jq`) so they run
on every repo regardless of what's installed:
- **Dependency pinning** — read the manifest/lockfile; flag floating ranges (`^`, `~`, `*`,
  unpinned `requirements.txt` lines, missing lockfile).
- **CI presence** — any CI config from step 1 present? If none, that's a safeguard gap.
- **Test presence** — any tests / a runnable test script? Thin-or-absent is a gap.
- **Secret handling** — grep for the patterns in step 1; check `.env*` is git-ignored; spot-check
  history. Any hit is a high-signal finding.
- **Git hygiene** — `.gitignore` present, no obviously committed build/secret artifacts.

### 4. Run heavier tools **only if present** (hybrid)
For each tool chosen in step 2, gate on availability: `command -v <tool>`. If present, run it
(read-only, against the target) and fold its output into findings. If absent, list it as
**recommended (not installed)** with the one-line rationale — do **not** install it.

### 5. Classify maturity + risk (Table B)
Derive the maturity *tier* and *risk level* from the safeguard signals — declaratively, via
**Table B**, so the same profile classifies the same way every run (no ad-hoc prose).

**Table B — safeguard signals → maturity tier + risk**

| Safeguard signal | Present | Absent → flag |
|---|---|---|
| CI configured | ✓ | "no CI" |
| Automated tests | ✓ | "no/weak tests" |
| Dependencies pinned (lockfile / exact versions) | ✓ | "unpinned dependencies" |
| Secret handling (no tracked/committed secrets, `.env` ignored, secret-scan clean) | ✓ | "weak secret handling" |
| Docs (README) + license | ✓ | "missing docs/license" |

- **Maturity tier:**
  - **mature** — CI **and** tests **and** pinned deps **and** clean secret handling all present.
  - **developing** — at least one of {CI, tests} present, but ≥1 core safeguard missing.
  - **prototype** — none of {CI, tests} present, or secrets tracked, or deps unpinned with no lockfile.
- **Risk level:**
  - **high** — any tracked/committed secret or secret-scan hit, **or** a known-vulnerable dependency
    (audit hit), **or** no tests in a security-sensitive domain (auth/payments/PII).
  - **medium** — missing CI, unpinned deps, or thin tests, with no high-severity finding.
  - **low** — core safeguards present and no high/critical findings.

### 6. Report
Print a brief report to chat **and** write it to `reviews/audit-<YYYY-MM-DD>.md` at the target
root (create `reviews/` if absent — the step-0 stand-down has already cleared the repo for writes).
Use these fixed sections, in order:

- **Detected profile** — type, ecosystem(s), domain, maturity tier.
- **Tools chosen — and why** — each selected tool with the detected marker that justified it, and
  for heavier tools whether it *ran* or is *recommended (not installed)*.
- **Findings** — core + tool output, most severe first.
- **Risk level** — high / medium / low, with the one-line reason (from Table B).
- **Best-practice gaps** — the safeguard flags from Table B that tripped (no CI, no/weak tests,
  unpinned dependencies, weak secret handling, missing docs/license).
- **Prioritized next steps** — concrete, ordered moves toward mature, secure delivery.

### 7. Backlog hand-off (report-first, human-gated)
After presenting the report, **offer** to graduate selected findings into `BACKLOG.md`. Append
**only on an explicit instruction** — never automatically. Audit-sourced items use the **`AUDIT-`**
id prefix (e.g. `AUDIT-1 — <finding> (from /dev-audit <date>)`), so their provenance is legible
alongside `BUG-`/`OPS-`. If the target repo has **no `BACKLOG.md`**, report the suggested entries
and require an explicit instruction before creating the file.
