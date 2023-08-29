import Foundation

public extension Payrails {
    struct InitResponse: Decodable {
        public let version: String
        public let data: String

        public init(
            version: String,
            data: String
        ) {
            self.version = version
            self.data = data
        }
    }
}
