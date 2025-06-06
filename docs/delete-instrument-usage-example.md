# DeleteInstrument API Usage Example

## Overview
The `deleteInstrument` method allows you to programmatically delete stored payment instruments using the PayrailsAPI. This method uses the existing `call` infrastructure and follows the same patterns as other API methods in the SDK.

## Basic Usage

```swift
import UIKit
import Payrails

class InstrumentManagementViewController: UIViewController {
    private var payrailsAPI: PayrailsAPI!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPayrailsAPI()
    }
    
    private func setupPayrailsAPI() {
        // Assuming you have a configured SDKConfig with instrumentDelete link
        guard let config = getSDKConfig() else {
            print("Error: SDKConfig not available")
            return
        }
        
        payrailsAPI = PayrailsAPI(config: config)
    }
    
    // Delete a specific instrument
    private func deleteInstrument(instrumentId: String) async {
        do {
            let response = try await payrailsAPI.deleteInstrument(instrumentId: instrumentId)
            
            if response.success {
                print("✅ Instrument deleted successfully")
                // Update UI to remove the deleted instrument
                await MainActor.run {
                    refreshInstrumentsList()
                }
            } else {
                print("❌ Failed to delete instrument")
                await MainActor.run {
                    showErrorAlert("Failed to delete payment method")
                }
            }
        } catch {
            print("❌ Error deleting instrument: \(error)")
            await MainActor.run {
                showErrorAlert("Error deleting payment method: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshInstrumentsList() {
        // Refresh your stored instruments list
        // This could involve calling StoredInstruments.refreshInstruments() 
        // or reloading your custom instruments list
    }
    
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

## Integration with StoredInstruments Component

```swift
import UIKit
import Payrails

