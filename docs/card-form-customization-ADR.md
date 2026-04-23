# IOS - SDK Card Form Customization ADR

## Executive Summary

This document analyzes the current card form customization capabilities in the Payrails iOS SDK and proposes a roadmap to address merchant feedback regarding limited styling options.

---

## Part 1: Current Customization Capabilities

### What Merchants CAN Customize Today

#### 1. Input Field Styles (per field or all fields)

```swift
let inputStyles = CardFieldSpecificStyles(
    base: CardStyle(
        cornerRadius: 8,
        padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
        borderWidth: 1,
        borderColor: .lightGray,
        textAlignment: .left,
        textColor: .black,
        backgroundColor: .white,
        font: UIFont.systemFont(ofSize: 16),
        placeholderColor: .gray,
        cursorColor: .blue
    ),
    focus: CardStyle(borderColor: .blue),
    completed: CardStyle(borderColor: .green),
    invalid: CardStyle(borderColor: .red)
)
```

#### 2. Label Styles (per field type)

```swift
let labelStyles: [CardFieldType: CardStyle] = [
    .CARD_NUMBER: CardStyle(textColor: .darkGray, font: UIFont.boldSystemFont(ofSize: 14)),
    .CVV: CardStyle(textColor: .darkGray),
    .EXPIRATION_MONTH: CardStyle(textColor: .darkGray),
    .EXPIRATION_YEAR: CardStyle(textColor: .darkGray),
    .CARDHOLDER_NAME: CardStyle(textColor: .darkGray)
]
```

#### 3. Error Text Style - Error message 

```swift
let errorStyle = CardStyle(textColor: .red, font: UIFont.systemFont(ofSize: 12))
```

#### 4. Wrapper/Container Style

```swift
let wrapperStyle = CardWrapperStyle(
    backgroundColor: .white,
    borderColor: .gray,
    borderWidth: 1.0,
    cornerRadius: 8.0,
    padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
)
```

#### 5. Button Style

```swift
let buttonStyle = CardButtonStyle(
    backgroundColor: .systemBlue,
    textColor: .white,
    font: UIFont.boldSystemFont(ofSize: 16),
    cornerRadius: 8.0,
    borderWidth: 0,
    borderColor: nil,
    contentEdgeInsets: UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
)
```

#### 6. Translations (Labels, Placeholders, Error Messages)

```swift
let translations = CardTranslations(
    placeholders: .init(values: [
        .CARD_NUMBER: "Enter card number",
        .CVV: "CVV",
        .EXPIRATION_MONTH: "MM",
        .EXPIRATION_YEAR: "YYYY",
        .CARDHOLDER_NAME: "Cardholder Name"
    ]),
    labels: .init(values: [
        .CARD_NUMBER: "Card Number",
        .CVV: "Security Code",
        .EXPIRATION_MONTH: "Exp Month",
        .EXPIRATION_YEAR: "Exp Year",
        .CARDHOLDER_NAME: "Name on Card"
    ], saveInstrument: "Save this card"),
    error: .init(values: [
        .CARD_NUMBER: "Invalid card number",
        .CVV: "Invalid CVV"
    ])
)
```

#### 7. Configuration Options

```swift
let config = CardFormConfig(
    showNameField: true,       // Show/hide cardholder name
    showSaveInstrument: true,  // Show/hide "save card" toggle
    styles: stylesConfig,
    translations: translations
)
```

### Complete Example: Current Merchant Integration

