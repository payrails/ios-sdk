---
type: how-to
title: How to Update the Checkout Amount
---

# How to Update the Checkout Amount

The checkout amount is set when the session is initialized from the init payload. If the amount changes after initialization — for example, the user adds a tip, chooses express shipping, or applies a discount code — you must update both your backend and the SDK in lockstep.

> **Important:** The SDK amount and the amount recorded in the Payrails execution must always match. A mismatch causes the payment to be rejected with a 401 error.

---

## How amount updates work

Updating the amount is a two-step process:

```
1. Recalculate amount in your UI (e.g. user selects a tip)
2. Call your backend to update the execution amount in Payrails
3. Call Payrails.update(options:) on the client to sync the SDK
4. User taps the pay button — amount is now consistent
```

Both steps must complete before the user initiates payment.

---

## Step 1: Recalculate the amount

```swift
let subtotal = 49.99
let tipPercentage = 0.15
let total = subtotal + (subtotal * tipPercentage)
let formattedTotal = String(format: "%.2f", total)  // "57.49"
let currency = "USD"
```

---

## Step 2: Update the amount on your backend

Call your backend, which calls the Payrails API to update the execution amount. The exact endpoint and request shape are defined by your backend implementation.

```swift
func updateExecutionAmount(value: String, currency: String) async throws {
    // Your backend call — POST /executions/{id}/update or similar
    // This MUST complete before calling Payrails.update()
    try await myBackendClient.updateCheckoutAmount(value: value, currency: currency)
}
```

---

## Step 3: Update the SDK amount

After the backend confirms the update, sync the SDK:

```swift
let newAmount = PayrailsAmount(value: formattedTotal, currency: currency)
Payrails.update(UpdateOptions(amount: newAmount))
```

---

## Complete example: tip selection

```swift
class CheckoutViewController: UIViewController {

    private var selectedTipRate: Double = 0.0

    @IBAction func tipButtonTapped(_ sender: UIButton) {
        let tipRate = tipRate(for: sender.tag)
        selectTip(rate: tipRate)
    }

    private func selectTip(rate: Double) {
        selectedTipRate = rate
        updateAmountDisplay()

        Task {
            await applyTipToPayment(rate: rate)
        }
    }

    private func updateAmountDisplay() {
        let total = calculateTotal(tipRate: selectedTipRate)
        amountLabel.text = formatAmount(total)
    }

    private func applyTipToPayment(rate: Double) async {
        let total = calculateTotal(tipRate: rate)
        let formatted = String(format: "%.2f", total)

        do {
            // Step 1: Update the backend execution
            try await myBackend.updateExecutionAmount(value: formatted, currency: "USD")

            // Step 2: Sync the SDK
            let newAmount = PayrailsAmount(value: formatted, currency: "USD")
            Payrails.update(UpdateOptions(amount: newAmount))

        } catch {
            showError("Failed to apply tip: \(error.localizedDescription)")
        }
    }

    private func calculateTotal(tipRate: Double) -> Double {
        let subtotal = 49.99
        return subtotal + (subtotal * tipRate)
    }
}
```

---

## After a redirect session recovery

If the user's payment involved a redirect (e.g. PayPal, generic redirect) and the app returned from the background, the session may be restored from the original init payload. In this case:

- Any in-memory amount updates made via `Payrails.update()` are **reset** to the original init payload amount.
- If you need to preserve the updated amount after a redirect, you must re-apply `Payrails.update()` once the session is restored.

---

## Troubleshooting

**Payment rejected with 401 / authorization error**
The SDK amount does not match the Payrails execution amount. Verify that your backend update completed successfully before calling `Payrails.update()`.

**`Payrails.update()` appears to have no effect**
If there is no active session, the call is silently dropped. Ensure `Payrails.createSession()` has completed successfully before calling `update()`. Check for any `No active Payrails session` log messages.

**Amount label does not update**
`Payrails.update()` updates the internal SDK state; it does not automatically refresh any UI element. Update your amount label independently after recalculating.

---

## Related

- [How to Query Session Data](how-to-query-session-data.md) — read the current amount back from the SDK
- [SDK API Reference – Updating Session State](sdk-api-reference.md#updating-session-state)
