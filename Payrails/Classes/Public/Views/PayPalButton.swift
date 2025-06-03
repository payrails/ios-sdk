import UIKit
import PayPalCheckout

public extension Payrails {

    final class PayPalButton: PaypalElement {

        private let prefixLabel = UILabel()
        private let paypalImageView = UIImageView()
        private let button = UIButton(type: .custom)
        
        override var isProcessing: Bool {
            didSet {
                self.button.isUserInteractionEnabled = !isProcessing && isEnabled
                showLoading(isProcessing)
            }
        }
        
        override public var isEnabled: Bool {
            didSet {
                self.button.isEnabled = isEnabled
                self.button.isUserInteractionEnabled = isEnabled && !isProcessing
                self.button.alpha = isEnabled ? 1.0 : 0.5
            }
        }

        public required init() {
            super.init(session: nil)
            internalSetup()
            print("Warning: Payrails.PayPalButton initialized without a session via required init(). Use Payrails.createPayPalButton().")
        }

        public required init?(coder: NSCoder) {
            super.init(coder: coder)
            internalSetup()
            print("Warning: Payrails.PayPalButton initialized via coder without a session. Use Payrails.createPayPalButton().")
        }

        internal override init(session: Payrails.Session?) {
            super.init(session: session)
            internalSetup()
        }

        private func internalSetup() {
            setupViews()
            button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        }
        
        @objc private func handleTap() {
            executePayment()
        }

        public func setTitle(_ title: String?, for state: UIControl.State) {
            button.setTitle(title, for: state)
            if state == .normal { prefixLabel.text = title }
        }
        
        private func setupViews() {
            // Configure button appearance
            button.backgroundColor = UIColor(red: 255/255, green: 204/255, blue: 0/255, alpha: 1)
            button.layer.cornerRadius = 6.0
            button.clipsToBounds = true
            button.translatesAutoresizingMaskIntoConstraints = false
            
            // Add button to self
            addSubview(button)
            
            // Setup constraints for button
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: topAnchor),
                button.leadingAnchor.constraint(equalTo: leadingAnchor),
                button.trailingAnchor.constraint(equalTo: trailingAnchor),
                button.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            
            // Configure stack view for button content
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.isUserInteractionEnabled = false
            stackView.distribution = .fill
            stackView.translatesAutoresizingMaskIntoConstraints = false
            stackView.spacing = 8
            stackView.alignment = .center
            
            // Configure label
            prefixLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            prefixLabel.textColor = UIColor(red: 0/255, green: 150/255, blue: 100/255, alpha: 1)
            prefixLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            prefixLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            
            // Configure image view
            paypalImageView.image = UIImage(named: "PayPal", in: Bundle(for: PayPalButton.self), compatibleWith: nil)
            paypalImageView.contentMode = .scaleAspectFit
            paypalImageView.translatesAutoresizingMaskIntoConstraints = false
            paypalImageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            paypalImageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            let desiredLogoHeight: CGFloat = 24.0
            paypalImageView.heightAnchor.constraint(equalToConstant: desiredLogoHeight).isActive = true
            
            // Add views to stack
            stackView.addArrangedSubview(paypalImageView)
            
            // Add stack view to button
            button.addSubview(stackView)
            
            // Setup constraints for stack view
            NSLayoutConstraint.activate([
                stackView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                
                // Optional: Add padding if needed (adjust constants)
                stackView.leadingAnchor.constraint(greaterThanOrEqualTo: button.layoutMarginsGuide.leadingAnchor, constant: 8),
                stackView.trailingAnchor.constraint(lessThanOrEqualTo: button.layoutMarginsGuide.trailingAnchor, constant: -8),
                stackView.topAnchor.constraint(greaterThanOrEqualTo: button.layoutMarginsGuide.topAnchor, constant: 4),
                stackView.bottomAnchor.constraint(lessThanOrEqualTo: button.layoutMarginsGuide.bottomAnchor, constant: -4)
            ])
        }
        
        private func showLoading(_ loading: Bool) {
            prefixLabel.isHidden = loading
            paypalImageView.isHidden = loading
            
            if loading {
                let activityIndicator = UIActivityIndicatorView(style: .medium)
                activityIndicator.translatesAutoresizingMaskIntoConstraints = false
                activityIndicator.color = .white
                activityIndicator.startAnimating()
                
                button.addSubview(activityIndicator)
                
                NSLayoutConstraint.activate([
                    activityIndicator.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                    activityIndicator.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                ])
                
                activityIndicator.tag = 999
            } else {
                if let activityIndicator = button.viewWithTag(999) {
                    activityIndicator.removeFromSuperview()
                }
            }
        }
    }
}
