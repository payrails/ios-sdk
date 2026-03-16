import Foundation

/// Shared mutable state for payment session values that can be updated at runtime.
/// Both `Session` and `PayrailsAPI` hold a reference to the same instance,
/// ensuring amount and meta changes propagate across the SDK.
class PaymentContext {
    var amount: Amount
    private var updatedMeta: [String: Any] = [:]

    init(amount: Amount) {
        self.amount = amount
    }

    func updateAmount(value: String, currency: String) {
        self.amount = Amount(value: value, currency: currency)
    }

    func updateMeta(key: String, value: Any) {
        if let newDict = value as? [String: Any],
           let existing = updatedMeta[key] as? [String: Any] {
            updatedMeta[key] = deepMerge(existing, newDict)
        } else {
            updatedMeta[key] = value
        }
    }

    func getUpdatedMeta() -> [String: Any]? {
        return updatedMeta.isEmpty ? nil : updatedMeta
    }

    private func deepMerge(_ base: [String: Any], _ override: [String: Any]) -> [String: Any] {
        var result = base
        for (key, value) in override {
            if let baseDict = result[key] as? [String: Any],
               let overrideDict = value as? [String: Any] {
                result[key] = deepMerge(baseDict, overrideDict)
            } else {
                result[key] = value
            }
        }
        return result
    }
}
