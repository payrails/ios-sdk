## ADDED Requirements

### Requirement: CI workflow triggers for pull requests and main branch pushes
The repository MUST execute iOS SDK validation CI for pull requests targeting `main` and for direct pushes to `main`.

#### Scenario: Pull request to main triggers validation
- **WHEN** a pull request is opened, synchronized, or reopened with `main` as the target branch
- **THEN** the CI workflow SHALL start build, lint, and test validation jobs for that change

#### Scenario: Direct push to main triggers post-merge validation
- **WHEN** a commit is pushed directly to `main`
- **THEN** the CI workflow SHALL run build, lint, and test validation for post-merge verification

### Requirement: CI build validation uses shared Xcode project configuration
The CI system MUST perform SDK build validation on a macOS runner using a committed shared Xcode scheme and a pinned Xcode toolchain configuration.

#### Scenario: Build validation succeeds with valid SDK changes
- **WHEN** CI executes the build step with the shared scheme configuration
- **THEN** the workflow SHALL mark the build step as successful only if compilation completes without errors

#### Scenario: Build validation fails on compile regression
- **WHEN** CI executes the build step and a compile error exists
- **THEN** the workflow SHALL fail the build step and report the failure in the CI run summary

### Requirement: CI test validation uses canonical simulator destination
The CI system MUST execute automated tests with `xcodebuild test` using `platform=iOS Simulator,name=iPhone 15,OS=latest` as the canonical destination.

#### Scenario: Tests pass on canonical simulator destination
- **WHEN** CI runs the test step with the canonical simulator destination
- **THEN** the workflow SHALL pass the test step only if all executed tests succeed

#### Scenario: Test failure blocks validation
- **WHEN** any test fails or the simulator test execution errors
- **THEN** the workflow SHALL fail the test step and mark the overall CI validation as failed

### Requirement: CI lint validation is strict and baseline-free
The CI system MUST run SwiftLint using repository configuration and MUST fail on lint violations without using a temporary baseline exception.

#### Scenario: Lint step passes when no violations exist
- **WHEN** CI executes SwiftLint with repository rules
- **THEN** the lint step SHALL pass only if no lint violations are reported

#### Scenario: Lint violation blocks validation
- **WHEN** SwiftLint reports any violation during CI
- **THEN** the lint step SHALL fail and the overall CI validation SHALL be marked as failed

### Requirement: CI results are enforceable as merge quality gates
The CI workflow MUST produce status checks that can be required by branch protection so failing build, lint, or test prevents merge.

#### Scenario: All checks pass and PR is merge-eligible
- **WHEN** build, lint, and test steps all succeed for a pull request
- **THEN** CI SHALL report successful status checks suitable for required-check enforcement

#### Scenario: Any check fails and PR remains blocked
- **WHEN** one or more validation steps fail
- **THEN** CI SHALL report a failed status and the pull request SHALL not satisfy required quality checks