```swift
import Payrails
import PayrailsCSE

class CheckoutViewController: UIViewController {
    
    func setupCardForm() {
        // 1. Define styles
        let stylesConfig = CardFormStylesConfig(
            wrapperStyle: CardWrapperStyle(
                backgroundColor: .systemBackground,
                borderColor: .separator,
                borderWidth: 1,
                cornerRadius: 12,
                padding: UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
            ),
            errorTextStyle: CardStyle(textColor: .systemRed, font: .systemFont(ofSize: 12)),
            allInputFieldStyles: CardFieldSpecificStyles(
                base: CardStyle(
                    borderColor: .separator,
                    cornerRadius: 8,
                    padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
                    borderWidth: 1,
                    font: .systemFont(ofSize: 16),
                    textColor: .label,
                    backgroundColor: .secondarySystemBackground,
                    placeholderColor: .placeholderText
                ),
                focus: CardStyle(borderColor: .systemBlue),
                completed: CardStyle(borderColor: .systemGreen),
                invalid: CardStyle(borderColor: .systemRed)
            ),
            buttonStyle: CardButtonStyle(
                backgroundColor: .systemBlue,
                textColor: .white,
                font: .boldSystemFont(ofSize: 16),
                cornerRadius: 8
            )
        )
        
        // 2. Define translations
        let translations = CardTranslations(
            placeholders: .init(values: [
                .CARD_NUMBER: "1234 5678 9012 3456",
                .CVV: "123",
                .EXPIRATION_MONTH: "MM",
                .EXPIRATION_YEAR: "YYYY"
            ]),
            labels: .init(values: [
                .CARD_NUMBER: "Card Number",
                .CVV: "CVV",
                .EXPIRATION_MONTH: "Month",
                .EXPIRATION_YEAR: "Year"
            ])
        )
        
        // 3. Create config
        let config = CardFormConfig(
            showNameField: true,
            showSaveInstrument: false,
            styles: stylesConfig,
            translations: translations
        )
        
        // 4. Create form
        let cardForm = Payrails.CardPaymentForm(
            config: config,
            tableName: "cards",
            cseConfig: (data: cseData, version: "1"),
            holderReference: "user-123",
            cseInstance: payrailsCSE,
            session: payrailsSession,
            buttonTitle: "Pay $99.00"
        )
        
        view.addSubview(cardForm)
    }
}
```

---

## Part 2: Identified Limitations (Merchant Feedback)

### ❌ 1. Field Placement & Form Structure (HARDCODED)

**Current behavior:**
- Layout is hardcoded in `CardForm.swift`:
  ```swift
  layout: config.showNameField ? [1, 1, 3] : [1, 3]
  ```
- This means:
  - Row 1: Card Number (full width)
  - Row 2: Cardholder Name (full width) — if enabled
  - Row 3: CVV, Exp Month, Exp Year (3 columns)

**What merchants want:**
- Custom field ordering
- Different layouts (e.g., CVV next to card number, combined expiry field)
- Ability to add custom fields or spacing

### ❌ 2. Field Dimensions — No Auto Layout / Constraints Support

**Current behavior:**
- Fields use fixed dimensions via `width`, `height`, `minWidth`, `maxWidth`, etc.
- No support for percentage-based widths or constraint-based layouts
- Merchant must manually calculate sizes for different screen sizes

**What merchants want:**
- Responsive layouts using Auto Layout constraints
- Percentage-based column widths
- Intrinsic content sizing (i.e., fields size themselves based on content and available space)

**Example: A UILabel**
```swift
let label = UILabel()
label.text = "Hello"
// No need to set width/height — the label knows its size based on the text + font
```

The label automatically sizes itself to fit "Hello". This is intrinsic content sizing.

**Example: A UITextField**
```swift
let textField = UITextField()
textField.placeholder = "Enter card number"
// TextField has intrinsic HEIGHT (based on font), but needs explicit WIDTH
```

**How this applies to the Card Form:**

| Current SDK Behavior | With Intrinsic Sizing |
|---------------------|----------------------|
| `width: 200` (fixed pixels) | Width adapts to container |
| `height: 44` (fixed pixels) | Height based on font + padding |
| Breaks on different devices | Works on all screen sizes |
| Merchant calculates sizes | SDK handles sizing automatically |

**Visual example:**

```
Current (Fixed sizing):
┌──────────────────────────────────────┐
│ [Card Number______] ← 200px fixed    │
│                     ^ Doesn't fill   │
└──────────────────────────────────────┘

With Intrinsic Sizing:
┌──────────────────────────────────────┐
│ [Card Number_____________________]   │
│ ^ Fills available width, height      │
│   based on font + padding            │
└──────────────────────────────────────┘
```

