# Payrails Query Extension Guide

Design rationale and step-by-step instructions for extending the `Payrails.query()` API.

---

## Why this API exists

Before `Payrails.query()`, merchant code accessed session state via ad-hoc paths:

```swift
// old approach — fragile, no type safety
let id = session?.executionId
```

This created implicit coupling to internal session fields. The query API replaces scattered getters with a single, typed entry point that mirrors the web SDK's `payrails.query(key, params)` pattern.

**Goals:**
- Single entry point for all read-only session state
- Type-safe results via `PayrailsQueryResult` enum
- No session reference required by the caller (static on `Payrails`)
- Exhaustive dispatch enforced by the Swift compiler (no `default:` fall-through)

---

## Architecture

### Query dispatch flow

```
Merchant code
      │
      ▼
Payrails.query(.amount)          ◄── static entry point
      │
      │  currentSession?.query(key)
      ▼
Session.query(_:)                ◄── internal dispatch
      │
      │  switch key {
      │    case .amount:
      │      return .amount(config.amount)
      │    case .executionId:
      │      return .string(config.execution.id)
      │    ...
      │  }
      ▼
PayrailsQueryResult?             ◄── typed result (nil if no session)
```

### Entry point

```swift
// Payrails.swift
public extension Payrails {
    static func query(_ key: PayrailsQueryKey) -> PayrailsQueryResult? {
        return currentSession?.query(key)
    }
}
```

Returns `nil` when no session is active. This is intentional — callers check for `nil` rather than receiving a throw.

### Dispatch

```swift
// PayrailsSession.swift — Session.query(_:)
func query(_ key: PayrailsQueryKey) -> PayrailsQueryResult? {
    switch key {
    case .holderReference: ...
    case .amount: ...
    case .executionId: ...
    case .binLookup: ...
    case .instrumentDelete: ...
    case .instrumentUpdate: ...
    case .paymentMethodConfig(let filter): ...
    case .paymentMethodInstruments(let type): ...
    }
}
```

The `switch` has no `default:` case. This is deliberate: adding a new `PayrailsQueryKey` case causes a compiler error here, forcing the implementor to handle it.

### Key and result types

Both live in `Domains/QueryTypes.swift`:

```swift
public enum PayrailsQueryKey { ... }     // one case per query
public enum PayrailsQueryResult { ... }  // one case per result type
public enum PaymentMethodFilter { ... }  // parameter type for paymentMethodConfig
```

Result types (`PayrailsAmount`, `PayrailsLink`, `PayrailsPaymentOption`) are public value types that wrap the internal `SDKConfig`-derived values. This keeps internal types out of the public API.

---

## Adding a new query key — step-by-step

### Overview

```
Step 1                    Step 2                    Step 3
Add key case              Add/reuse result type     Implement dispatch
in QueryTypes.swift       in QueryTypes.swift       in PayrailsSession.swift
        │                         │                         │
        ▼                         ▼                         ▼
PayrailsQueryKey {        PayrailsQueryResult {     switch key {
  case myNewKey             case myNewResult          case .myNewKey:
}                         }                           return .myNewResult(...)
                                                    }
        │                         │                         │
        └─────────────────────────┴─────────────────────────┘
                                  │
                    Step 4: Write tests
                    Step 5: Update public-api-audit.md
```

### Step 1: Add the key case

In `Domains/QueryTypes.swift`, add a case to `PayrailsQueryKey`:

```swift
public enum PayrailsQueryKey {
    // existing cases ...
    case myNewKey  // or with associated value: case myNewKey(SomeFilter)
}
```

If the result needs a parameter (like `paymentMethodConfig` uses `PaymentMethodFilter`), define the parameter type as a `public enum` or `public struct` in the same file.

### Step 2: Add or reuse a result type

If an existing `PayrailsQueryResult` case covers the return type (e.g. `.string`, `.amount`, `.link`), reuse it. Otherwise, add a new case:

```swift
public enum PayrailsQueryResult {
    case string(String)
    case amount(PayrailsAmount)
    case link(PayrailsLink)
    case paymentOptions([PayrailsPaymentOption])
    case storedInstruments([StoredInstrument])
    case myNewResultType(MyNewType)  // add if needed
}
```

If you add a new result type, also add the supporting public struct in `QueryTypes.swift`.

### Step 3: Implement dispatch in `Session.query(_:)`

In `PayrailsSession.swift`, add the case to the `switch`:

```swift
case .myNewKey:
    guard let value = config?.someInternalField else { return nil }
    return .myNewResultType(MyNewType(from: value))
```

The compiler will error here if you miss this step.

### Step 4: Write tests

Add tests in `PayrailsTests/` covering:
- Returns expected value when session is initialised with the relevant data
- Returns `nil` when the underlying data is absent
- Static `Payrails.query(.myNewKey)` returns `nil` when no session exists

### Step 5: Update the public API audit

Add the new key and result type to [`public-api-audit.md`](public-api-audit.md) with status **PUBLIC** and rationale.

---

## Current query keys reference

| Key | Associated value | Returns | Source in SDKConfig |
|---|---|---|---|
| `.executionId` | — | `.string` | `config.execution?.id` |
| `.holderReference` | — | `.string` | `config.holderReference` |
| `.amount` | — | `.amount` | `config.amount` |
| `.binLookup` | — | `.link` | `config.execution?.links.lookup` |
| `.instrumentDelete` | — | `.link` | `config.links?.instrumentDelete` |
| `.instrumentUpdate` | — | `.link` | `config.links?.instrumentUpdate` |
| `.paymentMethodConfig` | `PaymentMethodFilter` | `.paymentOptions` | `config.allPaymentOptions()` |
| `.paymentMethodInstruments` | `Payrails.PaymentType` | `.storedInstruments` | `session.storedInstruments(for:)` |

---

## Visibility rules

- `PayrailsQueryKey`, `PayrailsQueryResult`, `PaymentMethodFilter`, and all result value types must be `public`.
- The `Session.query(_:)` method is `internal` (not `public`) — the public entry point is the static `Payrails.query(_:)`.
- Internal config types (`SDKConfig`, `PaymentOptions`, `Link`) must not appear in query result types.

---

## Related files

| File | Role |
|---|---|
| `Domains/QueryTypes.swift` | Public key, result, and filter types |
| `Payrails/Classes/Public/Payrails.swift` | Static `query(_:)` entry point |
| `Payrails/Classes/Public/PayrailsSession.swift` | Dispatch logic in `Session.query(_:)` |
| `public-api-audit.md` | API status tracking |
