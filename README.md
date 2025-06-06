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

```swift
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

## UI elemenents

Payrails iOS SDK provides you buttons for Apple Pay, PayPal and Stored instuments (card buttons).

1. Initialize Tokenization context:

```swift
private let applePayButton = ApplePayButton(
        paymentButtonType: .checkout,
        paymentButtonStyle: .black
    )
applePayButton.onTap = { [weak self] in
    // Make payment
}

private let payPalButton = PayPalButton()
payPalButton.onTap = { [weak self] in
    // Make payment
}

private let cardButton = CardSubmitButton()
cardButton.onTap = { [weak self] in
    // Make payment
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

## Card Form Acceptance

After initializing your payrails SDK. You get a `session` object we use to interact with the payment controller.
There are 3 ways to integrate the Payrails SDK

1. Drop-in: an all-in-one payment form to accept payments on your website.
2. Elements: modular payment UI components you can assemble to build a modular payment form.
3. Secure fields: secure input fields for PCI-compliant cardholder data collection. **(not supported yet)**

### 1.Drop-in

#### Initilizing the drop-in view

```swift

let controller = try? DropInViewController(configuration: .init(
    initData: response,
    option: .init(env: .dev)
))
```

#### Handling events

Handle events by setting the callback function of your controller.
Allowed result types:
| Result | Description |
| --------------------- | --------------------------------------------------------------- |
| .authorizationFailed | Couldn't authroize the payment |
| .cancelledByUser | User cancelled the execution |
| .failure | Payment failed |  
| .success | Payment was successful |
| .error | An error occured with error values [here](Payrails/Classes/Public/Domains/PayrailsError.swift) |

```swift
controller?.callback = { [weak self] result in
    let message: String
    switch result {
    case .authorizationFailed:
        message = "Authorization Failed"
    case .cancelledByUser:
        message = "Cancelled by user"
    case .failure:
        message = "Failure"
    case .success:
        message = "Success"
    case let .error(error):
        switch error {
        case .invalidCardData:
            return
        default:
            message = "Error " + error.localizedDescription
        }
    }
    self?.showResultAlert(message)
}
```

#### Render your drop-in form

The controller exposes the drop-in view object, you can render it by adding it as a subview to your view controller

```swift
view.addSubview(controller.view)
```

### 2. Elements

### Element Types

Before we integrate our secure fields form you need to be fimiliar with the Card Element types.
| Result | Description |
| --------------------- | --------------------------------------------------------------- |
| CARDHOLDER_NAME | Field type that requires Cardholder Name input formatting and validation |
| CARD_NUMBER | Field type that requires Credit Card Number input formatting and validation |
| EXPIRATION_DATE | Field type that requires Card Expiration Date input formatting and validation, format can be set through CollectElementOptions, defaul is MM/YY |  
| CVV | Field type that requires Card CVV input formatting and validation |
| EXPIRATION_MONTH | Field type that requires Card Expiration Month formatting and validation (format: MM)|
| EXPIRATION_YEAR | Field type that requires Card Expiration Year formatting and validation, format can be set through CollectElementOptions for YY, defaul is YYYY |

They can be accessed as follows:

```swift
let type = CardFieldType.CARDHOLDER_NAME
```

### Initilize your secure fields view

```swift
func buildCardView {

    guard let payrails, // This is your Payrails.Session object
        payrails.isPaymentAvailable(type: .card) else { return }


    if let cardView = payrails.buildCardView(
        with: .init(
            style: .defaultStyle,
            showNameField: true,
        )
    ) {
        view.addSubview(cardView)
    } else {
        log("Payment card is enabled but view was not generated")
    }
}
```

### Configure your view

You can pass a `fieldConfigs` parameter to your view, allowing you to customize specific elements

```swift
let cardView = payrails.buildCardView(
    with: .init(
        style: .defaultStyle,
        showNameField: true,
        fieldConfigs: [
            CardFieldConfig.init(
                type: CardFieldType.CARDHOLDER_NAME,
                placeholder: "Enter name as it appears on your credit card",
                title: "Card holder name",
                style: .defaultStyle
            )
        ]
    )
)
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
