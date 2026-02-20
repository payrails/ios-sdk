import Foundation

public struct CardLayoutConfig: Equatable {
    public enum Preset: Equatable {
        case standard
        case compact
        case minimal
    }

    public let preset: Preset?
    public let customRows: [[CardFieldType]]?
    public let fieldOrder: [CardFieldType]?
    public let useCombinedExpiryDateField: Bool

    private init(
        preset: Preset?,
        customRows: [[CardFieldType]]?,
        fieldOrder: [CardFieldType]?,
        useCombinedExpiryDateField: Bool
    ) {
        self.preset = preset
        self.customRows = customRows
        self.fieldOrder = fieldOrder
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
        fieldOrder: [CardFieldType]? = nil,
        useCombinedExpiryDateField: Bool = false
    ) -> CardLayoutConfig {
        CardLayoutConfig(
            preset: preset,
            customRows: nil,
            fieldOrder: fieldOrder,
            useCombinedExpiryDateField: useCombinedExpiryDateField
        )
    }

    public static func custom(
        _ rows: [[CardFieldType]],
        fieldOrder: [CardFieldType]? = nil,
        useCombinedExpiryDateField: Bool = false
    ) -> CardLayoutConfig {
        CardLayoutConfig(
            preset: nil,
            customRows: rows,
            fieldOrder: fieldOrder,
            useCombinedExpiryDateField: useCombinedExpiryDateField
        )
    }

    func resolvedRows(showNameField: Bool) -> [[CardFieldType]] {
        let baseRows = baseRows(showNameField: showNameField)
        let sanitizedRows = baseRows.filter { !$0.isEmpty }

        guard !sanitizedRows.isEmpty else {
            return CardLayoutConfig.defaultRows(showNameField: showNameField)
        }

        let rowSizes = sanitizedRows.map { $0.count }
        let flattenedFields = sanitizedRows.flatMap { $0 }
        let orderedFields = applyFieldOrder(to: flattenedFields)
        return split(orderedFields, rowSizes: rowSizes)
    }

    static func defaultRows(showNameField: Bool) -> [[CardFieldType]] {
        if showNameField {
            return [[.CARD_NUMBER], [.CARDHOLDER_NAME], [.EXPIRATION_MONTH, .EXPIRATION_YEAR, .CVV]]
        }
        return [[.CARD_NUMBER], [.EXPIRATION_MONTH, .EXPIRATION_YEAR, .CVV]]
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

    private func applyFieldOrder(to fields: [CardFieldType]) -> [CardFieldType] {
        guard let fieldOrder, !fieldOrder.isEmpty else {
            return fields
        }

        var seen = Set<CardFieldType>()
        var ordered = [CardFieldType]()

        for field in fieldOrder where fields.contains(field) && !seen.contains(field) {
            ordered.append(field)
            seen.insert(field)
        }

        for field in fields where !seen.contains(field) {
            ordered.append(field)
            seen.insert(field)
        }

        return ordered
    }

    private func split(_ fields: [CardFieldType], rowSizes: [Int]) -> [[CardFieldType]] {
        var rows = [[CardFieldType]]()
        var currentIndex = 0

        for size in rowSizes where size > 0 {
            let nextIndex = min(currentIndex + size, fields.count)
            let row = Array(fields[currentIndex..<nextIndex])
            rows.append(row)
            currentIndex = nextIndex
        }

        if currentIndex < fields.count {
            rows.append(Array(fields[currentIndex..<fields.count]))
        }

        return rows
    }
}
