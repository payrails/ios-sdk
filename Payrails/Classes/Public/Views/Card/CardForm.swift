import UIKit
import PayrailsCSE

// Protocol for CardForm delegate
public protocol PayrailsCardFormDelegate: AnyObject {
    func cardForm(_ view: Payrails.CardForm, didCollectCardData data: String)
    func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error)

    /// Called when the co-branded scheme set or the selected (preferred) scheme changes: when a
    /// co-branded BIN resolves (default scheme chosen), when the shopper picks a different brand in
    /// the card-brand selector, and when the card number changes so co-branded state clears
    /// (`cardSchemes` empty, `preferredScheme` nil). Mirrors the web SDK's `onPreferredSchemeChanged`
    /// / `onChange.cardSchemes`. Optional — a default no-op is provided below.
    func cardForm(_ view: Payrails.CardForm, didChangePreferredScheme change: PreferredSchemeChange)
}

// Default no-op so adding the method above is source-compatible for merchants that only
// implement the two original callbacks.
public extension PayrailsCardFormDelegate {
    func cardForm(_ view: Payrails.CardForm, didChangePreferredScheme change: PreferredSchemeChange) {}
}

// Extension to Payrails for CardForm
public extension Payrails {

    final class CardCollectContainer: CardContainer {
        public let container: Container<ComposableContainer>

        public init(container: Container<ComposableContainer>) {
            self.container = container
        }

        public func collect(with callback: Callback) {
            container.collect(
                callback: callback
            )
        }
    }

    class CardForm: UIStackView {
        static let defaultConfig: CardFormConfig = {
            let defaultErrorValues: [CardFieldType: String] = [
                .CARDHOLDER_NAME: "Enter name as it appears on card",
                .CARD_NUMBER: "Enter a valid card number",
                .EXPIRATION_DATE: "Enter a valid expiry date (MM/YY)",
                .CVV: "Enter the 3 or 4 digit code",
                .EXPIRATION_MONTH: "Enter a valid month",
                .EXPIRATION_YEAR: "Enter a valid year"
            ]

            let defaultTranslations = CardTranslations(
                placeholders: CardTranslations.Placeholders(values: [
                    .CARDHOLDER_NAME: "Full Name",
                    .CARD_NUMBER: "Card Number",
                    .EXPIRATION_DATE: "MM/YY",
                    .CVV: "CVV",
                    .EXPIRATION_MONTH: "MM",
                    .EXPIRATION_YEAR: "YYYY"
                ]),
                labels: CardTranslations.Labels(
                    saveInstrument: "Save card",
                    storeInstrument: "Remember card",
                    paymentInstallments: "Pay in installments"
                ),
                error: CardTranslations.ErrorMessages(
                    values: defaultErrorValues
                )
            )

            return CardFormConfig(
                showNameField: false,
                translations: defaultTranslations
            )
        }()

        public weak var delegate: PayrailsCardFormDelegate?
        private let config: CardFormConfig
        private let containerClient: Client
        private var container: Container<ComposableContainer>?
        private let tableName: String
        private let holderReference: String
        public var cardContainer: CardCollectContainer?
        private var payrailsCSE: PayrailsCSE?
        private weak var session: Payrails.Session?
        // Constructed after `super.init` because `getCurrentBin` captures `self`.
        private var binLookupService: BinLookupService!
        private weak var cardNumberField: TextField?
        private var binLookupTask: Task<Void, Never>?
        private let coBrandedSchemeState = CoBrandedSchemeState()
        // Built lazily so `config` (set in init) is available for the merchant's title/subtitle
        // translations and selector styling. Falls back to the SDK defaults when unset.
        private lazy var cardBrandSelector = CardBrandSelectorView(
            title: config.translations?.labels.cardBrandSelectorTitle ?? CardBrandSelectorView.defaultTitle,
            subtitle: config.translations?.labels.cardBrandSelectorSubtitle ?? CardBrandSelectorView.defaultSubtitle,
            style: config.styles?.cardBrandSelector
        )
        // Last payload sent to the delegate; used to de-duplicate so layout re-renders that don't
        // actually change the schemes/selection never spam the merchant.
        private var lastEmittedSchemeChange = PreferredSchemeChange(preferredScheme: nil, cardSchemes: [])

        internal var selectedPreferredScheme: String? {
            coBrandedSchemeState.preferredSchemeForPayment
        }

