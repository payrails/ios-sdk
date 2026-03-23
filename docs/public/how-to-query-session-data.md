---
type: how-to
title: How to Query Session Data
---

# How to Query Session Data

`Payrails.query(_:)` provides read-only access to the current session's configuration and state. Use it to retrieve the execution ID, payment amount, stored instruments, API links, and more — without reaching into internal session state.

## Prerequisites

An active session must exist (created via `Payrails.createSession(with:)`). All queries return `nil` when no session is active.

---

## Calling `Payrails.query`

```swift
let result: PayrailsQueryResult? = Payrails.query(.amount)
```

The return type is `PayrailsQueryResult?`, a Swift enum. Switch on it to extract the typed value:

```swift
switch Payrails.query(.amount) {
case .amount(let amount):
    print("Amount:", amount.value, amount.currency)
case .none:
    print("No active session")
default:
    break
}
```

---

## Available query keys

### `.executionId`

The execution ID for the current checkout. Pass this to your backend for order correlation.

```swift
if case .string(let executionId) = Payrails.query(.executionId) {
    print("Execution ID:", executionId)
    // myBackend.attachExecutionId(executionId)
}
```

### `.holderReference`

The holder reference (customer identifier) associated with this session.

```swift
if case .string(let ref) = Payrails.query(.holderReference) {
    print("Holder reference:", ref)
}
```

### `.amount`

The payment amount and currency for the current execution.

```swift
if case .amount(let payrailsAmount) = Payrails.query(.amount) {
    let display = "\(payrailsAmount.currency) \(payrailsAmount.value)"
    amountLabel.text = display
}
```

### `.binLookup`

The API link for BIN lookup. Use this to call the lookup endpoint and determine card network, country, and 3DS requirements before payment.

```swift
if case .link(let link) = Payrails.query(.binLookup) {
    print("BIN lookup URL:", link.href ?? "")
    print("Method:", link.method ?? "")
}
```

### `.instrumentDelete`

The API link for deleting a stored instrument.

```swift
if case .link(let link) = Payrails.query(.instrumentDelete) {
    // Use link.href and link.method to build the request in your networking layer
}
```

### `.instrumentUpdate`

The API link for updating a stored instrument (e.g. setting as default).

```swift
if case .link(let link) = Payrails.query(.instrumentUpdate) {
    // Use link.href and link.method to build the request
}
```

### `.paymentMethodConfig(filter:)`

Configuration for available payment methods, filtered by a `PaymentMethodFilter`.

```swift
// All payment methods
if case .paymentOptions(let options) = Payrails.query(.paymentMethodConfig(.all)) {
    for option in options {
        print(option.paymentMethodCode, option.clientConfig?.displayName ?? "")
    }
}

// Redirect-based methods only
if case .paymentOptions(let options) = Payrails.query(.paymentMethodConfig(.redirect)) {
    // Build redirect payment buttons dynamically
}

// A specific method by code
if case .paymentOptions(let options) = Payrails.query(.paymentMethodConfig(.specific("ideal"))) {
    let ideal = options.first
    print("iDEAL display name:", ideal?.clientConfig?.displayName ?? "")
}
```

### `.paymentMethodInstruments(type:)`

The stored instruments for a given payment type.

```swift
// Card instruments
if case .storedInstruments(let cards) = Payrails.query(.paymentMethodInstruments(type: .card)) {
    print("Saved cards:", cards.count)
    for card in cards {
        print(" -", card.id, card.type.rawValue)
    }
}

// PayPal instruments
if case .storedInstruments(let paypals) = Payrails.query(.paymentMethodInstruments(type: .payPal)) {
    print("Saved PayPal accounts:", paypals.count)
}
```

---

## Summary table

| Key | Returns | Description |
|---|---|---|
| `.executionId` | `.string` | Current execution ID |
| `.holderReference` | `.string` | Customer holder reference |
| `.amount` | `.amount(PayrailsAmount)` | Payment amount and currency |
| `.binLookup` | `.link(PayrailsLink)` | BIN lookup API link |
| `.instrumentDelete` | `.link(PayrailsLink)` | Instrument delete API link |
| `.instrumentUpdate` | `.link(PayrailsLink)` | Instrument update API link |
| `.paymentMethodConfig(.all)` | `.paymentOptions([PayrailsPaymentOption])` | All payment method configs |
| `.paymentMethodConfig(.redirect)` | `.paymentOptions([PayrailsPaymentOption])` | Redirect-only methods |
| `.paymentMethodConfig(.specific(code))` | `.paymentOptions([PayrailsPaymentOption])` | Single method config |
| `.paymentMethodInstruments(type:)` | `.storedInstruments([StoredInstrument])` | Saved instruments by type |

---

## Related

- [How to Update Checkout Amount](how-to-update-checkout-amount.md)
- [SDK API Reference – Query API](sdk-api-reference.md#query-api)
