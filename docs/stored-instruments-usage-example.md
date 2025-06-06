# StoredInstruments Component Usage Example

## Overview
The StoredInstruments component displays a list of stored payment instruments (both card and PayPal) with an accordion-style interface. Users can tap on an instrument to reveal its payment button, and only one payment button is visible at a time.

## Basic Usage

```swift
import UIKit
import Payrails

class PaymentViewController: UIViewController {
    private var storedInstruments: Payrails.StoredInstruments!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStoredInstruments()
    }
    
    private func setupStoredInstruments() {
        // Create the stored instruments component
        storedInstruments = Payrails.createStoredInstruments()
        storedInstruments.delegate = self
        storedInstruments.presenter = self
        
        // Add to view hierarchy
        view.addSubview(storedInstruments)
        storedInstruments.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            storedInstruments.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            storedInstruments.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            storedInstruments.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
}

// MARK: - PayrailsStoredInstrumentsDelegate
extension PaymentViewController: PayrailsStoredInstrumentsDelegate {
    func storedInstruments(_ view: Payrails.StoredInstruments, didSelectInstrument instrument: StoredInstrument) {
        print("Selected instrument: \(instrument.id)")
    }
    
    func storedInstruments(_ view: Payrails.StoredInstruments, didCompletePaymentForInstrument instrument: StoredInstrument) {
        print("Payment completed for instrument: \(instrument.id)")
        // Handle successful payment
    }
    
    func storedInstruments(_ view: Payrails.StoredInstruments, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError) {
        print("Payment failed for instrument: \(instrument.id), error: \(error)")
        // Handle payment failure
    }
}

// MARK: - PaymentPresenter
extension PaymentViewController: PaymentPresenter {
    var encryptedCardData: String? {
        get { return nil }
        set { }
    }
    
    func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
}
```

## Custom Styling

```swift
private func setupStoredInstrumentsWithCustomStyle() {
    // Create custom style
    let customStyle = StoredInstrumentsStyle(
        backgroundColor: .systemBackground,
        itemBackgroundColor: .secondarySystemBackground,
        selectedItemBackgroundColor: .systemBlue.withAlphaComponent(0.1),
        labelTextColor: .label,
        labelFont: .systemFont(ofSize: 16, weight: .medium),
        itemCornerRadius: 12,
        itemSpacing: 12,
        itemPadding: UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20),
        buttonStyle: StoredInstrumentButtonStyle(
            backgroundColor: .systemBlue,
            textColor: .white,
            font: .systemFont(ofSize: 16, weight: .semibold),
            cornerRadius: 8,
            height: 48
        )
    )
    
    // Create custom translations
    let customTranslations = StoredInstrumentsTranslations(
        cardPrefix: "Credit Card",
        paypalPrefix: "PayPal Account",
        buttonTranslations: StoredInstrumentButtonTranslations(
            label: "Pay Now",
            processingLabel: "Processing Payment..."
        )
    )
    
    // Create component with custom style and translations
    storedInstruments = Payrails.createStoredInstruments(
        style: customStyle,
        translations: customTranslations
    )
}
```

## Features

### Display Format
- **Card instruments**: Shows "Card ending in [suffix]" or displayName if available
- **PayPal instruments**: Shows "PayPal - [email]"

### Accordion Behavior
- Tap on any instrument to show its payment button
- Only one payment button is visible at a time
- Tap on the same instrument again to hide the payment button
- Selected instrument gets highlighted background

### Payment Flow
1. User taps on a stored instrument → payment button appears
2. User taps payment button → payment process starts
3. Payment button shows loading state during processing
4. Delegate methods are called based on payment result

### Refresh Functionality
```swift
// Refresh the list of stored instruments (e.g., after adding a new one)
storedInstruments.refreshInstruments()
```

## Requirements
- Payrails session must be initialized before creating StoredInstruments
- PaymentPresenter must be set for payment functionality
- Delegate should be set to handle payment events

## Notes
- If no stored instruments are available, the component renders nothing (empty view)
- The component automatically fetches both card and PayPal stored instruments
- Payment buttons use the same payment flow as other Payrails payment components
