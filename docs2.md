# Payrails iOS SDK Documentation

## Introduction

Payrails iOS SDK provides you with the building blocks to create a seamless checkout experience for your customers. The SDK offers a variety of UI components and payment methods, including card payments, Apple Pay, PayPal, and redirect-based payment methods.

## Installation

### Minimum Requirements

- iOS 14.0 or later
- Swift 5.0 or later

### Using CocoaPods

Add the following line to your `Podfile`:

```ruby
pod 'Payrails/Checkout'
```

Then run:

```bash
pod install
```

### Using Swift Package Manager

1. In Xcode, go to File > Add Packages...
2. Enter the repository URL: `https://github.com/payrails/ios-sdk`
3. Select the `PayrailsCheckout` product

The SDK includes dependencies for PayPal's checkout SDK and Payrails' Client-Side Encryption (CSE) library. These are managed automatically by CocoaPods or Swift Package Manager.

### Enabling Apple Pay Capability

To use Apple Pay in your app:

1. Add the Apple Pay capability in your Xcode project's "Signing & Capabilities" tab for your app target
2. Configure a Merchant ID with Apple

## SDK Initialization

Before using any of the SDK's features, you need to initialize it by creating a `Payrails.Session` object.

### Using Async/Await

```swift
import Payrails

// Create initialization data with version and base64 data from your backend
let initData = Payrails.InitData(
    version: "your_sdk_version_from_backend",
    data: "your_base64_data_from_backend"
)

// Configure environment options
let options = Payrails.Options(env: .dev) // Use .prod for production

// Create configuration
let configuration = Payrails.Configuration(
    initData: initData,
    option: options
)

// Initialize the SDK
do {
    let session = try await Payrails.configure(with: configuration)
    // Store the session for later use
    self.payrailsSession = session
} catch {
    // Handle initialization error
    print("Payrails SDK initialization failed: \(error)")
}
```

### Using Callback

```swift
import Payrails

// Create initialization data with version and base64 data from your backend
let initData = Payrails.InitData(
    version: "your_sdk_version_from_backend",
    data: "your_base64_data_from_backend"
)

// Configure environment options
let options = Payrails.Options(env: .dev) // Use .prod for production

// Create configuration
let configuration = Payrails.Configuration(
    initData: initData,
    option: options
)

// Initialize the SDK
Payrails.configure(with: configuration) { [weak self] result in
    switch result {
    case .success(let session):
        // Store the session for later use
        self?.payrailsSession = session
    case .failure(let error):
        // Handle initialization error
        print("Payrails SDK initialization failed: \(error)")
    }
}
```

## Payment Flow Presenter

Many payment methods require presenting additional UI screens (such as 3D Secure authentication, PayPal login, or redirect pages). The SDK uses the `PaymentPresenter` protocol to handle these presentations.

### Implementing PaymentPresenter

Your view controller that initiates payments should conform to the `PaymentPresenter` protocol:

```swift
import Payrails
import UIKit

class CheckoutViewController: UIViewController, PaymentPresenter {
    
    // MARK: - PaymentPresenter Protocol
    
    // This method will be called by the SDK when it needs to present a view controller
    // (e.g., for 3DS authentication or PayPal login)
    func presentPayment(_ viewController: UIViewController) {
        // Present the view controller modally
        self.present(viewController, animated: true)
    }
    
    // This property is used by the SDK to pass encrypted card data
    // You typically don't need to interact with it directly
    var encryptedCardData: String?
}
```

You must assign an object conforming to `PaymentPresenter` to the `presenter` property of UI payment elements (like `CardPaymentButton`, `ApplePayButton`, etc.) before initiating a payment.

## UI Elements

The SDK provides several UI components for different payment methods. All UI elements are created using static factory methods on the `Payrails` class after SDK initialization.

### Card Form

The Card Form (`Payrails.CardForm`) is a `UIView` subclass that provides a secure and customizable form for collecting card payment details.

#### Creating a Card Form

```swift
// Create a card form with default configuration
let cardForm = Payrails.createCardForm()

// Or with custom configuration
let config = CardFormConfig(
    showNameField: true,
    showSaveInstrument: false,
    styles: customStyles, // Optional CardFormStylesConfig
    translations: customTranslations // Optional CardTranslations
)
let cardForm = Payrails.createCardForm(config: config, showSaveInstrument: true)

// Add the card form to your view hierarchy
view.addSubview(cardForm)
// Set up constraints...
```

#### Key Properties and Methods

