## Context

The change introduces CI quality gates for the iOS SDK so pull requests cannot merge without passing build, lint, and test checks. Current workflows cover naming and security scanning, but they do not validate SDK correctness.

Repository constraints relevant to this design:
- The codebase includes both `Package.swift` and an Xcode project.
- XCTest coverage exists under `PayrailsTests/`.
- There is no committed shared Xcode scheme in `Payrails.xcodeproj/xcshareddata/xcschemes/`, which is required for stable `xcodebuild` execution in CI.

Stakeholders are SDK maintainers, contributors opening PRs, and release owners depending on `main` branch stability.

## Goals / Non-Goals

**Goals:**
- Every PR must pass build + unit tests + lint before it can merge
- Enforce a deterministic CI workflow that runs on PRs to `main` and validates build, lint, and test.
- Use a single source of truth for commands so local checks and CI behavior stay aligned.
- Fail fast and provide clear PR status checks that can be required by branch protection.
- Keep the initial implementation practical for immediate adoption, then iterate.

**Non-Goals:**
- Replacing existing security workflows (Semgrep/Trivy) or notification workflows.
- Adding release, publish, or versioning automation.
- Introducing full matrix testing across multiple Xcode versions in this first iteration.
- Enforcing test coverage thresholds in this change.

## Decisions

### Decision 1: Add a dedicated CI workflow for SDK validation

Use a new GitHub Actions workflow (`.github/workflows/ci.yaml`) for build/lint/test checks.

Rationale:
- Separates quality validation from existing security and repository governance workflows.
- Produces a clear, dedicated required status check for code correctness.
- Keeps workflow ownership and future tuning isolated.

Alternatives considered:
- Extend `semgrep.yaml`/`trivy.yaml` with SDK validation jobs: rejected because it mixes unrelated concerns.
- Create separate build/lint/test workflows: rejected initially to reduce configuration overhead and required-check complexity.

### Decision 2: Run CI on macOS and execute checks via Xcode tooling

Use macOS runners with pinned Xcode setup and run build/test using `xcodebuild`.

Rationale:
- XCTest suite is project-based; package-level `swift test` is not currently sufficient as the package manifest has no test target.
- `xcodebuild` validates the same integration path used by SDK consumers.
- A single authoritative command path avoids divergence between local and CI execution.

Alternatives considered:
- `swift build` + `swift test` only: rejected because it does not cover current project-based test execution.
- Linux runners: rejected due iOS/Xcode requirements.

### Decision 3: Commit and use a shared scheme for reliable CI execution

Add and commit a shared `Payrails` scheme under `Payrails.xcodeproj/xcshareddata/xcschemes/` and make CI use it.

Rationale:
- CI cannot rely on developer-local user schemes.
- Shared schemes make build and test commands deterministic and reproducible.

Alternatives considered:
- Generate scheme dynamically in CI: rejected due fragility and harder debugging.
- Keep user-local scheme setup documented: rejected because it is not enforceable in CI.

### Decision 4: Standardize linting with SwiftLint and repository-level config

Use SwiftLint in CI (strict mode) with a committed `.swiftlint.yml` and a stable invocation in workflow/scripts.

Rationale:
- SwiftLint is established for Swift style and safety checks.
- A committed config keeps lint behavior explicit and versionable.
- Strict mode supports CI gate intent (fail on violations).

Alternatives considered:
- `swift-format` only: rejected for initial rollout because existing team conventions likely align with SwiftLint rule coverage.
- No lint gate (build+test only): rejected because proposal explicitly includes lint.

### Decision 5: Define reusable CI commands in repository scripts

Add executable scripts (for example under `scripts/ci/`) for build, lint, and test; workflow calls these scripts.

Rationale:
- Prevents command drift between local developer execution and CI.
- Simplifies troubleshooting and future changes by editing one command definition.

Alternatives considered:
- Inline all commands directly in workflow YAML: rejected due duplication and weaker local parity.
- Use Makefile targets only: possible, but shell scripts are less assumption-heavy for current repository tooling.

## Risks / Trade-offs

- [Longer PR feedback time on macOS runners] -> Mitigation: use caching where possible, keep jobs focused, and optimize command flags after baseline measurements.
- [Flaky simulator/test destination failures] -> Mitigation: pin simulator device/runtime and keep CI environment setup explicit.
- [Initial lint noise causing many failures] -> Mitigation: start with a pragmatic rule set and tighten incrementally in follow-up changes.
- [Shared scheme misconfiguration can block all PRs] -> Mitigation: validate scheme locally before enabling required-check enforcement.
- [Single workflow centralizes failure surface] -> Mitigation: keep steps separated and logs explicit so failing stage is immediately visible.

## Migration Plan

1. Create and commit shared Xcode scheme(s) required for CI.
2. Add repo-standard CI scripts for build, lint, and test.
3. Add/adjust lint configuration (`.swiftlint.yml`) and validate locally.
4. Add `.github/workflows/ci.yaml` invoking the standardized scripts.
5. Validate workflow on a test PR, then enforce the check via branch protection.
6. Rollback plan: remove required-check enforcement first, then revert workflow/scripts if needed.

## Open Questions

- Xcode baseline: Pin CI to a stable Xcode toolchain compatible with `platform=iOS Simulator,name=iPhone 15,OS=latest`.
- Canonical test destination: `platform=iOS Simulator,name=iPhone 15,OS=latest`.
- CI triggers: Run on PRs to `main` and direct pushes to `main` for post-merge verification.
- Lint rollout: No temporary lint baseline is needed.
