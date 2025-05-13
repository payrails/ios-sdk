import UIKit
import PassKit

// Define the delegate protocol
public protocol PayrailsApplePayButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.ApplePayButton)
    func onAuthorizeSuccess(_ button: Payrails.ApplePayButton)
    func onAuthorizeFailed(_ button: Payrails.ApplePayButton)
    func onPaymentSessionExpired(_ button: Payrails.ApplePayButton)
}

public extension Payrails {
    final class ApplePayButton: PKPaymentButton {
        
        public weak var delegate: PayrailsApplePayButtonDelegate?
        public weak var presenter: PaymentPresenter?
        
        private weak var session: Payrails.Session?
        private var paymentTask: Task<Void, Error>?
        private var isProcessing: Bool = false {
            didSet {
                self.isUserInteractionEnabled = !isProcessing
                // PKPaymentButton does not have a built-in loading indicator like a custom UIButton. ss
                // The visual feedback of processing is usually handled by the Apple Pay sheet itself.
                // If custom loading UI on the button is needed, it would require more complex view additions.
            }
        }
        
        // Internal initializer to be used by the factory method
        internal init(session: Payrails.Session, type: PKPaymentButtonType, style: PKPaymentButtonStyle) {
            self.session = session
            super.init(paymentButtonType: type, paymentButtonStyle: style)
            internalSetup()
        }
        
        // Update public initializers to guide developers
        public override init(paymentButtonType type: PKPaymentButtonType, paymentButtonStyle style: PKPaymentButtonStyle) {
            super.init(paymentButtonType: type, paymentButtonStyle: style)
            internalSetup()
            print("Warning: Payrails.ApplePayButton initialized directly. Use Payrails.createApplePayButton() for proper session injection.")
        }
        
        public required init?(coder: NSCoder) {
            super.init(coder: coder)
            internalSetup()
            print("Warning: Payrails.ApplePayButton initialized via coder. Use Payrails.createApplePayButton() for proper session injection.")
        }
        
        private func internalSetup() {
            addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        }
        
        deinit {
            paymentTask?.cancel()
        }
        
        @objc private func handleTap() {
            guard !isProcessing else { return }
            
            Payrails.log("ApplePy button initializong")
            
            guard let currentSession = session else {
                Payrails.log("Payrails.ApplePayButton Error: Internal Session is missing. Button was likely not created via Payrails.createApplePayButton().")
                print("Payrails.ApplePayButton Error: Internal Session is missing. Button was likely not created via Payrails.createApplePayButton().")
                // Optionally, call a delegate method for this specific error
                // delegate?.onConfigurationError(self, error: .missingSession)
                return
            }
            
            guard let currentPresenter = presenter else {
                Payrails.log("Payrails.ApplePayButton Error: Payment Presenter is not configured.")
                print("Payrails.ApplePayButton Error: Payment Presenter is not configured.")
                // Optionally, call a delegate method for this specific error
                // delegate?.onConfigurationError(self, error: .missingPresenter)
                return
            }
            
            isProcessing = true
            paymentTask?.cancel()
            delegate?.onPaymentButtonClicked(self)
            
            paymentTask = Task { [weak self] in
                guard let self = self else { return }
                do {
                    let result: OnPayResult? = await currentSession.executePayment(
                        with: .applePay,
                        saveInstrument: false,
                        presenter: currentPresenter
                    )
                    try Task.checkCancellation()
                    
                    await MainActor.run {
                        guard self.isProcessing else { return }
                        
                        switch result {
                        case .success:
                            self.delegate?.onAuthorizeSuccess(self)
                        case .authorizationFailed:
                            self.delegate?.onAuthorizeFailed(self)
                        case .failure:
                            self.delegate?.onAuthorizeFailed(self)
                        case .error(_):
                            self.delegate?.onAuthorizeFailed(self)
                        case .cancelledByUser:
                            self.delegate?.onPaymentSessionExpired(self) // Or a more specific "cancelled"
                        default:
                            // Handle other cases or log them
                            print("Apple Pay payment result: \(String(describing: result))")
                        }
                        self.isProcessing = false
                    }
                } catch is CancellationError {
                    await MainActor.run {
                        // Ensure isProcessing is reset if the task was cancelled
                        if self.isProcessing { self.isProcessing = false }
                    }
                } catch {
                    await MainActor.run {
                        // let payrailsError = PayrailsError.unknown(error: error) // Map to your error type
                        self.delegate?.onAuthorizeFailed(self) // Or a more specific error delegate
                        if self.isProcessing { self.isProcessing = false }
                    }
                }
            }
        }
    }
}