- `delegate: PayrailsCardFormDelegate?`: Assign an object to receive callbacks when card data is collected or an error occurs.
- `saveInstrument: Bool`: Get or set whether the "save card" option is enabled (if the toggle is visible).
- `collectFields()`: Call this method to trigger the collection and encryption of the card data. The result will be delivered via the delegate methods.

#### Styling the Card Form

The `CardFormConfig` object allows you to customize the appearance of the card form:

```swift
// Create custom styles for input fields
let cardNumberStyle = CardFieldSpecificStyles(
    base: CardStyle(
        textColor: .black,
        font: UIFont.systemFont(ofSize: 16),
        borderColor: .lightGray,
        borderWidth: 1,
        cornerRadius: 8,
        padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    ),
    focus: CardStyle(borderColor: .blue),
    completed: CardStyle(borderColor: .green),
    invalid: CardStyle(borderColor: .red)
)

// Create a styles configuration
let stylesConfig = CardFormStylesConfig(
    wrapperStyle: CardWrapperStyle(
        backgroundColor: .white,
        borderColor: .gray,
        borderWidth: 1,
        cornerRadius: 8,
        padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    ),
    errorTextStyle: CardStyle(textColor: .red, font: UIFont.systemFont(ofSize: 12)),
    allInputFieldStyles: CardFieldSpecificStyles.defaultStyle, // Base style for all fields
    inputFieldStyles: [.CARD_NUMBER: cardNumberStyle], // Override for specific fields
    labelStyles: [.CARD_NUMBER: CardStyle(textColor: .darkGray, font: UIFont.systemFont(ofSize: 14))]
)
```

#### Customizing Text and Translations

The `CardTranslations` object allows you to customize the text displayed in the card form:

```swift
let translations = CardTranslations(
    placeholders: CardTranslations.Placeholders(values: [
        .CARD_NUMBER: "Card Number",
        .CVV: "Security Code",
        .EXPIRATION_DATE: "MM/YY",
        .CARDHOLDER_NAME: "Name on Card"
    ]),
    labels: CardTranslations.Labels(
        values: [
            .CARD_NUMBER: "Card Number",
            .CVV: "CVV"
        ],
        saveInstrument: "Save this card for future payments"
    ),
    error: CardTranslations.ErrorMessages(values: [
        .CARD_NUMBER: "Please enter a valid card number",
        .CVV: "Please enter a valid security code",
        .EXPIRATION_DATE: "Please enter a valid expiration date"
    ])
)
```

#### Example Usage

```swift
class PaymentViewController: UIViewController, PayrailsCardFormDelegate {
    
    var cardForm: Payrails.CardForm?
    
    func setupCardForm() {
        // Create the card form
        self.cardForm = Payrails.createCardForm(showSaveInstrument: true)
        guard let cardForm = self.cardForm else { return }
        
        // Set delegate
        cardForm.delegate = self
        
        // Add to view hierarchy
        view.addSubview(cardForm)
        
        // Set up constraints
        cardForm.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cardForm.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cardForm.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardForm.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - PayrailsCardFormDelegate
    
    func cardForm(_ view: Payrails.CardForm, didCollectCardData data: String) {
        print("Card data collected successfully")
        // Proceed with payment using the encrypted data
    }
    
    func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error) {
        print("Failed to collect card data: \(error.localizedDescription)")
        // Handle the error
    }
}
```

### Card Payment Button

The Card Payment Button (`Payrails.CardPaymentButton`) is a button that works with a `CardForm` to initiate and manage the card payment process.

#### Creating a Card Payment Button

```swift
// First, create a card form (as shown in the previous section)
let cardForm = Payrails.createCardForm()

// Then create a card payment button
let buttonTranslations = CardPaymenButtonTranslations(label: "Pay Now")
let buttonStyle = CardButtonStyle(
    backgroundColor: .systemBlue,
    textColor: .white,
    font: UIFont.systemFont(ofSize: 16, weight: .semibold),
    cornerRadius: 8
)

let payButton = Payrails.createCardPaymentButton(
    buttonStyle: buttonStyle,
    translations: buttonTranslations
)

// Add the button to your view hierarchy
view.addSubview(payButton)
// Set up constraints...
```

#### Key Properties

- `delegate: PayrailsCardPaymentButtonDelegate?`: Assign an object to receive notifications about button taps and payment outcomes.
- `presenter: PaymentPresenter?`: **Required.** Assign a view controller that conforms to `PaymentPresenter` to handle UI presentations during the payment flow.

#### Interaction Flow

