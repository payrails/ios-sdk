# Get Stored Instruments Example

## Overview
This example demonstrates how to use the new `Payrails.getStoredInstruments()` method to retrieve all stored payment instruments.

## Basic Usage

```swift
import UIKit
import Payrails

class PaymentViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPayrails()
    }
    
    private func setupPayrails() {
        // Initialize Payrails session first
        Task {
            do {
                let session = try await Payrails.createSession(with: configuration)
                
                // Now you can get stored instruments
                displayStoredInstruments()
            } catch {
                print("Failed to initialize Payrails: \(error)")
            }
        }
    }
    
    private func displayStoredInstruments() {
        // Get all stored instruments (both cards and PayPal)
        let allInstruments = Payrails.getStoredInstruments()
        
        print("Found \(allInstruments.count) stored instruments:")
        
        for instrument in allInstruments {
            switch instrument.type {
            case .card:
                print("💳 Card: \(instrument.description ?? "Unknown") - ID: \(instrument.id)")
            case .payPal:
                print("🅿️ PayPal: \(instrument.email ?? "Unknown") - ID: \(instrument.id)")
            default:
                print("🔧 Other: \(instrument.description ?? "Unknown") - ID: \(instrument.id)")
            }
        }
        
        // Filter by type if needed
        let cardInstruments = allInstruments.filter { $0.type == .card }
        let paypalInstruments = allInstruments.filter { $0.type == .payPal }
        
        print("Cards: \(cardInstruments.count), PayPal: \(paypalInstruments.count)")
    }
}
```

## Advanced Usage with Delete Functionality

```swift
class AdvancedPaymentViewController: UIViewController {
    
    private func manageStoredInstruments() {
        // Get all stored instruments
        let instruments = Payrails.getStoredInstruments()
        
        guard !instruments.isEmpty else {
            print("No stored instruments found")
            return
        }
        
        print("Managing \(instruments.count) stored instruments:")
        
        // Display instruments with options
        for (index, instrument) in instruments.enumerated() {
            let typeIcon = instrument.type == .card ? "💳" : "🅿️"
            let description = instrument.description ?? instrument.email ?? "Unknown"
            print("\(index + 1). \(typeIcon) \(description)")
        }
        
        // Example: Delete the first instrument
        if let firstInstrument = instruments.first {
            deleteInstrument(firstInstrument)
        }
    }
    
    private func deleteInstrument(_ instrument: StoredInstrument) {
        let typeIcon = instrument.type == .card ? "💳" : "🅿️"
        let description = instrument.description ?? instrument.email ?? "Unknown"
        
        let alert = UIAlertController(
            title: "Delete Payment Method",
            message: "Delete \(typeIcon) \(description)?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            Task {
                await self.performDelete(instrument)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func performDelete(_ instrument: StoredInstrument) async {
        do {
            let response = try await Payrails.deleteInstrument(instrumentId: instrument.id)
            
            await MainActor.run {
                if response.success {
                    print("✅ Instrument deleted successfully")
                    
                    // Get updated list
                    let updatedInstruments = Payrails.getStoredInstruments()
                    print("Updated count: \(updatedInstruments.count) instruments")
                    
                    // Refresh your UI here
                    self.refreshUI()
                } else {
                    print("❌ Failed to delete instrument")
                }
            }
        } catch {
            await MainActor.run {
                print("❌ Error deleting instrument: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshUI() {
        // Refresh your UI components here
        // For example, if you have a table view or collection view showing instruments
    }
}
```

## Using with UI Components

```swift
class UIIntegratedViewController: UIViewController {
    private var storedInstruments: Payrails.StoredInstruments?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStoredInstrumentsUI()
    }
    
    private func setupStoredInstrumentsUI() {
        // Create the UI component
        storedInstruments = Payrails.createStoredInstruments(
            showDeleteButton: true
        )
        storedInstruments?.delegate = self
        
        // Add to view
        if let storedInstruments = storedInstruments {
            view.addSubview(storedInstruments)
            // Setup constraints...
        }
        
        // Log current instruments
        logCurrentInstruments()
    }
    
    private func logCurrentInstruments() {
        let instruments = Payrails.getStoredInstruments()
        print("UI Component will display \(instruments.count) instruments")
        
        for instrument in instruments {
            print("- \(instrument.type.rawValue): \(instrument.id)")
        }
    }
}

extension UIIntegratedViewController: PayrailsStoredInstrumentsDelegate {
    func storedInstruments(_ view: Payrails.StoredInstruments, didSelectInstrument instrument: StoredInstrument) {
        print("Selected: \(instrument.id)")
    }
    
    func storedInstruments(_ view: Payrails.StoredInstruments, didCompletePaymentForInstrument instrument: StoredInstrument) {
        print("Payment completed with: \(instrument.id)")
    }
    
    func storedInstruments(_ view: Payrails.StoredInstruments, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError) {
        print("Payment failed: \(error.localizedDescription)")
    }
    
    func storedInstruments(_ view: Payrails.StoredInstruments, didRequestDeleteInstrument instrument: StoredInstrument) {
        Task {
            do {
                let response = try await Payrails.deleteInstrument(instrumentId: instrument.id)
                if response.success {
                    await MainActor.run {
                        // Refresh the UI component
                        self.storedInstruments?.refreshInstruments()
                        
                        // Log updated count
                        let updatedCount = Payrails.getStoredInstruments().count
                        print("After deletion: \(updatedCount) instruments remaining")
                    }
                }
            } catch {
                print("Delete failed: \(error.localizedDescription)")
            }
        }
    }
}
```

## Key Features

### Method Signature
```swift
static func getStoredInstruments() -> [StoredInstrument]
```

### Behavior
- **Returns all instruments**: Combines both card and PayPal stored instruments
- **No session required check**: Returns empty array if no session is active
- **Automatic logging**: Logs the count of retrieved instruments
- **Thread-safe**: Can be called from any thread

### Return Value
- Returns an array of `StoredInstrument` objects
- Empty array if no session is active or no instruments are stored
- Includes both enabled card and PayPal instruments

### Use Cases
1. **Display instrument counts**: Show users how many payment methods they have saved
2. **Custom UI creation**: Build your own instrument selection interface
3. **Validation**: Check if instruments exist before showing payment options
4. **Analytics**: Track instrument usage patterns
5. **Bulk operations**: Perform operations on multiple instruments

## Best Practices

1. **Check for empty results**: Always handle the case where no instruments are returned
2. **Combine with delete operations**: Use together with `deleteInstrument` for management features
3. **Refresh after changes**: Call again after delete operations to get updated counts
4. **Filter by type**: Use array filtering to separate cards from PayPal instruments
5. **Error handling**: The method won't throw errors but may return empty arrays

## Requirements

- Active Payrails session (if no session, returns empty array)
- Properly configured SDK with stored instruments available
- No additional permissions or setup required

## Notes

- This method provides read-only access to stored instruments
- The returned instruments are the same objects used by the UI components
- Changes to the underlying data (like deletions) will be reflected in subsequent calls
- The method is synchronous and returns immediately
