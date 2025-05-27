import Foundation

class PayrailsAPI {
    let config: SDKConfig

    var isRunning = false
    
    var authorizeRequestDate  = Date()

    enum PaymentStatus {
        case success, failed, pending(GetExecutionResult)
    }

    enum PaymentAuthorizeStatus: String {
        case authorizePending, authorizeSuccessful, authorizeFailed
    }

    private let statusesAfterAuthorize: [PaymentAuthorizeStatus] = [
        .authorizePending,
        .authorizeSuccessful,
        .authorizeFailed
    ]

    private let statusesAfterPending: [PaymentAuthorizeStatus] = [
        .authorizeSuccessful, 
        .authorizeFailed
    ]

    fileprivate struct DataBody: Encodable {
        let data: [String: Any]
    }

    fileprivate struct Body: Encodable {
        struct ReturnInfo: Encodable {
            let success: String
            let cancel: String
            let error: String
        }
        let amount: Amount
        let returnInfo: ReturnInfo
        let paymentComposition: [[String: Any]]
    }

    private var token: String {
        config.token
    }

    private var authorizeURL: (url: URL, method: Method)? {
        let authorizeLink = config.execution?.initialResults.first(where: {
            $0.body.links.authorize.href != nil
        })?.body.links.authorize
        guard let href = authorizeLink?.href,
              !href.isEmpty,
              let url = URL(string: href) else {
            return nil
        }
        let method = Method(rawValue: authorizeLink?.method ?? "") ?? .POST
        return (url, method)
    }

    private var amount: Amount {
        config.amount
    }

    init(config: SDKConfig) {
        self.config = config
    }

    func makePayment(
        type: Payrails.PaymentType,
        payload: [String: Any]?
    ) async throws -> PayrailsAPI.PaymentStatus {
        isRunning = true
        // authorization request
        let executionUrl = try await authorizePayment(type: type, payload: payload)
        guard isRunning else { throw PayrailsError.unknown(error: nil) }
        let status = try await checkExecutionStatus(url: executionUrl, targetStatuses: statusesAfterAuthorize)
        return status
    }

    func confirmPayment(
        link: Link,
        payload: [String: Any]?
    ) async throws -> PayrailsAPI.PaymentStatus {
        isRunning = true
        guard let href = link.href,
        let method = Method(rawValue: link.method ?? ""),
        let url = URL(string: href) else {
            throw PayrailsError.missingData("links -> wrong href or method")
        }

        var data: Data?
        if let payload {
            let dataBody = DataBody(data: payload)
            data = try? JSONEncoder().encode(dataBody)
        }

        let authorizeResponse = try await call(
            url: url,
            method: method,
            body: data,
            type: AuthorizeResponse.self
        )
        
        // 1. Ensure 'execution' string exists
        guard let execution = authorizeResponse.links.execution else {
            print("🚨 Error: Execution link string is missing from authorizeResponse.links.")
            throw PayrailsError.missingData("Execution link string is missing from authorizeResponse.links")
        }

        // 2. Ensure 'execution' string can be converted to a URL
        guard let executionURL = URL(string: execution) else {
            print("🚨 Error: Could not create URL from execution string: '\(execution)'.")
            throw PayrailsError.missingData("Execution link string is invalid and cannot form a URL: \(execution)")
        }

        let paymentStatus = try await checkExecutionStatus(
            url: executionURL,
            targetStatuses: statusesAfterPending
        )
        
        return paymentStatus
    }

    private func authorizePayment(
        type: Payrails.PaymentType,
        payload: [String: Any]?
    ) async throws -> URL {
        guard let authorizeURL else {
            throw PayrailsError.missingData("links -> authorize")
        }
        var paymentComposition: [String: Any] = payload ?? [:]
        paymentComposition["amount"] = [
            "value": amount.value,
            "currency": amount.currency
        ]

        let body = Body(
            amount: amount,
            returnInfo: .init(
                success: "https://www.bootstrap.payrails.io/success",
                cancel: "https://www.bootstrap.payrails.io/cancel",
                error: "https://www.bootstrap.payrails.io/error"
            ),
            paymentComposition: [paymentComposition]
        )
        let jsonEncoder = JSONEncoder()
        let jsonData = convertToJSON(body: payload ?? [:])

        let authorizeResponse = try await call(
            url: authorizeURL.url,
            method: authorizeURL.method,
            body: jsonData,
            type: AuthorizeResponse.self
        )
        
        authorizeRequestDate = authorizeResponse.executedAt
        
        if let execution = authorizeResponse.links.execution,
           let executionURL = URL(string: execution) {
            return executionURL
        } else {
            throw PayrailsError.missingData("Execution link is missing")
        }
    }
    
