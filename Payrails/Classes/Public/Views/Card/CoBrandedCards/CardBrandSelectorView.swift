//  CardBrandSelectorView.swift
//  Co-branded cards — UI layer.
//  The brand-picker shown under the card number when a co-branded card is detected: a titled row of
//  tappable scheme tiles. Driven by `CardForm` (which feeds it from `CoBrandedSchemeState`) and
//  reports the user's pick back via `onSchemeSelected`. `CardBrandSelectorTileButton` is its private tile.

import UIKit

internal final class CardBrandSelectorView: UIStackView {
    static let defaultTitle = "Card Brand"
    static let defaultSubtitle = "You can select the card brand you prefer to pay with. This is optional."

    var onSchemeSelected: ((CardType) -> Void)?

    private let titleText: String
    private let subtitleText: String
    private let style: CardBrandSelectorStyle?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tilesStack = UIStackView()
    private var buttonsByCardType: [CardType: CardBrandSelectorTileButton] = [:]
    private var selectedCardType: CardType?
    // In-flight logo fetches, cancelled when tiles are re-rendered or the selector is hidden so a
    // stale BIN's image can't land on a recycled tile.
    private var iconTasks: [URLSessionDataTask] = []

    var schemeButtonsForTesting: [UIButton] {
        tilesStack.arrangedSubviews.compactMap { $0 as? UIButton }
    }

    var selectedCardTypeForTesting: CardType? {
        selectedCardType
    }

    var titleTextForTesting: String? { titleLabel.text }
    var subtitleTextForTesting: String? { subtitleLabel.text }
    var titleColorForTesting: UIColor? { titleLabel.textColor }

