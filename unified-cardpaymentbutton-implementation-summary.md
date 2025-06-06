# Unified CardPaymentButton Implementation Summary

## Overview
Successfully unified the `CardPaymentButton` to support both card form payments and stored instrument payments, eliminating the need for separate `StoredInstrumentPaymentButton`.

## Key Changes Made

### 1. CardPaymentButton Enhancements
- **Dual Mode Support**: Now supports both card form and stored instrument modes
- **Optional Properties**: Made `cardForm` optional and added `storedInstrument` as optional
- **Mode Detection**: Added `isStoredInstrumentMode` property for runtime mode detection
- **Dual Initializers**: 
  - Existing initializer for card form mode
  - New initializer for stored instrument mode
- **Dynamic Button Behavior**: Button tap behavior changes based on mode
- **Unified Styling**: Supports both `CardButtonStyle` and `StoredInstrumentButtonStyle`
- **Translation Support**: Handles translations for both modes

### 2. Factory Method Updates (Payrails.swift)
- **New Factory Method**: Added `createCardPaymentButton(storedInstrument:...)` for stored instrument mode
- **Backward Compatibility**: Existing card form factory method remains unchanged

### 3. StoredInstrumentView Updates
- **Uses Unified Button**: Now creates `CardPaymentButton` instead of `StoredInstrumentPaymentButton`
- **Delegate Updates**: Implements `PayrailsCardPaymentButtonDelegate` instead of the old delegate
- **Seamless Integration**: No breaking changes to StoredInstrumentView API

### 4. Deprecation Strategy
- **StoredInstrumentPaymentButton**: Marked as deprecated with migration guidance
- **PayrailsStoredInstrumentPaymentButtonDelegate**: Marked as deprecated
- **Clear Migration Path**: Deprecation messages provide examples of new usage

## Benefits

### 1. Simplified Architecture
- Single button component for all payment scenarios
- Reduced code duplication
- Easier maintenance

### 2. Consistent API
- Unified delegate pattern
- Same styling approach for both modes
- Consistent error handling

### 3. Backward Compatibility
- No breaking changes to existing card form usage
- Gradual migration path for stored instruments
- Existing code continues to work

### 4. Enhanced Flexibility
- Same component handles multiple payment types
- Easier to add new payment modes in future
- Consistent user experience

## Migration Guide

### For Card Form Users (No Changes Required)
```swift
// Existing usage continues to work
let button = Payrails.createCardPaymentButton(
    buttonStyle: style,
    translations: translations
)
```

### For Stored Instrument Users (Migration Required)
```swift
// Old approach (deprecated)
let oldButton = Payrails.StoredInstrumentPaymentButton(
    storedInstrument: instrument,
    session: session,
    translations: translations,
    style: style
)

// New unified approach
let newButton = Payrails.createCardPaymentButton(
    storedInstrument: instrument,
    buttonStyle: style,
    translations: translations,
    storedInstrumentTranslations: storedTranslations
)
```

## Technical Implementation Details

### Mode Detection
```swift
private var isStoredInstrumentMode: Bool {
    return storedInstrument != nil
}
```

### Payment Flow Routing
```swift
@objc private func payButtonTapped() {
    delegate?.onPaymentButtonClicked(self)
    
    if let cardForm = cardForm {
        // Card form mode: collect card data first
        cardForm.collectFields()
    } else if let storedInstrument = storedInstrument {
        // Stored instrument mode: direct payment
        pay(with: storedInstrument.type, storedInstrument: storedInstrument)
    }
}
```

### Unified Payment Execution
```swift
if let storedInstrument = storedInstrument ?? self?.storedInstrument {
    // Stored instrument payment
    result = await session.executePayment(
        withStoredInstrument: storedInstrument,
        presenter: presenter
    )
} else {
    // Card form payment
    let saveInstrument = self?.cardForm?.saveInstrument ?? false
    result = await session.executePayment(
        with: paymentType,
        saveInstrument: saveInstrument,
        presenter: presenter
    )
}
```

## Next Steps
1. Update stored instrument payment flow documentation
2. Update integration examples
3. Communicate deprecation timeline to developers
4. Monitor adoption and gather feedback
