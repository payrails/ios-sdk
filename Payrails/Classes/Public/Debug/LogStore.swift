import Foundation

public extension Payrails {

    internal class LogStore {

        public static let shared = LogStore()

        public static let didUpdateLogNotification = Notification.Name("PayrailsLogDidUpdateNotification")

        private var logs: [String] = []
        private let maxLogCount = 500 // Keep the last 500 logs
        private let queue = DispatchQueue(label: "com.payrails.logstore.queue")

        private init() {} // Singleton

        public func addLog(_ message: String) {
            queue.async {
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                let fullMessage = "[\(timestamp)] \(message)"

                self.logs.append(fullMessage)

                // Trim logs if they exceed maxLogCount
                if self.logs.count > self.maxLogCount {
                    self.logs.removeFirst(self.logs.count - self.maxLogCount)
                }

                NotificationCenter.default.post(name: LogStore.didUpdateLogNotification, object: nil)
            }
        }

        public func getLogs() -> [String] {
            return queue.sync {
                return self.logs
            }
        }

        public func clearLogs() {
            queue.async {
                self.logs.removeAll()
                NotificationCenter.default.post(name: LogStore.didUpdateLogNotification, object: nil)
            }
        }
    }
}

// MARK: - SDK Logging

extension Payrails {
    static func log(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, function: String = #function, line: UInt = #line) {
        let output = items.map { "\($0)" }.joined(separator: separator)
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) -> \(output)"

        Swift.print(logMessage, terminator: terminator)
        LogStore.shared.addLog(logMessage)
    }
}