        // Save instrument properties
        public var saveInstrument: Bool = false {
            didSet {
                saveInstrumentToggle.isOn = saveInstrument
            }
        }
        internal let saveInstrumentToggle = UISwitch()
        internal let saveInstrumentLabel = UILabel()

        public init(
            config: CardFormConfig,
            session: Payrails.Session
        ) {
            self.containerClient = Client()
            self.config = config
            self.tableName = "cards"
            self.holderReference = session.getSDKConfiguration()?.holderRefecerence ?? ""
            self.payrailsCSE = session.getCSEInstance()
            self.session = session

            super.init(frame: .zero)

            // Centralised BIN lookup module: `resolve(bin:)` adds throttle + cache + in-flight
            // de-dup + stale-guard on top of the raw call. `getCurrentBin` lets it discard a
            // response that lands after the user has typed past the BIN it was fetched for.
            self.binLookupService = BinLookupService(
                getCurrentBin: { [weak self] in self?.currentCardNumberBin() ?? "" },
                apiProvider: { [weak session] in session?.apiForBinLookupService }
            )

            let stylesConfig = config.styles ?? CardFormStylesConfig.defaultConfig
            let wrapperStyle = stylesConfig.wrapperStyle ?? CardWrapperStyle.defaultStyle

            if let bgColor = wrapperStyle.backgroundColor {
                self.backgroundColor = bgColor // Apply background color to the view itself
            }
            if let borderColor = wrapperStyle.borderColor {
                self.layer.borderColor = borderColor.cgColor
            }
            if let borderWidth = wrapperStyle.borderWidth {
                self.layer.borderWidth = borderWidth
            }
            if let cornerRadius = wrapperStyle.cornerRadius {
                self.layer.cornerRadius = cornerRadius
                self.clipsToBounds = true
            } else {
                self.clipsToBounds = false
            }

            if let padding = wrapperStyle.padding {
                self.layoutMargins = padding
            }
            self.isLayoutMarginsRelativeArrangement = true // Always true if using layoutMargins

            setupViews()
        }

        required init(coder: NSCoder) {
            fatalError(
                "Not implemented: please use init(skyflow: Skyflow.Client, config: Skyflow.Configuration)"
            )
        }

        deinit {
            binLookupTask?.cancel()
        }

        private func setupViews() {
            let stylesConfig = config.styles ?? CardFormStylesConfig.defaultConfig
            let defaultLabelStyle = CardStyle(textColor: .secondaryLabel)
            let defaultErrorStyle = CardStyle(textColor: .systemRed)
            let containerErrorStyle = stylesConfig.errorTextStyle ?? defaultErrorStyle
            let containerHorizontalInsets = Self.resolveComposableHorizontalInsets(stylesConfig: stylesConfig)
            let containerStyles = containerHorizontalInsets.map { Styles(base: Style(padding: $0)) }
            let iconAlignment = config.cardIconAlignment
            let layoutRows = sanitizedLayoutRows(from: resolvedLayoutRows())

            guard !layoutRows.isEmpty else {
                print("Card form layout does not contain supported fields")
                return
            }

            guard let container = self.containerClient.container(
                type: ContainerType.COMPOSABLE,
                options: ContainerOptions(
                    layout: layoutRows.map(\.count),
                    styles: containerStyles,
                    errorTextStyles: Styles(base: containerErrorStyle)
                )
            ) else {
                print("Failed to create Composable Container")
                return
            }

            container.composableRowSpacing = stylesConfig.fieldSpacing
            container.onLayoutInvalidationRequested = { [weak self] in
                self?.requestLayoutRefresh()
            }
            self.container = container
            self.cardContainer = CardCollectContainer(container: container)

            for fieldType in layoutRows.flatMap({ $0 }) {
                guard let input = makeCollectInput(
                    for: fieldType,
                    stylesConfig: stylesConfig,
                    defaultLabelStyle: defaultLabelStyle,
                    containerErrorStyle: containerErrorStyle,
                    iconAlignment: iconAlignment
                ) else {
                    continue
                }
                let options = CollectElementOptions(
                    required: true,
                    enableCardIcon: config.showCardIcon,
                    enableCopy: false,
                    showRequiredAsterisk: config.showRequiredAsterisk,
                    fieldVariant: config.fieldVariant
                )
                let field = container.create(input: input, options: options)
                if fieldType == .CARD_NUMBER {
                    cardNumberField = field
                }
            }

            container.setupDynamicCVVLengthHandling()
            setupCoBrandedCardsHandling()

            self.axis = .vertical
            self.spacing = stylesConfig.fieldSpacing ?? 10

            do {
                let composableView = try container.getComposableView()
                self.addArrangedSubview(composableView)
            } catch {
                print("Error getting composable view: \(error)")
            }

            self.addArrangedSubview(cardBrandSelector)

            if config.showSaveInstrument {
                setupSaveInstrumentToggle()
            }
        }

