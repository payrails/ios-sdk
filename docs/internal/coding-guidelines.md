# Coding Guidelines

Standards for contributors to the Payrails iOS SDK.

---

## Design principles

1. **Minimal public API.** Every `public` symbol is a maintenance obligation. Default to `internal`. Promote to `public` only when a merchant genuinely needs it, and track it in [`public-api-audit.md`](public-api-audit.md).
2. **Explicit over implicit.** Prefer named parameters and typed values over `Any`, string-based dispatch, and implicit state.
3. **No silent failures.** If an operation cannot proceed, use `precondition` (programming error) or return a typed `Result`/throw (runtime error). Do not silently return `nil` or `[]` from paths that indicate misuse.
4. **Simplicity over abstraction.** Do not introduce protocols, generics, or helper types until there are at least three concrete use sites. See the [one-off rule](#the-one-off-rule).

---

## Public API design rules

- New public types and methods must be added to [`public-api-audit.md`](public-api-audit.md) before the PR is merged.
- Public factory methods live on `Payrails` (static extension). UI elements are never initialised directly by merchants.
- Use `precondition` (not `fatalError` or `assert`) to guard against SDK misuse in factory methods. This produces a useful crash message in debug.
- Never expose internal types (`SDKConfig`, `PaymentOptions`, `Link`, etc.) in a public method signature.
- Prefer value types (`struct`, `enum`) over reference types for configuration and result objects.

---

## Visibility defaults

| Location | Default modifier | Rationale |
|---|---|---|
| `Domains/`, `Helpers/` configuration types | `public` | Merchant-facing API surface |
| `PaymentHelpers/` | `internal` | Implementation detail |
| `Vault/` | varies — follow existing pattern | Skyflow wrapper layer |
| Extension methods on `Payrails.Session` | `internal` unless added to audit doc | Session internals |
| `PaymentHandlerDelegate`, `PaymentHandlerStatus` | `internal` | Not part of the public contract |

---

## Error handling

### Programming errors (SDK misuse)

Use `precondition` when a factory is called before session creation. This crashes loudly in debug, helping merchants catch integration mistakes early:

```swift
precondition(currentSession != nil, "Payrails session must be initialized before creating a CardForm")
```

Do **not** return a sentinel value or empty view — it masks the bug.

### Runtime errors (expected failures)

Use `PayrailsError` for all runtime failure paths. Do not throw raw `Error` from the public API. If a new failure mode is needed, add a case to `PayrailsError` and update the audit doc.

### Delegate results vs throws

- Functions called from merchant code via `async throws` must throw `PayrailsError` (not a wrapped error).
- Delegate callbacks receive `OnPayResult` or `PayrailsError` directly — never raw `Error`.

---

## Concurrency

- All payment execution logic runs in `Task { }` blocks owned by the session or the button.
- Cancel in-flight tasks in `deinit` of view classes (`CardPaymentButton.deinit` cancels `paymentTask`).
- UI updates from async tasks use `await MainActor.run { }` or are dispatched via `DispatchQueue.main.async`. Do not call `@MainActor`-isolated code directly from a non-isolated async context.
- Do not use `DispatchQueue.global()` or `OperationQueue` for new code — use structured concurrency (`Task`, `async let`, `TaskGroup`).

---

## UIKit conventions

- All public UI elements are UIKit (`UIView`, `UIControl`) for maximum app compatibility.
- Do not add SwiftUI wrappers around payment elements — the debug viewer is the only SwiftUI surface.
- Use Auto Layout constraints internally inside SDK elements. Do not use frame-based layout.
- Public elements must work when added to a view hierarchy before `viewDidAppear`. Do not rely on the view being on-screen for configuration.
- Use `translatesAutoresizingMaskIntoConstraints = false` on all subviews inside SDK elements.

---

## Naming conventions

| Pattern | Convention |
|---|---|
| Factory methods | `create<Element>(config:)` on `Payrails` |
| Delegate methods | `elementType(_ view:, didEvent:)` |
| Callback typealiases | `On<Event>Callback` |
| Result enums | `On<Event>Result` |
| Style types | `<Element>Style` |
| Config types | `<Element>Config` |
| Translation types | `<Element>Translations` |

---

## The one-off rule

Do not create a helper, protocol, or abstraction for a one-time operation. Three concrete use sites are the threshold for extraction.

**Bad:**
```swift
// Only used for CardPaymentButton
protocol StylableButton {
    func applyButtonStyle(_ style: CardButtonStyle)
}
```

**Good:**
```swift
// Just inline it in CardPaymentButton
private func apply(style: CardButtonStyle) { ... }
```

---

## Code review checklist

- [ ] New public symbols are in `public-api-audit.md`
- [ ] No internal types exposed in public method signatures
- [ ] `precondition` used for factory misuse; `PayrailsError` for runtime failures
- [ ] Async tasks are cancelled in `deinit` if appropriate
- [ ] No `DispatchQueue.global()` or `OperationQueue` usage
- [ ] No `fatalError` in paths reachable at runtime (only in required initialisers like `init?(coder:)`)
- [ ] Tests added for new query keys, error cases, or factory behaviour
