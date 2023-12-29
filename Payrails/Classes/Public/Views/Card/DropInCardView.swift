import UIKit
import Skyflow

class DropInCardView: UIView {
    private let cardParentView = UIView()
    private let fields: [CardField]
    private let savePaymentSwitch = UISwitch()

    var savePayment: Bool {
        savePaymentSwitch.isOn
    }

    init(fields: [CardField]) {
        self.fields = fields
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { nil }

    private func setupViews() {
        self.translatesAutoresizingMaskIntoConstraints = false

        let mainStackView = UIStackView()
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.spacing = 4
        mainStackView.axis = .vertical

        addSubview(mainStackView)
        NSLayoutConstraint.activate(
            [
                mainStackView.topAnchor.constraint(equalTo: self.topAnchor),
                mainStackView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                mainStackView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                mainStackView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
            ]
        )

        if let cardField = fields.first(where: { $0.type == .CARD_NUMBER }) {
            mainStackView.addArrangedSubview(cardField.textField)
            cardField.textField.removeTitle()
            cardField.textField.removeError()
        }

        if let nameField = fields.first(where: { $0.type == .CARDHOLDER_NAME }) {
            mainStackView.addArrangedSubview(nameField.textField)
            nameField.textField.removeTitle()
            nameField.textField.removeError()
        }

        let rowStackView = UIStackView()
        rowStackView.spacing = 0
        rowStackView.axis = .horizontal
        rowStackView.distribution = .fillEqually
        rowStackView.spacing = 4

        if let monthField = fields.first(where: { $0.type == .EXPIRATION_MONTH }) {
            rowStackView.addArrangedSubview(monthField.textField)
            monthField.textField.removeTitle()
            monthField.textField.removeError()
        }
        
        if let yearField = fields.first(where: { $0.type == .EXPIRATION_YEAR }) {
            rowStackView.addArrangedSubview(yearField.textField)
            yearField.textField.removeTitle()
            yearField.textField.removeError()
        }

        if let cvcField = fields.first(where: { $0.type == .CVV}) {
            rowStackView.addArrangedSubview(cvcField.textField)
            cvcField.textField.removeTitle()
            cvcField.textField.removeError()
        }
        
        mainStackView.addArrangedSubview(rowStackView)

        let switchStackView = UIStackView()

        switchStackView.axis = .horizontal
        switchStackView.spacing = 12

        let explanationLabel = UILabel()
        explanationLabel.text = "Save instrument for future payments"
        explanationLabel.font = .systemFont(ofSize: 12)
        explanationLabel.textColor = .black.withAlphaComponent(0.8)

        switchStackView.addArrangedSubview(savePaymentSwitch)
        switchStackView.addArrangedSubview(explanationLabel)

        mainStackView.addArrangedSubview(switchStackView)
    }

}


private extension TextField {

    func removeTitle() {
        let stackView = subviews.first(where: { $0 is UIStackView} ) as? UIStackView
        stackView?.arrangedSubviews.first(where: { $0 is UILabel })?.removeFromSuperview()
    }

    func removeError() {
        let stackView = subviews.first(where: { $0 is UIStackView} ) as? UIStackView
        stackView?.arrangedSubviews.last(where: { $0 is UILabel })?.removeFromSuperview()
    }
}