        private func setupCoBrandedCardsHandling() {
            guard session?.isCoBrandedCardsEnabled() == true,
                  let cardNumberField else {
                cardBrandSelector.isHidden = true
                return
            }

            cardBrandSelector.onSchemeSelected = { [weak self] cardType in
                guard let self,
                      self.coBrandedSchemeState.selectScheme(displayName: cardType.instance.defaultName) else {
                    return
                }
                self.applyCoBrandedSchemesToCardField()
            }

            // We chain onto the field's existing onChangeHandler rather than registering a separate
            // observer. NOTE: anything that assigns `onChangeHandler` after this setup would replace
            // this chain — if a multi-listener hook is added to the field later, migrate to it.
            let existingOnChange = cardNumberField.onChangeHandler
            cardNumberField.onChangeHandler = { [weak self] state in
                existingOnChange?(state)
                self?.handleCardNumberChange(state)
            }
        }

        private func handleCardNumberChange(_ state: [String: Any]) {
            // The change-handler is only installed when co-branded is enabled at setup, so there's
            // no need to re-evaluate the feature flag on every keystroke — just bail if the session
            // has gone away.
            guard let session else {
                resetCoBrandedSchemes()
                return
            }

            if let selectedSchemeName = state["selectedCardScheme"] as? String,
               coBrandedSchemeState.selectScheme(displayName: selectedSchemeName) {
                applyCoBrandedSchemesToCardField()
            }

            let bin = Self.normalizedBin(from: state)
            if coBrandedSchemeState.clearIfBinChanged(bin) {
                applyCoBrandedSchemesToCardField()
            }

            guard bin.count >= BinLookupService.binLookupLength else {
                binLookupTask?.cancel()
                resetCoBrandedSchemes()
                return
            }

            // The module owns throttling, caching, in-flight de-dup, and the stale-response guard;
            // the form just hands it the BIN and applies whatever non-nil lookup comes back.
            binLookupTask?.cancel()
            binLookupTask = Task { [weak self, weak session, binLookupService] in
                guard let binLookupService,
                      let lookup = await binLookupService.resolve(bin: bin) else { return }
                await MainActor.run {
                    guard let self, let session, !Task.isCancelled else { return }
                    if self.coBrandedSchemeState.applyLookup(
                        bin: bin,
                        lookup: lookup,
                        preferredSchemes: session.preferredCardSchemes()
                    ) {
                        self.applyCoBrandedSchemesToCardField()
                    }
                }
            }
        }

        private func resetCoBrandedSchemes() {
            guard coBrandedSchemeState.isCoBranded || !coBrandedSchemeState.availableSchemes.isEmpty else {
                return
            }
            coBrandedSchemeState.reset()
            applyCoBrandedSchemesToCardField()
        }

        private func applyCoBrandedSchemesToCardField() {
            var options = CollectElementOptions()
            options.cardSchemeMetadata = CardSchemeMetadata(
                schemes: coBrandedSchemeState.availableCardTypes,
                selectedScheme: coBrandedSchemeState.selectedCardType
            )
            cardNumberField?.update(updateOptions: options)
            cardBrandSelector.update(
                cardTypes: coBrandedSchemeState.availableCardTypes,
                selected: coBrandedSchemeState.selectedCardType
            )

            notifyPreferredSchemeChangeIfNeeded()
        }

        /// Emits the current co-branded scheme state to the merchant's delegate, de-duplicated so an
        /// unchanged payload (e.g. from a pure layout refresh) is not re-sent. This is the single
        /// place every transition flows through — BIN resolve, shopper selection, and clear — so the
        /// merchant sees each real change exactly once.
        private func notifyPreferredSchemeChangeIfNeeded() {
            let change = PreferredSchemeChange(
                preferredScheme: coBrandedSchemeState.preferredSchemeForPayment,
                cardSchemes: coBrandedSchemeState.cardSchemes
            )
            guard change != lastEmittedSchemeChange else { return }
            lastEmittedSchemeChange = change
            delegate?.cardForm(self, didChangePreferredScheme: change)
        }

