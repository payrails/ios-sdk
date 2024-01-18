import UIKit

public final class CardSubmitButton: ActionButton {
    override func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .init(
            red: 255/255,
            green: 204/255,
            blue: 0/255, alpha: 1
        )
        layer.cornerRadius = 6.0
        setTitle("Confirm payment", for: .normal)
    }
}

public class ActionButton: UIButton, Loadingable {
    public var onTap: (() -> Void)?

    private let indicatorView = UIActivityIndicatorView(style: .medium)
    private var currentText: String?

    public required init() {
        super.init(frame: .zero)
        setupViews()
        setupOnTap()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOnTap()
    }

    func setupViews() {}

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

    func show(loading: Bool) {
        indicatorView.removeFromSuperview()
        if loading {
            currentText = title(for: .normal)
            setTitle(nil, for: .normal)
            addSubview(indicatorView)
            indicatorView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate(
                [
                    indicatorView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                    indicatorView.centerYAnchor.constraint(equalTo: self.centerYAnchor)
                ]
            )
            indicatorView.startAnimating()
        } else if let currentText, !currentText.isEmpty {
            setTitle(currentText, for: .normal)
        }
    }
}


protocol Loadingable {
    func show(loading: Bool)
}
