# Styling Guide

The Payrails iOS SDK exposes two primary styling surfaces: the **card form** (via `CardFormStylesConfig` and `CardFormConfig`) and the **pay button** (via `CardButtonStyle`). Both use a merge-over-defaults system — you only need to specify the values you want to change.

---

## Card form styling

### Style hierarchy

```
CardFormStylesConfig
├── wrapperStyle: CardWrapperStyle      — outer container (border, background, padding)
├── errorTextStyle: CardStyle           — error message appearance
├── allInputFieldStyles: CardFieldSpecificStyles  — applied to every field
├── inputFieldStyles: [CardFieldType: CardFieldSpecificStyles]  — per-field overrides
├── labelStyles: [CardFieldType: CardStyle]  — per-field label overrides
├── fieldSpacing: CGFloat               — vertical gap between fields (default: 10)
└── sectionSpacing: CGFloat             — gap between sections (default: 16)
```

`CardFieldSpecificStyles` holds four state variants:

| State | When applied |
|---|---|
| `base` | Default idle state |
| `focus` | Field is active / first responder |
| `completed` | Valid value entered |
| `invalid` | Validation failed |

### Basic example

```swift
let styles = CardFormStylesConfig(
    wrapperStyle: CardWrapperStyle(
        backgroundColor: .systemBackground,
        borderColor: .separator,
        borderWidth: 1,
        cornerRadius: 12,
        padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    ),
    errorTextStyle: Style(textColor: .systemRed),
    allInputFieldStyles: CardFieldSpecificStyles(
        base: Style(
            cornerRadius: 8,
            padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
            borderWidth: 1,
            borderColor: .systemGray4,
            textColor: .label,
            font: .systemFont(ofSize: 16),
            fieldInsets: .fieldInsets(left: 16, right: 16)  // field-to-container spacing
        ),
        focus: Style(borderColor: .systemBlue),
        completed: Style(borderColor: .systemGreen),
        invalid: Style(borderColor: .systemRed)
    ),
    fieldSpacing: 12,
    sectionSpacing: 20
)

let config = CardFormConfig(styles: styles)
let cardForm = Payrails.createCardForm(config: config)
```

### Field insets

`fieldInsets` controls the spacing between a field and its container edge. It is independent of `padding`, which controls the text inset inside the field.

```swift
// padding  = space between the field border and the text inside
// fieldInsets = space between the container edge and the field border
```

Use the convenience method `.fieldInsets(top:left:bottom:right:)` — defaults are `(0, 16, 0, 16)`, so only specify what you need:

```swift
// Only change horizontal insets
base: Style(fieldInsets: .fieldInsets(left: 24, right: 24))

// Only change top
base: Style(fieldInsets: .fieldInsets(top: 8))

// Edge-to-edge (no insets)
base: Style(fieldInsets: .zero)
```

Per-field-type overrides are supported via `inputFieldStyles`:

```swift
let styles = CardFormStylesConfig(
    allInputFieldStyles: CardFieldSpecificStyles(
        base: Style(fieldInsets: .fieldInsets(left: 16, right: 16))
    ),
    inputFieldStyles: [
        .CARD_NUMBER: CardFieldSpecificStyles(
            base: Style(fieldInsets: .fieldInsets(left: 24, right: 24))
        )
    ]
)
```

When an explicit `width` is set on a field, `fieldInsets` is ignored — the field uses a fixed-width constraint instead.

### Per-field overrides

Override the style for a specific field using `inputFieldStyles`. These are merged on top of `allInputFieldStyles`:

```swift
let styles = CardFormStylesConfig(
    allInputFieldStyles: CardFieldSpecificStyles(
        base: Style(borderWidth: 1, borderColor: .systemGray4, cornerRadius: 8)
    ),
    inputFieldStyles: [
        .CVV: CardFieldSpecificStyles(
            base: Style(backgroundColor: .systemGray6)
        ),
        .CARD_NUMBER: CardFieldSpecificStyles(
            base: Style(font: .monospacedDigitSystemFont(ofSize: 16, weight: .regular))
        )
    ]
)
```

### Label styles

Control the appearance of field labels with `labelStyles`:

```swift
let styles = CardFormStylesConfig(
    labelStyles: [
        .CARD_NUMBER: Style(textColor: .label, font: .boldSystemFont(ofSize: 14)),
        .CVV: Style(textColor: .secondaryLabel, font: .systemFont(ofSize: 13))
    ]
)
```

### Default values

| Property | Default |
|---|---|
| `wrapperStyle.borderColor` | `.separator` |
| `wrapperStyle.borderWidth` | `1.0` |
| `wrapperStyle.cornerRadius` | `8.0` |
| `wrapperStyle.padding` | `UIEdgeInsets(16, 16, 16, 16)` |
| `allInputFieldStyles.base.cornerRadius` | `2` |
| `allInputFieldStyles.base.padding` | `UIEdgeInsets(10, 10, 10, 10)` |
| `allInputFieldStyles.base.fieldInsets` | `nil` (defaults to `UIEdgeInsets(0, 16, 0, 16)`) |
| `allInputFieldStyles.base.borderWidth` | `1` |
| `allInputFieldStyles.focus.borderColor` | `.systemBlue` |
| `allInputFieldStyles.completed.borderColor` | `.systemGreen` |
| `allInputFieldStyles.invalid.borderColor` | `.systemRed` |
| `errorTextStyle.textColor` | `.systemRed` |
| `fieldSpacing` | `10` |
| `sectionSpacing` | `16` |