        private func currentCardNumberBin() -> String {
            guard let cardNumberField,
                  let state = (cardNumberField.state as? StateforText)?.getStateForListener() else {
                return ""
            }

            return Self.normalizedBin(from: state)
        }

        private static func normalizedBin(from state: [String: Any]) -> String {
            let value = (state["value"] as? String) ?? ""
            return String(value.filter(\.isNumber).prefix(8))
        }

        private func requestLayoutRefresh() {
            // Defer invalidation to avoid re-entering UIKit fitting during an active layout pass.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.invalidateIntrinsicContentSize()
                self.setNeedsLayout()
                self.superview?.setNeedsLayout()
            }
        }

        internal static func resolveComposableHorizontalInsets(stylesConfig: CardFormStylesConfig) -> UIEdgeInsets? {
            guard let wrapperPadding = stylesConfig.wrapperStyle?.padding else {
                return nil
            }

            let defaultHorizontalPadding = CardWrapperStyle.defaultStyle.padding ?? .zero
            let isHorizontalPaddingUnchanged =
                wrapperPadding.left == defaultHorizontalPadding.left &&
                wrapperPadding.right == defaultHorizontalPadding.right

            // Keep legacy default behavior unless merchant changed wrapper horizontal padding.
            if isHorizontalPaddingUnchanged {
                return nil
            }

            return UIEdgeInsets(top: 0, left: wrapperPadding.left, bottom: 0, right: wrapperPadding.right)
        }

        private func resolvedLayoutRows() -> [[CardFieldType]] {
            if let layout = config.layout {
                return layout.resolvedRows(showNameField: config.showNameField)
            }
            return CardLayoutConfig.defaultRows(showNameField: config.showNameField)
        }

        private func sanitizedLayoutRows(from rows: [[CardFieldType]]) -> [[CardFieldType]] {
            let supportedRows = rows
                .map { row in row.filter { isSupportedField($0) } }
                .filter { !$0.isEmpty }

            if supportedRows.isEmpty {
                return CardLayoutConfig.defaultRows(showNameField: config.showNameField)
            }

            if !CardLayoutConfig.containsRequiredSubmissionFields(in: supportedRows) {
                print("Card form layout is missing required fields; falling back to default layout")
                return CardLayoutConfig.defaultRows(showNameField: config.showNameField)
            }

            return supportedRows
        }

        private func isSupportedField(_ fieldType: CardFieldType) -> Bool {
            switch fieldType {
            case .CARD_NUMBER, .CARDHOLDER_NAME, .CVV, .EXPIRATION_MONTH, .EXPIRATION_YEAR, .EXPIRATION_DATE:
                return true
            default:
                return false
            }
        }

        private func makeCollectInput(
            for fieldType: CardFieldType,
            stylesConfig: CardFormStylesConfig,
            defaultLabelStyle: CardStyle,
            containerErrorStyle: CardStyle,
            iconAlignment: CardIconAlignment
        ) -> CollectElementInput? {
            guard let column = columnName(for: fieldType) else {
                return nil
            }

            let translation = getTranslation(for: fieldType)
            let inputStyle = stylesConfig.effectiveInputStyles(for: fieldType)
            let labelStyle = labelStyle(for: fieldType, stylesConfig: stylesConfig, defaultLabelStyle: defaultLabelStyle)
            // Keep icon alignment available for both static icons and clear button behavior.
            let iconStyle: Styles = Styles(base: CardStyle(cardIconAlignment: iconAlignment))

            return CollectElementInput(
                table: tableName,
                column: column,
                inputStyles: inputStyle.skyflowStyles,
                labelStyles: Styles(base: labelStyle),
                errorTextStyles: Styles(base: containerErrorStyle),
                iconStyles: iconStyle,
                label: translation.label ?? "",
                placeholder: translation.placeholder ?? defaultPlaceholder(for: fieldType),
                type: fieldType,
                customErrorMessage: translation.errorText
            )
        }

        private func getTranslation(for fieldType: CardFieldType) -> (placeholder: String?, label: String?, errorText: String?) {
            let placeholder = config.translations?.placeholders[fieldType]
            let label = config.translations?.labels[fieldType]
            let errorText = config.translations?.error[fieldType]
            return (placeholder, label, errorText)
        }

