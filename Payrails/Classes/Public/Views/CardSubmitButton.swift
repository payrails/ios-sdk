import UIKit

public final class CardSubmitButton: UIButton {
    public var onTap: (() -> Void)?

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
        setTitle("Confirm payment", for: .normal)
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
