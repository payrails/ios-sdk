import UIKit
import PassKit

public extension Payrails {
    final class ApplePayButton: ApplePayElement {
        private let pkPaymentButton: PKPaymentButton
        
        override var isProcessing: Bool {
            didSet {
                self.pkPaymentButton.isUserInteractionEnabled = !isProcessing && isEnabled
                // PKPaymentButton does not have a built-in loading indicator like a custom UIButton.
                // The visual feedback of processing is usually handled by the Apple Pay sheet itself.
                // If custom loading UI on the button is needed, it would require more complex view additions.
            }
        }
        
        override public var isEnabled: Bool {
            didSet {
                self.pkPaymentButton.isEnabled = isEnabled
                self.pkPaymentButton.isUserInteractionEnabled = isEnabled && !isProcessing
                self.pkPaymentButton.alpha = isEnabled ? 1.0 : 0.5
            }
        }
        
        // Internal initializer to be used by the factory method
        internal override init(session: Payrails.Session?) {
            guard let session = session else {
                fatalError("ApplePayButton requires a valid session")
            }
            self.pkPaymentButton = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .black)
            super.init(session: session)
            internalSetup()
        }
        
        // Initializer with button type and style
        internal init(session: Payrails.Session, type: PKPaymentButtonType, style: PKPaymentButtonStyle) {
            self.pkPaymentButton = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
            super.init(session: session)
            internalSetup()
        }
        
        public required init?(coder: NSCoder) {
            self.pkPaymentButton = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .black)
            super.init(coder: coder)
            internalSetup()
            print("Warning: Payrails.ApplePayButton initialized via coder. Use Payrails.createApplePayButton() for proper session injection.")
        }
        
        private func internalSetup() {
            // Add PKPaymentButton to self
            pkPaymentButton.translatesAutoresizingMaskIntoConstraints = false
            addSubview(pkPaymentButton)
            
            // Setup constraints
            NSLayoutConstraint.activate([
                pkPaymentButton.topAnchor.constraint(equalTo: topAnchor),
                pkPaymentButton.leadingAnchor.constraint(equalTo: leadingAnchor),
                pkPaymentButton.trailingAnchor.constraint(equalTo: trailingAnchor),
                pkPaymentButton.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            
            pkPaymentButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        }
        
        @objc private func handleTap() {
            executePayment()
        }
    }
}
