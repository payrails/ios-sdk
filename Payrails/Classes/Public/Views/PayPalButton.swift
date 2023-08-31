import UIKit

public final class PayPalButton: UIButton {
    public var onTap: (() -> Void)?

    private let prefixLabel = UILabel()

    override public var titleLabel: UILabel? {
        return prefixLabel
    }

    override public func setTitle(_ title: String?, for state: UIControl.State) {
        prefixLabel.text = title
    }

    public required init() {
        super.init(frame: .zero)
        setupViews()
        setupOnTap()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOnTap()
    }

    private func setupViews() {
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

        let logo = UIImage(
            named: "PayPal",
            in: Bundle(for: PayPalButton.self),
            with: nil
        )

        let imageView = UIImageView(image: logo)
        imageView.contentMode = .scaleAspectFit

        stackView.addArrangedSubview(prefixLabel)
        stackView.addArrangedSubview(imageView)
        addSubview(stackView)

        NSLayoutConstraint.activate(
            [
                imageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.66),
                imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 3.75),
                stackView.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 6.0),
                stackView.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: 6.0),
                stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
                stackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
            ]
        )
    }

    private func setupOnTap() {
        addTarget(
            self,
            action: #selector(didTap),
            for: .touchUpInside
        )
    }

    @objc private func didTap() {
        onTap?()
    }

}
