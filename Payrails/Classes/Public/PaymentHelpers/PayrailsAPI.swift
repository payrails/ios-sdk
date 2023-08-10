import Foundation

typealias PayrailsAPICallback = ((OnPayResult) -> ())

class PayrailsAPI {
    let config: SDKConfig
    private var onComplete: PayrailsAPICallback?

    private enum PaymentStatus: String {
        case authorizePending, authorizeSuccessful, authorizeFailed
    }

    private let statusesAfterAuthorize: [PaymentStatus] = [
        .authorizePending,
        .authorizeSuccessful,
        .authorizeFailed
    ]

    init(config: SDKConfig) {
        self.config = config
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

    func makePayment(
        type: Payrails.PaymentType,
        payload: [String: Any]?,
        onComplete: @escaping PayrailsAPICallback
    ) {
        self.onComplete = onComplete
        authorizePayment(
            type: type,
            payload: payload
        ) { [weak self] executionUrl in
            guard let strongSelf = self else { return }
            strongSelf.checkExecutionStatus(
                url: executionUrl,
                targetStatuses: strongSelf.statusesAfterAuthorize
            ) { [weak self] status, executionLink in
                switch status.code {
                case PaymentStatus.authorizeSuccessful.rawValue:
                    self?.onComplete?(.success)
                case PaymentStatus.authorizeFailed.rawValue:
                    self?.onComplete?(.failure)
                case PaymentStatus.authorizePending.rawValue:
                    //handle pending case
                    break
                default:
                    self?.onComplete?(.error(.unknown(error: nil)))
                }
            }
        }
    }

    private func authorizePayment(
        type: Payrails.PaymentType,
        payload: [String: Any]?,
        onAuthorize: @escaping ((URL) -> Void)
    ) {
        guard let authorizeURL else {
            onComplete?(.error(.missingData("links -> authorize")))
            return
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
        call(
            url: authorizeURL.url,
            method: authorizeURL.method,
            body: try? jsonEncoder.encode(body),
            type: AuthorizeResponse.self
        ) { [weak self] result in
                switch result {
                case .success(let success):
                    if let execution = success.links.execution,
                       let executionURL = URL(string: execution) {
                        onAuthorize(executionURL)
                    } else {
                        self?.onComplete?(.error(.missingData("Execution link is missing")))
                    }
                case .failure(let error):
                    switch error {
                    case .authenticationError:
                        self?.onComplete?(.authorizationFailed)
                    default:
                        self?.onComplete?(.error(error))
                    }
                }
        }
    }

    private func checkExecutionStatus(
        url: URL,
        targetStatuses: [PaymentStatus],
        onExecution: @escaping ((Status, ExecutionLinks) -> Void)
    ) {
        getExecution(url: url) { [weak self] executionResult in
            if let authorizeRequestedStatus = executionResult.sortedStatus.first(where: { $0.code == "authorizeRequested" }) {
                print(authorizeRequestedStatus)
                if let finalState = executionResult.sortedStatus.first(where: { status in
                    targetStatuses.map { $0.rawValue }.contains(status.code) && status.time > authorizeRequestedStatus.time
                }) {
                    onExecution(finalState, executionResult.links)
                } else {
                    //Start long polling
                    let currentStatuses = executionResult.sortedStatus.map { $0.code }
                    self?.getExecution(
                        url: url,
                        statusesToWait: currentStatuses
                    ) { [weak self] executionResult in
                        if let finalState = executionResult.sortedStatus.first(where: { status in
                            targetStatuses.map { $0.rawValue }.contains(status.code) && status.time > authorizeRequestedStatus.time
                        }) {
                            onExecution(finalState, executionResult.links)
                        } else {
                            self?.onComplete?(.failure)
                        }
                    }
                }
            } else {
                self?.checkExecutionStatus(
                    url: url,
                    targetStatuses: targetStatuses,
                    onExecution: onExecution
                )
            }
        }

    }

    private func getExecution(
        url: URL,
        statusesToWait: [String]? = nil,
        onExecution: @escaping ((GetExecutionResult) -> Void)
    ) {
        var url = url
        if let statusesToWait,
           let data = try? JSONSerialization.data(withJSONObject: statusesToWait, options: []) {
            var urlComps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryComponents = String(data: data, encoding: String.Encoding.utf8)
            urlComps?.queryItems = [.init(name: "waitWhile[status]", value: queryComponents)]
            url = urlComps?.url ?? url
        }
        call(
            url: url,
            method: .GET,
            type: GetExecutionResult.self
        ) { [weak self] result in
            switch result {
            case .success(let executionResult):
                onExecution(executionResult)
            case .failure(let error):
                self?.onComplete?(.error(error))
            }
        }
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
        type: T.Type?,
        completion: @escaping (Result<T, PayrailsError>) -> Void
    ) {
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

        request.addValue(
            (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0",
            forHTTPHeaderField: "x-client-version"
        )

        request.addValue(
            "ios-sdk",
            forHTTPHeaderField: "x-client-type"
        )
        request.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let status = (response as? HTTPURLResponse)?.statusCode,
               (status == 401 || status == 403) {
                completion(.failure(.authenticationError))
                return
            }
            if let error = error {
                completion(.failure(PayrailsError.unknown(error: error)))
                return
            }
            guard let data = data else {
                completion(.failure(PayrailsError.unknown(error: nil)))
                return
            }
            do {
                let jsonDecoder = JSONDecoder.API()
                let result = try jsonDecoder.decode(T.self, from: data)
                completion(.success(result))
            } catch {
                print(error)
                completion(.failure(.unknown(error: error)))
            }
        }
        .resume()
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