    init(
        title: String = CardBrandSelectorView.defaultTitle,
        subtitle: String = CardBrandSelectorView.defaultSubtitle,
        style: CardBrandSelectorStyle? = nil
    ) {
        self.titleText = title
        self.subtitleText = subtitle
        self.style = style
        super.init(frame: .zero)
        setup()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(cardTypes: [CardType], selected: CardType?) {
        guard cardTypes.count >= 2 else {
            isHidden = true
            selectedCardType = nil
            tilesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            cancelIconTasks()
            buttonsByCardType.removeAll()
            return
        }

        isHidden = false
        let nextSelection = selected ?? cardTypes.first
        selectedCardType = nextSelection
        renderTiles(cardTypes: cardTypes)
        syncSelection()
    }

    private func setup() {
        axis = .vertical
        spacing = 8
        isHidden = true

        titleLabel.text = titleText
        titleLabel.font = style?.titleFont ?? .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = style?.titleColor ?? .label

        subtitleLabel.text = subtitleText
        subtitleLabel.font = style?.subtitleFont ?? .systemFont(ofSize: 12)
        subtitleLabel.textColor = style?.subtitleColor ?? .secondaryLabel
        subtitleLabel.numberOfLines = 0

        tilesStack.axis = .horizontal
        tilesStack.alignment = .fill
        tilesStack.distribution = .fillEqually
        tilesStack.spacing = 8

        addArrangedSubview(titleLabel)
        addArrangedSubview(subtitleLabel)
        addArrangedSubview(tilesStack)
    }

    private func renderTiles(cardTypes: [CardType]) {
        let existingTypes = tilesStack.arrangedSubviews.compactMap { view -> CardType? in
            guard let button = view as? CardBrandSelectorTileButton else { return nil }
            return buttonsByCardType.first(where: { $0.value === button })?.key
        }
        guard existingTypes != cardTypes else { return }

        tilesStack.arrangedSubviews.forEach { view in
            tilesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        cancelIconTasks()
        buttonsByCardType.removeAll()

        for cardType in cardTypes {
            let button = makeTile(for: cardType)
            buttonsByCardType[cardType] = button
            tilesStack.addArrangedSubview(button)
        }
    }

    private func makeTile(for cardType: CardType) -> CardBrandSelectorTileButton {
        let button = CardBrandSelectorTileButton(cardType: cardType, style: style)
        button.accessibilityTraits = [.button]
        button.addAction(UIAction { [weak self] _ in
            self?.select(cardType, notify: true)
        }, for: .touchUpInside)
        loadIcon(for: cardType, into: button)
        return button
    }

    private func loadIcon(for cardType: CardType, into button: UIButton) {
        guard let iconURL = CardNetwork.from(cardType: cardType)?.iconURL else { return }
        let task = TextField.cardIconImageFetcher(iconURL) { [weak button] image in
            DispatchQueue.main.async {
                guard let tile = button as? CardBrandSelectorTileButton, let image else { return }
                tile.logoImage = image
            }
        }
        if let task { iconTasks.append(task) }
    }

    private func cancelIconTasks() {
        iconTasks.forEach { $0.cancel() }
        iconTasks.removeAll()
    }

    private func select(_ cardType: CardType, notify: Bool) {
        guard selectedCardType != cardType else { return }
        selectedCardType = cardType
        syncSelection()
        if notify {
            onSchemeSelected?(cardType)
        }
    }

    private func syncSelection() {
        for (cardType, button) in buttonsByCardType {
            let isSelected = cardType == selectedCardType
            button.applySelectedState(isSelected)
            button.accessibilityTraits = isSelected ? [.button, .selected] : [.button]
        }
    }
}

private final class CardBrandSelectorTileButton: UIButton {
    private let logoImageView = UIImageView()
    private let nameLabel = UILabel()
    private let checkContainer = UIView()
    private let checkImageView = UIImageView()
    private let style: CardBrandSelectorStyle?

    var logoImage: UIImage? {
        get { logoImageView.image }
        set { logoImageView.image = newValue?.withRenderingMode(.alwaysOriginal) }
    }

    init(cardType: CardType, style: CardBrandSelectorStyle?) {
        self.style = style
        super.init(frame: .zero)
        setup(cardType: cardType)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applySelectedState(_ isSelected: Bool) {
        let selectedColor = style?.selectedTileBorderColor ?? .systemBlue
        let unselectedColor = style?.tileBorderColor ?? .separator
        layer.borderColor = (isSelected ? selectedColor : unselectedColor).cgColor
        checkContainer.layer.borderColor = (isSelected ? selectedColor : unselectedColor).cgColor
        checkContainer.backgroundColor = isSelected ? selectedColor : .clear
        checkImageView.isHidden = !isSelected
    }

    private func setup(cardType: CardType) {
        backgroundColor = style?.tileBackgroundColor ?? .systemBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1

        heightAnchor.constraint(equalToConstant: 48).isActive = true

        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logoImageView.widthAnchor.constraint(equalToConstant: 56),
            logoImageView.heightAnchor.constraint(equalToConstant: 24)
        ])

        nameLabel.text = cardType.instance.defaultName
        nameLabel.font = style?.tileTitleFont ?? .systemFont(ofSize: 14)
        nameLabel.textColor = style?.tileTitleColor ?? .label
        nameLabel.numberOfLines = 1
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.8
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        checkImageView.image = UIImage(systemName: "checkmark")
        checkImageView.tintColor = .white
        checkImageView.contentMode = .scaleAspectFit
        checkImageView.isHidden = true
        checkImageView.translatesAutoresizingMaskIntoConstraints = false

        checkContainer.layer.cornerRadius = 9
        checkContainer.layer.borderWidth = 1
        checkContainer.translatesAutoresizingMaskIntoConstraints = false
        checkContainer.addSubview(checkImageView)
        NSLayoutConstraint.activate([
            checkContainer.widthAnchor.constraint(equalToConstant: 18),
            checkContainer.heightAnchor.constraint(equalToConstant: 18),
            checkImageView.centerXAnchor.constraint(equalTo: checkContainer.centerXAnchor),
            checkImageView.centerYAnchor.constraint(equalTo: checkContainer.centerYAnchor),
            checkImageView.widthAnchor.constraint(equalToConstant: 12),
            checkImageView.heightAnchor.constraint(equalToConstant: 12)
        ])

        let contentStack = UIStackView(arrangedSubviews: [logoImageView, nameLabel, checkContainer])
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 8
        contentStack.isUserInteractionEnabled = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        applySelectedState(false)
    }
}
