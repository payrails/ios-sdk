import Foundation

public extension Payrails {

    /// Describes the payment attempt the SDK is about to start, handed to the merchant's
    /// `RequestStartHandler` so it can decide whether to let the attempt proceed.
    ///
    /// The gate fires for **every** payment method, so a handler that only cares about one
    /// should branch on `paymentMethodCode` and answer `.proceed` for everything else:
    ///
    ///     onRequestStart: { context, completion in
    ///         guard context.paymentMethodCode == "payPal" else {
    ///             completion(.proceed)
    ///             return
    ///         }
    ///         myBackend.validate { completion($0) }
    ///     }
    ///
    /// Mirrors the Web SDK's `requestStart` event payload.
    struct RequestStartContext {

        /// The Payrails execution this attempt runs against, when one is known. Useful for
        /// correlating the merchant's own pre-payment call with the payment in Payrails.
        public let executionId: String?

        /// The payment method the customer chose — `"card"`, `"payPal"`, `"applePay"`, or any
        /// other code configured for the session. Matches the codes used by
        /// `getPaymentMethodConfig(_:)`.
        public let paymentMethodCode: String

        /// Whether the SDK is about to authorize a payment or tokenize an instrument.
        public let action: Action

        public init(
            executionId: String?,
            paymentMethodCode: String,
            action: Action
        ) {
            self.executionId = executionId
            self.paymentMethodCode = paymentMethodCode
            self.action = action
        }

        /// Raw values match the Web SDK's `PayrailsElementAction` so both SDKs report the same
        /// strings.
        public enum Action: String {
            /// The SDK is about to send an authorization request.
            case authorize = "AUTHORIZE"

            /// The SDK is about to tokenize an instrument without charging it.
            ///
            /// Reserved: the tokenization flow (`session.tokenize`) is not gated yet, so this
            /// case is never emitted today. It exists so that gating tokenization later is an
            /// additive change rather than a breaking one for handlers that `switch` on `action`.
            case tokenize = "TOKENIZE"
        }
    }
}
