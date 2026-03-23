---
type: how-to
title: How to Tokenize a Card
---

# How to Tokenize a Card

Tokenization saves a card to the Payrails vault without triggering an immediate payment. Use this when you want to store a card for future purchases (subscriptions, one-click checkout, etc.).

## Prerequisites

- An active Payrails session (see [Quick Start](quick-start.md))
- Vault configuration present in the init payload (`providerConfigId`)
- A `holderReference` in the session config (required to associate the card with a customer)

---

## How tokenization works

The card form collects and encrypts the card fields client-side using PayrailsCSE. The encrypted blob is sent to the Payrails vault, which returns an instrument ID. Your backend can then use that instrument ID for future payments without ever handling raw card data.

There are two paths:

| Path | When to use |
|---|---|
| **Tokenize only** (`storeInstrument: true`, no immediate payment) | Save the card for later, no charge now |
| **Pay and save** (`showSaveInstrument: true` on card form) | Charge the card and save it simultaneously |

---

## Path 1: Tokenize without payment

### Step 1: Create the card form with save toggle

```swift
let cardForm = Payrails.createCardForm(
    config: CardFormConfig(
        showNameField: true,
        showSaveInstrument: false  // hide the toggle; saving is always-on here
    )
)
```

### Step 2: Collect the card and tokenize

The card form collects and encrypts the data. You drive tokenization by calling `tokenize` on the session directly after collecting:

```swift
// Implement PaymentPresenter on your view controller
// When the user taps your custom "Save card" button, call collectFields() on the form.
// The form will call its delegate when data is ready.

extension MyViewController: PayrailsCardFormDelegate {
    func cardForm(_ view: Payrails.CardForm, didCollectCardData encryptedData: String) {
        Task {
            do {
                let options = TokenizeOptions(
                    storeInstrument: true,
                    futureUsage: .cardOnFile
                )
                let response = try await session.tokenize(
                    encryptedData: encryptedData,
                    options: options
                )
                // response.instrumentId is your saved card token
                print("Card saved with instrument ID:", response.instrumentId)
            } catch {
                print("Tokenization failed:", error.localizedDescription)
            }
        }
    }

    func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error) {
        print("Card collection error:", error.localizedDescription)
    }
}
```

### Step 3: Choose a `FutureUsage`

`FutureUsage` tells the vault how the instrument will be used for network-mandated storage rules:

| Value | Meaning |
|---|---|
| `.cardOnFile` | Customer-initiated future payments (default) |
| `.subscription` | Merchant-initiated recurring charges |
| `.unscheduledCardOnFile` | Merchant-initiated, non-recurring (e.g. top-up) |

```swift
let options = TokenizeOptions(
    storeInstrument: true,
    futureUsage: .subscription
)
```

---

## Path 2: Pay and save simultaneously

Enable the save toggle on the card form. The user checks the toggle and taps Pay; the SDK performs the payment and vaults the card in one call.

```swift
let cardForm = Payrails.createCardForm(
    showSaveInstrument: true  // renders a "Save card" checkbox
)

let payButton = Payrails.createCardPaymentButton(
    translations: CardPaymenButtonTranslations(label: "Pay")
)
payButton.delegate = self
payButton.presenter = self
```

The SDK automatically includes `storeInstrument: true` in the payment request when the toggle is checked. No additional code is needed.

---

## Using the saved instrument ID

After tokenization, the `SaveInstrumentResponse` contains the instrument ID:

```swift
let instrumentId = response.instrumentId

// Pass it to your backend to associate with the customer
// Or use it immediately with the SDK:
let storedInstruments = Payrails.getStoredInstruments(for: .card)
// storedInstruments will include the newly saved card after a session refresh
```

---

## Verification checklist

- [ ] `providerConfigId` is present in the init payload
- [ ] `holderReference` is present in the init payload
- [ ] `TokenizeOptions.storeInstrument` is `true`
- [ ] `FutureUsage` matches the intended use case
- [ ] Your backend associates the returned instrument ID with the customer record

---

## Troubleshooting

**"Vault configuration with providerConfigId is required"**
The init payload does not include vault configuration. Ensure your backend passes the correct Payrails environment and merchant configuration.

**"holderReference is required for tokenization"**
The holder reference is missing from the init payload. Contact your Payrails integration engineer to verify the checkout initialization call.

**Card form delegate not being called**
Make sure `cardForm.delegate = self` is set before the user triggers collection.

---

## Related

- [How to Query Session Data](how-to-query-session-data.md) — retrieve stored instruments after tokenization
- [SDK API Reference – Tokenization](sdk-api-reference.md#tokenization)
