import UIKit
import Payrails
import PayrailsCSE

// Protocol for CardPaymentForm delegate
public protocol PayrailsCardPaymentFormDelegate: AnyObject {
    func cardPaymentForm(_ form: Payrails.CardPaymentForm, didFinishPaymentWithResult result: OnPayResult?)
    func cardPaymentForm(_ form: Payrails.CardPaymentForm, didStartLoading isLoading: Bool)
    func cardPaymentForm(_ form: Payrails.CardPaymentForm, didLogMessage message: String)
    func cardPaymentForm(_ form: Payrails.CardPaymentForm, didFailWithError error: Error)
}

// Extension to Payrails for CardPaymentForm
public extension Payrails {
    
    class CardPaymentForm: UIStackView {
        // MARK: - Properties
        private let cardForm: Payrails.CardForm
        private let payButton: UIButton
        private var payrails: Payrails.Session?
        private var payrailsTask: Task<Void, Error>?
        private var encryptedCardData: String?
        
        public weak var delegate: PayrailsCardPaymentFormDelegate?
        public var presenter: PaymentPresenter?
        
        // MARK: - Initialization
        public init(
            config: CardFormConfig,
            tableName: String,
            cseConfig: (data: String, version: String),
            holderReference: String,
            cseInstance: PayrailsCSE,
            session: Payrails.Session? = nil,
            buttonTitle: String = "Pay Now"
        ) {
            // Initialize CardForm (inputs onlty)
            self.cardForm = CardForm(
                config: config,
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
        
        // MARK: - Setup
        private func setupUI(buttonTitle: String) {
            // Configure StackView
            self.axis = .vertical
            self.spacing = 16
            self.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
            self.isLayoutMarginsRelativeArrangement = true
            
            // Configure CardForm
            cardForm.delegate = self
            
            // Configure Pay Button
            payButton.setTitle(buttonTitle, for: .normal)
            payButton.backgroundColor = .systemBlue
            payButton.setTitleColor(.white, for: .normal)
            payButton.layer.cornerRadius = 8
            payButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
            payButton.addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
            
            // Add subviews
            self.addArrangedSubview(cardForm)
            self.addArrangedSubview(payButton)
        }
        
        // Method to update Payrails session if it's initialized later
        public func updatePayrailsSession(_ session: Payrails.Session) {
            self.payrails = session
        }
        
        // MARK: - Actions
        @objc private func payButtonTapped() {
            logMessage("Collecting card data...")
            cardForm.collectFields()
        }
        
        // MARK: - Payment
        public func pay(with type: Payrails.PaymentType? = nil,
                        storedInstrument: StoredInstrument? = nil) {
            guard let presenter = self.presenter else {
                logMessage("Payment presenter not set")
                return
            }
            
            // Use type if provided, otherwise default to .card
            let paymentType = type ?? .card
            
            logMessage("Starting payment")
            logMessage("Card data on pay method: " + (encryptedCardData ?? "nil"))
            
            payrailsTask = Task { [weak self, weak payrails] in
                self?.setLoading(true)
                
                var result: OnPayResult?
                if let payrails = payrails, let encryptedCardData = self?.encryptedCardData {
                    let paymentPresenter = presenter
                    if var cardPaymentPresenter = paymentPresenter as? (any PaymentPresenter) {
                        cardPaymentPresenter.encryptedCardData = encryptedCardData
                        
                        self?.logMessage("Executing payment...")
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
                logMessage("Payment was successful!")
            case .authorizationFailed:
                logMessage("Payment failed due to authorization")
            case .failure:
                logMessage("Payment failed (failure state)")
            case let .error(error):
                logMessage("Payment failed due to error: \(error.localizedDescription)")
            case .cancelledByUser:
                logMessage("Payment was cancelled by user")
            default:
                logMessage("Payment result: unknown state")
            }
            
            delegate?.cardPaymentForm(self, didFinishPaymentWithResult: result)
        }
        
        // MARK: - Helper Methods
        private func setLoading(_ isLoading: Bool) {
            payButton.isEnabled = !isLoading
            payButton.alpha = isLoading ? 0.7 : 1.0
            delegate?.cardPaymentForm(self, didStartLoading: isLoading)
        }
        
        private func logMessage(_ message: String) {
            print(message)
            delegate?.cardPaymentForm(self, didLogMessage: message)
        }
    }
}

// MARK: - PayrailsCardFormDelegate
extension Payrails.CardPaymentForm: PayrailsCardFormDelegate {
    public func cardForm(_ view: Payrails.CardForm, didCollectCardData data: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.logMessage("Collected encrypted card data: \(data)")
            self.encryptedCardData = data
            
            // Update the encryptedCardData on the presenter if it implements the property
            if let presenter = self.presenter as? (any PaymentPresenter) {
                presenter.encryptedCardData = data
            }
            
            // Automatically start the payment process
            self.pay(with: .card)
        }
    }
    
    public func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error) {
        logMessage("Card collection failed: \(error.localizedDescription)")
        delegate?.cardPaymentForm(self, didFailWithError: error)
    }
}
