public protocol StoredInstrument {
    var id: String { get }
    var email: String? { get }
    var description: String? { get }
    var type: Payrails.PaymentType { get }
}
