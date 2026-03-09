## 1. CI Foundations

- [x] 1.1 Create and commit a shared Xcode scheme under `Payrails.xcodeproj/xcshareddata/xcschemes/` for deterministic CI build/test execution.
- [x] 1.2 Add CI helper scripts under `scripts/ci/` for build, lint, and test commands so local and CI checks use the same entry points.
- [x] 1.3 Add or update `.swiftlint.yml` to define repository lint rules for strict CI enforcement without a temporary baseline.

## 2. GitHub Actions Workflow

- [x] 2.1 Add `.github/workflows/ci.yaml` to run on pull requests targeting `main` and on direct pushes to `main`.
- [x] 2.2 Configure the workflow to use macOS runners and a pinned Xcode setup compatible with `platform=iOS Simulator,name=iPhone 15,OS=latest`.
- [x] 2.3 Implement a build job step that invokes the CI build script and fails the workflow on compilation errors.
- [x] 2.4 Implement a lint job step that invokes the CI lint script and fails the workflow on any SwiftLint violation.
- [x] 2.5 Implement a test job step that invokes the CI test script with `xcodebuild test` on `platform=iOS Simulator,name=iPhone 15,OS=latest`.

## 3. Quality Gate Enforcement

- [x] 3.1 Ensure workflow check names are stable and suitable for branch protection required-check configuration.
- [x] 3.2 Update repository documentation to describe CI prerequisites, local pre-PR commands, and expected failure behavior.

## 4. Rollout and Safety
- [x] 4.3 Define and document rollback steps (disable required check, then revert CI workflow/scripts if needed).
