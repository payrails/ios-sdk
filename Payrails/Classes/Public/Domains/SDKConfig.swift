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
    let action: LinkAction?
}

struct LinkAction: Decodable {
    let redirectMethod: String
    let redirectUrl: String
    let parameters: Parameters
    let type: String?

    struct Parameters: Decodable {
        let orderId: String?
        let tokenId: String?
    }
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
    let initialResults: [InitialResult]
}

struct Status: Decodable {
    let code: String
    let time: Date
}

struct ExecutionLinks: Decodable {
  let `self`: String
  let threeDS: String?
  let lookup: Link?
  let confirm: Link?

    enum CodingKeys: String, CodingKey {
        case `self`
        case threeDS = "3ds"
        case lookup
        case confirm
    }
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
    let name: String
    let actionId: String
    let executedAt: Date
    let data: PaymentData
    let links: BodyLinks
}

struct BodyLinks: Decodable {
    let execution: String
    let authorize: Link
    let startPaymentSession: Link
}

struct PaymentData: Decodable {
    let paymentOptions: [PaymentOptions]

    enum CodingKeys: CodingKey {
        case paymentCompositionOptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let paymentOptions = try container.decode(
            [PaymentOptions].self,
            forKey: .paymentCompositionOptions
        )
        self.paymentOptions = paymentOptions
            .filter { $0.optionalPaymentType != nil }
    }
}

struct PaymentOptions: Decodable {
    let integrationType: String
    let paymentMethodCode: String
    let description: String?
    var paymentType: Payrails.PaymentType {
        optionalPaymentType!
    }
    fileprivate let optionalPaymentType: Payrails.PaymentType?
    let config: PaymentConfig?
    let originalConfig: [String: Any]?
    let paymentInstruments: PaymentInstrument?

    enum PaymentInstrument {
        case paypal([PayPalPaymentInstrument])
        case card([CardInstrument])
    }

    struct CardInstrument: StoredInstrument, Decodable {
        var id: String
        
        var email: String? { nil }

        var description: String? { String(format: "%@***%@", data?.bin ?? "", data?.suffix ?? "") }

        var type: Payrails.PaymentType {
            .card
        }

        let createdAt: String
        let status: String
        let data: CardInstrumentData?
    }


    struct CardInstrumentData: Decodable {
        let bin: String?
        let suffix: String?
    }

    struct PayPalPaymentInstrument: StoredInstrument, Decodable {
        var description: String? {
            email
        }

        var email: String? {
            data?.email
        }

        var type: Payrails.PaymentType {
            .payPal
        }

        let id: String
        let paymentMethod: String
        let holderId: String
        let createdAt: String
        let status: String
        let data: PayPalInstrumentData?
    }

    struct PayPalInstrumentData: Decodable {
        let email: String?
    }

    enum PaymentConfig {
        case applePay(ApplePayConfig)
        case paypal(PayPalConfig)
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

        optionalPaymentType = Payrails.PaymentType(rawValue: paymentMethodCode)
        originalConfig = try? container.decode([String: Any].self, forKey: .config)

        guard let optionalPaymentType else {
            config = nil
            paymentInstruments = nil
            return
        }

        switch optionalPaymentType {
        case .payPal:
            config = .paypal(try container.decode(PayPalConfig.self, forKey: .config))
            if let element = try? container.decode([PayPalPaymentInstrument].self, forKey: .paymentInstruments) {
                paymentInstruments = .paypal(element)
            } else {
                paymentInstruments = nil
            }

        case .applePay:
            config = .applePay(try container.decode(ApplePayConfig.self, forKey: .config))
            paymentInstruments = nil

        case .card:
            config = nil

            if let element = try? container.decode([CardInstrument].self, forKey: .paymentInstruments) {
                paymentInstruments = .card(element)
            } else {
                paymentInstruments = nil
            }
            
        }
    }

    private enum CodingKeys: CodingKey {
        case integrationType, paymentMethodCode, description, config, paymentInstruments
    }
}