**Benefits for merchants:**
1. **No manual calculations** — don't need to compute widths for iPhone SE vs iPad
2. **Consistent spacing** — Auto Layout handles gaps automatically
3. **Dynamic text support** — fields resize if user has large accessibility fonts enabled
4. **Simpler integration** — just add the form, constraints handle the rest

### ❌ 3. Asterisk Visibility (HARDCODED)

**Current behavior in `TextField.swift`:**
```swift
// Only add asterisk if required AND label text is not empty
if self.isRequired && !text.isEmpty {
    attributedString.append(asterisk)
}
```

- Asterisk is always shown for required fields
- Color/font can be styled via `requiredAstrisk` in `Styles`, but this is NOT exposed through `CardFormConfig`

**What merchants want:**
- Option to hide asterisks entirely
- Control asterisk appearance via public config

### ❌ 4. Card Provider Icon (HARDCODED)

**Current behavior in `CardForm.swift`:**
```swift
let requiredOption = CollectElementOptions(required: true, enableCardIcon: false, enableCopy: true)
```

- `enableCardIcon` is hardcoded to `false`
- The underlying `CollectElementOptions` supports it, but it's not exposed

**What merchants want:**
- Option to show/hide card brand icon (Visa, Mastercard, etc.)
- Control icon position (left/right) — already exists in `Style.cardIconAlignment` but not exposed

### ❌ 5. Pay Button Height (HARDCODED)

**Current behavior in `CardPaymentForm.swift`:**
```swift
payButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
```

**What merchants want:**
- Configurable button height
- Or remove the constraint and let `contentEdgeInsets` determine size

### ❌ 6. Stack View Spacing (HARDCODED)

**Current behavior:**
```swift
self.axis = .vertical
self.spacing = 16  // CardPaymentForm
self.spacing = 10  // CardForm
```

**What merchants want:**
- Configurable spacing between fields
- Configurable spacing between sections

---

## Part 3: Customization Roadmap

### Phase 1: Quick Wins (Low Effort, High Impact) — v1.26.0

| Feature | Effort | Files to Change |
|---------|--------|-----------------|
| Expose `enableCardIcon` option | 🟢 Low | `CardFormConfig.swift`, `CardForm.swift` |
| Expose `showAsterisk` option | 🟢 Low | `CardFormConfig.swift`, `CardForm.swift`, `TextField.swift` |
| Expose `cardIconAlignment` (left/right) | 🟢 Low | `CardFormConfig.swift`, `CardForm.swift` |
| Make button height configurable | 🟢 Low | `CardButtonStyle.swift`, `CardPaymentForm.swift` |
| Make stack spacing configurable | 🟢 Low | `CardFormStylesConfig`, `CardForm.swift`, `CardPaymentForm.swift` |

**Example API after Phase 1:**
```swift
let config = CardFormConfig(
    showNameField: true,
    showSaveInstrument: false,
    showCardIcon: true,              // NEW
    cardIconAlignment: .right,       // NEW
    showRequiredAsterisk: false,     // NEW
    styles: CardFormStylesConfig(
        fieldSpacing: 12,            // NEW
        sectionSpacing: 20,          // NEW
        buttonStyle: CardButtonStyle(
            height: 50,              // NEW
            // ...existing properties
        )
    )
)
```

---

### Phase 2: Layout Flexibility (Medium Effort) — v1.27.0

| Feature | Effort | Description |
|---------|--------|-------------|
| Configurable field layout | 🟡 Medium | Allow merchants to specify layout array (e.g., `[1, 2, 2]`) |
| Configurable field order | 🟡 Medium | Allow merchants to specify field order |
| Combined expiry date field option | 🟡 Medium | Single MM/YY field instead of separate Month/Year |

**Example API after Phase 2:**
```swift
let config = CardFormConfig(
    // ...existing
    layout: .custom([
        [.CARD_NUMBER],
        [.CARDHOLDER_NAME],
        [.EXPIRATION_DATE, .CVV]  // Combined expiry + CVV on same row
    ])
)

// OR predefined layouts:
let config = CardFormConfig(
    layout: .compact  // Predefined compact layout
)
```

---

### Phase 3: Full Layout Control (Higher Effort) — v1.28.0+

