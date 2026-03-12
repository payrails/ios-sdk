/*
 * Copyright (c) 2022 Skyflow
*/

//
//  File.swift
//  
//
//  Created by Akhil Anil Mangala on 25/10/21.
//

import Foundation

internal enum PayrailsAssets {
    static let cardIconBaseURL = "https://assets.payrails.io/img/logos/card"
}

internal class CreditCard {
    var defaultName: String
    var regex: String
    var cardLengths: [Int]
    var formatPattern: String
    var securityCodeLength: Int
    var securityCodeName: String
    var imageName: String
    public required init( defaultName: String, regex: String, cardLengths: [Int], formatPattern: String, securityCodeLength: Int, securityCodeName: String, imageName: String) {
        self.defaultName = defaultName
        self.regex = regex
        self.formatPattern = formatPattern
        self.cardLengths = cardLengths
        self.securityCodeLength = securityCodeLength
        self.securityCodeName = securityCodeName
        self.imageName = imageName
    }
    public init(defaultName: String, imageName: String) {
        self.defaultName = defaultName
        self.imageName = imageName
        self.regex = ""
        self.cardLengths = []
        self.formatPattern = ""
        self.securityCodeLength = 0
        self.securityCodeName = ""
    }
}

/// Default Cards and their FormatPatterns and validationrules.
public enum  CardType: CaseIterable {
    case VISA
    case MASTERCARD
    case DISCOVER
    case AMEX
    case DINERS_CLUB
    case JCB
    case MAESTRO
    case UNIONPAY
    case HIPERCARD
    case CARTES_BANCAIRES
    case UNKNOWN
    case EMPTY

    var instance: CreditCard {
        switch self {
        case .VISA: return CreditCard(
            defaultName: "Visa", regex: "^4\\d*", cardLengths: [13, 16],
            formatPattern: "#### #### #### ####", securityCodeLength: 3,
            securityCodeName: SecurityCode.cvv.rawValue, imageName: "Visa-Card")

        case .MASTERCARD: return CreditCard(
            defaultName: "Mastercard", regex: "^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[0-1]|2720)\\d*",
            cardLengths: [16], formatPattern: "#### #### #### ####",
            securityCodeLength: 3, securityCodeName: SecurityCode.cvc.rawValue, imageName: "Mastercard-Card")

        case .DISCOVER: return CreditCard(
            defaultName: "Discover", regex: "^(6011|65|64[4-9]|622)\\d*",
            cardLengths: [16, 17, 18, 19],
            formatPattern: "#### #### #### #### ###", securityCodeLength: 3, securityCodeName: SecurityCode.cid.rawValue, imageName: "Discover-Card")

        case .AMEX: return CreditCard(
            defaultName: "Amex", regex: "^3[47]\\d*",
            cardLengths: [15], formatPattern: "#### ###### #####",
            securityCodeLength: 4, securityCodeName: SecurityCode.cid.rawValue, imageName: "Amex-Card")

        case .DINERS_CLUB: return CreditCard(
            defaultName: "DinersClub", regex: "^(36|38|30[0-5])\\d*",
            cardLengths: [14, 15, 16, 17, 18, 19],
            formatPattern: "#### ###### #########", securityCodeLength: 3,
            securityCodeName: SecurityCode.cvv.rawValue, imageName: "Diners-Card")

        case .JCB: return CreditCard(
            defaultName: "Jcb", regex: "^35\\d*",
            cardLengths: [16, 17, 18, 19],
            formatPattern: "#### #### #### #### ###", securityCodeLength: 3,
            securityCodeName: SecurityCode.cvv.rawValue, imageName: "JCB-Card")

        case .MAESTRO: return CreditCard(
            defaultName: "Maestro", regex: "^(5018|5020|5038|5043|5[6-9]|6020|6304|6703|6759|676[1-3])\\d*",
            cardLengths: [12, 13, 14, 15, 16, 17, 18, 19],
            formatPattern: "#### #### #### #### ###", securityCodeLength: 3,
            securityCodeName: SecurityCode.cvc.rawValue, imageName: "Maestro-Card")

        case .UNIONPAY: return CreditCard(
            defaultName: "Unionpay", regex: "^62\\d*",
            cardLengths: [16, 17, 18, 19], formatPattern: "#### #### #### #### ###", securityCodeLength: 3,
            securityCodeName: SecurityCode.cvn.rawValue, imageName: "Unionpay-Card")

        case .HIPERCARD: return CreditCard(
            defaultName: "Hipercard", regex: "^606282\\d*",
            cardLengths: [14, 15, 16, 17, 18, 19], formatPattern: "#### #### #### #### ###",
            securityCodeLength: 3, securityCodeName: SecurityCode.cvc.rawValue, imageName: "Hipercard-Card")
        case .UNKNOWN: return CreditCard(
            defaultName: "Unknown", regex: "\\d+",
            cardLengths: [12, 13, 14, 15, 16, 17, 18, 19], formatPattern: "#### #### #### #### ###",
            securityCodeLength: 3, securityCodeName: SecurityCode.cvv.rawValue, imageName: "Unknown-Card")
        case .EMPTY: return CreditCard(
            defaultName: "Empty", regex: "^$",
            cardLengths: [12, 13, 14, 15, 16, 17, 18, 19], formatPattern: "#### #### #### #### ###",
            securityCodeLength: 3, securityCodeName: SecurityCode.cvv.rawValue, imageName: "Unknown-Card")
        case .CARTES_BANCAIRES:
            return CreditCard(defaultName: "Cartes Bancaires", imageName: "Cartes-Bancaires-Card")
        }
    }
        static func forCardNumber(cardNumber: String) -> CardType {
        let patternMatch = forCardPattern(cardNumber: cardNumber)
            if patternMatch.instance.defaultName != "Empty" {
                return patternMatch
            } else {
                return CardType.EMPTY
            }
        }

