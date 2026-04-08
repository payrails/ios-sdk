# Payrails iOS SDK — Styling Guide for Merchants

> **Version:** 1.0 · **Last Updated:** April 2026
> This guide covers how to customize the look and feel of every Payrails UI component so it matches your app's brand.

---

## Table of Contents

1. [Overview](#overview)
2. [How Styling Works](#how-styling-works)
3. [Card Form Styling](#card-form-styling)
   - [Wrapper Style](#wrapper-style)
   - [Input Field Styles](#input-field-styles)
   - [Per-Field Overrides](#per-field-overrides)
   - [Label Styles](#label-styles)
   - [Error Text Style](#error-text-style)
   - [Spacing](#spacing)
4. [Field Variants](#field-variants)
5. [Card Icon Alignment](#card-icon-alignment)
6. [Layout Presets](#layout-presets)
7. [Card Payment Button Styling](#card-payment-button-styling)
8. [Generic Redirect Button Styling](#generic-redirect-button-styling)
9. [Stored Instruments Styling](#stored-instruments-styling)
   - [List Style](#list-style)
   - [Pay Button Style](#pay-button-style)
   - [Delete Button Style](#delete-button-style)
   - [Update Button Style](#update-button-style)
10. [Apple Pay Button Styling](#apple-pay-button-styling)
11. [Translations & Labels](#translations--labels)
    - [Card Form Translations](#card-form-translations)
    - [Button Translations](#button-translations)
    - [Stored Instruments Translations](#stored-instruments-translations)
12. [Using with SwiftUI](#using-with-swiftui)
13. [Full Example — Themed Checkout](#full-example--themed-checkout)
14. [Style Properties Reference](#style-properties-reference)

---

## Overview

The Payrails iOS SDK ships with sensible default styles for every UI component. You can override **any** property you want — only the values you provide will replace the defaults, everything else stays intact.

**Key components you can style:**

| Component | Description |
|---|---|
| **Card Form** | Secure card-number, CVV, expiry, and cardholder-name fields |
| **Card Payment Button** | "Pay" button that submits the card form |
| **Generic Redirect Button** | Button for redirect-based methods (iDEAL, Sofort, etc.) |
| **Stored Instruments List** | Displays saved cards / PayPal accounts for returning customers |
| **Apple Pay Button** | Native Apple Pay button (limited to Apple's built-in styles) |

---

## How Styling Works

The SDK uses a **merge-over-defaults** pattern:

1. Every style struct has a `.defaultStyle` preset with production-ready defaults.
2. You create a style struct and set **only the properties you want to change** — leave everything else `nil`.
3. The SDK automatically merges your customizations over the defaults.

```swift
// You only need to set what you want to change:
let myButtonStyle = CardButtonStyle(
    backgroundColor: .black,
    cornerRadius: 12
    // Everything else (textColor, font, height…) keeps its default value
)
```

This means you **never** need to provide a complete style — just your overrides.

---

## Card Form Styling

The card form is created via `Payrails.createCardForm(config:)`. All visual customization goes into `CardFormConfig.styles`, which is a `CardFormStylesConfig`.

### Quick Start

```swift
let config = CardFormConfig(
    styles: CardFormStylesConfig(
        wrapperStyle: CardWrapperStyle(cornerRadius: 12),
        allInputFieldStyles: CardFieldSpecificStyles(
            base: CardStyle(
                borderColor: .systemGray3,
                cornerRadius: 8,
                borderWidth: 1,
                font: .systemFont(ofSize: 16),
                textColor: .label
            ),
            focus: CardStyle(borderColor: .systemBlue),
            completed: CardStyle(borderColor: .systemGreen),
            invalid: CardStyle(borderColor: .systemRed)
        )
    )
)

let cardForm = session.createCardForm(config: config)
```

---

### Wrapper Style

`CardWrapperStyle` controls the **outer container** that wraps all fields.

```swift
CardWrapperStyle(
    backgroundColor: UIColor?,   // Container background (default: nil / clear)
    borderColor: UIColor?,       // Border color (default: .separator)
    borderWidth: CGFloat?,       // Border width (default: 1.0)
    cornerRadius: CGFloat?,      // Corner radius (default: 8.0)
    padding: UIEdgeInsets?       // Inner padding (default: 16 on all sides)
)
```

**Example — card-like wrapper with shadow feel:**

```swift
let wrapper = CardWrapperStyle(
    backgroundColor: .systemBackground,
    borderColor: .systemGray4,
    borderWidth: 1,
    cornerRadius: 16,
    padding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
)
```

---

### Input Field Styles

`CardFieldSpecificStyles` lets you style text fields for **each state**:

| State | When Applied |
|---|---|
| `base` | Default / idle state |
| `focus` | Field is actively being edited |
| `completed` | Field has valid, complete input |
| `invalid` | Validation failed |

Each state is a `CardStyle` (alias for `Style`) with these properties:

```swift
CardStyle(
    borderColor: UIColor?,         // Field border color
    cornerRadius: CGFloat?,        // Field corner radius (default: 2)
    padding: UIEdgeInsets?,        // Inner text padding (default: 10 on all sides)
    borderWidth: CGFloat?,         // Border width (default: 1)
    font: UIFont?,                 // Text font
    textAlignment: NSTextAlignment?, // Text alignment (default: .left)
    textColor: UIColor?,           // Text color (default: .label)
    backgroundColor: UIColor?,     // Field background color
    cursorColor: UIColor?,         // Cursor / tint color
    placeholderColor: UIColor?,    // Placeholder text color
    width: CGFloat?,               // Explicit width (overrides fieldInsets)
    height: CGFloat?,              // Explicit height
    minWidth: CGFloat?,            // Minimum width constraint
    maxWidth: CGFloat?,            // Maximum width constraint
    minHeight: CGFloat?,           // Minimum height constraint
    maxHeight: CGFloat?,           // Maximum height constraint
    cardIconAlignment: CardIconAlignment?,  // Card brand icon position (.left / .right)
    fieldInsets: UIEdgeInsets?     // Field-to-container spacing (default: 0,6,0,6)
)
```

**Example — modern rounded fields:**

```swift
let fieldStyles = CardFieldSpecificStyles(
    base: CardStyle(
        borderColor: .systemGray4,
        cornerRadius: 10,
        padding: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14),
        borderWidth: 1.5,
        font: .systemFont(ofSize: 16),
        textColor: .label,
        backgroundColor: .secondarySystemBackground,
        placeholderColor: .tertiaryLabel
    ),
    focus: CardStyle(
        borderColor: UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
        backgroundColor: .systemBackground
    ),
    completed: CardStyle(
        borderColor: .systemGreen
    ),
    invalid: CardStyle(
        borderColor: .systemRed,
        backgroundColor: UIColor.systemRed.withAlphaComponent(0.05)
    )
)
```

> **Tip:** You only need to set properties that *differ* from the `base` state. For example, if the `focus` state should only change the border color, just set `borderColor` in `focus`.

---

### Per-Field Overrides

Need a specific field to look different? Use `inputFieldStyles` to target individual fields by type:

```swift
let styles = CardFormStylesConfig(
    // Applies to ALL fields:
    allInputFieldStyles: CardFieldSpecificStyles(
        base: CardStyle(cornerRadius: 8, borderWidth: 1)
    ),

    // Override just the card number field:
    inputFieldStyles: [
        .CARD_NUMBER: CardFieldSpecificStyles(
            base: CardStyle(
                font: .monospacedDigitSystemFont(ofSize: 18, weight: .medium),
                height: 52
            )
        ),
        .CVV: CardFieldSpecificStyles(
            base: CardStyle(
                maxWidth: 100
            )
        )
    ]
)
```

**Available field types:**

| `CardFieldType` | Description |
|---|---|
| `.CARDHOLDER_NAME` | Cardholder name field |
| `.CARD_NUMBER` | Card number field |
| `.EXPIRATION_DATE` | Combined expiry field (MM/YY) |
| `.EXPIRATION_MONTH` | Expiry month (separate) |
| `.EXPIRATION_YEAR` | Expiry year (separate) |
| `.CVV` | Security code field |

> Per-field styles are **merged over** `allInputFieldStyles`, so you only need to specify the differences.

---

### Label Styles

Customize the label above each field:

```swift
let styles = CardFormStylesConfig(
    labelStyles: [
        .CARD_NUMBER: CardStyle(
            font: .systemFont(ofSize: 13, weight: .semibold),
            textColor: .secondaryLabel
        ),
        .CVV: CardStyle(
            font: .systemFont(ofSize: 13, weight: .semibold),
            textColor: .secondaryLabel
        ),
        .EXPIRATION_MONTH: CardStyle(
            font: .systemFont(ofSize: 13, weight: .semibold),
            textColor: .secondaryLabel
        ),
        .EXPIRATION_YEAR: CardStyle(
            font: .systemFont(ofSize: 13, weight: .semibold),
            textColor: .secondaryLabel
        ),
        .CARDHOLDER_NAME: CardStyle(
            font: .systemFont(ofSize: 13, weight: .semibold),
            textColor: .secondaryLabel
        )
    ]
)
```

---

### Error Text Style

Control how validation error messages look below fields:

```swift
let styles = CardFormStylesConfig(
    errorTextStyle: CardStyle(
        font: .systemFont(ofSize: 12),
        textColor: .systemRed
    )
)
```

---

### Spacing

Fine-tune the spacing between fields and sections:

```swift
let styles = CardFormStylesConfig(
    fieldSpacing: 12,    // Vertical gap between fields (default: 10)
    sectionSpacing: 20   // Gap between row groups (default: 16)
)
```

---

### Field Insets

`fieldInsets` controls the spacing between a field and its container edge — **independent** of `padding`, which controls text inset inside the field.

```
┌─────────────── container ───────────────┐
│                                          │
│  fieldInsets.left  ┌──────────┐  fieldInsets.right
│  ◄────────────────►│  Field   │◄────────────────►│
│                    │ padding  │                   │
│                    │ ◄──────► │                   │
│                    │  (text)  │                   │
│                    └──────────┘                   │
└──────────────────────────────────────────────────┘
```

Use the convenience method `.fieldInsets(top:left:bottom:right:)` — defaults are `(0, 6, 0, 6)`:

```swift
let styles = CardFormStylesConfig(
    allInputFieldStyles: CardFieldSpecificStyles(
        base: CardStyle(
            padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10),  // text inset
            fieldInsets: .fieldInsets(left: 24, right: 24)                      // container spacing
        )
    )
)
```

Only specify the sides you want to change:

```swift
.fieldInsets(top: 8)                  // only change top
.fieldInsets(left: 24, right: 24)     // only change horizontal
.zero                                  // edge-to-edge
```

Per-field overrides work via `inputFieldStyles`:

```swift
inputFieldStyles: [
    .CARD_NUMBER: CardFieldSpecificStyles(
        base: CardStyle(fieldInsets: .fieldInsets(left: 32, right: 32))
    )
]
```

> **Note:** When an explicit `width` is set, `fieldInsets` is ignored — the field uses a fixed-width constraint instead.

---

## Field Variants

Choose between two visual styles for input fields:

| Variant | Description |
|---|---|
| `.outlined` | *(Default)* — bordered rectangle with transparent background |
| `.filled` | Filled background with no border |

```swift
let config = CardFormConfig(
    fieldVariant: .filled
)
```

You can further customize each variant using `CardFieldSpecificStyles` as described above.

---

## Card Icon Alignment

Display the detected card brand icon (Visa, Mastercard, etc.) inside the card number field:

```swift
let config = CardFormConfig(
    showCardIcon: true,
    cardIconAlignment: .right  // .left (default) or .right
)
```

---

## Layout Presets

Control the arrangement of fields using built-in presets or a custom layout:

### Built-in Presets

```swift
// Standard (default):
// Row 1: [Card Number]
// Row 2: [CVV] [Expiry Month] [Expiry Year]
let config = CardFormConfig(layout: .standard)

// Compact:
// Row 1: [Card Number]
// Row 2: [Expiry Month] [Expiry Year] [CVV]
let config = CardFormConfig(layout: .compact)

// Minimal (no name field, compact layout):
// Row 1: [Card Number]
// Row 2: [Expiry Month] [Expiry Year] [CVV]
let config = CardFormConfig(layout: .minimal)
```

### Combined Expiry Date Field

Replace separate month/year fields with a single MM/YY field:

```swift
let config = CardFormConfig(
    layout: .preset(.standard, useCombinedExpiryDateField: true)
)
// Row 1: [Card Number]
// Row 2: [CVV] [MM/YY]
```

### Custom Layout

Define exactly which fields appear on each row:

```swift
let config = CardFormConfig(
    showNameField: true,
    layout: .custom(
        [
            [.CARDHOLDER_NAME],           // Row 1
            [.CARD_NUMBER],               // Row 2
            [.EXPIRATION_DATE, .CVV]      // Row 3
        ],
        useCombinedExpiryDateField: true
    )
)
```

> **Note:** Custom layouts must include `.CARD_NUMBER`, `.CVV`, and expiry fields (either `.EXPIRATION_DATE` or both `.EXPIRATION_MONTH` / `.EXPIRATION_YEAR`). If the layout is invalid, the SDK falls back to the standard preset.

---

## Card Payment Button Styling

Created via `session.createCardPaymentButton(buttonStyle:translations:)`.

### Properties

```swift
CardButtonStyle(
    backgroundColor: UIColor?,      // Button background (default: .systemBlue)
    textColor: UIColor?,            // Title text color (default: .white)
    font: UIFont?,                  // Title font (default: system)
    cornerRadius: CGFloat?,         // Corner radius (default: 8)
    borderWidth: CGFloat?,          // Border width (default: none)
    borderColor: UIColor?,          // Border color (default: none)
    contentEdgeInsets: UIEdgeInsets?, // Padding inside button
    height: CGFloat?                // Button height (default: 44)
)
```

### Examples

```swift
// Pill-shaped dark button
let payButton = session.createCardPaymentButton(
    buttonStyle: CardButtonStyle(
        backgroundColor: .black,
        textColor: .white,
        font: .systemFont(ofSize: 18, weight: .bold),
        cornerRadius: 22,
        height: 48
    )
)

// Outlined / ghost button
let payButton = session.createCardPaymentButton(
    buttonStyle: CardButtonStyle(
        backgroundColor: .clear,
        textColor: .systemBlue,
        font: .systemFont(ofSize: 16, weight: .semibold),
        cornerRadius: 8,
        borderWidth: 2,
        borderColor: .systemBlue,
        height: 44
    )
)
```

> The button automatically shows a **loading spinner** during payment processing — no extra code needed.

---

## Generic Redirect Button Styling

For redirect-based payment methods (iDEAL, Sofort, Klarna, etc.). Uses the same `CardButtonStyle`:

```swift
let idealButton = session.createGenericRedirectButton(
    buttonStyle: CardButtonStyle(
        backgroundColor: UIColor(red: 0.8, green: 0, blue: 0.4, alpha: 1),
        textColor: .white,
        cornerRadius: 10,
        height: 48
    ),
    paymentMethodCode: "ideal"
)
```

---

## Stored Instruments Styling

When returning customers have saved cards or PayPal accounts, the `StoredInstruments` view displays them as a selectable list.

### List Style

```swift
StoredInstrumentsStyle(
    backgroundColor: UIColor,           // List background (default: .clear)
    itemBackgroundColor: UIColor,       // Unselected item background (default: .systemBackground)
    selectedItemBackgroundColor: UIColor, // Selected item background (default: .systemGray6)
    labelTextColor: UIColor,            // Instrument label color (default: .label)
    labelFont: UIFont,                  // Instrument label font (default: system 16)
    itemCornerRadius: CGFloat,          // Item corner radius (default: 8)
    itemSpacing: CGFloat,               // Gap between items (default: 8)
    itemPadding: UIEdgeInsets,          // Padding inside each item (default: 12/16/12/16)
    buttonStyle: StoredInstrumentButtonStyle,  // Pay button
    deleteButtonStyle: DeleteButtonStyle,      // Delete icon/button
    updateButtonStyle: UpdateButtonStyle       // Update icon/button
)
```

### Pay Button Style

```swift
StoredInstrumentButtonStyle(
    backgroundColor: UIColor,       // Default: .systemBlue
    textColor: UIColor,             // Default: .white
    font: UIFont,                   // Default: system 16 medium
    cornerRadius: CGFloat,          // Default: 8
    height: CGFloat,                // Default: 44
    borderWidth: CGFloat,           // Default: 0
    borderColor: UIColor,           // Default: .clear
    contentEdgeInsets: UIEdgeInsets  // Default: 8/16/8/16
)
```

### Delete Button Style

```swift
DeleteButtonStyle(
    backgroundColor: UIColor,   // Default: .systemRed
    textColor: UIColor,         // Default: .white
    font: UIFont,               // Default: system 14
    cornerRadius: CGFloat,      // Default: 4
    size: CGSize                // Default: 32×32
)
```

### Update Button Style

```swift
UpdateButtonStyle(
    backgroundColor: UIColor,   // Default: .systemBlue
    textColor: UIColor,         // Default: .white
    font: UIFont,               // Default: system 14
    cornerRadius: CGFloat,      // Default: 4
    size: CGSize                // Default: 32×32
)
```

### Full Example

```swift
let storedInstruments = session.createStoredInstruments(
    style: StoredInstrumentsStyle(
        backgroundColor: .clear,
        itemBackgroundColor: .secondarySystemBackground,
        selectedItemBackgroundColor: UIColor.systemBlue.withAlphaComponent(0.1),
        labelTextColor: .label,
        labelFont: .systemFont(ofSize: 15),
        itemCornerRadius: 12,
        itemSpacing: 10,
        itemPadding: UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18),
        buttonStyle: StoredInstrumentButtonStyle(
            backgroundColor: .black,
            textColor: .white,
            font: .systemFont(ofSize: 16, weight: .bold),
            cornerRadius: 22,
            height: 48
        ),
        deleteButtonStyle: DeleteButtonStyle(
            backgroundColor: UIColor.systemRed.withAlphaComponent(0.1),
            textColor: .systemRed,
            cornerRadius: 8,
            size: CGSize(width: 36, height: 36)
        ),
        updateButtonStyle: UpdateButtonStyle(
            backgroundColor: UIColor.systemBlue.withAlphaComponent(0.1),
            textColor: .systemBlue,
            cornerRadius: 8,
            size: CGSize(width: 36, height: 36)
        )
    )
)
```

---

## Apple Pay Button Styling

Apple restricts customization of the Apple Pay button to its own set of styles and types:

```swift
let applePayButton = session.createApplePayButton(
    type: .buy,          // .plain, .buy, .setUp, .inStore, .donate, .checkout, .book, .subscribe
    style: .black        // .black, .white, .whiteOutline, .automatic
)
```

> You cannot apply custom fonts, colors, or corner radii to the Apple Pay button — Apple enforces its Human Interface Guidelines.

---

## Translations & Labels

### Card Form Translations

Override placeholder text, labels, and error messages:

```swift
let translations = CardTranslations(
    placeholders: CardTranslations.Placeholders(values: [
        .CARD_NUMBER: "Card number",
        .CARDHOLDER_NAME: "Name on card",
        .CVV: "CVV",
        .EXPIRATION_DATE: "MM/YY",
        .EXPIRATION_MONTH: "MM",
        .EXPIRATION_YEAR: "YY"
    ]),
    labels: CardTranslations.Labels(
        values: [
            .CARD_NUMBER: "Card Number",
            .CARDHOLDER_NAME: "Cardholder Name",
            .CVV: "Security Code",
            .EXPIRATION_DATE: "Expiry Date",
            .EXPIRATION_MONTH: "Expiry Month",
            .EXPIRATION_YEAR: "Expiry Year"
        ],
        saveInstrument: "Save card for future payments",
        storeInstrument: "Store this card"
    ),
    error: CardTranslations.ErrorMessages(values: [
        .CARD_NUMBER: "Please enter a valid card number",
        .CARDHOLDER_NAME: "Cardholder name is required",
        .CVV: "Invalid security code",
        .EXPIRATION_DATE: "Invalid expiry date",
        .EXPIRATION_MONTH: "Invalid month",
        .EXPIRATION_YEAR: "Invalid year"
    ])
)

let config = CardFormConfig(
    translations: translations
)
```

### Button Translations

```swift
// Card payment button
let payButton = session.createCardPaymentButton(
    translations: CardPaymenButtonTranslations(label: "Complete Purchase")
)

// Stored instrument pay button
let payButton = session.createCardPaymentButton(
    storedInstrument: instrument,
    translations: StoredInstrumentButtonTranslations(
        label: "Pay Now",
        processingLabel: "Processing..."
    )
)
```

### Stored Instruments Translations

```swift
let storedInstruments = session.createStoredInstruments(
    translations: StoredInstrumentsTranslations(
        cardPrefix: "Card ending in",
        paypalPrefix: "PayPal",
        buttonTranslations: StoredInstrumentButtonTranslations(
            label: "Pay",
            processingLabel: "Processing..."
        )
    )
)
```

---

## Using with SwiftUI

The SDK's UI components are built with UIKit. To embed them in SwiftUI, use `UIViewRepresentable`:

```swift
import SwiftUI
import Payrails

struct CardFormView: UIViewRepresentable {
    let session: PayrailsSession

    func makeUIView(context: Context) -> UIView {
        let config = CardFormConfig(
            showNameField: true,
            showCardIcon: true,
            styles: CardFormStylesConfig(
                wrapperStyle: CardWrapperStyle(cornerRadius: 16),
                allInputFieldStyles: CardFieldSpecificStyles(
                    base: CardStyle(
                        cornerRadius: 10,
                        font: .systemFont(ofSize: 16),
                        textColor: .label
                    ),
                    focus: CardStyle(borderColor: .systemBlue)
                )
            )
        )
        return session.createCardForm(config: config)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct PayButtonView: UIViewRepresentable {
    let session: PayrailsSession

    func makeUIView(context: Context) -> UIView {
        return session.createCardPaymentButton(
            buttonStyle: CardButtonStyle(
                backgroundColor: .black,
                cornerRadius: 12,
                height: 50
            )
        )
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// Usage in a SwiftUI view:
struct CheckoutView: View {
    let session: PayrailsSession

    var body: some View {
        VStack(spacing: 20) {
            CardFormView(session: session)
                .frame(height: 300)

            PayButtonView(session: session)
                .frame(height: 50)
        }
        .padding()
    }
}
```

---

## Full Example — Themed Checkout

Here's a complete example that demonstrates a dark-themed, brand-customized checkout:

```swift
import UIKit
import Payrails

class CheckoutViewController: UIViewController {

    var session: PayrailsSession!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1)
        setupUI()
    }

    private func setupUI() {
        let brandBlue = UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)

        // 1. Card Form
        let cardForm = session.createCardForm(config: CardFormConfig(
            showNameField: true,
            showCardIcon: true,
            cardIconAlignment: .right,
            fieldVariant: .outlined,
            layout: .preset(.standard, useCombinedExpiryDateField: true),
            styles: CardFormStylesConfig(
                wrapperStyle: CardWrapperStyle(
                    backgroundColor: UIColor(white: 0.12, alpha: 1),
                    borderColor: UIColor(white: 0.25, alpha: 1),
                    borderWidth: 1,
                    cornerRadius: 16,
                    padding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
                ),
                errorTextStyle: CardStyle(
                    font: .systemFont(ofSize: 12),
                    textColor: .systemPink
                ),
                allInputFieldStyles: CardFieldSpecificStyles(
                    base: CardStyle(
                        borderColor: UIColor(white: 0.3, alpha: 1),
                        cornerRadius: 10,
                        padding: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14),
                        borderWidth: 1,
                        font: .monospacedDigitSystemFont(ofSize: 16, weight: .regular),
                        textColor: .white,
                        backgroundColor: UIColor(white: 0.15, alpha: 1),
                        cursorColor: brandBlue,
                        placeholderColor: UIColor(white: 0.5, alpha: 1)
                    ),
                    focus: CardStyle(
                        borderColor: brandBlue,
                        backgroundColor: UIColor(white: 0.18, alpha: 1)
                    ),
                    completed: CardStyle(
                        borderColor: .systemGreen
                    ),
                    invalid: CardStyle(
                        borderColor: .systemPink,
                        backgroundColor: UIColor.systemPink.withAlphaComponent(0.08)
                    )
                ),
                fieldSpacing: 12,
                sectionSpacing: 20
            ),
            translations: CardTranslations(
                placeholders: CardTranslations.Placeholders(values: [
                    .CARD_NUMBER: "1234 5678 9012 3456",
                    .CARDHOLDER_NAME: "John Doe",
                    .CVV: "123",
                    .EXPIRATION_DATE: "MM/YY"
                ]),
                labels: CardTranslations.Labels(values: [
                    .CARD_NUMBER: "CARD NUMBER",
                    .CARDHOLDER_NAME: "NAME ON CARD",
                    .CVV: "CVV",
                    .EXPIRATION_DATE: "EXPIRY"
                ])
            )
        ))

        // 2. Pay Button
        let payButton = session.createCardPaymentButton(
            buttonStyle: CardButtonStyle(
                backgroundColor: brandBlue,
                textColor: .white,
                font: .systemFont(ofSize: 18, weight: .bold),
                cornerRadius: 14,
                height: 52
            ),
            translations: CardPaymenButtonTranslations(label: "Pay $49.99")
        )

        // 3. Layout
        let stack = UIStackView(arrangedSubviews: [cardForm, payButton])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
}
```

---

## Style Properties Reference

### CardStyle (alias: `Style`)

| Property | Type | Default |
|---|---|---|
| `borderColor` | `UIColor?` | `nil` |
| `cornerRadius` | `CGFloat?` | `2` |
| `padding` | `UIEdgeInsets?` | `(10, 10, 10, 10)` |
| `borderWidth` | `CGFloat?` | `1` |
| `font` | `UIFont?` | System default |
| `textAlignment` | `NSTextAlignment?` | `.left` |
| `textColor` | `UIColor?` | `.label` |
| `backgroundColor` | `UIColor?` | `nil` |
| `cursorColor` | `UIColor?` | `nil` |
| `placeholderColor` | `UIColor?` | `nil` |
| `width` | `CGFloat?` | `nil` |
| `height` | `CGFloat?` | `nil` |
| `minWidth` | `CGFloat?` | `nil` |
| `maxWidth` | `CGFloat?` | `nil` |
| `minHeight` | `CGFloat?` | `nil` |
| `maxHeight` | `CGFloat?` | `nil` |
| `cardIconAlignment` | `CardIconAlignment?` | `.left` |
| `fieldInsets` | `UIEdgeInsets?` | `nil` (defaults to `(0, 6, 0, 6)`) |

### CardFieldSpecificStyles

| Property | Type | Description |
|---|---|---|
| `base` | `CardStyle?` | Default / idle state |
| `focus` | `CardStyle?` | Active editing state |
| `completed` | `CardStyle?` | Valid input state |
| `invalid` | `CardStyle?` | Validation error state |

### CardButtonStyle

| Property | Type | Default |
|---|---|---|
| `backgroundColor` | `UIColor?` | `.systemBlue` |
| `textColor` | `UIColor?` | `.white` |
| `font` | `UIFont?` | System default |
| `cornerRadius` | `CGFloat?` | `8` |
| `borderWidth` | `CGFloat?` | `nil` |
| `borderColor` | `UIColor?` | `nil` |
| `contentEdgeInsets` | `UIEdgeInsets?` | `nil` |
| `height` | `CGFloat?` | `44` |

### CardWrapperStyle

| Property | Type | Default |
|---|---|---|
| `backgroundColor` | `UIColor?` | `nil` |
| `borderColor` | `UIColor?` | `.separator` |
| `borderWidth` | `CGFloat?` | `1` |
| `cornerRadius` | `CGFloat?` | `8` |
| `padding` | `UIEdgeInsets?` | `(16, 16, 16, 16)` |

### CardFormStylesConfig

| Property | Type | Default |
|---|---|---|
| `wrapperStyle` | `CardWrapperStyle?` | `.defaultStyle` |
| `errorTextStyle` | `CardStyle?` | `textColor: .systemRed` |
| `allInputFieldStyles` | `CardFieldSpecificStyles?` | `.defaultStyle` |
| `inputFieldStyles` | `[CardFieldType: CardFieldSpecificStyles]?` | `nil` |
| `labelStyles` | `[CardFieldType: CardStyle]?` | `textColor: .secondaryLabel` |
| `fieldSpacing` | `CGFloat?` | `10` |
| `sectionSpacing` | `CGFloat?` | `16` |

### StoredInstrumentsStyle

| Property | Type | Default |
|---|---|---|
| `backgroundColor` | `UIColor` | `.clear` |
| `itemBackgroundColor` | `UIColor` | `.systemBackground` |
| `selectedItemBackgroundColor` | `UIColor` | `.systemGray6` |
| `labelTextColor` | `UIColor` | `.label` |
| `labelFont` | `UIFont` | `.systemFont(ofSize: 16)` |
| `itemCornerRadius` | `CGFloat` | `8` |
| `itemSpacing` | `CGFloat` | `8` |
| `itemPadding` | `UIEdgeInsets` | `(12, 16, 12, 16)` |
| `buttonStyle` | `StoredInstrumentButtonStyle` | `.defaultStyle` |
| `deleteButtonStyle` | `DeleteButtonStyle` | `.defaultStyle` |
| `updateButtonStyle` | `UpdateButtonStyle` | `.defaultStyle` |

### StoredInstrumentButtonStyle

| Property | Type | Default |
|---|---|---|
| `backgroundColor` | `UIColor` | `.systemBlue` |
| `textColor` | `UIColor` | `.white` |
| `font` | `UIFont` | `.systemFont(ofSize: 16, weight: .medium)` |
| `cornerRadius` | `CGFloat` | `8` |
| `height` | `CGFloat` | `44` |
| `borderWidth` | `CGFloat` | `0` |
| `borderColor` | `UIColor` | `.clear` |
| `contentEdgeInsets` | `UIEdgeInsets` | `(8, 16, 8, 16)` |

### DeleteButtonStyle

| Property | Type | Default |
|---|---|---|
| `backgroundColor` | `UIColor` | `.systemRed` |
| `textColor` | `UIColor` | `.white` |
| `font` | `UIFont` | `.systemFont(ofSize: 14)` |
| `cornerRadius` | `CGFloat` | `4` |
| `size` | `CGSize` | `(32, 32)` |

### UpdateButtonStyle

| Property | Type | Default |
|---|---|---|
| `backgroundColor` | `UIColor` | `.systemBlue` |
| `textColor` | `UIColor` | `.white` |
| `font` | `UIFont` | `.systemFont(ofSize: 14)` |
| `cornerRadius` | `CGFloat` | `4` |
| `size` | `CGSize` | `(32, 32)` |

---

**Need help?** Check the [SDK API Reference](sdk-api-reference.md) or the [Troubleshooting Guide](troubleshooting.md) for common issues.
