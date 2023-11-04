# Payrails iOS SDK

Payrails iOS SDK provides you with the building blocks to create a checkout experience for your customers.

## Installation with Cocoapods

```(rb)
pod 'Payrails/Checkout'
```

## Installation with Swift Package Manager

Use `https://github.com/payrails/ios-sdk` as the repository URL.

### Enabling Apple Pay capability

To enable Apple Pay in your app, you need to add the merchant ID in `Signing & Capabilities` in your project's target's settings.

## Initializing Payrails SDK

Use the `Payrails` component to initialize a Payrails client context as shown below.

Async Await

```(swift)
import Payrails

private var payrails: Payrails.Session?

payrails = try await Payrails.configure(
 with: .init(
     version: version,
  data: data,
   option: .init(env: .dev)
   )
)
```

Callback

```swift
Payrails.configure(with: .init(
        version: version,
                    data: data,
                    option: .init(env: .dev)
                )) { [weak self] result in
                    switch result {
                    case let .success(session):
                        self?.payrails = session
                    case let .failure(error):
                        print(error)
                    }
                }
```

Where `data` is base64 string and version is SDK version, you both receive from your backend.

Once your SDK is initialized, it is now allowed to interact directly with Payrails from your client.

## Card Payment Acceptance

After initializing your payrails SDK. You get a `session` object we use to interact with the payment controller.
There are 3 ways to integrate the Payrails SDK

1. Drop-in: an all-in-one payment form to accept payments on your website.
2. Elements: modular payment UI components you can assemble to build a modular payment form.
3. Secure fields: secure input fields for PCI-compliant cardholder data collection.

### How to integrate

1.  Translate form (Optional)

    ```swift
    let translations = Translations(
        cardNumber: Translations.ElementTranslation(
            label: "Card Number",
            placeholder: "Please enter the card number as it appears on your card"
        )
    )
    ```

2.  Initialize your payment form with Payrails
    `PaymentController` Arguments:

    | Argument              | Description                                                     | Default Value             | effective in modes           |
    | --------------------- | --------------------------------------------------------------- | ------------------------- | ---------------------------- |
    | session               | Payrails SDK init session object                                | required                  | SECURE_FIELDS, FORM, DROP_IN |
    | submit                | Controls the from submit type                                   | SubmitTypes.PAY_WITH_CARD | SECURE_FIELDS, FORM, DROP_IN |
    | mode                  | Controls the from mode                                          | ModeTypes.SECURE_FIELDS   | -                            |
    | enableCardholderName  | Controls the ability to show or hide the card holder name field | true                      | FORM, DROP_IN                |
    | showStoredInstruments | Shows previously saved payment instruments                      | true                      | DROP_IN                      |
    | translations          | Control the label and placeholder values of all form fields     | null                      | SECURE_FIELDS, FORM, DROP_IN |

    Choose your mode of implementation:

    **a. Secure Fields**

    ```swift
    controller = PaymentController(
    	session: payrails,
    	submit: PayrailsCheckout.SubmitTypes.PAY_WITH_CARD,
    	mode: PayrailsCheckout.ModeTypes.SECURE_FIELDS,
    	translations: translations
    )

    let cardNumberInput = CardHolderNameElement()
    let cardHolderNameInput = CardHolderNameElement()
    let cardExpirationDateInput = CardExpirationDateElement()
    let cardCVVInput = CardCVVElement()

    controller?.addCardElement(cardHolderNameInput)
    controller?.addCardElement(cardNumberInput)
    controller?.addCardElement(expiryDateInput)
    controller?.addCardElement(cvvInput)
    ```

    **b. Elements (Form)**

    ```swift
    controller = PaymentController(
    	session: payrails,
    	submit: PayrailsCheckout.SubmitTypes.PAY_WITH_CARD,
    	mode: PayrailsCheckout.ModeTypes.FORM,
    	enableCardholderName: false,
    	translations: translations
    )
    ```

    **c. Drop-in**

    ```swift
    controller = PaymentController(
    	session: payrails,
    	submit: PayrailsCheckout.SubmitTypes.PAY_WITH_CARD,
    	mode: PayrailsCheckout.ModeTypes.DROP_IN,
    	enableCardholderName: false,
        showStoredInstruments: true,
    	translations: translations
    )
    ```

