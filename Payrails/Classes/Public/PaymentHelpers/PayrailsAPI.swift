import Foundation

class PayrailsAPI {
    let config: SDKConfig

    var isRunning = false

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

        if let execution = authorizeResponse.links.execution,
           let executionURL = URL(string: execution) {
            let paymentStatus = try await checkExecutionStatus(
                url: executionURL,
                targetStatuses: statusesAfterPending
            )
            return paymentStatus
        } else {
            throw PayrailsError.missingData("Execution link is missing")
        }

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
        var executionResult: GetExecutionResult!
        var authorizeRequestedStatus: Status!

        var attempt = 0
        while !authorizeRequestedFound && isRunning && attempt < 10 {
            executionResult = try await getExecution(url: url)
            authorizeRequestedStatus = executionResult.sortedStatus.first(where: { $0.code == "authorizeRequested" })
            authorizeRequestedFound = authorizeRequestedStatus != nil
            if !authorizeRequestedFound {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            attempt += 1
        }

        guard authorizeRequestedFound,
              executionResult != nil,
              authorizeRequestedStatus != nil else {
            throw PayrailsError.unknown(error: nil)
        }

        if let finalState = executionResult.sortedStatus.first(where: { status in
            targetStatuses.map { $0.rawValue }.contains(status.code) && status.time > authorizeRequestedStatus.time
        }) {
            if let paymentStatus = finalState.paymentStatus(with: executionResult) {
                return paymentStatus
            } else {
                throw PayrailsError.unknown(error: nil)
            }
        } else {
            // Start long polling
            let currentStatuses = executionResult.sortedStatus.map { $0.code }
            let longPollingExecutionResult = try await getExecution(
                url: url,
                statusesToWait: currentStatuses,
                timeout: 300
            )
            let finalState = longPollingExecutionResult.sortedStatus.first(where: { status in
                targetStatuses.map { $0.rawValue }.contains(status.code) && status.time > authorizeRequestedStatus.time
            })

            if let paymentStatus = finalState?.paymentStatus(with: longPollingExecutionResult) {
                return paymentStatus
            } else {
                throw PayrailsError.unknown(error: nil)
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
        method
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
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            
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
            let compositionDict: [String: Any] = [
                "paymentMethodCode": composition.paymentMethodCode,
                "integrationType": composition.integrationType,
                "amount": [
                    "value": composition.amount.value,
                    "currency": composition.amount.currency
                ],
                "storeInstrument": composition.storeInstrument,
                "paymentInstrumentData": [
                    "encryptedData": composition.paymentInstrumentData?.encryptedData,
                    "vaultProviderConfigId": composition.paymentInstrumentData?.vaultProviderConfigId
                ],
                "enrollInstrumentToNetworkOffers": composition.enrollInstrumentToNetworkOffers
            ]
            
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

