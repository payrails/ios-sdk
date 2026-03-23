import Foundation

/// Options for updating the payment session at runtime.
public struct UpdateOptions {
    public var amount: PayrailsAmount?

    public init(amount: PayrailsAmount? = nil) {
        self.amount = amount
    }
}
