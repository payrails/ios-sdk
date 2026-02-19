import UIKit
import PayrailsCSE

final class CardFormStylingViewController: UIViewController, PayrailsCardFormDelegate {
    // MARK: - Demo Mock Data
    // Replace these with real values when integrating with a live session
    private let demoTableName = "cards"
    private let demoHolderReference = "holder_demo_123"

    // Mock/demo CSE instance
    private lazy var cseInstance: PayrailsCSE = {
        // In a real app, configure with your CSE public key and version.
        // For demo purposes we construct with placeholders.
        do {
            return try PayrailsCSE(data: "MOCK_PUBLIC_KEY", version: "1")
        } catch {
            fatalError("Failed to initialize PayrailsCSE: \(error)")
        }
    }()

    // MARK: - Views
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Captions
    private let defaultCaption = UILabel()
    private let customCaption = UILabel()

    // Card forms
    private var defaultForm: Payrails.CardForm!
    private var customForm: Payrails.CardForm!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Card Form Styling"
        view.backgroundColor = .systemBackground

        setupLayout()
        setupForms()
    }

    // MARK: - Layout
    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Forms
    private func setupForms() {
        // Default styling form
        defaultCaption.text = "Default styling"
        defaultCaption.font = .preferredFont(forTextStyle: .headline)
        contentStack.addArrangedSubview(defaultCaption)

        let defaultConfig = CardFormConfig(
            showNameField: true,
            showSaveInstrument: true,
            showCardIcon: true,
            showRequiredAsterisk: true,
            cardIconAlignment: .left,
            styles: CardFormStylesConfig(
                wrapperStyle: CardWrapperStyle(backgroundColor: UIColor.secondarySystemBackground, borderColor: nil, borderWidth: nil, cornerRadius: 12, padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)),
                fieldSpacing: 10,
                sectionSpacing: 20
            ),
            translations: nil
        )

        defaultForm = Payrails.CardForm(
            config: defaultConfig,
            tableName: demoTableName,
            cseConfig: (data: "MOCK_PUBLIC_KEY", version: "1"),
            holderReference: demoHolderReference,
            cseInstance: cseInstance
        )
        defaultForm.delegate = self
        contentStack.addArrangedSubview(defaultForm)

        // Customized form (Phase 1)
        customCaption.text = "Phase 1 customizations: icon visible, right-aligned; asterisk hidden; button height 60pt; custom spacing"
        customCaption.font = .preferredFont(forTextStyle: .headline)
        contentStack.addArrangedSubview(customCaption)

        let customStyles = CardFormStylesConfig(
            wrapperStyle: CardWrapperStyle(backgroundColor: UIColor.secondarySystemBackground, borderColor: UIColor.systemBlue, borderWidth: 1, cornerRadius: 12, padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)),
            fieldSpacing: 14,
            sectionSpacing: 28
        )

        let customConfig = CardFormConfig(
            showNameField: true,
            showSaveInstrument: true,
            showCardIcon: true,
            showRequiredAsterisk: false,
            cardIconAlignment: .right,
            styles: customStyles,
            translations: nil
        )

        customForm = Payrails.CardForm(
            config: customConfig,
            tableName: demoTableName,
            cseConfig: (data: "MOCK_PUBLIC_KEY", version: "1"),
            holderReference: demoHolderReference,
            cseInstance: cseInstance
        )
        customForm.delegate = self
        contentStack.addArrangedSubview(customForm)
    }

    // MARK: - PayrailsCardFormDelegate
    func cardForm(_ view: Payrails.CardForm, didCollectCardData data: String) {
        // For demo, show a quick alert with the encrypted payload length
        let alert = UIAlertController(title: "Collected", message: "Encrypted payload length: \(data.count)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
