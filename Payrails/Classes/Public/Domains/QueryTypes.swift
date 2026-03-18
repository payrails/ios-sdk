import Foundation

// MARK: - Public result value types

public struct PayrailsAmount {
    public let value: String
    public let currency: String
}

public struct PayrailsLink {
    public let method: String?
    public let href: String?
}

public struct PayrailsPaymentOption {
    public let paymentMethodCode: String
    public let description: String?
    public let integrationType: String
    public let clientConfig: ClientConfig?

    public struct ClientConfig {
        public let displayName: String?
        public let flow: String?
        public let supportsSaveInstrument: Bool?
        public let supportsBillingInfo: Bool?
    }

    init(from options: PaymentOptions) {
        paymentMethodCode = options.paymentMethodCode
        description = options.description
        integrationType = options.integrationType
        clientConfig = options.clientConfig.map {
            ClientConfig(
                displayName: $0.displayName,
                flow: $0.flow,
                supportsSaveInstrument: $0.supportsSaveInstrument,
                supportsBillingInfo: $0.supportsBillingInfo
            )
        }
    }
}

// MARK: - Query key

public enum PayrailsQueryKey {
    /// The holder reference for the current session.
    case holderReference
    /// The payment amount and currency for the current execution.
    case amount
    /// The execution ID.
    case executionId
    /// API link for BIN lookup.
    case binLookup
    /// API link for deleting a stored instrument.
    case instrumentDelete
    /// API link for updating a stored instrument.
    case instrumentUpdate
    /// Configuration for a specific payment method.
    /// Pass `"all"` to return all methods, `"redirect"` for redirect-flow methods only,
    /// or a specific `paymentMethodCode` for a single result.
    case paymentMethodConfig(paymentMethodCode: String)
    /// Stored instruments for the given payment type.
    case paymentMethodInstruments(type: Payrails.PaymentType)
}

// MARK: - Query result

public enum PayrailsQueryResult {
    case string(String)
    case amount(PayrailsAmount)
    case link(PayrailsLink)
    case paymentOptions([PayrailsPaymentOption])
    case storedInstruments([StoredInstrument])
}