1. User fills in the card form.
2. User taps the card payment button.
3. The button tells the card form to collect and encrypt the card data.
4. If successful, the button automatically initiates the payment process.
5. Results are communicated via the `PayrailsCardPaymentButtonDelegate`.

#### Example Usage

```swift
class PaymentViewController: UIViewController, PayrailsCardFormDelegate, PayrailsCardPaymentButtonDelegate, PaymentPresenter {
    
    var cardForm: Payrails.CardForm?
    var payButton: Payrails.CardPaymentButton?
    
    func setupPaymentUI() {
        // Create card form
        self.cardForm = Payrails.createCardForm(showSaveInstrument: true)
        
        // Create payment button
        let buttonTranslations = CardPaymenButtonTranslations(label: "Pay Now")
        self.payButton = Payrails.createCardPaymentButton(
            buttonStyle: nil, // Use default style
            translations: buttonTranslations
        )
        
        guard let cardForm = self.cardForm, let payButton = self.payButton else { return }
        
        // Set up delegates and presenter
        cardForm.delegate = self
        payButton.delegate = self
        payButton.presenter = self // Self conforms to PaymentPresenter
        
        // Add to view hierarchy
        view.addSubview(cardForm)
        view.addSubview(payButton)
        
        // Set up constraints...
    }
    
    // MARK: - PayrailsCardPaymentButtonDelegate
    
    func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton) {
        print("Payment button clicked")
    }
    
    func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton) {
        print("Payment authorized successfully")
        // Navigate to success screen
    }
    
    func onAuthorizeFailed(_ button: Payrails.CardPaymentButton) {
        print("Payment authorization failed")
        // Show error message
    }
    
    // MARK: - PaymentPresenter
    
    func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
    
    var encryptedCardData: String?
}
```

### Apple Pay Button

The Apple Pay Button (`Payrails.ApplePayButton` or `Payrails.ApplePayButtonWithToggle`) provides an Apple Pay payment option.

#### Creating an Apple Pay Button

```swift
// Create an Apple Pay button
let applePayButton = Payrails.createApplePayButton(
    type: .buy, // PKPaymentButtonType
    style: .black, // PKPaymentButtonStyle
    showSaveInstrument: false // Set to true to show a "Save instrument" toggle
)

// Add the button to your view hierarchy
view.addSubview(applePayButton)
// Set up constraints...
```

#### Key Properties

- `delegate: PayrailsApplePayButtonDelegate?`: Assign an object to receive notifications about button taps and payment outcomes.
- `presenter: PaymentPresenter?`: **Required.** Assign a view controller that conforms to `PaymentPresenter`.
- `saveInstrument: Bool`: Set to `true` to save the payment instrument after a successful transaction. If `showSaveInstrument` was `true` during creation, this property reflects the toggle's state.
- `isEnabled: Bool`: Controls the enabled state of the button.

#### Apple Pay Button with Toggle

If you pass `showSaveInstrument: true` to `createApplePayButton()`, it returns a `Payrails.ApplePayButtonWithToggle` that includes a switch for the user to choose whether to save their payment details.

#### Example Usage

```swift
class PaymentViewController: UIViewController, PayrailsApplePayButtonDelegate, PaymentPresenter {
    
    var applePayButton: Payrails.ApplePayElement?
    
    func setupApplePayButton() {
        // Check if Apple Pay is available
        if Payrails.Session.isApplePayAvailable() {
            // Create Apple Pay button with toggle
            self.applePayButton = Payrails.createApplePayButton(
                type: .buy,
                style: .black,
                showSaveInstrument: true
            )
            
            guard let applePayButton = self.applePayButton else { return }
            
            // Set up delegate and presenter
            applePayButton.delegate = self
            applePayButton.presenter = self
            
            // Add to view hierarchy
            view.addSubview(applePayButton)
            
            // Set up constraints...
        }
    }
    
    // MARK: - PayrailsApplePayButtonDelegate
    
    func onPaymentButtonClicked(_ button: Payrails.ApplePayButton) {
        print("Apple Pay button clicked")
    }
    
    func onAuthorizeSuccess(_ button: Payrails.ApplePayButton) {
        print("Apple Pay payment successful")
        // Navigate to success screen
    }
    
    func onAuthorizeFailed(_ button: Payrails.ApplePayButton) {
        print("Apple Pay payment failed")
        // Show error message
    }
    
    func onPaymentSessionExpired(_ button: Payrails.ApplePayButton) {
        print("Apple Pay session expired or was cancelled by user")
    }
    
    // MARK: - PaymentPresenter
    
    func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
    
    var encryptedCardData: String?
}
```

