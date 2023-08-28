# Payrails iOS SDK

Payrails iOS SDK provides you with the building blocks to create a checkout experience for your customers.

## Installation with Cocoapods

```(sh)
pod 'Payrails/Checkout'
```

### Enabling Apple Pay capability

To enable Apple Pay in your app, you need to add the merchant ID in `Signing & Capabilites` in your project's target's settings.


## Initializing Payrails React Native SDK

Use the `Payrails` component to initialize a Payrails client context as shown below.

Async Await

```(ts)
import Payrails

private var payrails: Payrails.Session?

payrails = try await Payrails.configure(
	with: .init(
		data: data,
		 option: .init(env: .dev)
		 )
)
```

Callback

```(ts)
Payrails.configure(with: .init(
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

Where `data` is base64 string you receive from your backend.

Once your SDK is initialized, it is now allowed to interact directly with Payrails from your client.

## UI elemenents

Payrails iOS SDK provides you buttons for Apple Pay and PayPal.

1. Initialize Tokenization context:

```(ts)
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

```(ts)
applePayButton.isHidden = !payrails.isPaymentAvailable(type: .applePay)
payPalButton.isHidden = !payrails.isPaymentAvailable(type: .payPal)
```

## Make new payment

Payrails iOS SDK allows you to easily perform payment using:


Async Await

```(ts)
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
                    self?.log("Payment was succesfull!")
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

```(ts)
payrails.executePayment(
            with: type, //.applePay or .payPal
            saveInstrument: false, //set to true if you want to store payment
            presenter: self) { [weak self] result in
                switch result {
                case .success:
                    self?.log("Payment was succesfull!")
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

```(ts)
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

```(ts)
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
                    self?.log("Payment was succesfull!")
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