| Feature | Effort | Description |
|---------|--------|-------------|
| Constraints-based layout support | 🔴 High | Support percentage widths, Auto Layout |
| Custom view injection | 🔴 High | Allow merchants to inject custom views between fields |
| Fully composable form | 🔴 High | Provide individual field components merchants can arrange |

**Example API after Phase 3:**
```swift
// Option A: Constraint-based config
let config = CardFormConfig(
    layout: .custom([
        .row([.field(.CARD_NUMBER, widthRatio: 1.0)]),
        .row([
            .field(.EXPIRATION_DATE, widthRatio: 0.5),
            .field(.CVV, widthRatio: 0.5)
        ]),
        .spacing(16),
        .row([.field(.CARDHOLDER_NAME, widthRatio: 1.0)])
    ])
)

// Option B: Fully composable (individual components)
let cardNumberField = Payrails.CardNumberField(style: ...)
let cvvField = Payrails.CVVField(style: ...)
let expiryField = Payrails.ExpiryField(style: ...)

// Merchant arranges in their own UIStackView / SwiftUI layout
```

---

## Part 4: Recommended Implementation Priority

### Immediate (v1.26.0) — Address Merchant Blockers
1. ✅ Expose `showCardIcon` + `cardIconAlignment`
2. ✅ Expose `showRequiredAsterisk`
3. ✅ Make button height configurable
4. ✅ Make field/section spacing configurable

### Short-term (v1.27.0) — Improve Flexibility
5. Configurable layout array
6. Configurable field order
7. Combined expiry date option

### Medium-term (v1.28.0+) — Full Control
8. Constraint-based layouts
9. Custom view injection points
10. Fully composable individual field components

---

## Part 5: Files That Need Changes

| File | Phase 1 | Phase 2 | Phase 3 |
|------|---------|---------|---------|
| `CardFormConfig.swift` | ✅ | ✅ | ✅ |
| `CardFormStylesConfig` (in `CardFormStyle.swift`) | ✅ | ✅ | ✅ |
| `CardForm.swift` | ✅ | ✅ | ✅ |
| `CardPaymentForm.swift` | ✅ | ✅ | ✅ |
| `CardButtonStyle` (in `CardFormStyle.swift`) | ✅ | | |
| `TextField.swift` | ✅ | | |
| `CollectElementOptions.swift` | | ✅ | |
| `ContainerOptions.swift` | | ✅ | ✅ |
| New: `CardLayoutConfig.swift` | | ✅ | ✅ |
| New: Individual field components | | | ✅ |

---

## Appendix: Full Style Property Reference

### CardStyle (alias: Style)
| Property | Type | Description |
|----------|------|-------------|
| `borderColor` | `UIColor?` | Border color |
| `cornerRadius` | `CGFloat?` | Corner radius |
| `padding` | `UIEdgeInsets?` | Internal padding |
| `borderWidth` | `CGFloat?` | Border width |
| `font` | `UIFont?` | Text font |
| `textAlignment` | `NSTextAlignment?` | Text alignment |
| `textColor` | `UIColor?` | Text color |
| `boxShadow` | `CALayer?` | Shadow layer |
| `backgroundColor` | `UIColor?` | Background color |
| `minWidth` | `CGFloat?` | Minimum width |
| `maxWidth` | `CGFloat?` | Maximum width |
| `minHeight` | `CGFloat?` | Minimum height |
| `maxHeight` | `CGFloat?` | Maximum height |
| `cursorColor` | `UIColor?` | Cursor/caret color |
| `width` | `CGFloat?` | Fixed width |
| `height` | `CGFloat?` | Fixed height |
| `placeholderColor` | `UIColor?` | Placeholder text color |
| `cardIconAlignment` | `CardIconAlignment?` | Card icon position (.left/.right) |

### Styles (State-based styling)
| Property | Description |
|----------|-------------|
| `base` | Default/idle state |
| `complete` | Valid/completed state |
| `empty` | Empty state |
| `focus` | Focused state |
| `invalid` | Invalid/error state |
| `requiredAstrisk` | Asterisk styling (NOT exposed via CardFormConfig) |
