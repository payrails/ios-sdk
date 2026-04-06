# Release SDK Skill — iOS SDK

Prepares a new release of the Payrails iOS SDK. Handles version bumping, changelog
generation, docs freshness audit, build/lint validation, and commit/push — producing
a PR-ready branch.

> **Publishing happens after the PR merges**, via a GitHub Release. This skill does
> NOT create the GitHub Release or push tags. It prepares everything up to that point.

---

## When to Use

Trigger on: `/release-sdk`, "release the SDK", "prepare a release", "bump version",
"create a new release".

---

## Inputs

The user may provide:
- **Version number** (e.g. "1.27.0", "v2.0.0") — if not provided, ASK.
- **Branch name** — if not on a release branch, ASK or create one.

---

## Workflow

### Step 1 — Determine the version

1. Read current version from `Payrails/Classes/Public/Version.swift` (`SDK_VERSION`)
2. Read current version from `Payrails.podspec` (`spec.version`)
3. Confirm they match. If not, flag the inconsistency and stop.
4. If the user specified a version, use it. Otherwise, ASK:
   - Show the current version
   - Suggest the next version based on semver:
     - PATCH: bug fixes, docs, internal refactors
     - MINOR: new public API (additive, backward-compatible)
     - MAJOR: breaking public API changes
5. Validate the new version is greater than the current version.

### Step 2 — Build the changelog entry

1. Find the last release tag: `git tag --sort=-version:refname | head -1`
2. Get the commit log since that tag: `git log <last-tag>..HEAD --oneline`
3. Group changes by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) categories:
   - **Added** — new features
   - **Changed** — changes to existing functionality
   - **Deprecated** — soon-to-be removed features
   - **Removed** — removed features
   - **Fixed** — bug fixes
   - **Security** — vulnerability fixes
4. Reference ticket numbers (ONB-123, PR-456) where available in commit messages
5. Flag any breaking changes prominently
6. Format the entry to match the existing `CHANGELOG.md` style

### Step 3 — Audit public docs for freshness

Read each file in `docs/public/` and cross-reference with the changelog:

| Document | Check |
|---|---|
| `quick-start.md` | Setup steps, dependencies, version references current? |
| `sdk-api-reference.md` | Covers all current public APIs? Missing any new ones? |
| `concepts.md` | Architectural descriptions still accurate? |
| `merchant-styling-guide.md` | Styling examples up to date? |
| `how-to-tokenize-card.md` | Code examples working with current API? |
| `how-to-query-session-data.md` | Query examples current? |
| `how-to-update-checkout-amount.md` | Update flow current? |
| `troubleshooting.md` | Known issues still relevant? Any new ones to add? |

For each doc, report: **UP TO DATE** or **NEEDS UPDATE** (with specific issue).

Present the audit table to the user before proceeding.

### Step 4 — Apply changes

Execute in this order:

#### 4.1 Version bump

Update both version files to the new version:

```
Payrails/Classes/Public/Version.swift  →  var SDK_VERSION = "<new-version>"
Payrails.podspec                       →  spec.version = "<new-version>"
```

Also update version references in docs:
- `docs/public/sdk-api-reference.md` → `**Current version:** <new-version>`

#### 4.2 Changelog

- If `CHANGELOG.md` does not exist at the repo root, create it with the standard
  Keep a Changelog header.
- Prepend the new version entry below the header.
- Format:

```markdown
## [<version>] - <YYYY-MM-DD>

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

#### 4.3 Docs updates

For each doc flagged as **NEEDS UPDATE** in the audit:
- Use the `/public-docs` skill to update it
- Ensure Mermaid diagrams are included where required

If no docs need updating, skip this step.

#### 4.4 Update `docs/internal/releasing.md`

Update the example version strings in the releasing doc to match the new version.

### Step 5 — Validate

Run these checks and report results:

#### 5.1 Build

```bash
xcodebuild -workspace Payrails.xcworkspace -scheme Payrails \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  build
```

#### 5.2 Podspec lint

```bash
pod spec lint Payrails.podspec --allow-warnings
```

If `pod` is not available, skip with a note.

#### 5.3 Version consistency check

Verify that `SDK_VERSION` in `Version.swift` matches `spec.version` in `Payrails.podspec`.

### Step 6 — Commit and push

1. Stage all changed files (version files, changelog, docs)
2. Commit with message: `ONB-XXX: prepare release v<version>` (use the ticket number
   from the branch name if available, otherwise ask)
3. Push to the current branch

### Step 7 — Summary

Print a release checklist:

```
Release v<version> preparation complete:

[x] Version bumped: <old> → <new>
[x] CHANGELOG.md updated
[x] Docs audit: X up to date, Y updated
[x] Build passed
[x] Podspec lint passed
[x] Committed and pushed to <branch>

Next steps (manual):
1. Open PR to main (or merge if already open)
2. Wait for CI to pass
3. Create GitHub Release:
   - Tag: v<version>
   - Target: main
   - Title: v<version>
   - Body: paste changelog entry
4. CI will auto-publish to CocoaPods trunk
5. SPM consumers can update immediately (tag = release)
```

---

## Version Files Reference

| File | Property | Format |
|---|---|---|
| `Payrails.podspec` | `spec.version` | `"X.Y.Z"` (Ruby string) |
| `Payrails/Classes/Public/Version.swift` | `SDK_VERSION` | `"X.Y.Z"` (Swift string) |

Both MUST always be in sync. Never update one without the other.

---

## CHANGELOG.md Format

Follow [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/):

```markdown
# Changelog

All notable changes to the Payrails iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [X.Y.Z] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

---

## Critical Rules

1. **Always ask for the version if not provided.** Never guess.
2. **Both version files must be updated together.** A mismatch blocks the release.
3. **Build must pass before committing.** Never commit a version bump that doesn't compile.
4. **Changelog entries must reference ticket numbers** where available in commit messages.
5. **Breaking changes must be flagged prominently** with migration instructions.
6. **This skill does NOT create GitHub Releases.** It prepares the branch. Publishing is manual.
7. **Use the `/public-docs` skill** for any documentation updates to ensure Divio compliance.
