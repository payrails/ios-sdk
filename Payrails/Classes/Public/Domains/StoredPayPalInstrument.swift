public extension Payrails {
    struct StoredInstrument: Decodable {
        public let id: String
        public let email: String?
        public let type: PaymentType
    }
}
