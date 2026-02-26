import Foundation

public struct CardLayoutConfig: Equatable {
    public enum Preset: Equatable {
        case standard
        case compact
        case minimal
    }

    public let preset: Preset?
    public let customRows: [[CardFieldType]]?
    public let useCombinedExpiryDateField: Bool

    private init(
        preset: Preset?,
        customRows: [[CardFieldType]]?,
        useCombinedExpiryDateField: Bool
    ) {
        self.preset = preset
        self.customRows = customRows
        self.useCombinedExpiryDateField = useCombinedExpiryDateField
    }

    public static var standard: CardLayoutConfig {
        .preset(.standard)
    }

    public static var compact: CardLayoutConfig {
        .preset(.compact, useCombinedExpiryDateField: true)
    }

    public static var minimal: CardLayoutConfig {
        .preset(.minimal, useCombinedExpiryDateField: true)
    }

    public static func preset(
        _ preset: Preset,
        useCombinedExpiryDateField: Bool = false
    ) -> CardLayoutConfig {
        CardLayoutConfig(
            preset: preset,
            customRows: nil,
            useCombinedExpiryDateField: useCombinedExpiryDateField
        )
    }

    public static func custom(
        _ rows: [[CardFieldType]],
        useCombinedExpiryDateField: Bool = false
    ) -> CardLayoutConfig {
        CardLayoutConfig(
            preset: nil,
            customRows: rows,
            useCombinedExpiryDateField: useCombinedExpiryDateField
        )
    }

    func resolvedRows(showNameField: Bool) -> [[CardFieldType]] {
        let baseRows = baseRows(showNameField: showNameField)
        let sanitizedRows = baseRows.filter { !$0.isEmpty }

        guard !sanitizedRows.isEmpty else {
            return CardLayoutConfig.defaultRows(showNameField: showNameField)
        }

        guard CardLayoutConfig.hasValidExpiryConfiguration(
            in: sanitizedRows,
            useCombinedExpiryDateField: useCombinedExpiryDateField,
            isCustomLayout: customRows != nil
        ) else {
            print("Card form layout has invalid expiry configuration; falling back to default layout")
            return CardLayoutConfig.defaultRows(showNameField: showNameField)
        }

        guard CardLayoutConfig.containsRequiredSubmissionFields(in: sanitizedRows) else {
            return CardLayoutConfig.defaultRows(showNameField: showNameField)
        }

        return sanitizedRows
    }

    static func defaultRows(showNameField: Bool) -> [[CardFieldType]] {
        if showNameField {
            return [[.CARD_NUMBER], [.CARDHOLDER_NAME], [.CVV, .EXPIRATION_MONTH, .EXPIRATION_YEAR]]
        }
        return [[.CARD_NUMBER], [.CVV, .EXPIRATION_MONTH, .EXPIRATION_YEAR]]
    }

    static func containsRequiredSubmissionFields(in rows: [[CardFieldType]]) -> Bool {
        let fields = Set(rows.flatMap { $0 })
        let hasCardNumber = fields.contains(.CARD_NUMBER)
        let hasCVV = fields.contains(.CVV)
        let hasCombinedExpiry = fields.contains(.EXPIRATION_DATE)
        let hasSplitExpiry = fields.contains(.EXPIRATION_MONTH) && fields.contains(.EXPIRATION_YEAR)

        return hasCardNumber && hasCVV && (hasCombinedExpiry || hasSplitExpiry)
    }

    static func hasValidExpiryConfiguration(
        in rows: [[CardFieldType]],
        useCombinedExpiryDateField: Bool,
        isCustomLayout: Bool
    ) -> Bool {
        guard isCustomLayout else {
            return true
        }

        let fields = Set(rows.flatMap { $0 })
        let hasExpiryMonth = fields.contains(.EXPIRATION_MONTH)
        let hasExpiryYear = fields.contains(.EXPIRATION_YEAR)

        if useCombinedExpiryDateField {
            return !hasExpiryMonth && !hasExpiryYear
        }

        return hasExpiryMonth == hasExpiryYear
    }

    private func baseRows(showNameField: Bool) -> [[CardFieldType]] {
        let rows: [[CardFieldType]]

        if let customRows {
            rows = customRows
        } else {
            let selectedPreset = preset ?? .standard

            switch selectedPreset {
            case .standard:
                rows = CardLayoutConfig.defaultRows(showNameField: showNameField)
            case .compact:
                if showNameField {
                    rows = [[.CARD_NUMBER], [.EXPIRATION_MONTH, .EXPIRATION_YEAR, .CVV], [.CARDHOLDER_NAME]]
                } else {
                    rows = [[.CARD_NUMBER], [.EXPIRATION_MONTH, .EXPIRATION_YEAR, .CVV]]
                }
            case .minimal:
                rows = [[.CARD_NUMBER], [.EXPIRATION_MONTH, .EXPIRATION_YEAR, .CVV]]
            }
        }

        if useCombinedExpiryDateField {
            return withCombinedExpiryDateField(rows)
        }
        return rows
    }

    private func withCombinedExpiryDateField(_ rows: [[CardFieldType]]) -> [[CardFieldType]] {
        var didInsertCombinedExpiry = false

        return rows.compactMap { row in
            var normalizedRow = [CardFieldType]()
            var firstExpiryIndexInRow: Int?

            for (index, field) in row.enumerated() {
                switch field {
                case .EXPIRATION_DATE:
                    if !didInsertCombinedExpiry {
                        normalizedRow.append(.EXPIRATION_DATE)
                        didInsertCombinedExpiry = true
                    }
                case .EXPIRATION_MONTH, .EXPIRATION_YEAR:
                    if firstExpiryIndexInRow == nil {
                        firstExpiryIndexInRow = index
                    }
                default:
                    normalizedRow.append(field)
                }
            }

            if let firstExpiryIndexInRow, !didInsertCombinedExpiry {
                let insertIndex = min(firstExpiryIndexInRow, normalizedRow.count)
                normalizedRow.insert(.EXPIRATION_DATE, at: insertIndex)
                didInsertCombinedExpiry = true
            }

            return normalizedRow.isEmpty ? nil : normalizedRow
        }
    }

}
