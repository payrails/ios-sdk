## Why

The repository currently lacks a CI quality gate that validates iOS SDK changes before merge. Adding automated build, lint, and test checks now will reduce regressions, shorten review cycles, and make releases more reliable.

The IOS SDK has no CI checks for build correctness or code quality on PRs. A broken build, failing tests, or publishing regression can be merged to `main` without detection. The existing CI workflows cover security scanning (Semgrep, Trivy dep-scan), PR naming, but nothing validates that the code itself compiles and passes tests.

## What Changes

- Add a new GitHub Actions workflow (`ci.yaml`) that runs on every PR targeting `main`
- Run automated SDK validation checks in CI: build, lint, and test.
- Define repository-standard commands and failure behavior for build, lint, and test so contributors and CI execute the same checks.
- Publish clear CI results in pull requests to block merges when core quality checks fail.

## Capabilities

### New Capabilities
- `ios-sdk-ci-pr-validation`: Define and enforce continuous integration quality gates for the iOS SDK, including build, lint, and test execution on code changes.

### Modified Capabilities
- None.

## Impact

- Affects repository automation in `.github/workflows/` by introducing a CI workflow for SDK validation.
- May add or update lint/build/test configuration files and scripts used by local development and CI.
- Introduces CI runtime/dependency requirements (for example, Xcode/macOS runner setup and lint tooling installation).
- Changes pull request merge behavior by requiring successful CI checks for SDK-related changes.