        private static func forCardPattern(cardNumber: String) -> CardType {
            for card in CardType.allCases {
                if NSPredicate(format: "SELF MATCHES %@", card.instance.regex).evaluate(with: cardNumber) {
                    return card
                }
            }
            return CardType.EMPTY
        }
}

internal enum SecurityCode: String {
    case cvv = "cvv"
    case cvc = "cvc"
    case cvn = "cvn"
    case cid = "cid"
}

public enum CardIconAlignment {
  case left
  case right
}

internal enum CardNetwork: Equatable {
    case VISA
    case MASTERCARD
    case AMEX
    case DISCOVER
    case JCB
    case DINERS
    case UNIONPAY
    case UNKNOWN

    private static let baseIconURL = PayrailsAssets.cardIconBaseURL
    private static let genericCardIconURL = "\(baseIconURL)/ic-card.png"

    private struct NetworkConfig {
        let network: CardNetwork
        let detectionRegex: String?
        let iconFileName: String?
        let cardTypes: [CardType]
        let schemeAliases: [String]
    }

    // Keep Android parity by preserving this config order for PAN detection.
    private static let configs: [NetworkConfig] = [
        NetworkConfig(
            network: .VISA,
            detectionRegex: "^4\\d*",
            iconFileName: "visa.png",
            cardTypes: [.VISA],
            schemeAliases: []
        ),
        NetworkConfig(
            network: .MASTERCARD,
            detectionRegex: "^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[0-1]|2720)\\d*",
            iconFileName: "mastercard.png",
            cardTypes: [.MASTERCARD],
            schemeAliases: ["master card"]
        ),
        NetworkConfig(
            network: .AMEX,
            detectionRegex: "^3[47]\\d*",
            iconFileName: "amex.png",
            cardTypes: [.AMEX],
            schemeAliases: ["american express"]
        ),
        NetworkConfig(
            network: .DISCOVER,
            detectionRegex: "^(6011|65|64[4-9]|622)\\d*",
            iconFileName: "discover.png",
            cardTypes: [.DISCOVER],
            schemeAliases: []
        ),
        NetworkConfig(
            network: .JCB,
            detectionRegex: "^35(2[89]|[3-8]\\d)\\d*",
            iconFileName: "jcb.png",
            cardTypes: [.JCB],
            schemeAliases: []
        ),
        NetworkConfig(
            network: .DINERS,
            detectionRegex: "^3(0[0-5]|[68])\\d*",
            iconFileName: "diners.png",
            cardTypes: [.DINERS_CLUB],
            schemeAliases: ["diners club"]
        ),
        NetworkConfig(
            network: .UNIONPAY,
            detectionRegex: "^62\\d*",
            iconFileName: "unionpay.png",
            cardTypes: [.UNIONPAY],
            schemeAliases: []
        ),
        NetworkConfig(
            network: .UNKNOWN,
            detectionRegex: nil,
            iconFileName: nil,
            cardTypes: [],
            schemeAliases: []
        )
    ]