    private func checkExecutionStatus(
        url: URL,
        targetStatuses: [PaymentAuthorizeStatus]
    ) async throws -> (PaymentStatus) {
        var authorizeRequestedFound = false
        var executionResult: GetExecutionResult! // Implicitly unwrapped, be careful!
        var authorizeRequestedStatus: Status!  // Implicitly unwrapped!

        var attempt = 0
        let maxAttempts = 10 // Define max attempts clearly

        while !authorizeRequestedFound && isRunning && attempt < maxAttempts {
            attempt += 1

            do {
                executionResult = try await getExecution(url: url)
                let receivedStatusCodes = executionResult.sortedStatus.map { "(\($0.code): \($0.time))" }.joined(separator: ", ")

                authorizeRequestedStatus = executionResult.sortedStatus.first(where: { $0.code == "authorizeRequested" })
                authorizeRequestedFound = authorizeRequestedStatus != nil

                if !authorizeRequestedFound && isRunning && attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            } catch {
                break
            }
        }

        if !isRunning {
            print("🛑 [CheckExecutionStatus] Loop terminated because isRunning became false.")
        }
        if attempt >= maxAttempts && !authorizeRequestedFound {
            print("🛑 [CheckExecutionStatus] Loop terminated because max attempts (\(maxAttempts)) reached without finding 'authorizeRequested'.")
        }

        print("ℹ️ [CheckExecutionStatus] After polling loop: authorizeRequestedFound: \(authorizeRequestedFound), executionResult is nil: \(executionResult == nil), authorizeRequestedStatus is nil: \(authorizeRequestedStatus == nil)")
        guard authorizeRequestedFound,
              executionResult != nil, // Should be non-nil if authorizeRequestedFound is true and no error in loop
              authorizeRequestedStatus != nil else { // Should be non-nil if authorizeRequestedFound is true
            print("🚨 [CheckExecutionStatus] Guard Failed! Conditions not met after polling loop.")
            print("   - authorizeRequestedFound: \(authorizeRequestedFound)")
            print("   - executionResult != nil: \(executionResult != nil)")
            if executionResult == nil {
                 print("   - executionResult was nil. This likely means getExecution failed or never successfully ran in the loop.")
            }
            print("   - authorizeRequestedStatus != nil: \(authorizeRequestedStatus != nil)")
            throw PayrailsError.unknown(error: nil) // Or a more specific error like .pollingFailed
        }


        if let finalState = executionResult.sortedStatus.first(where: { status in
            let isTargetStatus = targetStatuses.map { $0.rawValue }.contains(status.code)
            let isAfterRequestDate = status.time > authorizeRequestDate
            // Detailed log for each status being checked:
            // print("  🔎 Checking status: \(status.code) at \(status.time). Is target: \(isTargetStatus). Is after request date (\(authorizeRequestDate)): \(isAfterRequestDate).")
            return isTargetStatus && isAfterRequestDate
        }) {
            print("👍 [CheckExecutionStatus] Immediate finalState FOUND: (Code: \(finalState.code), Time: \(finalState.time))")
            if let paymentStatus = finalState.paymentStatus(with: executionResult) {
                print("✅ [CheckExecutionStatus] Successfully derived paymentStatus from immediate finalState. Returning: \(paymentStatus)")
                return paymentStatus
            } else {
                print("🚨 [CheckExecutionStatus] Error: finalState found, but paymentStatus(with:) returned nil.")
                throw PayrailsError.unknown(error: nil) // Or .failedToDerivePaymentStatus
            }
        } else {
            print("⏳ [CheckExecutionStatus] Immediate finalState NOT FOUND. Starting long polling.")
            let currentStatuses = executionResult.sortedStatus.map { $0.code }
            let timeoutSeconds: Double = 300
            print("ℹ️ [CheckExecutionStatus] Long polling with statusesToWait: \(currentStatuses), timeout: \(timeoutSeconds)s")

            do {
                let longPollingExecutionResult = try await getExecution(
                    url: url,
                    statusesToWait: currentStatuses,
                    timeout: Int(timeoutSeconds)
                )
                let receivedLongPollStatusCodes = longPollingExecutionResult.sortedStatus.map { "(\($0.code): \($0.time))" }.joined(separator: ", ")
                print("✅ [CheckExecutionStatus] Long polling getExecution successful. Statuses: [\(receivedLongPollStatusCodes)]")
                
                // Re-log authorizeRequestDate if there's any chance it could change or for clarity
                print("ℹ️ [CheckExecutionStatus] (Long Poll) authorizeRequestDate (for time comparison): \(String(describing: authorizeRequestDate))")

                if let finalStateFromLongPoll = longPollingExecutionResult.sortedStatus.first(where: { status in
                    let isTargetStatus = targetStatuses.map { $0.rawValue }.contains(status.code)
                    let isAfterRequestDate = status.time > authorizeRequestDate
                    // print("  🔎 [Long Poll] Checking status: \(status.code) at \(status.time). Is target: \(isTargetStatus). Is after request date (\(authorizeRequestDate)): \(isAfterRequestDate).")
                    return isTargetStatus && isAfterRequestDate
                }) {
                    print("👍 [CheckExecutionStatus] finalState FOUND after long polling: (Code: \(finalStateFromLongPoll.code), Time: \(finalStateFromLongPoll.time))")
                    if let paymentStatus = finalStateFromLongPoll.paymentStatus(with: longPollingExecutionResult) {
                        print("✅ [CheckExecutionStatus] Successfully derived paymentStatus from long-polled finalState. Returning: \(paymentStatus)")
                        return paymentStatus
                    } else {
                        print("🚨 [CheckExecutionStatus] Error: finalState found after long poll, but paymentStatus(with:) returned nil.")
                        throw PayrailsError.unknown(error: nil) // Or .failedToDerivePaymentStatusAfterLongPoll
                    }
                } else {
                    print("🛑 [CheckExecutionStatus] No suitable finalState found even after long polling.")
                    print("   - Target statuses: \(targetStatuses.map { $0.rawValue })")
                    print("   - Last known statuses from long poll: \(longPollingExecutionResult.sortedStatus.map { "(\($0.code) at \($0.time))" })")
                    print("   - authorizeRequestDate for comparison: \(String(describing: authorizeRequestDate))")
                    throw PayrailsError.unknown(error: nil) // Or .finalStatusNotFoundAfterLongPoll
                }
            } catch {
                print("🚨 [CheckExecutionStatus] Error during long polling getExecution(): \(error)")
                throw error // Rethrow the error from long polling
            }
        }
    }

//    private func checkExecutionStatus(
//        url: URL,
//        targetStatuses: [PaymentAuthorizeStatus]
//    ) async throws -> (PaymentStatus) {
//        var authorizeRequestedFound = false
//        var executionResult: GetExecutionResult!
//        var authorizeRequestedStatus: Status!
//
//        
//        var attempt = 0
//        while !authorizeRequestedFound && isRunning && attempt < 10 {
//            executionResult = try await getExecution(url: url)
//            authorizeRequestedStatus = executionResult.sortedStatus.first(where: { $0.code == "authorizeRequested" })
//            authorizeRequestedFound = authorizeRequestedStatus != nil
//            if !authorizeRequestedFound {
//                try? await Task.sleep(nanoseconds: 1_000_000_000)
//            }
//            attempt += 1
//        }
//
//        guard authorizeRequestedFound,
//              executionResult != nil,
//              authorizeRequestedStatus != nil else {
//            throw PayrailsError.unknown(error: nil)
//        }
//        
//
//        if let finalState = executionResult.sortedStatus.first(where: { status in
//            targetStatuses.map { $0.rawValue }.contains(status.code) && status.time > authorizeRequestDate
//        }) {
//            if let paymentStatus = finalState.paymentStatus(with: executionResult) {
//                return paymentStatus
//            } else {
//                throw PayrailsError.unknown(error: nil)
//            }
//        } else {
//            // Start long polling
//            let currentStatuses = executionResult.sortedStatus.map { $0.code }
//            let longPollingExecutionResult = try await getExecution(
//                url: url,
//                statusesToWait: currentStatuses,
//                timeout: 300
//            )
//            let finalState = longPollingExecutionResult.sortedStatus.first(where: { status in
//                targetStatuses.map { $0.rawValue }.contains(status.code) && status.time > authorizeRequestDate
//            })
//
//            if let paymentStatus = finalState?.paymentStatus(with: longPollingExecutionResult) {
//                return paymentStatus
//            } else {
//                throw PayrailsError.unknown(error: nil)
//            }
//        }
//    }

