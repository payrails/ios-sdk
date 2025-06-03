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
  let redirect: String?

    enum CodingKeys: String, CodingKey {
        case `self`
        case threeDS = "3ds"
        case lookup
        case confirm
        case redirect
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
    let startPaymentSession: Link?
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
    var paymentType: Payrails.PaymentType? {
        optionalPaymentType
    }
    fileprivate let optionalPaymentType: Payrails.PaymentType?
    let config: PaymentConfig?
    let clientConfig: ClientConfig?
    let paymentInstruments: PaymentInstrument?

    // Define ClientConfig to properly decode that field
    struct ClientConfig: Decodable {
        let displayName: String?
        let flow: String?
        let supportsSaveInstrument: Bool?
        let supportsBillingInfo: Bool?
        let additionalConfig: [String: AnyCodable]?
        
        // Allow any other fields
        private var additionalInfo: [String: AnyCodable]?
        
        enum CodingKeys: String, CodingKey, CaseIterable {
            case displayName, flow, supportsSaveInstrument, supportsBillingInfo, additionalConfig
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            flow = try container.decodeIfPresent(String.self, forKey: .flow)
            supportsSaveInstrument = try container.decodeIfPresent(Bool.self, forKey: .supportsSaveInstrument)
            supportsBillingInfo = try container.decodeIfPresent(Bool.self, forKey: .supportsBillingInfo)
            additionalConfig = try container.decodeIfPresent([String: AnyCodable].self, forKey: .additionalConfig)
            
            // Capture any additional fields
            let additionalContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
            var additionalDict = [String: AnyCodable]()
            
            for key in additionalContainer.allKeys {
                // Use array mapping with explicit type annotation
                let codingKeyValues = CodingKeys.allCases.map { $0.rawValue }
                if !codingKeyValues.contains(key.stringValue) {
                    let value = try additionalContainer.decode(AnyCodable.self, forKey: key)
                    additionalDict[key.stringValue] = value
                }
            }
            
            if !additionalDict.isEmpty {
                additionalInfo = additionalDict
            }
        }
    }
    
    // Helper for dynamic decoding
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }

    // Helper for handling any JSON value
    struct AnyCodable: Codable {
        let value: Any
        
        init(_ value: Any) {
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if container.decodeNil() {
                self.value = NSNull()
            } else if let bool = try? container.decode(Bool.self) {
                self.value = bool
            } else if let int = try? container.decode(Int.self) {
                self.value = int
            } else if let double = try? container.decode(Double.self) {
                self.value = double
            } else if let string = try? container.decode(String.self) {
                self.value = string
            } else if let array = try? container.decode([AnyCodable].self) {
                self.value = array.map { $0.value }
            } else if let dictionary = try? container.decode([String: AnyCodable].self) {
                self.value = dictionary.mapValues { $0.value }
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            switch self.value {
            case is NSNull:
                try container.encodeNil()
            case let bool as Bool:
                try container.encode(bool)
            case let int as Int:
                try container.encode(int)
            case let double as Double:
                try container.encode(double)
            case let string as String:
                try container.encode(string)
            case let array as [Any]:
                try container.encode(array.map { AnyCodable($0) })
            case let dict as [String: Any]:
                try container.encode(dict.mapValues { AnyCodable($0) })
            default:
                throw EncodingError.invalidValue(self.value, EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable cannot encode \(type(of: self.value))"
                ))
            }
        }
    }

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
        case genericRedirect(GenericRedirectConfig)
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
    
    struct GenericRedirectConfig: Decodable {
        // Most genericRedirect payments don't require special config
        // but we may add specific fields if needed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        integrationType = try container.decode(String.self, forKey: .integrationType)
        paymentMethodCode = try container.decode(String.self, forKey: .paymentMethodCode)
        description = try? container.decode(String.self, forKey: .description)
        clientConfig = try? container.decode(ClientConfig.self, forKey: .clientConfig)

        var determinedPaymentType = Payrails.PaymentType(rawValue: paymentMethodCode)

        if determinedPaymentType == nil {
            if clientConfig?.flow == "redirect" || integrationType == "hpp" {
                determinedPaymentType = .genericRedirect
            }
        }
        self.optionalPaymentType = determinedPaymentType
        
        // Initialize with nil values first
        var tempConfig: PaymentConfig? = nil
        var tempInstruments: PaymentInstrument? = nil

        // Decode config only if it exists and payment type is recognized
        let hasConfig = container.contains(.config)
        if let paymentType = optionalPaymentType, hasConfig {
            switch paymentType {
            case .payPal:
                if let paypalConfig = try? container.decode(PayPalConfig.self, forKey: .config) {
                    tempConfig = .paypal(paypalConfig)
                }
            case .applePay:
                if let applePayConfig = try? container.decode(ApplePayConfig.self, forKey: .config) {
                    tempConfig = .applePay(applePayConfig)
                }
            case .genericRedirect:
                if let genericRedirectConfig = try? container.decode(GenericRedirectConfig.self, forKey: .config) {
                    tempConfig = .genericRedirect(genericRedirectConfig)
                }
            default:
                break
            }
        }
        
        // Decode paymentInstruments separately (regardless of config presence)
        if let paymentType = optionalPaymentType {
            switch paymentType {
            case .payPal:
                if let element = try? container.decode([PayPalPaymentInstrument].self, forKey: .paymentInstruments) {
                    tempInstruments = .paypal(element)
                }
            case .card:
                if let element = try? container.decode([CardInstrument].self, forKey: .paymentInstruments) {
                    tempInstruments = .card(element)
                }
            default:
                break
            }
        }
        
        // Assign the final values
        config = tempConfig
        paymentInstruments = tempInstruments
    }

    private enum CodingKeys: String, CodingKey {
        case integrationType, paymentMethodCode, description, config, clientConfig, paymentInstruments
    }
}


public struct PublicSDKConfig {
    public let holderRefecerence: String
    
    internal init(from config: SDKConfig) {
        self.holderRefecerence = config.holderReference ?? ""
    }
}
