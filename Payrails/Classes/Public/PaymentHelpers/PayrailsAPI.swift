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
    ) async throws -> PaymentStatus {
        var finalExecutionResultContainingAuthorizeRequested: GetExecutionResult? // Will store the specific result
        var dateOfAuthorizeRequested: Date?                                     // Will store the specific time

        var attempt = 0
        let maxAttempts = 10
        var latestExecutionResult: GetExecutionResult? // To hold the most recent result for long polling starting point

        while finalExecutionResultContainingAuthorizeRequested == nil && isRunning && attempt < maxAttempts {
            attempt += 1
            do {
                let currentExecutionResult = try await getExecution(url: url)
                latestExecutionResult = currentExecutionResult // Always store the latest result

                if let foundStatus = currentExecutionResult.sortedStatus.first(where: { $0.code == "authorizeRequested" }) {
                    // This is the moment we found it. Capture this specific result and time.
                    finalExecutionResultContainingAuthorizeRequested = currentExecutionResult
                    dateOfAuthorizeRequested = foundStatus.time
                    // Loop will now terminate because finalExecutionResultContainingAuthorizeRequested is no longer nil
                } else if isRunning && attempt < maxAttempts {
                    // Only sleep if not found and still within criteria
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            } catch {
                // Error during getExecution, break and let guard handle it
                break
            }
        }

        guard let validResultForAuth = finalExecutionResultContainingAuthorizeRequested,
              let validDateForAuth = dateOfAuthorizeRequested else {
            // If this guard fails, it means we never successfully found "authorizeRequested" within attempts,
            // or isRunning became false, or getExecution continuously failed.
            let reason = "Could not find 'authorizeRequested' status after \(attempt) attempts or polling was interrupted."
            throw PayrailsError.pollingFailed(reason)
        }

        // Check for immediate final state using the specific result and time
        if let finalState = validResultForAuth.sortedStatus.first(where: { status in
            targetStatuses.map { $0.rawValue }.contains(status.code) && status.time > validDateForAuth
        }) {
            if let paymentStatus = finalState.paymentStatus(with: validResultForAuth) {
                return paymentStatus
            } else {
                throw PayrailsError.failedToDerivePaymentStatus("Found final state but could not derive payment status.")
            }
        } else {
            // No immediate final state, proceed to long polling
            // Use latestExecutionResult for current statuses if available, otherwise validResultForAuth
            let statusesForLongPoll = (latestExecutionResult ?? validResultForAuth).sortedStatus.map { $0.code }
            let timeoutSeconds: Int = 300

            do {
                let longPollingExecutionResult = try await getExecution(
                    url: url,
                    statusesToWait: statusesForLongPoll,
                    timeout: timeoutSeconds
                )

                if let finalStateFromLongPoll = longPollingExecutionResult.sortedStatus.first(where: { status in
                    targetStatuses.map { $0.rawValue }.contains(status.code) && status.time > validDateForAuth // CRITICAL: Still use validDateForAuth
                }) {
                    if let paymentStatus = finalStateFromLongPoll.paymentStatus(with: longPollingExecutionResult) {
                        return paymentStatus
                    } else {
                        throw PayrailsError.failedToDerivePaymentStatus("Found final state after long poll but could not derive payment status.")
                    }
                } else {
                    throw PayrailsError.finalStatusNotFoundAfterLongPoll("No target final status found after long polling that occurred after authorizeRequested.")
                }
            } catch {
                if let payrailsError = error as? PayrailsError { throw payrailsError }
                throw PayrailsError.longPollingFailed(underlyingError: error)
            }
        }
    }

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


