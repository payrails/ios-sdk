# Delete Instrument with UI Integration Example

## Overview
This example demonstrates how to use the new delete button functionality in StoredInstrumentView and StoredInstruments components, along with the `deleteInstrument` API method.

## Using Built-in Delete Button

### Basic Usage with Delete Button

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
        
        // Setup StoredInstruments component with delete button enabled
        storedInstruments = Payrails.createStoredInstruments(
            showDeleteButton: true  // Enable delete button with trash emoji 🗑️
        )
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
    
    // Handle delete button taps
    func storedInstruments(_ view: Payrails.StoredInstruments, didRequestDeleteInstrument instrument: StoredInstrument) {
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

## Custom Delete Button Styling

```swift
class CustomStyledPaymentViewController: UIViewController {
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
        
        // Create custom delete button style
        let customDeleteStyle = DeleteButtonStyle(
            backgroundColor: .systemRed,
            textColor: .white,
            font: .systemFont(ofSize: 16),
            cornerRadius: 6,
            size: CGSize(width: 36, height: 36)
        )
        
        // Create custom style with delete button styling
        let customStyle = StoredInstrumentsStyle(
            backgroundColor: .systemBackground,
            itemBackgroundColor: .secondarySystemBackground,
            selectedItemBackgroundColor: .systemBlue.withAlphaComponent(0.1),
            labelTextColor: .label,
            labelFont: .systemFont(ofSize: 16, weight: .medium),
            itemCornerRadius: 12,
            itemSpacing: 12,
            itemPadding: UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20),
            buttonStyle: .defaultStyle,
            deleteButtonStyle: customDeleteStyle
        )
        
        // Setup StoredInstruments component with custom styling and delete button
        storedInstruments = Payrails.createStoredInstruments(
            style: customStyle,
            showDeleteButton: true
        )
        storedInstruments.delegate = self
        storedInstruments.presenter = self
        
        // Add to view hierarchy
        view.addSubview(storedInstruments)
        setupConstraints()
    }
    
    // ... rest of the implementation same as above
}
```

## Individual StoredInstrumentView with Delete Button

```swift
class IndividualInstrumentViewController: UIViewController {
    private var instrumentView: Payrails.StoredInstrumentView!
    private var payrailsAPI: PayrailsAPI!
    private let instrument: StoredInstrument
    
    init(instrument: StoredInstrument) {
        self.instrument = instrument
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupComponents()
    }
    
    private func setupComponents() {
        // Setup PayrailsAPI for delete operations
        guard let config = getSDKConfig() else { return }
        payrailsAPI = PayrailsAPI(config: config)
        
        // Create individual StoredInstrumentView with delete button
        instrumentView = Payrails.createStoredInstrumentView(
            instrument: instrument,
            showDeleteButton: true
        )
        instrumentView.delegate = self
        instrumentView.presenter = self
        
        // Add to view hierarchy
        view.addSubview(instrumentView)
        setupConstraints()
    }
    
    private func setupConstraints() {
        instrumentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            instrumentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            instrumentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            instrumentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func deleteInstrument(instrumentId: String) async {
        do {
            let response = try await payrailsAPI.deleteInstrument(instrumentId: instrumentId)
            
            await MainActor.run {
                if response.success {
                    // Navigate back or update UI
                    navigationController?.popViewController(animated: true)
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
}

// MARK: - PayrailsStoredInstrumentViewDelegate
extension IndividualInstrumentViewController: PayrailsStoredInstrumentViewDelegate {
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didSelectInstrument instrument: StoredInstrument) {
        print("Selected instrument: \(instrument.id)")
    }
    
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didDeselectInstrument instrument: StoredInstrument) {
        print("Deselected instrument: \(instrument.id)")
    }
    
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didCompletePaymentForInstrument instrument: StoredInstrument) {
        print("Payment completed for instrument: \(instrument.id)")
    }
    
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError) {
        print("Payment failed for instrument: \(instrument.id), error: \(error)")
    }
    
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didRequestDeleteInstrument instrument: StoredInstrument) {
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
}
```

## Delete Button Features

### Visual Design
- **Emoji**: Uses 🗑️ trash can emoji by default
- **Styling**: Fully customizable via `DeleteButtonStyle`
- **Position**: Positioned on the right side of each instrument row
- **Size**: Default 32x32 points, customizable

### Behavior
- **Optional**: Only shown when `showDeleteButton: true`
- **Confirmation**: Triggers delegate method for confirmation handling
- **Layout**: Automatically adjusts label width to accommodate delete button

### Customization Options

```swift
let deleteStyle = DeleteButtonStyle(
    backgroundColor: .systemRed,      // Button background color
    textColor: .white,                // Emoji/text color
    font: .systemFont(ofSize: 14),    // Font for the emoji
    cornerRadius: 4,                  // Button corner radius
    size: CGSize(width: 32, height: 32) // Button size
)
```

## Best Practices

1. **Always show confirmation**: Never delete immediately on button tap
2. **Provide feedback**: Show success/error messages to users
3. **Refresh UI**: Update the instruments list after successful deletion
4. **Handle errors gracefully**: Provide clear error messages
5. **Consider accessibility**: The emoji button is accessible by default

## Requirements

- iOS SDK with `deleteInstrument` API method implemented
- SDK configuration must include `instrumentDelete` link
- Proper error handling for network and API errors
- UI updates must be performed on the main thread

## Notes

- The delete button is completely optional and disabled by default
- The button integrates seamlessly with existing StoredInstruments styling
- The delete functionality works with both individual views and collections
- The implementation follows the same patterns as other SDK components
