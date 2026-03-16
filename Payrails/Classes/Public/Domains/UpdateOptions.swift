import Foundation

/// Options for updating the payment session at runtime.
/// Mirrors the web SDK's `LookupUpdateOptions`.
public struct UpdateOptions {
    public var value: String?
    public var currency: String?
    public var meta: ExecutionMetaUpdate?

    public init(value: String? = nil, currency: String? = nil, meta: ExecutionMetaUpdate? = nil) {
        self.value = value
        self.currency = currency
        self.meta = meta
    }
}

/// A key-value pair for updating execution metadata.
public struct ExecutionMetaUpdate {
    public let key: String
    public let value: Any

    public init(key: String, value: Any) {
        self.key = key
        self.value = value
    }
}
