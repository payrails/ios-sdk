import Foundation

// Root level array of payment composition objects
typealias PaymentCompositions = [PaymentComposition]

struct PaymentComposition {
    let paymentMethodCode: String
    let integrationType: String
    let amount: Amount
    let storeInstrument: Bool
    // TODO: this must be typed better, problem is applePay and others have different object structures
    let paymentInstrumentData: Any?
    let enrollInstrumentToNetworkOffers: Bool?
}


struct PaymentInstrumentData {
    let encryptedData: String
    let vaultProviderConfigId: String
    let billingAddress: BillingAddress
}

struct BillingAddress {
    let country: Country
}

struct Country {
    let code: String
    let fullName: String
    let iso3: String
}
