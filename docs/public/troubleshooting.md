# Troubleshooting

Common issues and how to fix them.

---

## Enabling debug logs

The SDK provides two mechanisms for debugging.

### On-screen log overlay (SwiftUI)

Add the debug config viewer to any SwiftUI view:

```swift
import SwiftUI
import Payrails

struct DebugView: View {
    var body: some View {
        Payrails.Debug.configViewer()
    }
}
```

This renders the parsed SDK configuration and recent log entries on screen. Requires an active session.

### Console logging

The SDK writes to `LogStore.shared` and also calls `Swift.print`. To see logs in the Xcode console, ensure the scheme is not suppressing standard output.

---

## Installation issues

**`pod install` fails with "Unable to find a specification for Payrails/Checkout"`**
- Ensure your `Podfile` specifies the correct subspec: `pod 'Payrails/Checkout'`
- Run `pod repo update` to refresh the CocoaPods spec repos, then retry

**SPM resolution fails**
- Confirm the package URL is exactly `https://github.com/payrails/ios-sdk.git`
- Try **File → Packages → Reset Package Caches** in Xcode

**Linker error: PayrailsCSE not found**
- CocoaPods: ensure `PayrailsCSE` is a transitive dependency via the `Checkout` subspec — do not remove it from `Podfile.lock`
- SPM: the `ios-cse` package is declared in `Package.swift` and should resolve automatically

---

## SDK initialization issues

**"Provided configuration data is invalid and cannot be parsed"**
- The init payload `data` field is not valid base64-encoded JSON
- Ensure your backend passes the exact string returned by the Payrails `POST /checkout/initialize` endpoint without modification

**"SDK has not been properly initialized"**
- `Payrails.createCardForm()` or another factory was called before `Payrails.createSession()` completed
- These calls trigger a `precondition` failure if called without an active session — always `await` session creation first

**Session init works in debug but fails in release**
- Check that your backend call succeeds in the production environment
- Verify that the `env` option matches your backend environment (`.prod` vs `.dev`)

---

## Card form issues

**Card form appears but cannot submit — payment button stays unresponsive**
- Ensure `Payrails.createCardForm()` is called before `Payrails.createCardPaymentButton()`
- The button holds a strong reference to the form at creation time; order matters

**Validation errors not shown**
- Check that the card form has enough vertical space — error labels require height to render
- Use `CardFormConfig(showRequiredAsterisk: true)` to make required fields explicit

**Card icon not appearing**
- Pass `showCardIcon: true` in `CardFormConfig`
- Icons require the `Media.xcassets` bundle to be included. SPM bundles this automatically; CocoaPods requires `spec.resources` — verify nothing is overriding it

**Layout falls back to default unexpectedly (console logs "falling back to default layout")**
- Your custom `CardLayoutConfig` is missing required fields (`.CARD_NUMBER`, `.CVV`, and at least one expiry field)
- All three are required for a valid submission

---

## Apple Pay issues

**Apple Pay button is not visible**
- Check `session.isApplePayAvailable` — it returns `false` if the device has no cards or Apple Pay is not configured in the init payload
- The `PKPaymentButton` hides itself when `PKPaymentAuthorizationViewController.canMakePayments()` returns false

**Apple Pay sheet dismisses immediately**
- The merchant identifier in your app's entitlements does not match the one in the Payrails merchant configuration
- Verify the capability is enabled under **Signing & Capabilities** in Xcode

**"incorrectPaymentSetup" error for Apple Pay**
- The init payload does not include an Apple Pay payment option configuration
- Contact your Payrails integration engineer to enable Apple Pay in your merchant account

---

## PayPal issues

**PayPal button tap does nothing**
- Ensure the `PayPalCheckout` SDK is properly linked (check the build phases)
- The PayPal SDK requires a client ID in the init payload config; verify the payload includes it

**PayPal checkout WebView dismissed with no result**
- The user cancelled — `OnPayResult.cancelledByUser` is delivered via the delegate callback

---

## Payment issues

**Payment results in `.authorizationFailed`**
- This maps to `PayrailsError.authenticationError` — the session token has expired
- Re-initialize the session with a fresh init payload from your backend

**Payment results in `.failure` after 3DS**
- The card issuer declined the transaction post-3DS; this is not an SDK error
- Show the user an appropriate message and optionally offer another payment method

**3DS challenge never appears / `presentPayment(_:)` not called**
- Confirm that `payButton.presenter = self` is set on the `CardPaymentButton`
- Confirm your view controller conforms to both `PaymentPresenter` and `PayrailsCardPaymentFormDelegate` if needed

**Long-polling timeout errors**
- `PayrailsError.finalStatusNotFoundAfterLongPoll` — the payment status was not confirmed within the polling window
- This is typically a transient network or backend issue; prompt the user to check their payment status through your order history

---

## Stored instruments issues

**`Payrails.getStoredInstruments()` returns an empty array**
- The init payload does not include any stored instruments for this holder reference
- Instruments with status other than `"enabled"` or `"created"` are filtered out

**StoredInstruments view renders nothing**
- Same as above — the list silently renders nothing when there are no eligible instruments
- Optionally check the count before adding the view: `Payrails.getStoredInstruments().isEmpty`

---

## Getting help

1. Enable debug logs and capture the output
2. Reproduce the issue with `env: .dev` to rule out production-only configuration issues
3. Check the `PayrailsError.errorDescription` for the specific failure reason
4. Open a support ticket with your `executionId` (from `Payrails.query(.executionId)`) and the full error description