### PayPal Button

The PayPal Button (`Payrails.PayPalButton` or `Payrails.PayPalButtonWithToggle`) provides a PayPal payment option.

#### Creating a PayPal Button

```swift
// Create a PayPal button
let payPalButton = Payrails.createPayPalButton(
    showSaveInstrument: false // Set to true to show a "Save instrument" toggle
)

// Add the button to your view hierarchy
view.addSubview(payPalButton)
// Set up constraints...
```

#### Key Properties

- `delegate: PayrailsPayPalButtonDelegate?`: Assign an object to receive notifications about button taps and payment outcomes.
- `presenter: PaymentPresenter?`: **Required.** Assign a view controller that conforms to `PaymentPresenter` to handle the presentation of the PayPal web login.
- `saveInstrument: Bool`: Set to `true` to save the payment instrument after a successful transaction. If `showSaveInstrument` was `true` during creation, this property reflects the toggle's state.
- `isEnabled: Bool`: Controls the enabled state of the button.

#### Customizing the PayPal Button

You can set a prefix text for the PayPal button:

```swift
if let payPalButton = payPalButton as? Payrails.PayPalButton {
    payPalButton.setTitle("Pay with", for: .normal)
}
```

#### PayPal Button with Toggle

If you pass `showSaveInstrument: true` to `createPayPalButton()`, it returns a `Payrails.PayPalButtonWithToggle` that includes a switch for the user to choose whether to save their payment details.

#### Example Usage

```swift
class PaymentViewController: UIViewController, PayrailsPayPalButtonDelegate, PaymentPresenter {
    
    var payPalButton: Payrails.PaypalElement?
    
    func setupPayPalButton() {
        // Create PayPal button with toggle
        self.payPalButton = Payrails.createPayPalButton(showSaveInstrument: true)
        
        guard let payPalButton = self.payPalButton else { return }
        
        // Set up delegate and presenter
        payPalButton.delegate = self
        payPalButton.presenter = self
        
        // Add to view hierarchy
        view.addSubview(payPalButton)
        
        // Set up constraints...
    }
    
    // MARK: - PayrailsPayPalButtonDelegate
    
    func onPaymentButtonClicked(_ button: Payrails.PayPalButton) {
        print("PayPal button clicked")
    }
    
    func onAuthorizeSuccess(_ button: Payrails.PayPalButton) {
        print("PayPal payment successful")
        // Navigate to success screen
    }
    
    func onAuthorizeFailed(_ button: Payrails.PayPalButton) {
        print("PayPal payment failed")
        // Show error message
    }
    
    func onPaymentSessionExpired(_ button: Payrails.PayPalButton) {
        print("PayPal session expired or was cancelled by user")
    }
    
    // MARK: - PaymentPresenter
    
    func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
    
    var encryptedCardData: String?
}
```

### Generic Redirect Button

The Generic Redirect Button (`Payrails.GenericRedirectButton`) is used for payment methods that require redirecting the user to an external webpage (e.g., Klarna, Sofort, iDEAL).

#### Creating a Generic Redirect Button

```swift
// Create a button for a specific payment method (e.g., iDEAL)
let buttonTranslations = CardPaymenButtonTranslations(label: "Pay with iDEAL")
let buttonStyle = CardButtonStyle(
    backgroundColor: .systemBlue,
    textColor: .white,
    cornerRadius: 8
)

let idealButton = Payrails.createGenericRedirectButton(
    buttonStyle: buttonStyle,
    translations: buttonTranslations,
    paymentMethodCode: "ideal" // The code for the specific payment method
)

// Add the button to your view hierarchy
view.addSubview(idealButton)
// Set up constraints...
```

#### Key Properties

- `delegate: GenericRedirectPaymentButtonDelegate?`: Assign an object to receive notifications about button taps and payment outcomes.
- `presenter: PaymentPresenter?`: **Required.** Assign a view controller that conforms to `PaymentPresenter` to handle the presentation of the redirect web view.

#### Example Usage