3.  Listen to events
    The `PaymentController` object exposes an event handler to listen for different events taking place on the controller

    ```swift
    controller.on(eventName: PayrailsCheckout.EventName.SUBMIT) { state in
        print(state)
    }

    controller.on(eventName: PayrailsCheckout.EventName.ERROR) { error in
        print(error)
    }
    ```

4.  Render the payment form

    ```swift
    do {

    guard let layout = container.getLayout() else {
        throw NSError(domain: "LayoutError", code: 1, userInfo: nil)
    }

    view.addSubview(layout)

    } catch {
        print(error)
    }
    ```

## UI elemenents

Payrails iOS SDK provides you buttons for Apple Pay and PayPal.

1. Initialize Tokenization context:

```swift
private let applePayButton = ApplePayButton(
        paymentButtonType: .checkout,
        paymentButtonStyle: .black
    )
applePayButton.onTap = { [weak self] in
            //make payment
}

private let payPalButton = PayPalButton()
payPalButton.onTap = { [weak self] in
            //make payment
}
```

## Check for available payments

Payrails iOS SDK allows you to easily check if particular payment is available:

```swift
applePayButton.isHidden = !payrails.isPaymentAvailable(type: .applePay)
payPalButton.isHidden = !payrails.isPaymentAvailable(type: .payPal)
```

## Make new payment

Payrails iOS SDK allows you to easily perform payment using:

Async Await

```swift
import Payrails

Task { [weak self, weak payrails] in
            let result = await payrails?.executePayment(
                with: type, //.applePay or .payPal
                saveInstrument: false, //set to true if you want to store payment
                presenter: self
            )

            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.log("Payment was successful!")
                case .authorizationFailed:
                    self?.log("Payment failed due to authorization")
                case .failure:
                    self?.log("Payment failed")
                case let .error(error):
                    self?.log(
                        format: "Payment failed due to error: %@",
                        error.localizedDescription
                    )
                case .cancelledByUser:
                    self?.log("Payment was cancelled by user")
                }
            }
        }
```

Callback

```swift
payrails.executePayment(
            with: type, //.applePay or .payPal
            saveInstrument: false, //set to true if you want to store payment
            presenter: self) { [weak self] result in
                switch result {
                case .success:
                    self?.log("Payment was successful!")
                case .authorizationFailed:
                    self?.log("Payment failed due to authorization")
                case .failure:
                    self?.log("Payment failed (failure state)")
                case let .error(error):
                    self?.log(
                        format: "Payment failed due to error: %@",
                        error.localizedDescription
                    )
                case .cancelledByUser:
                    self?.log("Payment was cancelled by user")
                }
        }
```

Where

```swift
extension YourPaymentViewController: PaymentPresenter {
    func presentPayment(_ viewController: UIViewController) {
        DispatchQueue.main.async {
            self.present(viewController, animated: true)
        }
    }
}
```

### Stored payments

Payrails iOS SDK allows you to retrieve and reuse stored payments:

```swift
 payrails.storedInstruments.forEach { storedElement in
            switch storedElement.type {
            case .payPal:
                let storedPayPalButton = PayPalButton()
                storedPayPalButton.onTap = { [weak self] in
                    self?.pay(storedInstrument: storedElement)
                }
            default:
                break
            }
        }

private func pay(
        storedInstrument: StoredInstrument
    ) {
        Task { [weak self, weak payrails] in
            let result = await payrails?.executePayment(
                withStoredInstrument: storedInstrument,
                presenter: self
            )

            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.log("Payment was successful!")
                case .authorizationFailed:
                    self?.log("Payment failed due to authorization")
                case .failure:
                    self?.log("Payment failed (failure state)")
                case let .error(error):
                    self?.log(
                        format: "Payment failed due to error: %@",
                        error.localizedDescription
                    )
                case .cancelledByUser:
                    self?.log("Payment was cancelled by user")
                default:
                    break
                }
            }
        }
    }
```

## Security Policy

### Reporting a Vulnerability

If you find any vulnerability in Payrails iOS SDK, do not hesitate to _report them_.

1. Send the disclosure to security@payrails.com

2. Describe the vulnerability.

   If you have a fix, that is most welcome -- please attach or summarize it in your message!

3. We will evaluate the vulnerability and, if necessary, release a fix or mitigating steps to address it. We will contact you to let you know the outcome, and will credit you in the report.

   Please **do not disclose the vulnerability publicly** until a fix is released!

4. Once we have either a) published a fix, or b) declined to address the vulnerability for whatever reason, you are free to publicly disclose it.
