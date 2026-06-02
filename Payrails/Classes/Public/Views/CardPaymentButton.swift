import Foundation
import UIKit

public protocol PayrailsCardPaymentButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton)
    func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton)
    func onThreeDSecureChallenge(_ button: Payrails.CardPaymentButton)

    /// Fires for every terminal failure of an authorization attempt. The `failure` carries a
    /// `code` discriminating issuer decline, authentication error, user cancellation, and
    /// other errors, plus a human-readable `message` and the underlying `rawError`. Mirrors
    /// the Web SDK's `onFailed(action, { code, message, rawError })`.
    ///
    /// **Breaking change vs earlier iOS SDK versions** — the method now takes a `failure`
    /// argument. See PR ONB-739 for migration notes.
    func onAuthorizeFailed(_ button: Payrails.CardPaymentButton, failure: AuthorizationFailure)

    /// Fires when the backend left the execution in a pending state with no action for the
    /// SDK to perform. The payment is neither succeeded nor failed — it may settle later.
    /// Default implementation is a no-op.
    func onAuthorizePending(_ button: Payrails.CardPaymentButton)

    func onStoredInstrumentChanged(_ button: Payrails.CardPaymentButton, instrument: StoredInstrument?)
}

public extension PayrailsCardPaymentButtonDelegate {
    func onAuthorizePending(_ button: Payrails.CardPaymentButton) {}
    func onStoredInstrumentChanged(_ button: Payrails.CardPaymentButton, instrument: StoredInstrument?) {}
}

public extension Payrails {
    final class CardPaymentButton: ActionButton {
        // Optional properties for dual mode support
        private let cardForm: Payrails.CardForm?
        private var storedInstrument: StoredInstrument?
        private weak var session: Payrails.Session?
        private var heightConstraint: NSLayoutConstraint?
        private var paymentTask: Task<Void, Error>?
        private var encryptedCardData: String?
        private var isProcessing: Bool = false {
            didSet {
                self.isUserInteractionEnabled = !isProcessing
                show(loading: isProcessing)
                updateButtonTitle()
            }
        }

        // Mode detection
        private var isStoredInstrumentMode: Bool {
            return storedInstrument != nil
        }

        // Translations for different modes
        private let translations: CardPaymenButtonTranslations
        private let storedInstrumentTranslations: StoredInstrumentButtonTranslations?

        public weak var delegate: PayrailsCardPaymentButtonDelegate?
        public weak var presenter: PaymentPresenter?

        // Card form mode initializer (existing)
        internal init(cardForm: Payrails.CardForm, session: Payrails.Session?, translations: CardPaymenButtonTranslations, buttonStyle: CardButtonStyle? = nil) {
            self.cardForm = cardForm
            self.storedInstrument = nil
            self.session = session
            self.translations = translations
            self.storedInstrumentTranslations = nil
            super.init()

            setupButton(style: buttonStyle)
            cardForm.delegate = self
        }

        // Stored instrument mode initializer (new)
        internal init(storedInstrument: StoredInstrument, session: Payrails.Session?, translations: CardPaymenButtonTranslations, storedInstrumentTranslations: StoredInstrumentButtonTranslations? = nil, buttonStyle: StoredInstrumentButtonStyle? = nil) {
            self.cardForm = nil
            self.storedInstrument = storedInstrument
            self.session = session
            self.translations = translations
            self.storedInstrumentTranslations = storedInstrumentTranslations
            super.init()

            setupButton(storedInstrumentStyle: buttonStyle)
        }

        // Internal initializer used by unit tests to validate card-form button styling logic.
        internal init(translations: CardPaymenButtonTranslations = CardPaymenButtonTranslations(), buttonStyle: CardButtonStyle? = nil) {
            self.cardForm = nil
            self.storedInstrument = nil
            self.session = nil
            self.translations = translations
            self.storedInstrumentTranslations = nil
            super.init()

            setupButton(style: buttonStyle)
        }

        // Required initializers with warnings
        public required init() {
            fatalError("Use Payrails.createCardPaymentButton() instead")
        }

        public required init?(coder: NSCoder) {
            fatalError("Use Payrails.createCardPaymentButton() instead")
        }

        deinit {
            paymentTask?.cancel()
            if let session = session,
               session.isPaymentInProgress {
                session.cancelPayment()
            }
        }

        private func setupButton(style: CardButtonStyle? = nil) {
            updateButtonTitle()

            let effectiveStyle = style?.merged(over: CardButtonStyle.defaultStyle) ?? CardButtonStyle.defaultStyle
            apply(style: effectiveStyle)
            updateHeightConstraint(to: effectiveStyle.height ?? 44)

            removeTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
            addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
        }

        private func setupButton(storedInstrumentStyle: StoredInstrumentButtonStyle? = nil) {
            updateButtonTitle()

            if let style = storedInstrumentStyle {
                backgroundColor = style.backgroundColor
                setTitleColor(style.textColor, for: .normal)
                titleLabel?.font = style.font
                layer.cornerRadius = style.cornerRadius
                layer.borderWidth = style.borderWidth
                layer.borderColor = style.borderColor.cgColor
                contentEdgeInsets = style.contentEdgeInsets
                updateHeightConstraint(to: style.height)
            } else {
                // Default styling
                backgroundColor = .systemBlue
                setTitleColor(.white, for: .normal)
                layer.cornerRadius = 8
            }

            removeTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
            addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
        }

