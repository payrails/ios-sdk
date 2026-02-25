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
        case .VISA : return CreditCard(
            defaultName: "Visa", regex: "^4\\d*", cardLengths: [13, 16],
            formatPattern: "#### #### #### ####", securityCodeLength: 3,
            securityCodeName: SecurityCode.cvv.rawValue, imageName: "Visa-Card")

        case .MASTERCARD: return CreditCard(
            defaultName: "Mastercard", regex: "^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[0-1]|2720)\\d*",
            cardLengths: [16], formatPattern: "#### #### #### ####",
            securityCodeLength: 3, securityCodeName: SecurityCode.cvc.rawValue, imageName: "Mastercard-Card")

        case .DISCOVER : return CreditCard(
            defaultName: "Discover", regex: "^(6011|65|64[4-9]|622)\\d*",
            cardLengths: [16, 17, 18, 19],
            formatPattern: "#### #### #### #### ###", securityCodeLength: 3, securityCodeName: SecurityCode.cid.rawValue, imageName: "Discover-Card")

        case .AMEX: return CreditCard(
            defaultName: "Amex", regex: "^3[47]\\d*",
            cardLengths: [15], formatPattern: "#### ###### #####",
            securityCodeLength: 4, securityCodeName: SecurityCode.cid.rawValue, imageName: "Amex-Card")

        case .DINERS_CLUB: return CreditCard(
            defaultName: "DinersClub", regex: "^(36|38|30[0-5])\\d*",
            cardLengths: [14,15,16, 17, 18, 19],
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
                if NSPredicate(format: "SELF MATCHES %@", card.instance.regex).evaluate(with: cardNumber){
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

    private static let visaRegex = "^4\\d*"
    private static let mastercardRegex = "^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[0-1]|2720)\\d*"
    private static let amexRegex = "^3[47]\\d*"
    private static let discoverRegex = "^(6011|65|64[4-9]|622)\\d*"
    private static let jcbRegex = "^35(2[89]|[3-8]\\d)\\d*"
    private static let dinersRegex = "^3(0[0-5]|[68])\\d*"
    private static let unionPayRegex = "^62\\d*"
    private static let baseIconURL = "https://assets.payrails.io/img/integrations"

    internal static func detect(pan: String) -> CardNetwork {
        let normalizedPAN = normalize(pan: pan)
        guard !normalizedPAN.isEmpty else {
            return .UNKNOWN
        }

        if matches(normalizedPAN, regex: visaRegex) {
            return .VISA
        }

        if matches(normalizedPAN, regex: mastercardRegex) {
            return .MASTERCARD
        }

        if matches(normalizedPAN, regex: amexRegex) {
            return .AMEX
        }

        if matches(normalizedPAN, regex: discoverRegex) {
            return .DISCOVER
        }

        if matches(normalizedPAN, regex: jcbRegex) {
            return .JCB
        }

        if matches(normalizedPAN, regex: dinersRegex) {
            return .DINERS
        }

        if matches(normalizedPAN, regex: unionPayRegex) {
            return .UNIONPAY
        }

        return .UNKNOWN
    }

    internal static func from(cardType: CardType?) -> CardNetwork? {
        guard let cardType else {
            return nil
        }

        switch cardType {
        case .VISA:
            return .VISA
        case .MASTERCARD:
            return .MASTERCARD
        case .AMEX:
            return .AMEX
        case .DISCOVER:
            return .DISCOVER
        case .JCB:
            return .JCB
        case .DINERS_CLUB:
            return .DINERS
        case .UNIONPAY:
            return .UNIONPAY
        default:
            return nil
        }
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

        if let cardType = CardType.allCases.first(where: {
            $0.instance.defaultName.lowercased() == normalizedScheme
        }) {
            return from(cardType: cardType)
        }

        switch normalizedScheme {
        case "master card":
            return .MASTERCARD
        case "american express":
            return .AMEX
        case "diners club":
            return .DINERS
        default:
            return nil
        }
    }

    internal var iconURL: URL? {
        switch self {
        case .VISA:
            return URL(string: "\(Self.baseIconURL)/visa.png")
        case .MASTERCARD:
            return URL(string: "\(Self.baseIconURL)/mastercard.png")
        case .AMEX:
            return URL(string: "\(Self.baseIconURL)/amex.png")
        case .DISCOVER:
            return URL(string: "\(Self.baseIconURL)/discover.png")
        case .JCB:
            return URL(string: "\(Self.baseIconURL)/jcb.png")
        case .DINERS:
            return URL(string: "\(Self.baseIconURL)/diners.png")
        case .UNIONPAY:
            return URL(string: "\(Self.baseIconURL)/unionpay.png")
        case .UNKNOWN:
            return nil
        }
    }

    private static func normalize(pan: String) -> String {
        pan.filter(\.isNumber)
    }

    private static func matches(_ value: String, regex: String) -> Bool {
        value.range(of: regex, options: .regularExpression) != nil
    }
}
