import Foundation

/// Options for updating the payment session at runtime.
public struct UpdateOptions {
    public var value: String?
    public var currency: String?

    public init(value: String? = nil, currency: String? = nil) {
        self.value = value
        self.currency = currency
    }
}