    private func getExecution(
        url: URL,
        statusesToWait: [String]? = nil,
        timeout: Int = 120
    ) async throws -> GetExecutionResult {
        var url = url
        if let statusesToWait,
           let data = try? JSONSerialization.data(withJSONObject: statusesToWait, options: []) {
            var urlComps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryComponents = String(data: data, encoding: String.Encoding.utf8)
            urlComps?.queryItems = [.init(name: "waitWhile[status]", value: queryComponents)]
            url = urlComps?.url ?? url
        }

        return try await call(
            url: url,
            method: .GET,
            timeout: timeout,
            type: GetExecutionResult.self
        )
    }
}

fileprivate extension PayrailsAPI {
    enum Method: String {
        case POST, GET
    }

    func call<T: Decodable>(
        url: URL,
        method: Method,
        body: Data? = nil,
        timeout: Int = 120,
        type: T.Type?
    ) async throws -> T {
        
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        
        request.httpMethod = method.rawValue
        
        if let httpBody = body {
            request.httpBody = httpBody
        }
        
        request.addValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.addValue(
            UUID().uuidString,
            forHTTPHeaderField: "x-idempotency-key"
        )

        request.addValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
              request.addValue("no-cache", forHTTPHeaderField: "Pragma")
              request.addValue("0", forHTTPHeaderField: "Expires")
        
        request.addValue(
            (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0",
            forHTTPHeaderField: "x-client-version"
        )

        request.addValue(
            "ios-sdk",
            forHTTPHeaderField: "x-client-type"
        )
        request.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = TimeInterval(timeout)
        
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            
            if statusCode == 401 || statusCode == 403 {
                print("Authentication error: status code \(statusCode)")
                throw PayrailsError.authenticationError
            }
            
            // If status code is not successful (outside 200-299 range)
            if statusCode < 200 || statusCode >= 300 {
                print("API error: status code \(statusCode)")
                print("Error response: \(responseString)")
            }
            
            let jsonDecoder = JSONDecoder.API()
            do {
                let result = try jsonDecoder.decode(T.self, from: data)
                return result
            } catch {
                print("ERROR: Failed to decode response: \(error)")
                throw error
            }
        } catch {
            print("ERROR: Network or decoding error: \(error)")
            throw error
        }
    }
}

