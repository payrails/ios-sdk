import Foundation
import UIKit

class DropInPaymentView: UIView, Loadingable {

    private let payButton = PaymentButton()
    private let payParentView = UIView()
    private let bottomStackView = UIStackView()
    private let topButton = ActionButton()

    func show(loading: Bool) {
        payButton.show(loading: loading)
    }
    
    var isSelected: Bool = false {
        didSet {
            payParentView.isHidden = !isSelected

            if isSelected && bottomStackView.alpha == 1.0 {
                bottomStackView.alpha = 0.0
                UIView.animate(withDuration: 0.66) {
                    self.bottomStackView.alpha = 1.0
                }
            }
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
        with text: String?,
        insideView: UIView? = nil
    ) {
        super.init(frame: .zero)
        let stackView = UIStackView()
        addSubview(stackView)

        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 0

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
        stackView.addArrangedSubview(payParentView)

        bottomStackView.axis = .vertical
        bottomStackView.spacing = 12

        if let insideView {
            bottomStackView.addArrangedSubview(insideView)
        }
        bottomStackView.addArrangedSubview(payButton)

        payParentView.addSubview(bottomStackView)
        payParentView.isHidden = true

        payButton.onTap = onPay
        payButton.setTitle("Pay", for: .normal)
        payButton.setTitleColor(.black.withAlphaComponent(0.81), for: .normal)
        payButton.titleLabel?.font = .systemFont(ofSize: 15)
        payButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 16, right: 10)
        bottomStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate(
            [
                bottomStackView.topAnchor.constraint(equalTo: payParentView.topAnchor, constant: 6),
                bottomStackView.bottomAnchor.constraint(equalTo: payParentView.bottomAnchor, constant: -6),
                bottomStackView.leadingAnchor.constraint(equalTo: payParentView.leadingAnchor, constant: 12),
                bottomStackView.trailingAnchor.constraint(equalTo: payParentView.trailingAnchor, constant: -12),
            ]
        )
        payButton.layer.cornerRadius = 6
        payButton.layer.borderColor = UIColor.black.withAlphaComponent(0.81).cgColor
        payButton.layer.borderWidth = 1

        stackView.layer.cornerRadius = 6
        stackView.layer.borderColor = UIColor.black.withAlphaComponent(0.81).cgColor
        stackView.layer.borderWidth = 1
    }

    required init?(coder: NSCoder) { nil }
}
