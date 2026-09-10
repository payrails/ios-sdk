import UIKit
import PayPalCheckout

public protocol PayrailsPayPalButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.PayPalButton)
    func onAuthorizeSuccess(_ button: Payrails.PayPalButton)

    @available(*, deprecated, message: "Implement onAuthorizeFailed(_:failure:) instead — it carries the discriminating code, which is the only way to tell a blocked payment from a decline.")
    func onAuthorizeFailed(_ button: Payrails.PayPalButton)

    /// The payment did not authorize. `failure.code` discriminates the cause — an issuer decline,
    /// an expired session, or `.validationFailed` when the merchant's own `onRequestStart` gate
    /// stopped the payment before it started.
    ///
    /// Matches the shape already used by the card, generic-redirect and stored-instrument
    /// delegates.
    func onAuthorizeFailed(_ button: Payrails.PayPalButton, failure: AuthorizationFailure)

    func onPaymentSessionExpired(_ button: Payrails.PayPalButton)
}

public extension PayrailsPayPalButtonDelegate {
    func onAuthorizeFailed(_ button: Payrails.PayPalButton) {}

    /// Forwards to the legacy no-reason method so integrations written before
    /// `onAuthorizeFailed(_:failure:)` existed keep receiving failures unchanged.
    func onAuthorizeFailed(_ button: Payrails.PayPalButton, failure: AuthorizationFailure) {
        onAuthorizeFailed(button)
    }
}

public extension Payrails {

    class PaypalElement: UIView {

        public weak var delegate: PayrailsPayPalButtonDelegate?
        public weak var presenter: PaymentPresenter?
        public var saveInstrument: Bool = false
        public var isEnabled: Bool = true

        // Session reference
        internal weak var session: Payrails.Session?
        internal var paymentTask: Task<Void, Error>?
        internal var isProcessing: Bool = false

        // Initializers
        internal init(session: Payrails.Session?) {
            self.session = session
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            print("Warning: Payrails.PaypalElement initialized via coder without a session.")
        }

        deinit {
            paymentTask?.cancel()
        }

        // Common method to execute payment
        internal func executePayment() {
            guard !isProcessing else { return }

            guard let currentSession = session else {
                print("Payrails.PaypalElement Error: Internal Session is missing.")
                return
            }

            guard let currentPresenter = presenter else {
                print("Payrails.PaypalElement Error: Payment Presenter is not configured.")
                return
            }

            isProcessing = true
            paymentTask?.cancel()

            if let button = self as? PayPalButton {
                delegate?.onPaymentButtonClicked(button)
            }

            paymentTask = Task { [weak self] in
                guard let self = self else { return }
                do {
                    let result: OnPayResult? = await currentSession.executePayment(
                        with: .payPal,
                        saveInstrument: self.saveInstrument,
                        presenter: currentPresenter
                    )
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard self.isProcessing else { return }

                        if let button = self as? PayPalButton {
                            switch result {
                            case .success:
                                self.delegate?.onAuthorizeSuccess(button)
                            case let .authorizationFailed(failure) where failure.code == .userCancelled:
                                self.delegate?.onPaymentSessionExpired(button)
                            case let .authorizationFailed(failure):
                                self.delegate?.onAuthorizeFailed(button, failure: failure)
                            case .pending:
                                self.delegate?.onPaymentSessionExpired(button)
                            case .none:
                                print("PayPal payment result: nil")
                            }
                        }

                        self.isProcessing = false
                    }
                } catch is CancellationError {
                    await MainActor.run { self.isProcessing = false }
                } catch {
                    await MainActor.run {
                        let payrailsError = PayrailsError.unknown(error: error)
                        if let button = self as? PayPalButton {
                            self.delegate?.onAuthorizeFailed(
                                button,
                                failure: .unknownError(payrailsError)
                            )
                        }
                        self.isProcessing = false
                    }
                }
            }
        }
    }
}
