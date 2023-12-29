import Foundation
import UIKit


enum DropInPaymentType {
    case stored(StoredInstrument)
    case new(Payrails.PaymentType, storePayment: Bool)
}

final public class DropInView: UIView {

    private let config: SDKConfig
    private let formConfig: CardFormConfig
    private let session: Payrails.Session

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let ccFields: [CardField]
    internal var onPay: ((DropInPaymentType) -> Void)?

    init(
        with config: SDKConfig,
        session: Payrails.Session,
        formConfig: CardFormConfig = CardFormConfig.defaultConfig
    ) {
        self.config = config
        self.formConfig = formConfig
        self.session = session
        self.ccFields = session.cardSession?.buildCardFields(with: formConfig) ?? []
        super.init(frame: .zero)
        setupViews()
    }

    func hideLoading() {
        self.isUserInteractionEnabled = true
        stackView.arrangedSubviews.filter { $0 is Loadingable }.forEach { view in
            (view as? Loadingable)?.show(loading: false)
        }
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
        stackView.spacing = 12

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
        if session.isPaymentAvailable(type: .card),
           !ccFields.isEmpty {
            let cardView = buildCardView()
            stackView.addArrangedSubview(cardView)
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
                self?.onPay?(.new(type, storePayment: false))
            }
            button = applePayButton
        case .payPal:
            let payPalButton = PayPalButton()
            payPalButton.onTap = { [weak self] in
                payPalButton.show(loading: true)
                self?.onPay?(.new(type, storePayment: false))
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
        let button = DropInPaymentView(with: title)
        button.onTap = { [weak self] in
            self?.stackView.arrangedSubviews.forEach { view in
                if let view = view as? DropInPaymentView {
                    view.isSelected = false
                }
            }
            button.isSelected = !button.isSelected
            UIView.animate(withDuration: 0.3) {
                self?.stackView.layoutIfNeeded()
            }
        }
        button.onPay = { [weak self] in
            self?.isUserInteractionEnabled = false
            button.show(loading: true)
            self?.onPay?(.stored(item))
        }
        return button
    }

    private func buildCardView() -> UIView {
        let cardView = DropInCardView(fields: ccFields)
        let button = DropInPaymentView(with: "Card", insideView: cardView)
        button.onTap = { [weak self] in
            self?.stackView.arrangedSubviews.forEach { view in
                if let view = view as? DropInPaymentView {
                    view.isSelected = false
                }
            }
            button.isSelected = !button.isSelected
            UIView.animate(withDuration: 0.3) {
                self?.stackView.layoutIfNeeded()
            }
        }
        button.onPay = { [weak self, weak cardView] in
            self?.isUserInteractionEnabled = false
            button.show(loading: true)
            self?.onPay?(.new(.card, storePayment: cardView?.savePayment ?? false))
        }
        return button
    }
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
                view.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -40),
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