class PaymentViewController: UIViewController {
    private var storedInstruments: Payrails.StoredInstruments!
    private var payrailsAPI: PayrailsAPI!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupComponents()
    }
    
    private func setupComponents() {
        // Setup PayrailsAPI for delete operations
        guard let config = getSDKConfig() else { return }
        payrailsAPI = PayrailsAPI(config: config)
        
        // Setup StoredInstruments component
        storedInstruments = Payrails.createStoredInstruments()
        storedInstruments.delegate = self
        storedInstruments.presenter = self
        
        // Add to view hierarchy
        view.addSubview(storedInstruments)
        setupConstraints()
    }
    
    private func setupConstraints() {
        storedInstruments.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            storedInstruments.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            storedInstruments.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            storedInstruments.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    // Add delete functionality to stored instruments
    private func showDeleteConfirmation(for instrument: StoredInstrument) {
        let alert = UIAlertController(
            title: "Delete Payment Method",
            message: "Are you sure you want to delete this payment method?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            Task {
                await self.deleteInstrument(instrumentId: instrument.id)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func deleteInstrument(instrumentId: String) async {
        do {
            let response = try await payrailsAPI.deleteInstrument(instrumentId: instrumentId)
            
            await MainActor.run {
                if response.success {
                    // Refresh the stored instruments list
                    storedInstruments.refreshInstruments()
                    showSuccessMessage("Payment method deleted successfully")
                } else {
                    showErrorAlert("Failed to delete payment method")
                }
            }
        } catch {
            await MainActor.run {
                showErrorAlert("Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func showSuccessMessage(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PayrailsStoredInstrumentsDelegate
extension PaymentViewController: PayrailsStoredInstrumentsDelegate {
    func storedInstruments(_ view: Payrails.StoredInstruments, didSelectInstrument instrument: StoredInstrument) {
        print("Selected instrument: \(instrument.id)")
    }
    
    func storedInstruments(_ view: Payrails.StoredInstruments, didCompletePaymentForInstrument instrument: StoredInstrument) {
        print("Payment completed for instrument: \(instrument.id)")
    }
    
    func storedInstruments(_ view: Payrails.StoredInstruments, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError) {
        print("Payment failed for instrument: \(instrument.id), error: \(error)")
    }
    
    // Custom method to handle long press for delete (if you implement this)
    func storedInstruments(_ view: Payrails.StoredInstruments, didLongPressInstrument instrument: StoredInstrument) {
        showDeleteConfirmation(for: instrument)
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

## Error Handling

The `deleteInstrument` method can throw various errors:

```swift
private func handleDeleteInstrument(instrumentId: String) async {
    do {
        let response = try await payrailsAPI.deleteInstrument(instrumentId: instrumentId)
        
        if response.success {
            print("✅ Instrument deleted successfully")
        } else {
            print("❌ Server returned success: false")
        }
        
    } catch PayrailsError.missingData(let message) {
        print("❌ Missing data error: \(message)")
        // Handle cases where instrumentDelete link is not configured
        
    } catch PayrailsError.authenticationError {
        print("❌ Authentication error - check your token")
        // Handle authentication issues
        
    } catch {
        print("❌ Unexpected error: \(error)")
        // Handle other errors (network, parsing, etc.)
    }
}
```

## Requirements

### SDK Configuration
Your SDKConfig must include the `instrumentDelete` link:

```json
{
  "token": "your-token",
  "holderReference": "holder-ref",
  "links": {
    "instrumentDelete": {
      "href": "https://api.payrails.com/instruments/:instrumentId",
      "method": "DELETE"
    }
  }
}
```

### URL Pattern
The `instrumentDelete` link should include `:instrumentId` as a placeholder that will be replaced with the actual instrument ID.

## API Response

The method returns a `DeleteInstrumentResponse` object:

```swift
struct DeleteInstrumentResponse: Decodable {
    let success: Bool
}
```

## Best Practices

1. **Always confirm deletion**: Show a confirmation dialog before deleting instruments
2. **Handle errors gracefully**: Provide clear error messages to users
3. **Refresh UI**: Update the instruments list after successful deletion
4. **Use async/await**: The method is async, so call it from an async context
5. **Check response**: Always check the `success` field in the response

## Notes

- The method uses the existing `call` infrastructure from PayrailsAPI
- It supports the DELETE HTTP method
- The instrument ID is automatically inserted into the URL template
- The method follows the same error handling patterns as other PayrailsAPI methods
- No request body is sent (as per the web SDK implementation)
        present(alert, animated: true)
    }
    
    private func deleteInstrument(instrumentId: String) async {
        do {
            let response = try await payrailsAPI.deleteInstrument(instrumentId: instrumentId)
            
            await MainActor.run {
                if response.success {
                    // Refresh the stored instruments list
                    storedInstruments.refreshInstruments()
                    showSuccessMessage("Payment method deleted successfully")
                } else {
                    showErrorAlert("Failed to delete payment method")
                }
            }
        } catch {
            await MainActor.run {
                showErrorAlert("Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func showSuccessMessage(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PayrailsStoredInstrumentsDelegate
extension PaymentViewController: PayrailsStoredInstrumentsDelegate {
    func storedInstruments(_ view: Payrails.StoredInstruments, didSelectInstrument instrument: StoredInstrument) {
        print("Selected instrument: \(instrument.id)")
    }
    
    func storedInstruments(_ view: Payrails.StoredInstruments, didCompletePaymentForInstrument instrument: StoredInstrument) {
        print("Payment completed for instrument: \(instrument.id)")
    }
    
    func storedInstruments(_ view: Payrails.StoredInstruments, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError) {
        print("Payment failed for instrument: \(instrument.id), error: \(error)")
    }
    
    // Custom method to handle long press for delete (if you implement this)
    func storedInstruments(_ view: Payrails.StoredInstruments, didLongPressInstrument instrument: StoredInstrument) {
        showDeleteConfirmation(for: instrument)
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

## Error Handling

The `deleteInstrument` method can throw various errors:

```swift
private func handleDeleteInstrument(instrumentId: String) async {
    do {
        let response = try await payrailsAPI.deleteInstrument(instrumentId: instrumentId)
        
        if response.success {
            print("✅ Instrument deleted successfully")
        } else {
            print("❌ Server returned success: false")
        }
        
    } catch PayrailsError.missingData(let message) {
        print("❌ Missing data error: \(message)")
        // Handle cases where instrumentDelete link is not configured
        
    } catch PayrailsError.authenticationError {
        print("❌ Authentication error - check your token")
        // Handle authentication issues
        
    } catch {
        print("❌ Unexpected error: \(error)")
        // Handle other errors (network, parsing, etc.)
    }
}
```

## Requirements

### SDK Configuration
Your SDKConfig must include the `instrumentDelete` link:

```json
{
  "token": "your-token",
  "holderReference": "holder-ref",
  "links": {
    "instrumentDelete": {
      "href": "https://api.payrails.com/instruments/:instrumentId",
      "method": "DELETE"
    }
  }
}
```

### URL Pattern
The `instrumentDelete` link should include `:instrumentId` as a placeholder that will be replaced with the actual instrument ID.

## API Response

The method returns a `DeleteInstrumentResponse` object:

```swift
struct DeleteInstrumentResponse: Decodable {
    let success: Bool
}
```

## Best Practices

1. **Always confirm deletion**: Show a confirmation dialog before deleting instruments
2. **Handle errors gracefully**: Provide clear error messages to users
3. **Refresh UI**: Update the instruments list after successful deletion
4. **Use async/await**: The method is async, so call it from an async context
5. **Check response**: Always check the `success` field in the response

## Notes

- The method uses the existing `call` infrastructure from PayrailsAPI
- It supports the DELETE HTTP method
- The instrument ID is automatically inserted into the URL template
- The method follows the same error handling patterns as other PayrailsAPI methods
- No request body is sent (as per the web SDK implementation)
