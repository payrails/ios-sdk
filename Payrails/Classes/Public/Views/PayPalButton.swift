import UIKit

import PayPalCheckout

// MARK: - Delegate Protocol (Remains the same)
public protocol PayrailsPayPalButtonDelegate: AnyObject {
    func payPalButton(_ button: Payrails.PayPalButton, didFinishPaymentWithResult result: OnPayResult?)
    func payPalButton(_ button: Payrails.PayPalButton, didStartLoading isLoading: Bool)
}

// MARK: - Payrails.PayPalButton
public extension Payrails {

    final class PayPalButton: ActionButton { // Inherits from your ActionButton

        // --- UI Properties ---
        private let prefixLabel = UILabel()
        private let paypalImageView = UIImageView( /* ... image setup ... */ )

        // --- Dependencies (Set externally AFTER creation) ---
        public weak var delegate: PayrailsPayPalButtonDelegate?
        public weak var presenter: PaymentPresenter?

        // --- Internal Properties ---
        private weak var session: Payrails.Session? // Set via internal init
        private var paymentTask: Task<Void, Error>?
        private var isProcessing: Bool = false {
            didSet {
                self.isUserInteractionEnabled = !isProcessing
                show(loading: isProcessing)
                delegate?.payPalButton(self, didStartLoading: isProcessing)
            }
        }

        // --- Initialization (Internal - Called by Factory) ---
        // Note: If ActionButton's required init() is public, this needs to be public.
        // If ActionButton's required init() can be internal, this can be internal.
        // Let's assume ActionButton's is public for now.
        public required init() {
            // This path might be problematic if session is required.
            // Relying on the factory method is safer.
             super.init()
             internalSetup()
             print("Warning: Payrails.PayPalButton initialized without a session via required init(). Use Payrails.createPayPalButton().")
             // Button will be unusable until configured if created this way, which we want to avoid.
        }

        public required init?(coder: NSCoder) {
            // Required by UIControl/UIButton via ActionButton
            super.init(coder: coder)
             internalSetup()
             print("Warning: Payrails.PayPalButton initialized via coder without a session. Use Payrails.createPayPalButton().")
        }

        // Internal initializer used by the factory method
        internal init(session: Payrails.Session) {
            self.session = session
            super.init() // Call ActionButton's required init()
            internalSetup()
        }

        // Common setup routine
        private func internalSetup() {
            setupViews()
            addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        }

        deinit {
            paymentTask?.cancel()
        }

        // --- Action ---
        @objc private func handleTap() {
            guard !isProcessing else { return }
            // Use the internally stored session
            guard let currentSession = session else {
                print("Payrails.PayPalButton Error: Internal Session is missing. Button was likely not created via Payrails.createPayPalButton().")
                return
            }
            guard let currentPresenter = presenter else {
                print("Payrails.PayPalButton Error: Payment Presenter is not configured.")
                // Maybe notify delegate? delegate?.payPalButton(self, didFailWithError: ...)
                return
            }

            isProcessing = true
            paymentTask?.cancel()

            paymentTask = Task { [weak self] in
                // Capture session/presenter safely for async context
                guard let self = self else { return }
                do {
                    let result: OnPayResult? = await currentSession.executePayment(
                        with: .payPal,
                        saveInstrument: false,
                        presenter: currentPresenter
                    )
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard self.isProcessing else { return }
                        self.delegate?.payPalButton(self, didFinishPaymentWithResult: result)
                        self.isProcessing = false
                    }
                } catch is CancellationError {
                    await MainActor.run { self.isProcessing = false }
                } catch {
                    await MainActor.run {
                         let payrailsError = PayrailsError.unknown(error: error)
                         self.delegate?.payPalButton(self, didFinishPaymentWithResult: .error(payrailsError))
                         self.isProcessing = false
                    }
                }
            }
        }

        // --- Overrides for UI (setupViews, show(loading:), setTitle, etc.) ---
        // (Keep the UI implementation details from the previous version)
        override public var titleLabel: UILabel? { return prefixLabel }
        override public func setTitle(_ title: String?, for state: UIControl.State) {
            super.setTitle(title, for: state) // Let ActionButton handle internal state if needed
            if state == .normal { prefixLabel.text = title }
        }
        override func setupViews() {
             super.setupViews()
             backgroundColor = UIColor(red: 255/255, green: 204/255, blue: 0/255, alpha: 1)
             layer.cornerRadius = 6.0
             clipsToBounds = true
             let stackView = UIStackView()
             stackView.axis = .horizontal
             stackView.isUserInteractionEnabled = false
             stackView.distribution = .fill
             stackView.translatesAutoresizingMaskIntoConstraints = false
             stackView.spacing = 8
             stackView.alignment = .center
             prefixLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
             prefixLabel.textColor = UIColor(red: 0/255, green: 50/255, blue: 100/255, alpha: 1)
             prefixLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
             prefixLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
             paypalImageView.image = UIImage(named: "PayPal", in: Bundle(for: PayPalButton.self), compatibleWith: nil) // Ensure image setup is here
             paypalImageView.contentMode = .scaleAspectFit
             paypalImageView.translatesAutoresizingMaskIntoConstraints = false
             paypalImageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
             paypalImageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
             stackView.addArrangedSubview(prefixLabel)
             stackView.addArrangedSubview(paypalImageView)
             addSubview(stackView)
             NSLayoutConstraint.activate([ /* ... constraints ... */ ])
        }
         override func show(loading: Bool) {
             super.show(loading: loading)
             prefixLabel.isHidden = loading
             paypalImageView.isHidden = loading
         }
    }
}
