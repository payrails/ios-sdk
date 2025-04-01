import Foundation

// Root level array of payment composition objects
typealias PaymentCompositions = [PaymentComposition]

struct PaymentComposition {
    let paymentMethodCode: String
    let integrationType: String
    let amount: Amount
    let storeInstrument: Bool
    let paymentInstrumentData: PaymentInstrumentData?
    let enrollInstrumentToNetworkOffers: Bool
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

// Example manual creation:
// let country = Country(code: "DE", fullName: "Germany", iso3: "DEU")
// let billingAddress = BillingAddress(country: country)
// let paymentInstrumentData = PaymentInstrumentData(
//     encryptedData: "encrypted_string_here",
//     vaultProviderConfigId: "0077318a-5dd2-47fb-b709-e475d2172d32",
//     billingAddress: billingAddress
// )
// let amount = Amount(value: "100.00", currency: "EUR")
// let paymentComposition = PaymentComposition(
//     paymentMethodCode: "card",
//     integrationType: "api",
//     amount: amount,
//     storeInstrument: false,
//     paymentInstrumentData: paymentInstrumentData,
//     enrollInstrumentToNetworkOffers: false
// )
