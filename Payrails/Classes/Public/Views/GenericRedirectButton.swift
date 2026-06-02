//
//  GenericRedirectButton.swift
//  Pods
//
//

import Foundation
import UIKit

public protocol GenericRedirectPaymentButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.GenericRedirectButton)
    func onAuthorizeSuccess(_ button: Payrails.GenericRedirectButton)

    /// Fires for every terminal authorization failure. The `failure` carries a `code`,
    /// human-readable `message`, and underlying `rawError`.
    /// **Breaking change vs earlier versions.**
    func onAuthorizeFailed(_ button: Payrails.GenericRedirectButton, failure: AuthorizationFailure)

    /// Fires when the backend left the execution in a pending state with no action for the
    /// SDK to perform. Default implementation is a no-op.
    func onAuthorizePending(_ button: Payrails.GenericRedirectButton)

    /// Legacy: payment-session-expired signal predating this redesign. Kept for
    /// backward compatibility with existing GenericRedirect merchants.
    func onPaymentSessionExpired(_ button: Payrails.GenericRedirectButton)
}

public extension GenericRedirectPaymentButtonDelegate {
    func onAuthorizePending(_ button: Payrails.GenericRedirectButton) {}
}

public extension Payrails {
    final class GenericRedirectButton: ActionButton {
        private weak var session: Payrails.Session?
        private var paymentTask: Task<Void, Error>?
        private let paymentMethodCode: String

        private var isProcessing: Bool = false {
            didSet {
                self.isUserInteractionEnabled = !isProcessing
                show(loading: isProcessing)
            }
        }

        public weak var delegate: GenericRedirectPaymentButtonDelegate?
        public weak var presenter: PaymentPresenter?

        // Internal initializer used by factory method
        internal init(
            // TODO: paymentMethodCode can probably be typed better
            paymentMethodCode: String,
            session: Payrails.Session?,
            translations: CardPaymenButtonTranslations
        ) {
            self.session = session
            self.paymentMethodCode = paymentMethodCode
            super.init()

            setupButton(translations: translations)
        }

        // Required initializers with warnings
        public required init() {
            fatalError("Use Payrails.createRedirectPaymentButton() instead")
        }

        public required init?(coder: NSCoder) {
            fatalError("Use Payrails.createRedirectPaymentButton() instead")
        }

        deinit {
            paymentTask?.cancel()
            if let session = session,
               session.isPaymentInProgress {
                session.cancelPayment()
            }
        }

        private func setupButton(translations: CardPaymenButtonTranslations) {
            setTitle(translations.label, for: .normal)
            backgroundColor = .systemBlue
            setTitleColor(.white, for: .normal)
            layer.cornerRadius = 8
            addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
        }

        @objc private func payButtonTapped() {
            delegate?.onPaymentButtonClicked(self)
            pay()
        }

        public func pay(with type: Payrails.PaymentType? = nil,
                        storedInstrument: StoredInstrument? = nil) {
            guard let presenter = self.presenter else {
                Payrails.log("Payment presenter not set")
                return
            }

            paymentTask = Task { [weak self, weak session] in
                self?.isProcessing = true

                var result: OnPayResult?
                if let session = session {
                    if var cardPaymentPresenter = presenter as? (any PaymentPresenter) {
                        result = await session.executePayment(
                            with: PaymentType.genericRedirect,
                            paymentMethodCode: self?.paymentMethodCode,
                            saveInstrument: false,
                            presenter: presenter
                        )
                    }
                } else if let storedInstrument = storedInstrument, let session = session {
                    result = await session.executePayment(
                        withStoredInstrument: storedInstrument
                    )
                } else {
                    Payrails.log("Missing required payment data or session")
                }

                await MainActor.run {
                    self?.handlePaymentResult(result)
                    self?.isProcessing = false
                }
            }
        }

        // internal for @testable test drive — see CardPaymentButton.
        internal func handlePaymentResult(_ result: OnPayResult?) {
            switch result {
            case .success:
                delegate?.onAuthorizeSuccess(self)
            case let .authorizationFailed(failure):
                delegate?.onAuthorizeFailed(self, failure: failure)
            case .pending:
                delegate?.onAuthorizePending(self)
            case .none:
                Payrails.log("Payment result: nil")
            }
        }
    }
}
