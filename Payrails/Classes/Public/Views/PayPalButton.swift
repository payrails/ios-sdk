import UIKit

public final class PayPalButton: ActionButton {
    private let prefixLabel = UILabel()
    private let paypalImageView = UIImageView(
        image: UIImage(
            named: "PayPal",
            in: Bundle(for: PayPalButton.self),
            with: nil
        )
    )

    override public var titleLabel: UILabel? {
        return prefixLabel
    }

    override public func setTitle(_ title: String?, for state: UIControl.State) {
        prefixLabel.text = title
    }

    override func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .init(
            red: 255/255,
            green: 204/255,
            blue: 0/255, alpha: 1
        )
        layer.cornerRadius = 6.0

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.isUserInteractionEnabled = false
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 8
        stackView.alignment = .center

        paypalImageView.contentMode = .scaleAspectFit

        stackView.addArrangedSubview(prefixLabel)
        stackView.addArrangedSubview(paypalImageView)
        addSubview(stackView)

        NSLayoutConstraint.activate(
            [
                paypalImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.66),
                paypalImageView.widthAnchor.constraint(equalTo: paypalImageView.heightAnchor, multiplier: 3.75),
                stackView.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 6.0),
                stackView.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: 6.0),
                stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
                stackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
            ]
        )
    }

    override func show(loading: Bool) {
        super.show(loading: loading)
        prefixLabel.isHidden = loading
        paypalImageView.isHidden = loading
    }
}