        private func labelStyle(
            for fieldType: CardFieldType,
            stylesConfig: CardFormStylesConfig,
            defaultLabelStyle: CardStyle
        ) -> CardStyle {
            switch fieldType {
            case .EXPIRATION_MONTH, .EXPIRATION_YEAR:
                return stylesConfig.labelStyles?[fieldType]
                    ?? stylesConfig.labelStyles?[.EXPIRATION_DATE]
                    ?? defaultLabelStyle
            default:
                return stylesConfig.labelStyles?[fieldType] ?? defaultLabelStyle
            }
        }

        private func columnName(for fieldType: CardFieldType) -> String? {
            switch fieldType {
            case .CARD_NUMBER:
                return "card_number"
            case .CARDHOLDER_NAME:
                return "cardholder_name"
            case .CVV:
                return "security_code"
            case .EXPIRATION_MONTH:
                return "expiry_month"
            case .EXPIRATION_YEAR:
                return "expiry_year"
            case .EXPIRATION_DATE:
                return "expiry_date"
            default:
                return nil
            }
        }

        private func defaultPlaceholder(for fieldType: CardFieldType) -> String {
            switch fieldType {
            case .CARD_NUMBER:
                return "•••• •••• •••• ••••"
            case .CARDHOLDER_NAME:
                return "Full Name"
            case .CVV:
                return "•••"
            case .EXPIRATION_MONTH:
                return "MM"
            case .EXPIRATION_YEAR:
                return "YYYY"
            case .EXPIRATION_DATE:
                return "MM/YY"
            default:
                return ""
            }
        }

        public class CardCollectCallback: Callback {
            var onSuccess: ((Any) -> Void)?
            var onFailure: ((Any) -> Void)?

            public func onSuccess(_ responseBody: Any) {
                onSuccess?(responseBody)
            }

            public func onFailure(_ error: Any) {
                onFailure?(error)
            }
        }

        private func setupSaveInstrumentToggle() {
            // Configure label
            let labelText = config.translations?.labels.saveInstrument ?? "Save card"
            saveInstrumentLabel.text = labelText
            saveInstrumentLabel.font = UIFont.systemFont(ofSize: 14)
            saveInstrumentLabel.textColor = .secondaryLabel

            // Create toggle container
            let toggleContainer = UIStackView()
            toggleContainer.axis = .horizontal
            toggleContainer.spacing = 8
            toggleContainer.alignment = .center

            // Add toggle and label to container
            toggleContainer.addArrangedSubview(saveInstrumentLabel)
            toggleContainer.addArrangedSubview(saveInstrumentToggle)

            // Add toggle container to main stack
            self.addArrangedSubview(toggleContainer)

            // Link toggle to property
            saveInstrumentToggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        }

        @objc private func toggleChanged() {
            self.saveInstrument = saveInstrumentToggle.isOn
        }

        public func collectFields() {
            guard let container = self.container else { return }

            let callback = CardCollectCallback()

            callback.onSuccess = { [weak self] responseBody in
                guard let self = self else { return }

                guard
                    let response = responseBody as? [String: Any],
                    let records = response["records"] as? [[String: Any]],
                    let firstRecord = records.first,
                    let fields = firstRecord["fields"] as? [String: Any]
                else {
                    self.notifyCollectionFailure(PayrailsError.invalidDataFormat)
                    return
                }

                guard
                    let cardNumber = fields["card_number"] as? String,
                    let securityCode = fields["security_code"] as? String
                else {
                    self.notifyCollectionFailure(PayrailsError.invalidCardData)
                    return
                }

                guard let expiry = self.resolveExpiry(from: fields) else {
                    self.notifyCollectionFailure(PayrailsError.invalidCardData)
                    return
                }

                let payrailsCard = Card(
                    holderReference: self.holderReference,
                    cardNumber: cardNumber,
                    expiryMonth: expiry.month,
                    expiryYear: expiry.year,
                    holderName: fields["cardholder_name"] as? String,
                    securityCode: securityCode
                )

                guard let payrailsCSE = self.payrailsCSE else {
                    self.notifyCollectionFailure(PayrailsError.missingData("CSE instance"))
                    return
                }

                do {
                    let encryptedCardData = try payrailsCSE.encryptCardData(card: payrailsCard)
                    DispatchQueue.main.async {
                        self.delegate?.cardForm(self, didCollectCardData: encryptedCardData)
                    }
                } catch {
                    print("Failed to encrypt card data:", error)
                    self.notifyCollectionFailure(error)
                }
            }

            callback.onFailure = { [weak self] error in
                print("Failed to collect card data:", error)
                self?.notifyCollectionFailure(PayrailsError.invalidCardData)
            }

            cardContainer?.collect(with: callback)
        }

