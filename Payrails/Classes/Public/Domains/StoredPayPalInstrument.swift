public protocol StoredInstrument {
    var id: String { get }
    var email: String? { get }
    var description: String? { get }
    var type: Payrails.PaymentType { get }
    /// `true` when this instrument is the holder's default payment method.
    /// Decoded from the `default` field in the server response.
    var isDefault: Bool { get }
}
