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
    func onAuthorizeFailed(_ button: Payrails.GenericRedirectButton)
    func onPaymentSessionExpired(_ button: Payrails.GenericRedirectButton)
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
        
        private func handlePaymentResult(_ result: OnPayResult?) {
            switch result {
            case .success:
                delegate?.onAuthorizeSuccess(self)
            case .authorizationFailed:
                delegate?.onAuthorizeFailed(self)
            case .failure:
                delegate?.onAuthorizeFailed(self)
            case .error(_):
                delegate?.onAuthorizeFailed(self)
            case .cancelledByUser:
                Payrails.log("Payment was cancelled by user")
            default:
                Payrails.log("Payment result: unknown state")
            }
        }
    }
}
