import UIKit
import PassKit

public protocol PayrailsApplePayButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.ApplePayButton)
    func onAuthorizeSuccess(_ button: Payrails.ApplePayButton)
    func onAuthorizeFailed(_ button: Payrails.ApplePayButton)
    func onPaymentSessionExpired(_ button: Payrails.ApplePayButton)
}

public extension Payrails {

    class ApplePayElement: UIView {

        public weak var delegate: PayrailsApplePayButtonDelegate?
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
            print("Warning: Payrails.ApplePayElement initialized via coder without a session.")
        }
        
        deinit {
            paymentTask?.cancel()
        }
        
        // Common method to execute payment
        internal func executePayment() {
            guard !isProcessing else { return }
            
            guard let currentSession = session else {
                print("Payrails.ApplePayElement Error: Internal Session is missing.")
                return
            }
            
            guard let currentPresenter = presenter else {
                print("Payrails.ApplePayElement Error: Payment Presenter is not configured.")
                return
            }
            
            isProcessing = true
            paymentTask?.cancel()
            
            if let button = self as? ApplePayButton {
                delegate?.onPaymentButtonClicked(button)
            }
            
            print("--------------------")
            print("save instrument: ", self.saveInstrument)
            print("--------------------")
            
            paymentTask = Task { [weak self] in
                guard let self = self else { return }
                do {
                    let result: OnPayResult? = await currentSession.executePayment(
                        with: .applePay,
                        saveInstrument: self.saveInstrument,
                        presenter: currentPresenter
                    )
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard self.isProcessing else { return }
                        
                        if let button = self as? ApplePayButton {
                            switch result {
                            case .success:
                                self.delegate?.onAuthorizeSuccess(button)
                            case .authorizationFailed:
                                self.delegate?.onAuthorizeFailed(button)
                            case .failure:
                                self.delegate?.onAuthorizeFailed(button)
                            case let .error(error):
                                self.delegate?.onAuthorizeFailed(button)
                            case .cancelledByUser:
                                self.delegate?.onPaymentSessionExpired(button)
                            default:
                                print("Apple Pay payment result: \(String(describing: result))")
                            }
                        }
                        
                        self.isProcessing = false
                    }
                } catch is CancellationError {
                    await MainActor.run { self.isProcessing = false }
                } catch {
                    await MainActor.run {
                        let payrailsError = PayrailsError.unknown(error: error)
                        if let button = self as? ApplePayButton {
                            self.delegate?.onAuthorizeFailed(button)
                        }
                        self.isProcessing = false
                    }
                }
            }
        }
    }
}