```swift
class PaymentViewController: UIViewController, GenericRedirectPaymentButtonDelegate, PaymentPresenter {
    
    var idealButton: Payrails.GenericRedirectButton?
    
    func setupIdealButton() {
        // Create iDEAL button
        let buttonTranslations = CardPaymenButtonTranslations(label: "Pay with iDEAL")
        self.idealButton = Payrails.createGenericRedirectButton(
            buttonStyle: nil, // Use default style
            translations: buttonTranslations,
            paymentMethodCode: "ideal"
        )
        
        guard let idealButton = self.idealButton else { return }
        
        // Set up delegate and presenter
        idealButton.delegate = self
        idealButton.presenter = self
        
        // Add to view hierarchy
        view.addSubview(idealButton)
        
        // Set up constraints...
    }
    
    // MARK: - GenericRedirectPaymentButtonDelegate
    
    func onPaymentButtonClicked(_ button: Payrails.GenericRedirectButton) {
        print("iDEAL button clicked")
    }
    
    func onAuthorizeSuccess(_ button: Payrails.GenericRedirectButton) {
        print("iDEAL payment successful")
        // Navigate to success screen
    }
    
    func onAuthorizeFailed(_ button: Payrails.GenericRedirectButton) {
        print("iDEAL payment failed")
        // Show error message
    }
    
    func onPaymentSessionExpired(_ button: Payrails.GenericRedirectButton) {
        print("iDEAL session expired or was cancelled by user")
    }
    
    // MARK: - PaymentPresenter
    
    func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
    
    var encryptedCardData: String?
}
```

## Event Handling with UI Component Delegates

The Payrails SDK uses delegate patterns to notify your app about events related to UI components. Each UI component has its own delegate protocol.

### Card Form Events (PayrailsCardFormDelegate)

The `PayrailsCardFormDelegate` protocol is used to receive notifications about card data collection:

```swift
protocol PayrailsCardFormDelegate: AnyObject {
    func cardForm(_ view: Payrails.CardForm, didCollectCardData data: String)
    func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error)
}
```

- `cardForm(_:didCollectCardData:)`: Called when card data is successfully collected and encrypted. The `data` parameter contains the encrypted card data.
- `cardForm(_:didFailWithError:)`: Called if an error occurs during collection or encryption.

### Card Payment Button Events (PayrailsCardPaymentButtonDelegate)

The `PayrailsCardPaymentButtonDelegate` protocol is used to receive notifications about card payment button actions:

```swift
protocol PayrailsCardPaymentButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton)
    func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton)
    func onAuthorizeFailed(_ button: Payrails.CardPaymentButton)
}
```

- `onPaymentButtonClicked(_:)`: Called when the button is tapped, before card collection starts.
- `onAuthorizeSuccess(_:)`: Called when the payment authorization is successful.
- `onAuthorizeFailed(_:)`: Called if payment authorization fails for any reason.

### Apple Pay Button Events (PayrailsApplePayButtonDelegate)

The `PayrailsApplePayButtonDelegate` protocol is used to receive notifications about Apple Pay button actions:

```swift
protocol PayrailsApplePayButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.ApplePayButton)
    func onAuthorizeSuccess(_ button: Payrails.ApplePayButton)
    func onAuthorizeFailed(_ button: Payrails.ApplePayButton)
    func onPaymentSessionExpired(_ button: Payrails.ApplePayButton)
}
```

- `onPaymentButtonClicked(_:)`: Called when the button is tapped.
- `onAuthorizeSuccess(_:)`: Called when the payment authorization is successful.
- `onAuthorizeFailed(_:)`: Called if payment authorization fails.
- `onPaymentSessionExpired(_:)`: Called if the Apple Pay sheet is cancelled by the user.

### PayPal Button Events (PayrailsPayPalButtonDelegate)

The `PayrailsPayPalButtonDelegate` protocol is used to receive notifications about PayPal button actions:

```swift
protocol PayrailsPayPalButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.PayPalButton)
    func onAuthorizeSuccess(_ button: Payrails.PayPalButton)
    func onAuthorizeFailed(_ button: Payrails.PayPalButton)
    func onPaymentSessionExpired(_ button: Payrails.PayPalButton)
}
```

- `onPaymentButtonClicked(_:)`: Called when the button is tapped.
- `onAuthorizeSuccess(_:)`: Called when the payment authorization is successful.
- `onAuthorizeFailed(_:)`: Called if payment authorization fails.
- `onPaymentSessionExpired(_:)`: Called if the PayPal flow is cancelled by the user.

### Generic Redirect Button Events (GenericRedirectPaymentButtonDelegate)

The `GenericRedirectPaymentButtonDelegate` protocol is used to receive notifications about redirect-based payment button actions:

```swift
protocol GenericRedirectPaymentButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.GenericRedirectButton)
    func onAuthorizeSuccess(_ button: Payrails.GenericRedirectButton)
    func onAuthorizeFailed(_ button: Payrails.GenericRedirectButton)
    func onPaymentSessionExpired(_ button: Payrails.GenericRedirectButton)
}
```

- `onPaymentButtonClicked(_:)`: Called when the button is tapped.
- `onAuthorizeSuccess(_:)`: Called when the payment authorization is successful.
- `onAuthorizeFailed(_:)`: Called if payment authorization fails.
- `onPaymentSessionExpired(_:)`: Called if the redirect flow is cancelled by the user.

### Example: Implementing Multiple Delegates

A single view controller can implement multiple delegate protocols to handle different payment methods:

```swift
class CheckoutViewController: UIViewController, 
                              PayrailsCardFormDelegate,
                              PayrailsCardPaymentButtonDelegate,
                              PayrailsApplePayButtonDelegate,
                              PayrailsPayPalButtonDelegate,
                              GenericRedirectPaymentButtonDelegate,
                              PaymentPresenter {
    
    // UI components
    var cardForm: Payrails.CardForm?
    var cardPayButton: Payrails.CardPaymentButton?
    var applePayButton: Payrails.ApplePayElement?
    var payPalButton: Payrails.PaypalElement?
    var idealButton: Payrails.GenericRedirectButton?
    
    // MARK: - Setup Methods
    
    func setupPaymentMethods() {
        setupCardPayment()
        setupApplePay()
        setupPayPal()
        setupIdeal()
    }
    
    // Setup methods for each payment method...
    
    // MARK: - PayrailsCardFormDelegate
    
    func cardForm(_ view: Payrails.CardForm, didCollectCardData data: String) {
        print("Card data collected successfully")
    }
    
    func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error) {
        print("Failed to collect card data: \(error.localizedDescription)")
    }
    
    // MARK: - PayrailsCardPaymentButtonDelegate
    
    func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton) {
        print("Card payment button clicked")
    }
    
    func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton) {
        print("Card payment successful")
        showSuccessScreen()
    }
    
    func onAuthorizeFailed(_ button: Payrails.CardPaymentButton) {
        print("Card payment failed")
        showErrorMessage("Payment failed")
    }
    
    // MARK: - PayrailsApplePayButtonDelegate
    
    func onPaymentButtonClicked(_ button: Payrails.ApplePayButton) {
        print("Apple Pay button clicked")
    }
    
    func onAuthorizeSuccess(_ button: Payrails.ApplePayButton) {
        print("Apple Pay payment successful")
        showSuccessScreen()
    }
    
    func onAuthorizeFailed(_ button: Payrails.ApplePayButton) {
        print("Apple Pay payment failed")
        showErrorMessage("Payment failed")
    }
    
    func onPaymentSessionExpired(_ button: Payrails.ApplePayButton) {
        print("Apple Pay session expired or was cancelled")
    }
    
    // MARK: - PayrailsPayPalButtonDelegate
    
    func onPaymentButtonClicked(_ button: Payrails.PayPalButton) {
        print("PayPal button clicked")
    }
    
    func onAuthorizeSuccess(_ button: Payrails.PayPalButton) {
        print("PayPal payment successful")
        showSuccessScreen()
    }
    
    func onAuthorizeFailed(_ button: Payrails.PayPalButton) {
        print("PayPal payment failed")
        showErrorMessage("Payment failed")
    }
    
    func onPaymentSessionExpired(_ button: Payrails.PayPalButton) {
        print("PayPal session expired or was cancelled")
    }
    
    // MARK: - GenericRedirectPaymentButtonDelegate
    
    func onPaymentButtonClicked(_ button: Payrails.GenericRedirectButton) {
        print("Redirect payment button clicked")
    }
    
    func onAuthorizeSuccess(_ button: Payrails.GenericRedirectButton) {
        print("Redirect payment successful")
        showSuccessScreen()
    }
    
    func onAuthorizeFailed(_ button: Payrails.GenericRedirectButton) {
        print("Redirect payment failed")
        showErrorMessage("Payment failed")
    }
    
    func onPaymentSessionExpired(_ button: Payrails.GenericRedirectButton) {
        print("Redirect session expired or was cancelled")
    }
    
    // MARK: - PaymentPresenter
    
    func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
    
    var encryptedCardData: String?
    
    // MARK: - Helper Methods
    
    private func showSuccessScreen() {
        // Navigate to success screen
    }
    
    private func showErrorMessage(_ message: String) {
        // Show error alert to user
        let alert = UIAlertController(title: "Payment Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```
