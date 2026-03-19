import Foundation

/// Options for updating the payment session at runtime.
public struct UpdateOptions {
    public struct Amount {
        public var value: String
        public var currency: String

        public init(value: String, currency: String) {
            self.value = value
            self.currency = currency
        }
    }

    public var amount: Amount?

    public init(amount: Amount? = nil) {
        self.amount = amount
    }
}
