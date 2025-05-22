public struct CardTranslations {
    public struct Placeholders {
        private var values: [CardFieldType: String]

        public init(values: [CardFieldType: String] = [:]) {
            self.values = values
        }

        public subscript(type: CardFieldType) -> String? {
            get { values[type] }
            set { values[type] = newValue }
        }

        var allValues: [CardFieldType: String] {
            return values
        }
    }

    public struct Labels {
        private var values: [CardFieldType: String]
        public var saveInstrument: String?
        private var storeInstrument: String?
        private var paymentInstallments: String?

        public init(
            values: [CardFieldType: String] = [:],
            saveInstrument: String? = nil,
            storeInstrument: String? = nil,
            paymentInstallments: String? = nil
        ) {
            self.values = values
            self.saveInstrument = saveInstrument
            self.storeInstrument = storeInstrument
            self.paymentInstallments = paymentInstallments
        }

        public subscript(type: CardFieldType) -> String? {
            get { values[type] }
            set { values[type] = newValue }
        }

        public var saveCreditCard: String? {
            get { values[.CARDHOLDER_NAME] }
            set { values[.CARDHOLDER_NAME] = newValue }
        }

        var allValues: [CardFieldType: String] {
            return values
        }

        var saveInstrumentText: String? { return saveInstrument }
        var storeInstrumentText: String? { return storeInstrument }
        var paymentInstallmentsText: String? { return paymentInstallments }
    }

    public struct ErrorMessages {
        private var values: [CardFieldType: String] // Holds the dictionary directly

        public init(values: [CardFieldType: String] = [:]) { // Updated Initializer
            self.values = values
        }

        public subscript(type: CardFieldType) -> String? {
            get { values[type] }
            set { values[type] = newValue }
        }

        var allValues: [CardFieldType: String] {
            return values
        }
    }

    public let placeholders: Placeholders
    public let labels: Labels
    public let error: ErrorMessages

    public init(
        placeholders: Placeholders = Placeholders(),
        labels: Labels = Labels(),
        error: ErrorMessages = ErrorMessages()
    ) {
        self.placeholders = placeholders
        self.labels = labels
        self.error = error
    }
}

extension CardTranslations {
    func merged(with other: CardTranslations?) -> CardTranslations {
        guard let other = other else {
            return self
        }

        var mergedPlaceholders = self.placeholders.allValues
        other.placeholders.allValues.forEach { key, value in mergedPlaceholders[key] = value }
        let finalPlaceholders = Placeholders(values: mergedPlaceholders)

        var mergedLabelValues = self.labels.allValues
        other.labels.allValues.forEach { key, value in mergedLabelValues[key] = value }
        let finalLabels = Labels(
            values: mergedLabelValues,
            saveInstrument: other.labels.saveInstrumentText ?? self.labels.saveInstrumentText,
            storeInstrument: other.labels.storeInstrumentText ?? self.labels.storeInstrumentText,
            paymentInstallments: other.labels.paymentInstallmentsText ?? self.labels.paymentInstallmentsText
        )

        var mergedErrorValues = self.error.allValues
        other.error.allValues.forEach { key, value in mergedErrorValues[key] = value }
        let finalErrorMessages = ErrorMessages(values: mergedErrorValues)

        return CardTranslations(
            placeholders: finalPlaceholders,
            labels: finalLabels,
            error: finalErrorMessages
        )
    }
}

public struct CardPaymenButtonTranslations {
    public let label: String?
    
    public init(label: String? = "Pay") {
        self.label = label
    }
}
