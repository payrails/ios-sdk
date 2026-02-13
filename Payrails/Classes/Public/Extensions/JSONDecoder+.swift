import Foundation

extension JSONDecoder {
    static func API() -> JSONDecoder {
        let jsonDecoder = JSONDecoder()

        // Cached formatters - to avoid repeatedly creating expensive formatter instances during decoding/
        enum APIFormatters {
            static let isoWithFraction: ISO8601DateFormatter = {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f
            }()

            static let isoNoFraction: ISO8601DateFormatter = {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f
            }()

            static let preciseWithMillis: DateFormatter = {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone(secondsFromGMT: 0)
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                return f
            }()

            static let preciseNoMillis: DateFormatter = {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone(secondsFromGMT: 0)
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                return f
            }()
        }

        jsonDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // 1) ISO8601 with fractional seconds
            if let d = APIFormatters.isoWithFraction.date(from: dateString) { return d }
            // 2) ISO8601 without fractional seconds
            if let d = APIFormatters.isoNoFraction.date(from: dateString) { return d }
            // 3) Precise formats (explicit Z suffix)
            if let d = APIFormatters.preciseWithMillis.date(from: dateString) { return d }
            if let d = APIFormatters.preciseNoMillis.date(from: dateString) { return d }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(dateString)"
            )
        }

        return jsonDecoder
    }
}
