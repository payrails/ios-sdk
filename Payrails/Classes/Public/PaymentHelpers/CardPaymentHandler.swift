import Foundation
import WebKit

class CardPaymentHandler: NSObject {
    private weak var delegate: PaymentHandlerDelegate?
    private var response: Any?
    private let saveInstrument: Bool
    public weak var presenter: PaymentPresenter?
    private var webViewController: PayWebViewController?
    private var selfLink: String

    init(
        delegate: PaymentHandlerDelegate?,
        saveInstrument: Bool,
        presenter: PaymentPresenter?
    ) {
        self.delegate = delegate
        self.saveInstrument = saveInstrument
        self.presenter = presenter
        self.selfLink = ""
    }
}

extension CardPaymentHandler: PaymentHandler {
    func set(response: Any) {
        self.response = response
    }
    
    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter?
    ) {
        let effectivePresenter = presenter ?? self.presenter
        
        guard let encryptedCardData = effectivePresenter?.encryptedCardData, !encryptedCardData.isEmpty else {
            print("Error: Missing or empty encrypted card data.")
            delegate?.paymentHandlerDidFail(
                handler: self,
                error: .missingData("Encrypted card data is required but was missing or empty."),
                type: .card
            )
            return
        }

        var data: [String: Any] = [:]
        data["card"] = [
            "vaultProviderConfigId": "0077318a-5dd2-47fb-b709-e475d2172d32",
            "encryptedData": encryptedCardData
        ]

        delegate?.paymentHandlerDidFinish(
            handler: self,
            type: .card,
            status: .success,
            payload: [
                "paymentInstrumentData": data,
                "storeInstrument": saveInstrument
            ]
        )
    }

    func handlePendingState(with executionResult: GetExecutionResult) {
        self.selfLink = executionResult.links.`self`
        
        guard let link = executionResult.links.threeDS,
            let url = URL(string: link) else {
            delegate?.paymentHandlerDidFail(
                handler: self,
                error: .missingData("Pending state failed due to missing 3ds link"),
                type: .card
            )
            return
        }
        
        delegate?.paymentHandlerWillRequestChallengePresentation(self)

        DispatchQueue.main.async {
            let webViewController = PayWebViewController(
                url: url,
                delegate: self
            )
            self.presenter?.presentPayment(webViewController)
            self.webViewController = webViewController
        }
    }
    
    func processSuccessPayload(
        payload: [String: Any]?,
        amount: Amount,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let payload = payload,
              let paymentInstrumentData = payload["paymentInstrumentData"] as? [String: Any],
              let cardData = paymentInstrumentData["card"] as? [String: Any],
              let encryptedData = cardData["encryptedData"] as? String,
              let vaultProviderConfigId = cardData["vaultProviderConfigId"] as? String,
              let storeInstrument = payload["storeInstrument"] as? Bool else {

            completion(.failure(PayrailsError.invalidDataFormat))
            return
        }

        let country = Country(code: "DE", fullName: "Germany", iso3: "DEU") // TODO: Review hardcoded country
        let billingAddress = BillingAddress(country: country)

        let instrumentData = PaymentInstrumentData(
            encryptedData: encryptedData,
            vaultProviderConfigId: vaultProviderConfigId,
            billingAddress: billingAddress
        )

        let paymentComposition = PaymentComposition(
            paymentMethodCode: Payrails.PaymentType.card.rawValue,
            integrationType: "api",
            amount: amount,
            storeInstrument: storeInstrument,
            paymentInstrumentData: instrumentData,
            enrollInstrumentToNetworkOffers: false
        )

        let returnInfo: [String: String] = [
             "success": "https://assets.payrails.io/html/payrails-success.html",
             "cancel": "https://assets.payrails.io/html/payrails-cancel.html",
             "error": "https://assets.payrails.io/html/payrails-error.html",
             "pending": "https://assets.payrails.io/html/payrails-pending.html"
        ]
        let risk = ["sessionId": "03bf5b74-d895-48d9-a871-dcd35e609db8"]
        let meta = ["risk": risk]
        let amountDict = ["value": amount.value, "currency": amount.currency]

        let body: [String: Any] = [
            "amount": amountDict,
            "paymentComposition": [paymentComposition],
            "returnInfo": returnInfo,
            "meta": meta
        ]
        
        completion(.success(body))
    }
}

extension CardPaymentHandler: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let urlString = navigationAction.request.mainDocumentURL?.absoluteString else {            decisionHandler(.allow)
            return
        }

        let successPrefix = "https://assets.payrails.io/html/payrails-success.html"
        let cancelPrefix = "https://assets.payrails.io/html/payrails-cancel.html"
        let errorPrefix = "https://assets.payrails.io/html/payrails-error.html"

        let finalAction: (() -> Void)?

        if urlString.hasPrefix(successPrefix) {
            finalAction = { [weak self] in
                guard let self = self else { return }

                self.delegate?.paymentHandlerDidHandlePending(
                    handler: self,
                    type: .card,
                    link: Link(
                        method: "GET",
                        href: selfLink,
                        action: LinkAction(
                            redirectMethod: "",
                            redirectUrl: "",
                            parameters:  LinkAction.Parameters(orderId: "orderId", tokenId: "tokenId"),
                            type: "")
                    ),
                    payload: [:]
                )
            }
        } else if urlString.hasPrefix(cancelPrefix) {
            finalAction = { [weak self] in
                guard let self = self else { return }
                self.delegate?.paymentHandlerDidFinish(
                    handler: self,
                    type: .card,
                    status: .canceled,
                    payload: nil
                )
            }
        } else if urlString.hasPrefix(errorPrefix) {
            finalAction = { [weak self] in
                guard let self = self else { return }
                self.delegate?.paymentHandlerDidFinish(
                    handler: self,
                    type: .card,
                    status: .error(nil),
                    payload: nil
                )
            }
        } else {
            finalAction = nil
        }

        // If we matched one of the final URLs, perform the common cleanup and specific action
        if let action = finalAction {
            decisionHandler(.cancel)
            action()
            webViewController?.dismiss(animated: true)
            webViewController = nil
        } else {
            decisionHandler(.allow)
        }
    }
}