    internal static func detect(pan: String) -> CardNetwork {
        let normalizedPAN = normalize(pan: pan)
        guard !normalizedPAN.isEmpty else {
            return .UNKNOWN
        }

        for config in configs {
            guard let regex = config.detectionRegex else {
                continue
            }
            if matches(normalizedPAN, regex: regex) {
                return config.network
            }
        }

        return .UNKNOWN
    }

    internal static func from(cardType: CardType?) -> CardNetwork? {
        guard let cardType else {
            return nil
        }

        return configs.first(where: { $0.cardTypes.contains(cardType) })?.network
    }

    internal static func from(schemeName: String?) -> CardNetwork? {
        guard let schemeName else {
            return nil
        }

        let normalizedScheme = schemeName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedScheme.isEmpty else {
            return nil
        }

        for config in configs {
            if config.schemeAliases.contains(normalizedScheme) {
                return config.network
            }
            if config.cardTypes.contains(where: { $0.instance.defaultName.lowercased() == normalizedScheme }) {
                return config.network
            }
        }

        return nil
    }

    internal static func resolve(schemeName: String?, cardType: CardType?, pan: String) -> CardNetwork {
        from(schemeName: schemeName)
            ?? from(cardType: cardType)
            ?? detect(pan: pan)
    }

    internal var iconURL: URL? {
        if self == .UNKNOWN {
            return URL(string: Self.genericCardIconURL)
        }

        guard let config = Self.configs.first(where: { $0.network == self }),
              let iconFileName = config.iconFileName else {
            return nil
        }

        return URL(string: "\(Self.baseIconURL)/\(iconFileName)")
    }

    private static func normalize(pan: String) -> String {
        pan.filter(\.isNumber)
    }

    private static func matches(_ value: String, regex: String) -> Bool {
        value.range(of: regex, options: .regularExpression) != nil
    }
}

internal enum FieldStaticIcon {
    case cardNumber
    case cvv
    case cardholder
    case expiryDate

    private static let baseIconURL = PayrailsAssets.cardIconBaseURL

    static func from(fieldType: ElementType) -> FieldStaticIcon? {
        switch fieldType {
        case .CARD_NUMBER:
            return .cardNumber
        case .CVV:
            return .cvv
        case .CARDHOLDER_NAME:
            return .cardholder
        case .EXPIRATION_DATE, .EXPIRATION_MONTH, .EXPIRATION_YEAR:
            return .expiryDate
        default:
            return nil
        }
    }

    var iconURL: URL? {
        let fileName: String
        switch self {
        case .cardNumber:
            fileName = "ic-card.png"
        case .cvv:
            fileName = "ic-cvv.png"
        case .cardholder:
            fileName = "ic-cardholder.png"
        case .expiryDate:
            fileName = "ic-expiration.png"
        }
        return URL(string: "\(Self.baseIconURL)/\(fileName)")
    }

    var sfSymbolFallback: String {
        switch self {
        case .cardNumber:
            return "creditcard"
        case .cvv:
            return "lock.shield"
        case .cardholder:
            return "person"
        case .expiryDate:
            return "calendar"
        }
    }
}
