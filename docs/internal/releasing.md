# Releasing

How to publish a new version of the Payrails iOS SDK.

---

## Version source of truth

The version string lives in **two places** that must always be kept in sync:

| File | Property |
|---|---|
| `Payrails.podspec` | `spec.version` |
| `Payrails/Classes/Public/Version.swift` | `SDK_VERSION` |

Both must be updated to the same value before releasing.

```ruby
# Payrails.podspec
spec.version = "1.28.0"
```

```swift
// Version.swift
var SDK_VERSION = "1.28.0"
```

---

## Release workflow

```
Update version in two files
(Payrails.podspec + Version.swift)
        │
        ▼
Commit to main (or merge PR)
        │
        ▼
Verify CI is green
├── scripts/ci/build.sh
├── scripts/ci/lint.sh
└── scripts/ci/test.sh
        │
        ▼
Create GitHub Release
(tag: v<version>, target: main)
        │
        ├──── CocoaPods ──► CI runs `pod trunk push`
        │                        │
        │                   Consumers: pod install
        │
        └──── SPM ──► Tag is the release (no extra step)
                           │
                      Consumers: update package version
```

Releases are triggered by creating a **GitHub Release** with a version tag. The CI pipeline publishes to CocoaPods trunk automatically.

### Step-by-step

1. **Update the version** in both files above. Commit directly to `main` (or merge a version bump PR).

2. **Verify CI is green** on `main`:
   - Build: `scripts/ci/build.sh`
   - Lint: `scripts/ci/lint.sh`
   - Tests: `scripts/ci/test.sh`

3. **Create a GitHub Release:**
   - Tag: `v<version>` (e.g. `v1.28.0`) — must match `spec.version` exactly
   - Target: `main`
   - Title: `v<version>`
   - Body: changelog summary

4. **CI publishes the podspec** to CocoaPods trunk using `pod trunk push`.

5. **Verify the release** by checking the CocoaPods trunk page and doing a clean `pod install` in a test project.

---

## SPM release

SPM consumers use the GitHub tag directly. Once the GitHub Release is created with the correct tag, SPM consumers can update to the new version immediately — no separate publish step.

---

## Local testing before release

To test the SDK locally without publishing:

### CocoaPods

In your test app's `Podfile`:

```ruby
pod 'Payrails', :path => '../ios-sdk'
```

Run `pod install`. This links directly to the local source directory.

### SPM

In Xcode, **File → Add Package Dependencies**, use a local file URL:

```
file:///path/to/ios-sdk
```

Or add to your `Package.swift`:

```swift
.package(path: "../ios-sdk")
```

---

## Lint the podspec before release

```bash
pod spec lint Payrails.podspec --allow-warnings
```

This validates the spec against the current source. Fix all errors before releasing. Warnings are acceptable but should be minimised.

---

## Versioning policy

This SDK follows **Semantic Versioning** (`MAJOR.MINOR.PATCH`):

| Type of change | Version bump |
|---|---|
| Breaking public API change (remove/rename public symbol) | MAJOR |
| New public API (additive, backward-compatible) | MINOR |
| Bug fix, internal refactor, documentation update | PATCH |

Breaking changes require an entry in the public API audit doc documenting the migration path.

---

## Required GitHub secrets

The CI pipeline requires the following secrets to be configured in the repository settings:

| Secret | Purpose |
|---|---|
| `COCOAPODS_TRUNK_TOKEN` | Authentication for `pod trunk push` |

Contact the infrastructure team if these need to be rotated.

---

## Rollback

If a bad release is published:

1. Create a patch release immediately with the fix (do not unpublish from CocoaPods trunk — it breaks existing `Podfile.lock` files for all consumers).
2. For SPM, the bad tag can be removed from GitHub if no consumers have locked to it yet. Check with the team before deleting tags.
