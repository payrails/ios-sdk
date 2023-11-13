import Foundation
import UIKit


enum DropInPaymentType {
    case stored(StoredInstrument)
    case new(Payrails.PaymentType)
}

final public class DropInView: UIView {

    private let config: SDKConfig
    private let formConfig: CardFormConfig
    private let session: Payrails.Session

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let onPay: ((DropInPaymentType) -> Void)

    init(
        with config: SDKConfig,
        session: Payrails.Session,
        formConfig: CardFormConfig = CardFormConfig.defaultConfig,
        onPay: @escaping ((DropInPaymentType) -> Void)
    ) {
        self.config = config
        self.formConfig = formConfig
        self.session = session
        self.onPay = onPay
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate(
            [
                scrollView.topAnchor.constraint(equalTo: self.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            ]
        )

        scrollView.addSubview(stackView)
        stackView.axis = .vertical
        stackView.spacing = 6

        scrollView.setup(with: stackView)

        setupPayments()
    }

    private func setupPayments() {
        let cardPayments = session.storedInstruments(for: .card)
        let paypalPayments = session.storedInstruments(for: .payPal)

        cardPayments.forEach { item in
            let button = self.buildPaymentView(with: item, title: item.description)
            stackView.addArrangedSubview(button)
        }

        paypalPayments.forEach { item in
            let button = self.buildPaymentView(with: item, title: item.email)
            stackView.addArrangedSubview(button)
        }
        if session.isApplePayAvailable {
            stackView.addArrangedSubview(buildPaymentButton(for: .applePay))
        }
        if session.isPaymentAvailable(type: .payPal) {
            stackView.addArrangedSubview(buildPaymentButton(for: .payPal))

        }
        layoutSubviews()
    }

    private func buildPaymentButton(for type: Payrails.PaymentType) -> UIView {
        let button: UIButton

        switch type {
        case .applePay:
            let applePayButton = ApplePayButton()
            applePayButton.onTap = { [weak self] in
                self?.onPay(.new(type))
            }
            button = applePayButton
        case .payPal:
            let payPalButton = PayPalButton()
            payPalButton.onTap = { [weak self] in
                self?.onPay(.new(type))
            }
            button = payPalButton
        case .card:
            return UIView()
        }

        let parentView = UIView()
        parentView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(
            [
                button.topAnchor.constraint(equalTo: parentView.topAnchor),
                button.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 12),
                button.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -12),
                button.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
                button.heightAnchor.constraint(equalToConstant: 46)
            ]
        )
        return parentView
    }

    private func buildPaymentView(with item: StoredInstrument, title: String?) -> UIView {
        let button = PaymentView(with: title)
        button.onTap = { [weak self] in
            self?.stackView.arrangedSubviews.forEach { view in
                if let view = view as? PaymentView {
                    view.isSelected = false
                }
            }
            button.isSelected = !button.isSelected
            UIView.animate(withDuration: 0.3) {
                self?.stackView.layoutIfNeeded()
            }
        }
        button.onPay = { [weak self] in
            self?.onPay(.stored(item))
        }
        return button
    }

}

private class PaymentView: UIView {

    private let payButton = PaymentButton()
    private let topButton = ActionButton()
    var isSelected: Bool = false {
        didSet {
            payButton.isHidden = !isSelected
        }
    }

    var onTap: (() -> Void)? = nil {
        didSet {
            topButton.onTap = onTap
        }
    }

    var onPay: (() -> Void)? = nil {
        didSet {
            payButton.onTap = onPay
        }
    }

    init(
        with text: String?
    ) {
        super.init(frame: .zero)
        let stackView = UIStackView()
        addSubview(stackView)

        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 6

        let top = stackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 0)
        let bottom = stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0)
        let leading = stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 12)
        let trailing = stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12)

        top.priority = .defaultHigh
        bottom.priority = .defaultLow
        leading.priority = .defaultHigh
        trailing.priority = .defaultHigh

        NSLayoutConstraint.activate(
            [
                top,
                bottom,
                leading,
                trailing
            ]
        )

        topButton.setTitle(text ?? "-", for: .normal)
        topButton.onTap = onTap
        topButton.contentHorizontalAlignment = .left
        topButton.contentEdgeInsets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 10)
        topButton.setTitleColor(.black.withAlphaComponent(0.81), for: .normal)
        topButton.titleLabel?.font = .systemFont(ofSize: 12)

        stackView.addArrangedSubview(topButton)
        stackView.addArrangedSubview(payButton)


        payButton.onTap = onPay
        payButton.setTitle("Pay", for: .normal)
        payButton.isHidden = true
        payButton.setTitleColor(.black.withAlphaComponent(0.81), for: .normal)
        payButton.titleLabel?.font = .systemFont(ofSize: 15)
        payButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 16, right: 10)

        stackView.layer.cornerRadius = 6
        stackView.layer.borderColor = UIColor.systemGray.cgColor
        stackView.layer.borderWidth = 1
    }
    
    required init?(coder: NSCoder) { nil }
}

private class PaymentButton: ActionButton {

}

private extension UIScrollView {
    func setup(with view: UIView) {
        subviews.forEach {
            $0.removeFromSuperview()
        }

        addSubview(view)

        NSLayoutConstraint.activate(
            [
                view.topAnchor.constraint(equalTo: self.topAnchor),
                view.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                self.widthAnchor.constraint(equalTo: view.widthAnchor)
            ]
        )

        view.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        isDirectionalLockEnabled = true
        isScrollEnabled = true
        showsHorizontalScrollIndicator = false
    }
}
