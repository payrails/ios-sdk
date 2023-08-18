import UIKit
import PassKit

public class ApplePayButton: PKPaymentButton {
    public var onTap: (() -> Void)?

    public override init(paymentButtonType type: PKPaymentButtonType, paymentButtonStyle style: PKPaymentButtonStyle) {
        super.init(paymentButtonType: type, paymentButtonStyle: style)
        setupOnTap()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOnTap()
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
