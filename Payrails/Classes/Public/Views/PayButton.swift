//
//  PayButton.swift
//  Pods
//
//  Created by Mustafa Dikici on 05.03.25.
//
import UIKit
import PayrailsCSE

public protocol CardCollectButtonDelegate: AnyObject {
    func cardCollectButton(_ button: CardCollectButton, didFinishPaymentWithResult result: OnPayResult?)
    func cardCollectButton(_ button: CardCollectButton, didStartLoading isLoading: Bool)
    func cardCollectButton(_ button: CardCollectButton, didLogMessage message: String)
}

public class CardCollectButton: UIButton {
    // MARK: - Properties
    private weak var cardForm: CardForm?
    private var payrails: Payrails.Session?
    private var payrailsTask: Task<Void, Error>?
    private var encryptedCardData: String?
    
    public weak var delegate: CardCollectButtonDelegate?
    public var presenter: PaymentPresenter?
    
    // MARK: - Initialization
    public init(cardForm: CardForm, payrails: Payrails.Session?) {
        self.cardForm = cardForm
        self.payrails = payrails
        super.init(frame: .zero)
        
        setupButton()
        setupCardFormDelegate()
    }
    
    // Method to update Payrails session if it's initialized later
    public func updatePayrailsSession(_ session: Payrails.Session) {
        self.payrails = session
    }
    
    required init?(coder: NSCoder) {
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
    private func setupButton() {
        setTitle("Collect Card Data", for: .normal)
        backgroundColor = .systemBlue
        setTitleColor(.white, for: .normal)
        layer.cornerRadius = 8
        addTarget(self, action: #selector(collectButtonTapped), for: .touchUpInside)
    }
    
    private func setupCardFormDelegate() {
        cardForm?.delegate = self
    }
    
    // MARK: - Actions
    @objc private func collectButtonTapped() {
        logMessage("Collecting card data...")
        cardForm?.collectFields()
    }
    
    // MARK: - Payment
    public func pay(with type: Payrails.PaymentType? = nil,
                   storedInstrument: StoredInstrument? = nil) {
        guard let presenter = self.presenter else { return }
        
        // Use type if provided, otherwise default to .card
        let paymentType = type ?? .card
        
        logMessage("Starting payment")
        logMessage("Card data on pay method: " + (encryptedCardData ?? "nil"))
        
        payrailsTask = Task { [weak self, weak payrails] in
            self?.setLoading(true)
            
            var result: OnPayResult?
            if let payrails = payrails {
                logMessage("Trying to pay...")
                
                result = await payrails.executePayment(
                    with: paymentType,
                    saveInstrument: false,
                    presenter: presenter
                )
                
                logMessage("After payment attempt")
            } else if let storedInstrument = storedInstrument, let payrails = payrails {
                result = await payrails.executePayment(
                    withStoredInstrument: storedInstrument
                )
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
            break
        }
        
        delegate?.cardCollectButton(self, didFinishPaymentWithResult: result)
    }
    
    // MARK: - Helper Methods
    private func setLoading(_ isLoading: Bool) {
        isEnabled = !isLoading
        alpha = isLoading ? 0.7 : 1.0
        delegate?.cardCollectButton(self, didStartLoading: isLoading)
    }
    
    private func logMessage(_ message: String) {
        print(message)
        delegate?.cardCollectButton(self, didLogMessage: message)
    }
}


extension CardCollectButton: CardFormDelegate {
    public func cardCollectView(_ view: CardForm, didCollectCardData data: String) {
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
    
    public func cardCollectView(_ view: CardForm, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.logMessage("Card collection failed: \(error.localizedDescription)")
        }
    }
}