---

## Field variants

`FieldVariant` controls the visual style of input fields:

```swift
let config = CardFormConfig(
    fieldVariant: .outlined  // default: bordered rectangle
    // or
    fieldVariant: .filled    // filled background, no border
)
```

---

## Layout presets

`CardLayoutConfig` controls field arrangement:

| Preset | Rows |
|---|---|
| `.standard` (default) | `[cardNumber]`, `[cvv, expiryMonth, expiryYear]` |
| `.compact` | `[cardNumber]`, `[expiryMonth, expiryYear, cvv]` |
| `.minimal` | `[cardNumber]`, `[expiryMonth, expiryYear, cvv]` (name hidden) |

```swift
let config = CardFormConfig(
    layout: .compact
)
```

### Combined expiry date field

Use `useCombinedExpiryDateField: true` to render a single MM/YY field instead of separate month/year:

```swift
let config = CardFormConfig(
    layout: CardLayoutConfig.preset(.compact, useCombinedExpiryDateField: true)
)
```

### Custom layout

Define your own row arrangement:

```swift
let config = CardFormConfig(
    layout: CardLayoutConfig.custom(
        [[.CARD_NUMBER], [.EXPIRATION_DATE, .CVV]],
        useCombinedExpiryDateField: true
    )
)
```

> Custom layouts must include `.CARD_NUMBER`, `.CVV`, and at least one expiry field (`.EXPIRATION_DATE` or both `.EXPIRATION_MONTH` + `.EXPIRATION_YEAR`). Invalid configurations fall back to the default layout.

---

## Card icon alignment

```swift
let config = CardFormConfig(
    showCardIcon: true,
    cardIconAlignment: .left   // or .right
)
```

---

## Pay button styling

Style the `CardPaymentButton` or `GenericRedirectButton` with `CardButtonStyle`:

```swift
let buttonStyle = CardButtonStyle(
    backgroundColor: .systemIndigo,
    textColor: .white,
    font: .boldSystemFont(ofSize: 16),
    cornerRadius: 10,
    borderWidth: 0,
    contentEdgeInsets: UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24),
    height: 52
)

let payButton = Payrails.createCardPaymentButton(
    buttonStyle: buttonStyle,
    translations: CardPaymenButtonTranslations(label: "Pay now")
)
```

### `CardButtonStyle` properties

| Property | Type | Default |
|---|---|---|
| `backgroundColor` | `UIColor?` | `.systemBlue` |
| `textColor` | `UIColor?` | `.white` |
| `font` | `UIFont?` | System default |
| `cornerRadius` | `CGFloat?` | `8.0` |
| `borderWidth` | `CGFloat?` | `nil` |
| `borderColor` | `UIColor?` | `nil` |
| `contentEdgeInsets` | `UIEdgeInsets?` | `nil` |
| `height` | `CGFloat?` | `44` |

---

## Stored instruments styling

`StoredInstrumentsStyle` controls the appearance of the stored instruments list:

```swift
let style = StoredInstrumentsStyle(
    backgroundColor: .clear,
    itemBackgroundColor: .systemBackground,
    selectedItemBackgroundColor: .systemGray6,
    labelTextColor: .label,
    labelFont: .systemFont(ofSize: 16),
    itemCornerRadius: 8,
    itemSpacing: 8,
    itemPadding: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16),
    deleteButtonStyle: DeleteButtonStyle(
        backgroundColor: .systemRed,
        textColor: .white,
        cornerRadius: 4,
        size: CGSize(width: 32, height: 32)
    ),
    updateButtonStyle: UpdateButtonStyle(
        backgroundColor: .systemBlue,
        textColor: .white,
        cornerRadius: 4,
        size: CGSize(width: 32, height: 32)
    )
)

let instruments = Payrails.createStoredInstruments(style: style)
```

---

## Translations

Override field labels, placeholders, and error messages:

```swift
let translations = CardTranslations(
    placeholders: CardTranslations.Placeholders(values: [
        .CARD_NUMBER: "Card number",
        .CVV: "Security code",
        .EXPIRATION_DATE: "MM / YY"
    ]),
    labels: CardTranslations.Labels(
        saveInstrument: "Remember this card"
    ),
    error: CardTranslations.ErrorMessages(values: [
        .CARD_NUMBER: "Please enter a valid card number",
        .CVV: "Invalid security code"
    ])
)

let config = CardFormConfig(translations: translations)
```

Override the pay button label:

```swift
let payButton = Payrails.createCardPaymentButton(
    translations: CardPaymenButtonTranslations(label: "Complete payment")
)
```

Translations are merged with the SDK defaults — you only need to provide the strings you want to change.
