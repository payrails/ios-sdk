//
//  GenericRedirectHandler.swift
//  Pods
//
//  Created by Mustafa Dikici on 15.05.25.
//

import Foundation
import WebKit

class GenericRedirectHandler: NSObject {
    private weak var delegate: PaymentHandlerDelegate?
    private var response: Any?
    private let saveInstrument: Bool
    private let paymentOption: PaymentOptions
    public weak var presenter: PaymentPresenter?
    private var webViewController: PayWebViewController?
    private var paymentCompleted = false

    init(
        delegate: PaymentHandlerDelegate?,
        saveInstrument: Bool,
        presenter: PaymentPresenter?,
        paymentOption: PaymentOptions
    ) {
        self.delegate = delegate
        self.saveInstrument = saveInstrument
        self.presenter = presenter
        self.paymentOption = paymentOption
    }
}

extension GenericRedirectHandler: PaymentHandler {
    func set(response: Any) {
        self.response = response
    }
    
    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter?
    ) {
        let effectivePresenter = presenter ?? self.presenter
        
        delegate?.paymentHandlerDidFinish(
            handler: self,
            type: .genericRedirect,
            status: .success,
            payload: [
                "storeInstrument": saveInstrument
            ]
        )
    }

    func handlePendingState(with executionResult: GetExecutionResult) {
        guard let link = executionResult.links.redirect,
            let url = URL(string: link) else {
            delegate?.paymentHandlerDidFail(
                handler: self,
                error: .missingData("Pending state failed due to missing redirect link"),
                type: .genericRedirect
            )
            return
        }
        delegate?.paymentHandlerWillRequestChallengePresentation(self)

        // Reset payment completed flag when starting a new payment flow
        paymentCompleted = false

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create dismissal callback
            let dismissalCallback = { [weak self] in
                guard let self = self else { return }
                
                // Check if payment was not completed before dismissal
                if !self.paymentCompleted {
                    self.delegate?.paymentHandlerDidFinish(
                        handler: self,
                        type: .genericRedirect,
                        status: .canceled,
                        payload: nil
                    )
                    self.webViewController = nil
                }
            }
            
            let webViewController = PayWebViewController(
                url: url,
                delegate: self,
                dismissalCallback: dismissalCallback
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
        let returnInfo: [String: String] = [
             "success": "https://assets.payrails.io/html/payrails-success.html",
             "cancel": "https://assets.payrails.io/html/payrails-cancel.html",
             "error": "https://assets.payrails.io/html/payrails-error.html",
             "pending": "https://assets.payrails.io/html/payrails-pending.html"
        ]
        let risk = ["sessionId": "03bf5b74-d895-48d9-a871-dcd35e609db8"]
        let meta = ["risk": risk]
        let amountDict = ["value": amount.value, "currency": amount.currency]
        
        let paymentComposition = PaymentComposition(
            paymentMethodCode: self.paymentOption.paymentMethodCode,
            integrationType: self.paymentOption.integrationType,
            amount: amount,
            storeInstrument: false,
            paymentInstrumentData: nil,
            enrollInstrumentToNetworkOffers: false
        )

        let body: [String: Any] = [
            "amount": amountDict,
            "returnInfo": returnInfo,
            "meta": meta,
            "paymentComposition": [paymentComposition]
        ]
        
        completion(.success(body))
    }
}

extension GenericRedirectHandler: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let urlString = navigationAction.request.mainDocumentURL?.absoluteString else {
            decisionHandler(.allow)
            return
        }

        let successPrefix = "https://assets.payrails.io/html/payrails-success.html"
        let cancelPrefix = "https://assets.payrails.io/html/payrails-cancel.html"
        let errorPrefix = "https://assets.payrails.io/html/payrails-error.html"

        let finalAction: (() -> Void)?
        
        print("Webview navigation")
        print(urlString)

        if urlString.hasPrefix(successPrefix) {
            finalAction = { [weak self] in
                guard let self = self else { return }
                self.paymentCompleted = true
                self.delegate?.paymentHandlerDidHandlePending(
                    handler: self,
                    type: .genericRedirect,
                    link: nil,
                    payload: [:]
                )
            }
        } else if urlString.hasPrefix(cancelPrefix) {
            finalAction = { [weak self] in
                guard let self = self else { return }
                self.paymentCompleted = true
                self.delegate?.paymentHandlerDidFinish(
                    handler: self,
                    type: .genericRedirect,
                    status: .canceled,
                    payload: nil
                )
            }
        } else if urlString.hasPrefix(errorPrefix) {
            finalAction = { [weak self] in
                guard let self = self else { return }
                self.paymentCompleted = true
                self.delegate?.paymentHandlerDidFinish(
                    handler: self,
                    type: .genericRedirect,
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
