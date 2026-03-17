import Foundation

/// Shared mutable state for payment session values that can be updated at runtime.
/// Both `Session` and `PayrailsAPI` hold a reference to the same instance,
/// ensuring amount changes propagate across the SDK.
class PaymentContext {
    var amount: Amount

    init(amount: Amount) {
        self.amount = amount
    }

    func updateAmount(value: String, currency: String) {
        self.amount = Amount(value: value, currency: currency)
    }
}
