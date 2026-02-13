public extension Payrails {
    struct InitData: Codable {
        public let version: String
        public let data: String

        /// Public initializer for merchant integrations.
        /// - Parameters:
        ///   - version: Init data version.
        ///   - data: The init data payload (usually a base64 or JSON string as provided by Payrails).
        public init(version: String, data: String) {
            self.version = version
            self.data = data
        }
    }
}
