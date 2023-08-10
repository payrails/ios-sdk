import Foundation

struct SDKConfig: Decodable {
    let token: String
    let holderReference: String?
    let vaultConfiguration: VaultConfiguration?
    let execution: Execution?
    let amount: Amount
}

struct VaultConfiguration: Decodable {
    let vaultId: String?
    let vaultUrl: String?
    let token: String?
    let status: String?
    let providerId: String?
    let providerConfigId: String?
    let cardTableName: String?
    let links: VaultConfigurationLinks?
}

struct VaultConfigurationLinks: Decodable {
    let saveInstrument: Link?
}

struct Link: Decodable {
    let method: String?
    let href: String?
}

struct Execution: Decodable {
    let id: String
    let status: [Status]
    let createdAt: Date
    let merchantReference: String
    let holderReference: String
    let holderId: String
    let workflow: Workflow
    let links: ExecutionLinks
    let initialResults: [InitialResult];
}

struct Status: Decodable {
    let code: String
    let time: Date
}

struct ExecutionLinks: Decodable {
  let `self`: String
  let lookup: Link?
}

struct Workflow: Decodable {
  let code: String
  let version: Double
}

struct Amount: Codable {
  let value: String
  let currency: String
}

struct InitialResult: Decodable {
    let httpCode: Int
    let body: Body
}

struct Body: Decodable {
    let name: String;
    let actionId: String
    let executedAt: Date
    let data: PaymentData
    let links: BodyLinks;
}

struct BodyLinks: Decodable {
    let execution: String
    let authorize: Link
    let startPaymentSession: Link
}

struct PaymentData: Decodable {
    let paymentCompositionOptions: [PaymentCompositionOptions]
}

struct PaymentCompositionOptions: Decodable {
    let integrationType: String
    let paymentMethodCode: String
    let description: String?
    let paymentType: Payrails.PaymentType
    let config: PaymentConfig?
    let originalConfig: [String: Any]?

    enum PaymentConfig {
        case applePay(ApplePayConfig)
        case paypal(PayPalConfig)
        case card
        case other([String: Any])
    }

    struct ApplePayConfig: Decodable {
        struct Parameters: Decodable {
            let countryCode: String
            let merchantCapabilities: [String]
            let merchantIdentifier: String
            let supportedNetworks: [String]
        }
        let parameters: Parameters
    }

    struct PayPalConfig: Decodable {
        let clientId: String
        let merchantId: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        integrationType = try container.decode(String.self, forKey: .integrationType)
        paymentMethodCode = try container.decode(String.self, forKey: .paymentMethodCode)
        description = try? container.decode(String.self, forKey: .description)

        paymentType = Payrails.PaymentType(rawValue: paymentMethodCode) ?? .other
        originalConfig = try? container.decode([String: Any].self, forKey: .config)

        guard let originalConfig else {
            config = nil
            return
        }

        switch paymentType {
        case .card:
            config = nil
        case .payPal:
            config = .paypal(try container.decode(PayPalConfig.self, forKey: .config))
        case .applePay:
            config = .applePay(try container.decode(ApplePayConfig.self, forKey: .config))
        case .other:
            config = .other(originalConfig)
        }
    }

    private enum CodingKeys: CodingKey {
        case integrationType, paymentMethodCode, description, config
    }
}