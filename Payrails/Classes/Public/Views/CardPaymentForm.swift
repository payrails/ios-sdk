import UIKit
import Payrails
import PayrailsCSE

// Protocol for CardPaymentForm delegates
public protocol PayrailsCardPaymentFormDelegate: AnyObject {
    func onPaymentButtonClicked(_ form: Payrails.CardPaymentForm)
    func onAuthorizeSuccess(_ form: Payrails.CardPaymentForm)
    func onThreeDSecureChallenge()
    func onAuthorizeFailed(_ form: Payrails.CardPaymentForm)
}

public extension Payrails {
    
    class CardPaymentForm: UIStackView {
        private let cardForm: Payrails.CardForm
        private let payButton: UIButton
        private var payrails: Payrails.Session?
        private var payrailsTask: Task<Void, Error>?
        private var encryptedCardData: String?
        private let stylesConfig: CardFormStylesConfig // Store the styles config
        
        public weak var delegate: PayrailsCardPaymentFormDelegate?
        public var presenter: PaymentPresenter?
        
        public init(
            config: CardFormConfig,
            tableName: String,
            cseConfig: (data: String, version: String),
            holderReference: String,
            cseInstance: PayrailsCSE,
            session: Payrails.Session? = nil,
            buttonTitle: String = "Pay Now"
        ) {
            self.stylesConfig = config.styles ?? CardFormStylesConfig.defaultConfig

            self.cardForm = CardForm(
                config: config, // Pass original config down
                tableName: tableName,
                cseConfig: cseConfig,
                holderReference: holderReference,
                cseInstance: cseInstance
            )
            
            self.payButton = UIButton(type: .system)
            self.payrails = session
            
            // Initialize Stack View
            super.init(frame: .zero)
            
            // Setup the component
            setupUI(buttonTitle: buttonTitle)
        }
        
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            payrailsTask?.cancel()
            if let payrails = payrails,
               payrails.isPaymentInProgress {
                payrails.cancelPayment()
            }
        }
        
        private func setupUI(buttonTitle: String) {
            self.axis = .vertical
            self.spacing = stylesConfig.sectionSpacing ?? 16
            self.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
            self.isLayoutMarginsRelativeArrangement = true
            
            // --- Add Border to the StackView (self) ---
            self.layer.borderWidth = 1.0 // Set the thickness of the border
            self.layer.borderColor = UIColor.lightGray.cgColor // Set the color (use .cgColor)
            self.layer.cornerRadius = 8.0 // Optional: Add rounded corners
            self.clipsToBounds = true   // Optional: Needed if using cornerRadius to clip content
            
            self.layoutMargins = UIEdgeInsets(top: 15, left: 15, bottom:15, right: 15)

            // Apply button styles from config
            let buttonStyle = CardButtonStyle.defaultStyle
            payButton.setTitle(buttonTitle, for: .normal)
            
            if let bgColor = buttonStyle.backgroundColor {
                payButton.backgroundColor = bgColor
            }
            if let textColor = buttonStyle.textColor {
                payButton.setTitleColor(textColor, for: .normal)
            }
            if let font = buttonStyle.font {
                payButton.titleLabel?.font = font
            }
            if let cornerRadius = buttonStyle.cornerRadius {
                payButton.layer.cornerRadius = cornerRadius
                payButton.layer.masksToBounds = cornerRadius > 0 // Clip if corner radius is set
            }
            if let borderWidth = buttonStyle.borderWidth {
                payButton.layer.borderWidth = borderWidth
            }
            if let borderColor = buttonStyle.borderColor {
                payButton.layer.borderColor = borderColor.cgColor
            }
            if let insets = buttonStyle.contentEdgeInsets {
                payButton.contentEdgeInsets = insets
            }

            // Apply configurable button height
            let buttonHeight = buttonStyle.height ?? 44
            payButton.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
            payButton.addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
            
            // Add subviews
            self.addArrangedSubview(cardForm)
            self.addArrangedSubview(payButton)
        }
        
        // Method to update Payrails session if it's initialized later
        public func updatePayrailsSession(_ session: Payrails.Session) {
            self.payrails = session
        }
        
        @objc private func payButtonTapped() {
            delegate?.onPaymentButtonClicked(self)
            cardForm.collectFields()
        }
        
        public func pay(with type: Payrails.PaymentType? = nil,
                        storedInstrument: StoredInstrument? = nil) {
            guard let presenter = self.presenter else {
                logMessage("Payment presenter not set")
                return
            }
            
            // Use type if provided, otherwise default to .card
            let paymentType = type ?? .card
            
            payrailsTask = Task { [weak self, weak payrails] in
                self?.setLoading(true)
                
                var result: OnPayResult?
                if let payrails = payrails, let encryptedCardData = self?.encryptedCardData {
                    let paymentPresenter = presenter
                    if var cardPaymentPresenter = paymentPresenter as? (any PaymentPresenter) {
                        cardPaymentPresenter.encryptedCardData = encryptedCardData
                        
                        result = await payrails.executePayment(
                            with: paymentType,
                            saveInstrument: false,
                            presenter: paymentPresenter
                        )
                    }
                } else if let storedInstrument = storedInstrument, let payrails = payrails {
                    result = await payrails.executePayment(
                        withStoredInstrument: storedInstrument
                    )
                } else {
                    self?.logMessage("Missing required payment data or session")
                }
                
                DispatchQueue.main.async {
                    self?.handlePaymentResult(result)
                    self?.setLoading(false)
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
            case let .error(error):
                delegate?.onAuthorizeFailed(self)
            case .cancelledByUser:
                logMessage("Payment was cancelled by user")
            default:
                logMessage("Payment result: unknown state")
            }
        }
        
        // MARK: - Helper Methods
        private func setLoading(_ isLoading: Bool) {
            payButton.isEnabled = !isLoading
            payButton.alpha = isLoading ? 0.7 : 1.0
        }
        
        private func logMessage(_ message: String) {
            print(message)
        }
    }
}