        /// Tokenizes the card form data — encrypts card details and registers the instrument
        /// in the vault without processing a payment.
        ///
        /// This matches the web SDK's `cardForm.tokenize()` and Android SDK's `cardForm.tokenize()`.
        public func tokenize(options: TokenizeOptions = TokenizeOptions()) async throws -> SaveInstrumentResponse {
            guard let session = self.session else {
                throw PayrailsError.missingData("Session is required for tokenization.")
            }
            // Single entry point: route through the unified `tokenize` so the card and wallet
            // paths share one implementation. `Session.tokenize(.card(_:))` calls back into
            // `encryptCardData()` below (NOT this method), so there is no recursion.
            return try await session.tokenize(.card(self), options: options)
        }

        /// Collects the live card fields from the embedded form and encrypts them with the CSE,
        /// returning the vault ciphertext. Called by `Session.tokenize(.card(_:))`: the form owns
        /// the PAN and the encryption (the PCI boundary), so this stays on the form, not the session.
        func encryptCardData() async throws -> String {
            guard self.container != nil else {
                throw PayrailsError.missingData("Card form container is not available")
            }

            let fields: [String: Any] = try await withCheckedThrowingContinuation { continuation in
                let callback = CardCollectCallback()

                callback.onSuccess = { responseBody in
                    guard
                        let response = responseBody as? [String: Any],
                        let records = response["records"] as? [[String: Any]],
                        let firstRecord = records.first,
                        let fields = firstRecord["fields"] as? [String: Any]
                    else {
                        continuation.resume(throwing: PayrailsError.invalidDataFormat)
                        return
                    }
                    continuation.resume(returning: fields)
                }

                callback.onFailure = { _ in
                    continuation.resume(throwing: PayrailsError.invalidCardData)
                }

                self.cardContainer?.collect(with: callback)
            }

            guard
                let cardNumber = fields["card_number"] as? String,
                let securityCode = fields["security_code"] as? String
            else {
                throw PayrailsError.invalidCardData
            }

            guard let expiry = self.resolveExpiry(from: fields) else {
                throw PayrailsError.invalidCardData
            }

            guard let payrailsCSE = self.payrailsCSE else {
                throw PayrailsError.missingData("CSE instance")
            }

            let payrailsCard = Card(
                holderReference: self.holderReference,
                cardNumber: cardNumber,
                expiryMonth: expiry.month,
                expiryYear: expiry.year,
                holderName: fields["cardholder_name"] as? String,
                securityCode: securityCode
            )

            return try payrailsCSE.encryptCardData(card: payrailsCard)
        }

        private func notifyCollectionFailure(_ error: Error) {
            DispatchQueue.main.async {
                self.delegate?.cardForm(self, didFailWithError: error)
            }
        }

        private func resolveExpiry(from fields: [String: Any]) -> (month: String, year: String)? {
            if
                let expiryMonth = fields["expiry_month"] as? String,
                let expiryYear = fields["expiry_year"] as? String {
                return (month: expiryMonth, year: expiryYear)
            }

            guard let combinedExpiry = fields["expiry_date"] as? String else {
                return nil
            }

            return parseCombinedExpiry(combinedExpiry)
        }

        private func parseCombinedExpiry(_ value: String) -> (month: String, year: String)? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let parts = trimmed.split(separator: "/").map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if parts.count == 2 {
                if isValidMonth(parts[0]) {
                    return (month: parts[0], year: parts[1])
                }
                if isValidMonth(parts[1]) {
                    return (month: parts[1], year: parts[0])
                }
            }

            let digits = trimmed.filter { $0.isWholeNumber }
            if digits.count == 4 {
                let month = String(digits.prefix(2))
                let year = String(digits.suffix(2))
                return isValidMonth(month) ? (month: month, year: year) : nil
            }

            if digits.count == 6 {
                let firstMonth = String(digits.prefix(2))
                if isValidMonth(firstMonth) {
                    return (month: firstMonth, year: String(digits.suffix(4)))
                }

                let trailingMonth = String(digits.suffix(2))
                if isValidMonth(trailingMonth) {
                    return (month: trailingMonth, year: String(digits.prefix(4)))
                }
            }

            return nil
        }

        private func isValidMonth(_ month: String) -> Bool {
            guard month.count == 2, let monthInt = Int(month) else {
                return false
            }
            return (1...12).contains(monthInt)
        }
    }
}