fileprivate extension PayrailsAPI.Body {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encode(returnInfo, forKey: .returnInfo)
        try container.encode(paymentComposition, forKey: .paymentComposition)
    }

    private enum CodingKeys: CodingKey {
        case amount, returnInfo, paymentComposition
    }
}

fileprivate extension PayrailsAPI.DataBody {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
    }

    private enum CodingKeys: CodingKey {
        case data
    }
}

private extension Status {
    func paymentStatus(with executionResult: GetExecutionResult) -> PayrailsAPI.PaymentStatus? {
        switch self.code {
        case PayrailsAPI.PaymentAuthorizeStatus.authorizeSuccessful.rawValue:
            return .success
        case PayrailsAPI.PaymentAuthorizeStatus.authorizeFailed.rawValue:
            return .failed
        case PayrailsAPI.PaymentAuthorizeStatus.authorizePending.rawValue:
            return .pending(executionResult)
        default:
           return nil
        }
    }
}

func convertToJSON(body: [String: Any]) -> Data? {
    // Create a mutable copy of the body
    var jsonBody = body
    
    // Check if paymentComposition exists and is an array
    if let paymentCompositions = body["paymentComposition"] as? [PaymentComposition],
       !paymentCompositions.isEmpty {
        
        // Convert each PaymentComposition object to a dictionary
        var paymentCompositionDicts: [[String: Any]] = []
        
        for composition in paymentCompositions {
            var compositionDict: [String: Any] = [
                "paymentMethodCode": composition.paymentMethodCode,
                "integrationType": composition.integrationType,
                "amount": [
                    "value": composition.amount.value,
                    "currency": composition.amount.currency
                ],
                "storeInstrument": composition.storeInstrument,
                "enrollInstrumentToNetworkOffers": composition.enrollInstrumentToNetworkOffers
            ]
            
            // Special handling for Apple Pay
            if composition.paymentMethodCode == "applePay" {
                // For Apple Pay, use the paymentInstrumentData directly
                compositionDict["paymentInstrumentData"] = composition.paymentInstrumentData
            } else {
                // For other payment methods, use the standard structure
                compositionDict["paymentInstrumentData"] = [
                    "encryptedData": (composition.paymentInstrumentData as? PaymentInstrumentData)?.encryptedData,
                    "vaultProviderConfigId": (composition.paymentInstrumentData as? PaymentInstrumentData)?.vaultProviderConfigId
                ]
            }
            
            paymentCompositionDicts.append(compositionDict)
        }
        
        // Replace the PaymentComposition objects with their dictionary representations
        jsonBody["paymentComposition"] = paymentCompositionDicts
    }
    
    // Convert to JSON data
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: jsonBody, options: [.prettyPrinted])
        return jsonData
    } catch {
        print("Error converting to JSON: \(error)")
        return nil
    }
}


