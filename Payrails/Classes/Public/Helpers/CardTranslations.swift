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
    }
    
    public struct Labels {
        private var values: [CardFieldType: String]
        private var saveInstrument: String?
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
    }
    
    public struct ErrorMessages {
        public struct DefaultErrors {
            private var values: [CardFieldType: String]
            
            public init(values: [CardFieldType: String] = [:]) {
                self.values = values
            }
            
            public subscript(type: CardFieldType) -> String? {
                get { values[type] }
                set { values[type] = newValue }
            }
        }
        
        public let defaultErrors: DefaultErrors
        
        public init(defaultErrors: DefaultErrors = DefaultErrors()) {
            self.defaultErrors = defaultErrors
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

// Add this extension to your CardTranslations definition file or nearby
extension CardTranslations {

    /// Merges the current translations with another, giving precedence to the other's values.
    /// - Parameter other: The CardTranslations object to merge with. If nil, returns self.
    /// - Returns: A new CardTranslations object containing the merged values.
    func merged(with other: CardTranslations?) -> CardTranslations {
        guard let other = other else {
            // If the other translations are nil, return the current ones.
            return self
        }

        // Merge Placeholders
        var mergedPlaceholders = self.placeholders.allValues // Start with default
        other.placeholders.allValues.forEach { key, value in mergedPlaceholders[key] = value } // Override/add custom
        let finalPlaceholders = Placeholders(values: mergedPlaceholders)

        // Merge Labels
        var mergedLabelValues = self.labels.allValues // Start with default values
        other.labels.allValues.forEach { key, value in mergedLabelValues[key] = value } // Override/add custom values
        let finalLabels = Labels(
            values: mergedLabelValues,
            // Use 'other' value if present, otherwise fallback to 'self' value
            saveInstrument: other.labels.saveInstrumentText ?? self.labels.saveInstrumentText,
            storeInstrument: other.labels.storeInstrumentText ?? self.labels.storeInstrumentText,
            paymentInstallments: other.labels.paymentInstallmentsText ?? self.labels.paymentInstallmentsText
        )

        // Merge Error Messages
        var mergedErrorValues = self.error.defaultErrors.allValues // Start with default
        other.error.defaultErrors.allValues.forEach { key, value in mergedErrorValues[key] = value } // Override/add custom
        let finalDefaultErrors = ErrorMessages.DefaultErrors(values: mergedErrorValues)
        let finalErrorMessages = ErrorMessages(defaultErrors: finalDefaultErrors)

        // Return the fully merged translations
        return CardTranslations(
            placeholders: finalPlaceholders,
            labels: finalLabels,
            error: finalErrorMessages
        )
    }
}

// Helper properties/methods to access underlying dictionaries easily for merging
// Add these inside the respective struct definitions

extension CardTranslations.Placeholders {
    // Expose all values for easier merging
    var allValues: [CardFieldType: String] {
        return values
    }
}

extension CardTranslations.Labels {
    // Expose all values for easier merging
    var allValues: [CardFieldType: String] {
        return values
    }
    // Provide accessors to the specific label texts
    var saveInstrumentText: String? { return saveInstrument }
    var storeInstrumentText: String? { return storeInstrument }
    var paymentInstallmentsText: String? { return paymentInstallments }
    
    // We need to modify the subscript/saveCreditCard setters if `values` is private
    // If `values` remains private, you might need an internal initializer or a mutating merge func
    // Assuming 'values' is accessible within the module for the merge function above.
    // If not, make 'values' `internal` or provide a public initializer taking a dictionary.
}

extension CardTranslations.ErrorMessages.DefaultErrors {
    // Expose all values for easier merging
    var allValues: [CardFieldType: String] {
        return values
    }
}
