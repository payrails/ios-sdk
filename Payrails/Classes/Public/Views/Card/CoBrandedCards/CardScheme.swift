//  CardScheme.swift
//  Co-branded cards — public merchant-facing event payload.
//  Mirrors the web SDK's `CardScheme` (code / name / logoUrl / selected, see
//  the Web SDK) and the `onPreferredSchemeChanged` payload.
//  Delivered to merchants via `PayrailsCardFormDelegate.cardForm(_:didChangePreferredScheme:)`.

import Foundation

/// One card scheme available for the active card, with a flag for the selected (preferred) one.
public struct CardScheme: Equatable {
    /// Canonical scheme code, e.g. `"mada"`, `"mastercard"`, `"cartesbancaires"`.
    public let code: String
    /// Display label for the scheme (e.g. the brand's name).
    public let name: String
    /// Brand logo URL, when one is available for the scheme.
    public let logoUrl: URL?
    /// Whether this is the currently selected (preferred) scheme.
    public let selected: Bool
}

/// Payload for `PayrailsCardFormDelegate.cardForm(_:didChangePreferredScheme:)`.
/// Mirrors the web SDK's `onPreferredSchemeChanged` payload (`{ preferredScheme, cardSchemes }`).
public struct PreferredSchemeChange: Equatable {
    /// The selected scheme code, or `nil` when the active card is not co-branded.
    public let preferredScheme: String?
    /// Every scheme available for the active card. Empty when the card is not co-branded.
    public let cardSchemes: [CardScheme]
}

/// Internal payload handed from `CardForm` to the card-number field describing the co-branded
/// schemes to render. Typed replacement for the former `[String: Any]` `cardMetaData` dictionary.
internal struct CardSchemeMetadata {
    let schemes: [CardType]
    let selectedScheme: CardType?
}
