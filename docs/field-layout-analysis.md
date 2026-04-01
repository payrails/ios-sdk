# Field Layout Analysis & Proposed Fix

**iOS SDK · CardForm Field Width Constraints · Payrails**

---

## Table of Contents

1. [Current Behavior — The Problem](#1-current-behavior--the-problem)
2. [Architecture — Constraint Flow](#2-architecture--constraint-flow)
3. [Solution Options](#3-solution-options)
4. [Naming Analysis](#4-naming-analysis)
5. [Recommended Fix](#5-recommended-fix)
6. [Code Changes Summary](#6-code-changes-summary)
7. [Multi-Element Rows](#7-multi-element-rows--how-does-fieldinsets-apply)

---

## 1. Current Behavior — The Problem

Merchants integrating the SDK encounter three scenarios when configuring field widths. Only one produces the desired result, and it requires manual pixel calculations that break across devices.

### Scenario A: No width set (default) — `PROBLEM`

```
┌──────────────────────────────────┐
│           iPhone Screen          │
│  ┌──────────────────────────────┐│
│  │ 6pt ┌──────────────────┐ 6pt││
│  │ ◄──►│  Card Number     │◄──►││
│  │     └──────────────────┘    ││
│  │ 6pt ┌──────────────────┐ 6pt││
│  │ ◄──►│  Expiry          │◄──►││
│  │     └──────────────────┘    ││
│  │ 6pt ┌──────────────────┐ 6pt││
│  │ ◄──►│  CVV             │◄──►││
│  │     └──────────────────┘    ││
│  └──────────────────────────────┘│
└──────────────────────────────────┘
```

- Fields pin to row edges with only **6pt inset**
- Padding is minimal and **not configurable** separately
- Container may not be properly constrained to screen edges

### Scenario B: Explicit width set — `WORKAROUND`

```
┌─────────────────────────────────┐
│           iPhone Screen         │
│                                 │
│      ┌──────────────────┐       │
│      │  Card Number     │       │
│      └──────────────────┘       │
│      ┌──────────────────┐       │
│      │  Expiry          │       │
│      └──────────────────┘       │
│      ┌──────────────────┐       │
│      │  CVV             │       │
│      └──────────────────┘       │
│                                 │
└─────────────────────────────────┘
```

- Merchant must calculate: `UIScreen.main.bounds.width - margins`
- Hardcoded pixels **break on different devices**
- Trailing constraint is **skipped**; field floats

### Scenario C: Desired behavior — `GOAL`

```
┌──────────────────────────────────┐
│           iPhone Screen          │
│  ┌──────────────────────────────┐│
│  │16pt ┌────────────────┐ 16pt ││
│  │ ◄──►│  Card Number   │◄───► ││
│  │     └────────────────┘      ││
│  │16pt ┌────────────────┐ 16pt ││
│  │ ◄──►│  Expiry        │◄───► ││
│  │     └────────────────┘      ││
│  │16pt ┌────────────────┐ 16pt ││
│  │ ◄──►│  CVV           │◄───► ││
│  │     └────────────────┘      ││
│  └──────────────────────────────┘│
└──────────────────────────────────┘
```

- Fields **auto-stretch** to fill available width
- Merchant specifies only **horizontal padding** (e.g., 16pt)
- Works on **all screen sizes** without manual calculation

### Core Issue

> **`leadingInset` / `trailingInset`** defaults to 6pt and is derived from `containerOptions?.styles?.base?.padding`, which is also used for *internal text padding* inside the text field. This **conflates two different layout concepts**: the spacing between the field and its container edge, and the text inset within the field itself.

---

## 2. Architecture — Constraint Flow

The view hierarchy and how Auto Layout constraints flow from screen to text field:

```
Screen (UIScreen.main.bounds.width)
│
└─── CardForm (UIStackView)
     │   • Arranged subviews stack vertically
     │   • layoutMargins from wrapperStyle.padding
     │
     └─── parentView (created by createDynamicViews())
          │   • Width matches stack view
          │
          └─── childView (Row Container)
               │   • leading → parentView.leading
               │   • trailing → parentView.trailing
               │
               └─── TextField (Element)
                    │   • leading  → childView.leading  + leadingInset (6pt)  ⚠️ CONFLATED
                    │   • trailing → childView.trailing - trailingInset (6pt) ⚠️ CONFLATED
                    │   • top      → childView.top
                    │   • bottom   → childView.bottom
                    │
                    └─── ⛔ BUG: leadingInset / trailingInset = padding value
                         • Derived from containerOptions?.styles?.base?.padding
                         • Same value also controls internal text padding
                         • Two distinct concepts conflated into one property
```

### Constraint Detail

| Constraint | Current Source | Actual Concept | Status |
|------------|---------------|----------------|--------|
| `leadingInset` | `styles.base.padding` | Container → field horizontal spacing | ⚠️ **Conflated** |
| `trailingInset` | `styles.base.padding` | Container → field horizontal spacing | ⚠️ **Conflated** |
| Text inset (internal) | `styles.base.padding` | Field border → text offset | ⚠️ **Conflated** |
| `width` (explicit) | Merchant-specified | Fixed width — skips trailing | Works but fragile |

> **What this means:** When a merchant changes `padding` to adjust text inset, the field-to-container spacing also changes. Conversely, there is no way to adjust container spacing independently.

---

## 3. Solution Options

There are **4 viable approaches** to solve this issue. Each has trade-offs.

### Option A: New `fieldInsets: UIEdgeInsets` property

Add a dedicated `UIEdgeInsets` property to the style model that controls how the field is inset within its container row. Completely independent of internal text padding.

| | Detail |
|---|---|
| **Pros** | Full 4-side control (top, left, bottom, right). Matches existing patterns: `contentEdgeInsets`, `itemPadding`, `insets`. Familiar `UIEdgeInsets` type used throughout the SDK. |
| **Cons** | Slightly more verbose for merchants who only need horizontal control. Merchant must construct `UIEdgeInsets(top:0, left:16, bottom:0, right:16)`. |
| **Impact** | 3 files changed. Backward compatible — nil means current defaults. |

#### Option A — Merchant-Facing Code

```swift
//rev-commentDone: fieldInsets now lives inside base (Style), not on CardFormStylesConfig
// Merchant creates a style config with field insets on the base style
let styles = CardFormStylesConfig(
    wrapperStyle: CardWrapperStyle(padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)),
    allInputFieldStyles: CardFieldSpecificStyles(
        base: CardStyle(
            cornerRadius: 8,
            padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10),  // ← text inset (unchanged)
            borderWidth: 1,
            fieldInsets: .fieldInsets(left: 16, right: 16)  // ← NEW: field-to-container spacing
        )
    )
)

let config = CardFormConfig(styles: styles)
let cardForm = CardForm(config: config, session: session)
```

- `fieldInsets` lives on `Style` (aka `CardStyle`) inside `base` — alongside `padding`, `width`, `height`
- Discoverable via autocomplete alongside other per-field layout properties
- `nil` means default `(0, 16, 0, 16)` — no action needed for most merchants
- Convenience extension means merchants only override the sides they care about
- Per-field-type overrides possible via `inputFieldStyles` (e.g., different insets for card number vs CVV)

#### Option A — SDK-Side Implementation (ComposableContainer.swift)

```swift
//rev-commentDone: fieldInsets read from element's style (base), not from top-level config
// In createDynamicViews()
let insets = elementStyle.fieldInsets ?? UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

if let width = elementStyle.width {
    // Existing: fixed width, centered
    element.widthAnchor.constraint(equalToConstant: width).isActive = true
    element.centerXAnchor.constraint(equalTo: childView.centerXAnchor).isActive = true
} else {
    // Stretch with fieldInsets — manual constraints
    element.leadingAnchor.constraint(
        equalTo: parentView.leadingAnchor, constant: insets.left
    ).isActive = true
    element.trailingAnchor.constraint(
        equalTo: parentView.trailingAnchor, constant: -insets.right
    ).isActive = true
}
```

#### Option A — Multi-Element Row Behavior

```
┌─────────────────────── childView ───────────────────────────┐
│                                                             │
│ .left ┌──────────┐ 20pt ┌──────────┐ 20pt ┌──────────┐.right│
│ ◄────►│ Exp Month│◄────►│ Exp Year │◄────►│   CVV    │◄────►│
│       └──────────┘      └──────────┘      └──────────┘      │
└─────────────────────────────────────────────────────────────┘

fieldInsets.left → first field's leading constraint constant
fieldInsets.right → last field's trailing constraint constant
Inter-item spacing (20pt) → unchanged, still manual constraints
```

`fieldInsets` applies only to the outermost edges. Inter-item spacing remains a separate concern handled by explicit `NSLayoutAnchor` constraints between fields.

---

### Option B: Leverage `layoutMargins` on the row container

Use UIKit's native `layoutMargins` on the `childView` (row container), combined with `layoutMarginsGuide` for constraints.

| | Detail |
|---|---|
| **Pros** | Native UIKit pattern. `layoutMarginsGuide` already used in PayPalButton.swift. Leverages UIKit's built-in margin system. |
| **Cons** | System defaults (8pt) require explicit override. `insetsLayoutMarginsFromSafeArea` defaults to `true` and must be disabled. Merchant still needs a property in the style model to configure the values (see analysis below). |
| **Impact** | 2–3 files changed. Backward compatible — nil means current defaults. |

#### Option B — The Key Architectural Question

The `childView` is created internally by the SDK inside `createDynamicViews()`. **Merchants never have direct access to it.** This means there are two sub-variants of Option B:

**B1: Merchant configures via style model (same API as Option A)**

The merchant specifies insets through a property in `CardFormStylesConfig`. The SDK relays that value to `childView.layoutMargins` internally.

**B2: Merchant accesses childView directly (raw UIKit)**

The merchant would need to reach into the view hierarchy to set `layoutMargins` on a view the SDK owns. This breaks encapsulation and is fragile.

> **B2 is not viable** — the `childView` is internal, has no public accessor, and exposing it would couple merchants to the SDK's internal view hierarchy. The rest of this analysis focuses on **B1**.

#### Option B (B1) — Merchant-Facing Code

```swift
//rev-commentD: fieldInsets inside base — identical placement to Option A
// Merchant creates a style config — identical API surface to Option A
let styles = CardFormStylesConfig(
    wrapperStyle: CardWrapperStyle(padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)),
    allInputFieldStyles: CardFieldSpecificStyles(
        base: CardStyle(
            cornerRadius: 8,
            padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10),  // ← text inset
            borderWidth: 1,
            fieldInsets: .fieldInsets(left: 16, right: 16)  // ← same property name, same type
        )
    )
)

let config = CardFormConfig(styles: styles)
let cardForm = CardForm(config: config, session: session)
```

> **Note:** The merchant-facing code is **identical** to Option A. The only difference is what happens inside the SDK.

#### Option B (B1) — SDK-Side Implementation (ComposableContainer.swift)

```swift
//rev-commentD: fieldInsets read from element's style (base), not from top-level config
// In createDynamicViews()
let insets = elementStyle.fieldInsets ?? UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

// Configure layoutMargins on the row container
childView.layoutMargins = insets
childView.insetsLayoutMarginsFromSafeArea = false  // ⚠️ REQUIRED: prevent system override

if let width = elementStyle.width {
    // Existing: fixed width, centered
    element.widthAnchor.constraint(equalToConstant: width).isActive = true
    element.centerXAnchor.constraint(equalTo: childView.centerXAnchor).isActive = true
} else {
    // Stretch using layoutMarginsGuide
    element.leadingAnchor.constraint(
        equalTo: childView.layoutMarginsGuide.leadingAnchor
    ).isActive = true
    element.trailingAnchor.constraint(
        equalTo: childView.layoutMarginsGuide.trailingAnchor
    ).isActive = true
}
```

Key differences from Option A's implementation:

| Aspect | Option A (Manual Constants) | Option B (layoutMarginsGuide) |
|--------|----------------------------|-------------------------------|
| Leading constraint | `equalTo: parent.leading, constant: insets.left` | `equalTo: child.layoutMarginsGuide.leading` |
| Trailing constraint | `equalTo: parent.trailing, constant: -insets.right` | `equalTo: child.layoutMarginsGuide.trailing` |
| Safe area handling | Not affected | Must set `insetsLayoutMarginsFromSafeArea = false` |
| System default margins | Not applicable | `UIView` defaults to 8pt — must explicitly override |
| Runtime margin changes | Requires deactivating/reactivating constraints | Can update `layoutMargins` and layout auto-updates |

#### Option B — Multi-Element Row Behavior

```
┌─────────────────────── childView ───────────────────────────┐
│          (layoutMargins applied to childView)               │
│ .left ┌──────────┐ 20pt ┌──────────┐ 20pt ┌──────────┐.right│
│ ◄────►│ Exp Month│◄────►│ Exp Year │◄────►│   CVV    │◄────►│
│       └──────────┘      └──────────┘      └──────────┘      │
└─────────────────────────────────────────────────────────────┘

layoutMarginsGuide.leading → first field snaps to margin edge
layoutMarginsGuide.trailing → last field snaps to margin edge
Inter-item spacing (20pt) → still manual constraints (layoutMargins doesn't help here)
```

For multi-element rows, `layoutMarginsGuide` only affects the **first** and **last** field constraints. Middle fields are still chained with manual `NSLayoutAnchor` constraints (20pt inter-item gap). This is the same as Option A — `layoutMargins` provides no additional benefit for the inter-item layout.

```swift
// Multi-element row — Option B implementation
childView.layoutMargins = insets
childView.insetsLayoutMarginsFromSafeArea = false

for j in 0..<layoutArray[i] {
    if j == 0 {
        // FIRST field: use layoutMarginsGuide
        elements[elementCount].leadingAnchor.constraint(
            equalTo: childView.layoutMarginsGuide.leadingAnchor
        ).isActive = true
    } else {
        // SUBSEQUENT fields: manual chain (same as Option A)
        elements[elementCount].leadingAnchor.constraint(
            equalTo: elements[elementCount - 1].trailingAnchor,
            constant: 20.0
        ).isActive = true
        elements[elementCount].widthAnchor.constraint(
            equalTo: elements[elementCount - j].widthAnchor
        ).isActive = true
    }

    if j == layoutArray[i] - 1 {
        // LAST field: use layoutMarginsGuide
        elements[elementCount].trailingAnchor.constraint(
            equalTo: childView.layoutMarginsGuide.trailingAnchor
        ).isActive = true
    }
}
```

#### Option B — UIKit Gotchas

| Gotcha | Detail | Mitigation |
|--------|--------|------------|
| **System default margins** | `UIView.layoutMargins` defaults to `UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)` on most devices. If we forget to set it, fields get unexpected 8pt insets. | Always explicitly set `childView.layoutMargins = insets`. |
| **Safe area insets** | `insetsLayoutMarginsFromSafeArea` defaults to `true`. On devices with notches/home indicators, the system can *add* extra margin on top of what we set. | Must set `childView.insetsLayoutMarginsFromSafeArea = false`. |
| **Margin propagation** | If `preservesSuperviewLayoutMargins` is `true` (default `false`), margins can propagate up the view hierarchy unexpectedly. | Leave as default `false` — but worth documenting. |
| **Directional margins** | iOS 11+ has `directionalLayoutMargins` (leading/trailing instead of left/right) which can override `layoutMargins`. | Use `layoutMargins` (not directional) to match the rest of the SDK. |

---

### Option C: Percentage-based `widthRatio: CGFloat` (0.0–1.0)

Let merchants specify the field width as a fraction of its container. E.g., `0.9` means 90% of parent width.

| | Detail |
|---|---|
| **Pros** | Simple mental model ("I want 90% width"). One property, one concept. Auto-adapts to all screen sizes. |
| **Cons** | No precise pixel control. Unusual pattern in iOS (not idiomatic UIKit). Doesn't give independent left/right control. Merchants can't express asymmetric padding. |
| **Impact** | 2–3 files changed. New concept not seen elsewhere in SDK. |

---

### Option D: Separate `horizontalPadding: CGFloat`

Add a single `CGFloat` property for symmetric left/right spacing between the field and its container.

| | Detail |
|---|---|
| **Pros** | Simple — one value. Easy for merchants to understand. |
| **Cons** | **`horizontalPadding` is already a local variable name in ComposableContainer.swift line ~107.** "padding" is overloaded — already means internal text insets. Only horizontal, no vertical control. Continues naming confusion. |
| **Impact** | 2–3 files changed. Risk of naming collision. |

---

### Head-to-Head: Option A vs Option B

Since Options C and D have clear drawbacks (non-idiomatic and naming collision respectively), the real decision is between **A** and **B**. Here is a direct comparison:

| Dimension | Option A (Manual Constants) | Option B (layoutMarginsGuide) |
|-----------|----------------------------|-------------------------------|
| **Merchant-facing API** | `fieldInsets: UIEdgeInsets?` on `Style` (inside `base`) | Identical — same property, same type, same location |
| **Merchant-facing code** | Identical | Identical |
| **SDK implementation** | `constant: insets.left` on `NSLayoutAnchor` | `childView.layoutMargins = insets` + constrain to `.layoutMarginsGuide` |
| **UIKit idiom** | Manual constraint constants — common in layout code | `layoutMarginsGuide` — Apple's intended pattern for content insets |
| **Safe area risk** | None | Must disable `insetsLayoutMarginsFromSafeArea` (defaults `true`) |
| **System default risk** | None — we set the constant explicitly | Must override system 8pt default explicitly |
| **Runtime updates** | Must deactivate + reactivate constraints | Can mutate `layoutMargins` directly — layout auto-updates |
| **Consistency with SDK** | SDK already uses manual constants for field layout in `createDynamicViews()` | `layoutMargins` already used at the `CardForm` stack view level (not at row level) |
| **Multi-element rows** | Manual constraint chain (inter-item gap is unaffected) | Same — `layoutMarginsGuide` only helps outer edges |
| **Debugging** | Constraint constants visible in Debug View Hierarchy | Margins visible via `layoutMargins` property in debugger |
| **Files changed** | 3 | 2–3 |
| **Cognitive overhead** | Low — same pattern already used in the method | Low — but requires remembering safe area + default margin caveats |

#### Verdict

Both options solve the merchant's problem equally well. The merchant-facing API is **identical** — the difference is purely internal SDK implementation.

**Option A** is the simpler internal implementation because:
- It follows the **exact pattern already used** in `createDynamicViews()` (constraint constants)
- It has **zero UIKit gotchas** (no safe area, no system defaults to override)
- It requires **no defensive code** (`insetsLayoutMarginsFromSafeArea = false`)
- The method already uses manual `NSLayoutAnchor` constraints for everything — switching to `layoutMarginsGuide` for just the outer edges creates inconsistency within the same method

**Option B** would be preferred if:
- The SDK were moving toward `layoutMarginsGuide` more broadly (it isn't — only `CardForm` uses it, and only for the stack view wrapper)
- We needed runtime margin updates without reconstructing constraints (not a current requirement)
- The row container were a `UIStackView` with `isLayoutMarginsRelativeArrangement` (it's a plain `UIView`)

**Recommendation: Option A** — it solves the problem with the least internal complexity, zero UIKit edge cases, and full consistency with the existing constraint code in the same method. Option B is architecturally sound but introduces defensive boilerplate (`insetsLayoutMarginsFromSafeArea`, explicit margin override) for no additional merchant benefit.

---

## 4. Naming Analysis

Based on existing naming patterns in the SDK codebase.

### Codebase Naming Conventions

| Pattern | Meaning | Examples |
|---------|---------|---------|
| `*Spacing` | Distance **between items** | `fieldSpacing`, `sectionSpacing`, `itemSpacing` |
| `*Padding` / `*Insets` | Distance from **container edge to content** | `padding`, `contentEdgeInsets`, `itemPadding`, `insets` |
| Type convention | `UIEdgeInsets` for 4-side control, `CGFloat` for single-axis | — |

### Candidate Names Comparison

| Candidate Name | Type | Fits Pattern? | Issue | Verdict |
|----------------|------|--------------|-------|---------|
| **`fieldInsets`** | `UIEdgeInsets` | ✅ Yes | None — follows `contentEdgeInsets`, `itemPadding`, `insets` patterns | ✅ **RECOMMENDED** |
| `horizontalPadding` | `CGFloat` | ❌ Conflict | Already a local var in ComposableContainer.swift. "padding" means text insets — reusing it continues the conflation bug | ❌ Avoid |
| `horizontalFieldSpacing` | `CGFloat` | ❌ Wrong | "Spacing" in this codebase means between items, not edge-to-content. Would imply space *between fields* | ❌ Avoid |
| `fieldEdgeInsets` | `UIEdgeInsets` | ⚪ OK | Correct but verbose — "Edge" is redundant since `UIEdgeInsets` already implies edges | ⚪ Acceptable |
| `contentInset` | `UIEdgeInsets` | ⚠️ Risky | Could confuse with `UIScrollView.contentInset` which has a different meaning | ⚠️ Risky |

### Recommendation: `fieldInsets`

- Follows the existing `UIEdgeInsets` pattern used throughout the SDK
- Clear it controls **where the field sits within its container**, not text inside the field
- Gives full 4-side control when needed
- No naming collisions with existing properties or local variables
- Concise — `fieldEdgeInsets` is redundant

---

## 5. Recommended Fix

### New Property

> **`fieldInsets: UIEdgeInsets?`**
>
> A dedicated `UIEdgeInsets` property for the spacing between the container edge and the field edge. Completely independent of the text inset (`padding`). Gives full 4-side control.

### New Layout Model

```
Screen
│
└─── CardForm (UIStackView, layoutMargins = wrapperStyle.padding)
     │
     └─── parentView
          │
          └─── childView (row)
               │
               └─── TextField
                    • IF width is set → fixed width constraint, centered
                    • IF width is NOT set (default):
                         leading  = parentView.leading  + fieldInsets.left
                         trailing = parentView.trailing  - fieldInsets.right
                         top      = childView.top        + fieldInsets.top
                         bottom   = childView.bottom     - fieldInsets.bottom
                         → TextField stretches to fill
```

> **Key Improvement:** `padding` controls text inset inside the field. `fieldInsets` controls the space between the field and its container. Two distinct, independently configurable values with full 4-side control.

### Decision Flow

```
                    ┌─────────────────────┐
                    │ Merchant sets width? │
                    └──────────┬──────────┘
                       ┌───────┴───────┐
                      YES              NO
                       │               │
                       ▼               ▼
              ┌──────────────┐  ┌───────────────────┐
              │ Fixed width  │  │ fieldInsets set?  │
              │ constraint   │  └────────┬──────────┘
              │ (existing    │     ┌─────┴───────┐
              │  behavior)   │    YES            NO
              └──────────────┘     │             │
                                  ▼             ▼
                         ┌───────────────┐ ┌──────────────┐
                         │ Pin to edges  │ │ Default      │
                         │ using         │ │ insets       │
                         │ fieldInsets   │ │ (0,16,0,16)  │
                         │ (all 4 sides) │ │ pin to edges │
                         └───────────────┘ └──────────────┘
```

### Before / After Comparison

| Aspect | Before (Current) | After (Proposed) |
|--------|-------------------|------------------|
| Container-to-field spacing | Derived from `padding` (6pt default) | Dedicated `fieldInsets` (0,16,0,16 default) |
| Text inset inside field | Same `padding` property | Separate `padding` property (unchanged) |
| Default width behavior | Stretches with 6pt inset | Stretches with 16pt inset |
| Explicit width | Fixed, trailing skipped | Fixed, centered (unchanged) |
| Cross-device behavior | Requires manual calculation | Auto-adapts |

---

## 6. Code Changes Summary

Three files need to change to implement the recommended fix (Option A with `fieldInsets`).

### Files to Modify

//rev-commentD: Style.swift is now the primary change target (fieldInsets added there), CardFormStyle.swift no longer needs a new property

| File | Action | Description |
|------|--------|-------------|
| `Style.swift` | **Add Property** | Add `fieldInsets: UIEdgeInsets?` to the `Style` struct. Update `init()` and `merged()`. Sits alongside `padding`, `width`, `height` as a per-field layout property. |
| `ComposableContainer.swift` | **Modify Logic** | Update `createDynamicViews()` constraint logic. Read `fieldInsets` from the element's style. When no explicit width is set, use `fieldInsets` (defaulting to `UIEdgeInsets(top:0, left:16, bottom:0, right:16)`) instead of deriving from `padding`. Rename existing local `horizontalPadding` variable to avoid confusion. |
| `UIEdgeInsets+FieldInsets.swift` | **Add Extension** | Convenience static factory `UIEdgeInsets.fieldInsets(top:left:bottom:right:)` with default parameter values. |

### New Constraint Logic

```swift
// In createDynamicViews() — ComposableContainer.swift

let defaultInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

if let width = elementStyle.width {
    // Existing behavior: fixed width, centered
    element.widthAnchor.constraint(equalToConstant: width).isActive = true
    element.centerXAnchor.constraint(equalTo: childView.centerXAnchor).isActive = true
} else {
    // New behavior: stretch with fieldInsets
    let insets = elementStyle.fieldInsets ?? defaultInsets

    element.leadingAnchor.constraint(
        equalTo: parentView.leadingAnchor,
        constant: insets.left
    ).isActive = true

    element.trailingAnchor.constraint(
        equalTo: parentView.trailingAnchor,
        constant: -insets.right
    ).isActive = true

    element.topAnchor.constraint(
        equalTo: childView.topAnchor,
        constant: insets.top
    ).isActive = true

    element.bottomAnchor.constraint(
        equalTo: childView.bottomAnchor,
        constant: -insets.bottom
    ).isActive = true
}
```

### Style Model Addition

```swift
//rev-commentD: fieldInsets added to Style struct (not CardFormStyle / CardFormStylesConfig)
// In Style.swift

public struct Style {
    // ... existing properties (borderColor, cornerRadius, padding, width, height, etc.) ...

    /// Insets between the field and its container edge (all 4 sides).
    /// Independent of the text inset (`padding`).
    /// Defaults to UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16) when nil.
    var fieldInsets: UIEdgeInsets?

    public init(
        // ... existing parameters ...
        fieldInsets: UIEdgeInsets? = nil
    ) {
        // ... existing assignments ...
        self.fieldInsets = fieldInsets
    }

    func merged(over base: Style?) -> Style {
        let baseStyle = base ?? Style()
        return Style(
            // ... existing merges ...
            fieldInsets: self.fieldInsets ?? baseStyle.fieldInsets
        )
    }
}
```

### Merchant Usage Examples

```swift
//rev-commentD: fieldInsets set on base style, not top-level config
// Via CardFieldSpecificStyles (most common path)
let inputStyle = CardFieldSpecificStyles(
    base: CardStyle(
        padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10),  // text inset
        fieldInsets: .fieldInsets(left: 16, right: 16)                     // container spacing
    )
)

// Simple: only change horizontal — rest defaults
baseStyle.fieldInsets = .fieldInsets(left: 16, right: 16)

// Only change top
baseStyle.fieldInsets = .fieldInsets(top: 8)

// Edge-to-edge (no insets)
baseStyle.fieldInsets = .zero

// Asymmetric (e.g., larger left for icon space)
baseStyle.fieldInsets = .fieldInsets(top: 4, left: 48, right: 16)

// Full explicit control
baseStyle.fieldInsets = UIEdgeInsets(top: 4, left: 48, bottom: 4, right: 16)

// Per-field-type override (card number gets wider insets than others)
let styles = CardFormStylesConfig(
    allInputFieldStyles: CardFieldSpecificStyles(
        base: CardStyle(fieldInsets: .fieldInsets(left: 16, right: 16))
    ),
    inputFieldStyles: [
        .CARD_NUMBER: CardFieldSpecificStyles(
            base: CardStyle(fieldInsets: .fieldInsets(left: 24, right: 24))
        )
    ]
)

// Nil = default (0, 16, 0, 16) — no action needed
```

### Backward Compatibility

When `fieldInsets` is nil, the default of `(0, 16, 0, 16)` is applied. Merchants who already set an explicit `width` are unaffected because the fixed-width path remains unchanged. The only visual change is for merchants using the default (no width set): fields will have 16pt spacing instead of 6pt, which matches the desired behavior in Scenario C.

---

## 7. Multi-Element Rows — How Does `fieldInsets` Apply?

A common layout is placing multiple fields in a single row (e.g., Expiry Month + Expiry Year + CVV). This section analyzes how the current layout works for multi-element rows and how `fieldInsets` should behave.

### Current Multi-Element Row Behavior

The SDK supports configurable row layouts via `CardLayoutConfig`:

```swift
// Example: Card number alone, then 3 fields in one row
CardLayoutConfig.custom([
    [.CARD_NUMBER],                                    // Row 0: 1 field
    [.EXPIRATION_MONTH, .EXPIRATION_YEAR, .CVV],       // Row 1: 3 fields
    [.CARDHOLDER_NAME]                                 // Row 2: 1 field
])
```

### Current Constraint Model — Multi-Element Row

For a row with N fields, the constraints work as follows:

```
childView (row container)
│
├── Field[0] (first)
│   ├── leading  = childView.leading + leadingInset (6pt)
│   ├── top      = childView.top
│   ├── bottom   = childView.bottom
│   └── trailing = (not set — determined by equal-width + chain)
│
├── Field[1] (middle)
│   ├── leading  = Field[0].trailing + 20pt  ← HARDCODED inter-item gap
│   ├── centerY  = childView.centerY
│   ├── width    = Field[0].width            ← EQUAL WIDTH
│   ├── top      = childView.top
│   └── bottom   = childView.bottom
│
└── Field[2] (last)
    ├── leading  = Field[1].trailing + 20pt  ← HARDCODED inter-item gap
    ├── centerY  = childView.centerY
    ├── width    = Field[0].width            ← EQUAL WIDTH
    ├── top      = childView.top
    ├── bottom   = childView.bottom
    └── trailing = childView.trailing - trailingInset (6pt)
```

### Visual: Single-Element vs Multi-Element Row

**Single element in row (e.g., Card Number):**

```
┌─────────────────────── childView ─────────────────────┐
│                                                       │
│  6pt ┌──────────────────────────────────────────┐ 6pt │
│  ◄──►│              Card Number                 │◄───►│
│      └──────────────────────────────────────────┘     │
│                                                       │
└───────────────────────────────────────────────────────┘
```

**Three elements in row (e.g., Expiry Month + Expiry Year + CVV):**

```
┌─────────────────────── childView ─────────────────────────┐
│                                                           │
│  6pt ┌──────────┐ 20pt ┌──────────┐ 20pt ┌──────────┐ 6pt │
│  ◄──►│ Exp Month│◄────►│ Exp Year │◄────►│   CVV    │◄──► │
│      └──────────┘      └──────────┘      └──────────┘     │
│      ◄── equal ──►     ◄── equal ──►     ◄── equal ──►    │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### Key Observations

| Property | Value | Configurable? |
|----------|-------|---------------|
| Inter-item spacing (between fields in same row) | **20pt** | **No** (hardcoded) |
| Leading inset (first field to row edge) | **6pt** default | Via wrapper `padding` (conflated) |
| Trailing inset (last field to row edge) | **6pt** default | Via wrapper `padding` (conflated) |
| Width distribution | **Equal widths** | **No** (all fields match first) |
| Vertical alignment | Pin top + bottom (fill), centerY for non-first | **No** |

> **Note:** There is no `UIStackView` used for the horizontal arrangement. All positioning is done with manual `NSLayoutAnchor` constraints in `createDynamicViews()`.

### How `fieldInsets` Applies to Multi-Element Rows

`fieldInsets` controls the spacing between the **row container edge** and the **outermost fields**. It does NOT affect inter-item spacing between fields within the same row.

**Proposed behavior with `fieldInsets`:**

```
┌─────────────────────── childView ───────────────────────────┐
│                                                             │
│ .left ┌──────────┐ 20pt ┌──────────┐ 20pt ┌──────────┐.right│
│ ◄────►│ Exp Month│◄────►│ Exp Year │◄────►│   CVV    │◄────►│
│       └──────────┘      └──────────┘      └──────────┘      │
│       ◄── equal ──►     ◄── equal ──►     ◄── equal ──►     │
│                                                             │
└─────────────────────────────────────────────────────────────┘

fieldInsets.left ──────┐              ┌────── fieldInsets.right
                       │              │
  Applied to FIRST     │              │  Applied to LAST
  field's leading      │              │  field's trailing
  constraint only      │              │  constraint only
```

### Updated Constraint Logic for Multi-Element Rows

```swift
// In createDynamicViews() — ComposableContainer.swift

let insets = elementStyle.fieldInsets ?? UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

for j in 0..<layoutArray[i] {
    if j == 0 {
        // FIRST field in row: apply fieldInsets.left
        elements[elementCount].leadingAnchor.constraint(
            equalTo: childView.leadingAnchor,
            constant: insets.left
        ).isActive = true
    } else {
        // SUBSEQUENT fields: chain to previous with inter-item spacing
        elements[elementCount].leadingAnchor.constraint(
            equalTo: elements[elementCount - 1].trailingAnchor,
            constant: 20.0  // inter-item spacing (consider making configurable)
        ).isActive = true
        elements[elementCount].widthAnchor.constraint(
            equalTo: elements[elementCount - j].widthAnchor
        ).isActive = true
    }

    // Top and bottom insets (all fields)
    elements[elementCount].topAnchor.constraint(
        equalTo: childView.topAnchor,
        constant: insets.top
    ).isActive = true
    elements[elementCount].bottomAnchor.constraint(
        equalTo: childView.bottomAnchor,
        constant: -insets.bottom
    ).isActive = true

    // LAST field in row: apply fieldInsets.right
    if j == layoutArray[i] - 1 {
        elements[elementCount].trailingAnchor.constraint(
            equalTo: childView.trailingAnchor,
            constant: -insets.right
        ).isActive = true
    }
}
```

### Full Form Example with `fieldInsets`

```
Screen (390pt wide — iPhone 14)
│
├── Row 0: [Card Number] — single element
│   ┌─────────────────────────────────────────────┐
│   │ 16pt ┌──────────────────────────────┐ 16pt  │
│   │ ◄───►│        Card Number           │◄───►  │
│   │      └──────────────────────────────┘       │
│   └─────────────────────────────────────────────┘
│
├── Row 1: [Exp Month, Exp Year, CVV] — three elements
│   ┌──────────────────────────────────────────────────────┐
│   │ 16pt ┌────────┐ 20pt ┌────────┐ 20pt ┌────────┐ 16pt │
│   │ ◄───►│Exp Mon │◄────►│Exp Yr  │◄────►│  CVV   │◄────►│
│   │      └────────┘      └────────┘      └────────┘      │
│   │      ◄─ 86pt ─►     ◄─ 86pt ─►     ◄─ 86pt ─►        │
│   └──────────────────────────────────────────────────────┘
│           16 + 86 + 20 + 86 + 20 + 86 + 16 = 330pt
│           (parentView width matches screen: 390pt)
│
└── Row 2: [Cardholder Name] — single element
    ┌─────────────────────────────────────────────┐
    │ 16pt ┌──────────────────────────────┐ 16pt  │
    │ ◄───►│       Cardholder Name        │◄───►  │
    │      └──────────────────────────────┘       │
    └─────────────────────────────────────────────┘

    Width math for 3-field row:
    availableWidth = parentWidth - insets.left - insets.right - (interItemSpacing × 2)
                   = 390 - 16 - 16 - (20 × 2)
                   = 318pt
    fieldWidth     = 318 / 3 = 106pt each
```

### Edge Case: `fieldInsets` vs `width` in Multi-Element Rows

| Scenario | Behavior |
|----------|----------|
| No width, no fieldInsets | Default 16pt insets, equal-width distribution |
| fieldInsets set, no width | Custom insets, equal-width distribution |
| width set on all fields | Each field gets fixed width — **fieldInsets ignored**, fields centered in row |
| width set on some fields | ⚠️ Undefined — should document: either all fields have width or none |
| fieldInsets with 1 field | Same as single-element — field stretches between insets |

### Future Consideration: Configurable Inter-Item Spacing

The 20pt inter-item gap is currently hardcoded. A natural follow-up would be to add an `interItemSpacing: CGFloat?` property to make this configurable:

```swift
//rev-commentD: fieldInsets lives on Style, interItemSpacing could live on Style or CardFormStylesConfig
public struct Style {
    // ... existing properties ...
    var fieldInsets: UIEdgeInsets?       // Container edge → field edge (per-field)
    var interItemSpacing: CGFloat?      // Field → field within same row (per-field or global TBD)
}
```

This is out of scope for the current fix but worth noting for the roadmap.

---

### Limitation: No Column-Span / Grid-Based Layout

> **Colleague's question:** *"So with this, the merchant would not be able to do a custom grid layout, where one field takes up two columns and another field only takes up one — correct? Each field would be the same width, same outer padding on each side and then same padding in between fields?"*

**Yes, that is correct.** The current model — and the proposed `fieldInsets` fix — both enforce **equal-width distribution** across all fields in a row. There is no concept of a field spanning multiple columns.

#### What merchants can do today (and after the fix)

```
Row: [Exp Month, Exp Year, CVV]

┌────────────────────────────────────────────────┐
│ 16pt ┌──────┐ 20pt ┌──────┐ 20pt ┌──────┐ 16pt │
│      │ Exp M│      │ Exp Y│      │ CVV  │      │
│      └──────┘      └──────┘      └──────┘      │
│      ◄─1/3─►       ◄─1/3─►       ◄─1/3─►       │
└────────────────────────────────────────────────┘
All fields: equal width. No exceptions.
```

#### What they cannot do (no column-span support)

```
Desired: Expiry takes 2/3 width, CVV takes 1/3
┌───────────────────────────────────────────┐
│ 16pt ┌───────────────┐ 20pt ┌──────┐ 16pt │
│      │  Expiry Date  │      │ CVV  │      │
│      └───────────────┘      └──────┘      │
│      ◄──── 2/3 ──────►      ◄─1/3─►       │
└───────────────────────────────────────────┘
Not possible with current or proposed model.
```

This is analogous to **CSS Flexbox `flex-grow`** or a **12-column grid `col-8 / col-4`** pattern on the web — where each item can declare how much of the available space it wants to occupy.

#### What a grid-based layout system would look like

To support this, the SDK would need a column-weight or span model. Two approaches from web development that translate well to iOS:

**Option 1: Weight-based (like CSS `flex-grow`)**

Each field declares a relative weight. Available width is distributed proportionally.

```swift
// Merchant configuration
CardLayoutConfig.custom([
    [.card(.CARD_NUMBER, weight: 1)],
    [.card(.EXPIRATION_DATE, weight: 2), .card(.CVV, weight: 1)],
    // Expiry gets 2/3 of row width, CVV gets 1/3
])
```

```
availableWidth = 390 - 16 - 16 - 20 = 338pt
expiry = 338 × (2/3) = 225pt
cvv    = 338 × (1/3) = 113pt
```

**Option 2: Column-span (like CSS Grid `grid-column: span 2`)**

Define a fixed column count (e.g., 12), and each field declares how many columns it spans.

```swift
CardLayoutConfig.grid(columns: 12, rows: [
    [.span(.CARD_NUMBER, cols: 12)],
    [.span(.EXPIRATION_DATE, cols: 8), .span(.CVV, cols: 4)],
])
```

#### Complexity assessment

| Concern | Detail |
|---------|--------|
| API surface change | Significant — `CardLayoutConfig` and `ContainerOptions` would need a new model |
| Constraint logic | More complex — `widthAnchor.constraint(equalTo:, multiplier:)` per field |
| Inter-item spacing | Becomes more nuanced — spacing must be factored into weight math |
| Backward compatibility | Breaking change if layout config structure changes |
| Merchant benefit | High — enables standard payment form layouts (wide expiry, narrow CVV) |

#### Recommendation

This is **out of scope for the current `fieldInsets` fix**, which solves the immediate problem (edge padding, full-width stretch). However, the weight-based approach (Option 1) is the natural next step and aligns with how web developers already think about responsive layouts.

The current fix does not block a future grid system — `fieldInsets` would remain valid as the outer padding, and a `weight` or `columnSpan` property would be added alongside it.
