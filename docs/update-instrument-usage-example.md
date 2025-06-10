# Update Instrument Usage Example

This document demonstrates how to use the `updateInstrument` method in the Payrails iOS SDK.

## Overview

The `updateInstrument` method allows you to update properties of a stored payment instrument, such as enabling/disabling it, setting it as default, or updating metadata.

## Usage

### Basic Usage

```swift
import Payrails

// Initialize Payrails session first
let configuration = Payrails.Configuration(
    initData: initData,
    option: .init(env: .sandbox)
)

do {
    let session = try await Payrails.createSession(with: configuration)
    
    // Create update body with desired changes
    let updateBody = UpdateInstrumentBody(
        status: "enabled",           // Enable the instrument
        default: true,              // Set as default payment method
        merchantReference: "ref123" // Update merchant reference
    )
    
    // Update the instrument
    let response = try await Payrails.updateInstrument(
        instrumentId: "instrument_id_here",
        body: updateBody
    )
    
    print("Instrument updated successfully:")
    print("ID: \(response.id)")
    print("Status: \(response.status)")
    print("Payment Method: \(response.paymentMethod)")
    
} catch {
    print("Failed to update instrument: \(error)")
}
```

### Available Update Fields

The `UpdateInstrumentBody` supports the following optional fields:

- `status`: Set to "enabled" or "disabled"
- `networkTransactionReference`: Update network transaction reference
- `merchantReference`: Update merchant reference
- `paymentMethod`: Update payment method ("applepay", "card", "googlepay", "paypal")
- `default`: Set as default payment instrument (true/false)

### Example: Disable an Instrument

```swift
let updateBody = UpdateInstrumentBody(status: "disabled")

do {
    let response = try await Payrails.updateInstrument(
        instrumentId: "instrument_123",
        body: updateBody
    )
    print("Instrument disabled successfully")
} catch {
    print("Failed to disable instrument: \(error)")
}
```

### Example: Set as Default Payment Method

```swift
let updateBody = UpdateInstrumentBody(default: true)

do {
    let response = try await Payrails.updateInstrument(
        instrumentId: "instrument_123",
        body: updateBody
    )
    print("Instrument set as default")
} catch {
    print("Failed to set as default: \(error)")
}
```

### Response Structure

The `UpdateInstrumentResponse` contains:

- `id`: Instrument ID
- `createdAt`: Creation timestamp
- `holderId`: Holder ID
- `paymentMethod`: Payment method type
- `status`: Current status
- `data`: Instrument data (card details, etc.)
- `fingerprint`: Instrument fingerprint (optional)
- `futureUsage`: Future usage settings (optional)

## Error Handling

The method throws `PayrailsError` in case of failures:

- Missing or invalid `instrumentUpdate` link in SDK configuration
- Network errors
- Authentication errors
- Invalid instrument ID

## Requirements

- Active Payrails session must be initialized
- Valid instrument ID
- Proper SDK configuration with `instrumentUpdate` link