        private func apply(style: CardButtonStyle) {
            if let bgColor = style.backgroundColor {
                backgroundColor = bgColor
            }
            if let textColor = style.textColor {
                setTitleColor(textColor, for: .normal)
            }
            if let font = style.font {
                titleLabel?.font = font
            }
            if let cornerRadius = style.cornerRadius {
                layer.cornerRadius = cornerRadius
                layer.masksToBounds = cornerRadius > 0
            }
            if let borderWidth = style.borderWidth {
                layer.borderWidth = borderWidth
            }
            if let borderColor = style.borderColor {
                layer.borderColor = borderColor.cgColor
            }
            if let insets = style.contentEdgeInsets {
                contentEdgeInsets = insets
            }
        }

        private func updateHeightConstraint(to constant: CGFloat) {
            if let existingConstraint = heightConstraint {
                existingConstraint.constant = constant
                return
            }

            let constraint = heightAnchor.constraint(equalToConstant: constant)
            constraint.isActive = true
            heightConstraint = constraint
        }

        private func updateButtonTitle() {
            if isStoredInstrumentMode {
                // Use stored instrument translations if available
                if let storedTranslations = storedInstrumentTranslations {
                    let title = isProcessing ? storedTranslations.processingLabel : storedTranslations.label
                    setTitle(title, for: .normal)
                } else {
                    // Fallback to card translations
                    setTitle(translations.label, for: .normal)
                }
            } else {
                // Card form mode - use card translations
                let title = isProcessing ? "" : translations.label
                setTitle(title, for: .normal)
            }
        }

        @objc private func payButtonTapped() {
            Payrails.log("CardPaymentButton.payButtonTapped fired (isProcessing=\(isProcessing), isUserInteractionEnabled=\(isUserInteractionEnabled), session=\(session != nil ? "present" : "nil"), cardForm=\(cardForm != nil ? "present" : "nil"))")
            delegate?.onPaymentButtonClicked(self)

            if let storedInstrument = storedInstrument {
                // Stored instrument mode: direct payment (takes priority over card form)
                pay(with: storedInstrument.type, storedInstrument: storedInstrument)
            } else if let cardForm = cardForm {
                // Card form mode: collect card data first
                cardForm.collectFields()
            }
        }

        public func pay(with type: Payrails.PaymentType? = nil,
                        storedInstrument: StoredInstrument? = nil) {
            guard let presenter = self.presenter else {
                Payrails.log("Payment presenter not set")
                return
            }

            guard let session = session else {
                Payrails.log("Session not available")
                return
            }

            let paymentType = type ?? .card

            paymentTask = Task { [weak self, weak session] in
                await MainActor.run {
                    self?.isProcessing = true
                }

                var result: OnPayResult?
                if let session = session {
                    if let storedInstrument = storedInstrument ?? self?.storedInstrument {
                        // Stored instrument payment
                        result = await session.executePayment(
                            withStoredInstrument: storedInstrument,
                            presenter: presenter
                        )
                    } else {
                        // Card form payment
                        let saveInstrument = self?.cardForm?.saveInstrument ?? false
                        result = await session.executePayment(
                            with: paymentType,
                            saveInstrument: saveInstrument,
                            presenter: presenter
                        )
                    }
                } else {
                    Payrails.log("Session is no longer available")
                }

                await MainActor.run {
                    self?.handlePaymentResult(result)
                    self?.isProcessing = false
                }
            }
        }

        // internal (not private) so @testable tests can drive the result-routing
        // logic directly. Not part of the public API surface.
        internal func handlePaymentResult(_ result: OnPayResult?) {
            switch result {
            case .success:
                delegate?.onAuthorizeSuccess(self)
            case let .authorizationFailed(failure):
                delegate?.onAuthorizeFailed(self, failure: failure)
            case .pending:
                // Backend left the execution pending with no action for the SDK to perform.
                // The payment is not terminal — surface it as pending so the merchant can
                // decide how to follow up.
                delegate?.onAuthorizePending(self)
            case .none:
                Payrails.log("Payment result: nil")
            }
        }

        // Public method to get the stored instrument (for stored instrument mode)
        public func getStoredInstrument() -> StoredInstrument? {
            return storedInstrument
        }

        /// Dynamically sets a stored instrument on this button, switching it to stored instrument mode.
        /// When set, the button skips card form validation and pays directly with the instrument.
        public func setStoredInstrument(_ instrument: StoredInstrument) {
            self.storedInstrument = instrument
            updateButtonTitle()
            delegate?.onStoredInstrumentChanged(self, instrument: instrument)
        }

        /// Clears the stored instrument, reverting the button to card form mode.
        public func clearStoredInstrument() {
            self.storedInstrument = nil
            updateButtonTitle()
            delegate?.onStoredInstrumentChanged(self, instrument: nil)
        }
    }
}

// MARK: - PayrailsCardFormDelegate
extension Payrails.CardPaymentButton: PayrailsCardFormDelegate {
    public func cardForm(_ view: Payrails.CardForm, didCollectCardData data: String) {
        Payrails.log("CardPaymentButton.cardForm didCollectCardData (data length=\(data.count))")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.encryptedCardData = data
            self.presenter?.encryptedCardData = encryptedCardData
            // Start the payment process
            self.pay(with: .card)
        }
    }

    public func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error) {
        Payrails.log("Card collection failed: \(error.localizedDescription)")
        // Card collection / validation failure is not an authorization outcome — the form
        // renders its own inline field errors. Just re-enable the button so the user can
        // correct the input and retry; do not emit onAuthorizeFailed.
        DispatchQueue.main.async { [weak self] in
            self?.isProcessing = false
        }
    }
}
