//  CoBrandedSchemeState.swift
//  Co-branded cards — state / view-model layer.
//  Holds the resolved brands for the active BIN plus the user's manual scheme override, and exposes
//  derived values the form renders (`availableCardTypes`, `selectedCardType`, `isCoBranded`).
//  Delegates the actual brand resolution to `CardBrandResolver`. No UIKit.

import Foundation

internal final class CoBrandedSchemeState {
    private var resolvedBin: String?
    private var resolved: ResolvedCardBrands?
    private var selectedOverride: String?

    var isCoBranded: Bool {
        resolved?.isCoBranded ?? false
    }

    var availableSchemes: [String] {
        resolved?.availableSchemes ?? []
    }

    var selectedScheme: String? {
        selectedOverride ?? resolved?.selectedScheme
    }

    var availableCardTypes: [CardType] {
        guard isCoBranded else { return [] }
        return availableSchemes.compactMap(CardType.fromSchemeCode)
    }

    var selectedCardType: CardType? {
        CardType.fromSchemeCode(selectedScheme)
    }

    var preferredSchemeForPayment: String? {
        isCoBranded ? selectedScheme : nil
    }

    /// The schemes for the active card, with the selected one flagged — empty when not co-branded.
    /// Mirrors the web SDK's `CoBrandedSchemeState.cardSchemes` getter; this is the merchant-facing
    /// payload the form emits via `PayrailsCardFormDelegate.cardForm(_:didChangePreferredScheme:)`.
    var cardSchemes: [CardScheme] {
        guard isCoBranded else { return [] }
        let selectedKey = selectedScheme.map(CardBrandResolver.schemeKey)
        return availableSchemes.map { code in
            let cardType = CardType.fromSchemeCode(code)
            return CardScheme(
                code: code,
                name: cardType?.instance.defaultName ?? code,
                logoUrl: cardType.flatMap { CardNetwork.from(cardType: $0)?.iconURL },
                selected: selectedKey == CardBrandResolver.schemeKey(code)
            )
        }
    }

    func applyLookup(
        bin: String,
        lookup: BinLookupResponse?,
        preferredSchemes: [String]
    ) -> Bool {
        if bin == resolvedBin {
            return false
        }

        resolved = CardBrandResolver.resolve(
            network: lookup?.network,
            localNetwork: lookup?.localNetwork,
            preferredSchemes: preferredSchemes
        )
        resolvedBin = bin
        selectedOverride = nil
        return true
    }

    func clearIfBinChanged(_ bin: String) -> Bool {
        if bin == resolvedBin || resolved == nil {
            return false
        }

        let hadCoBrandedSchemes = isCoBranded
        reset()
        return hadCoBrandedSchemes
    }

    @discardableResult
    func selectScheme(code: String) -> Bool {
        guard let canonical = availableSchemes.first(where: {
            CardBrandResolver.schemeKey($0) == CardBrandResolver.schemeKey(code)
        }) else {
            return false
        }

        if CardBrandResolver.schemeKey(selectedOverride ?? "") == CardBrandResolver.schemeKey(canonical) {
            return false
        }

        selectedOverride = canonical
        return true
    }

    @discardableResult
    func selectScheme(displayName: String?) -> Bool {
        guard let cardType = CardType.fromDisplayName(displayName),
              let code = availableSchemes.first(where: {
                  CardType.fromSchemeCode($0) == cardType
              }) else {
            return false
        }

        return selectScheme(code: code)
    }

    func reset() {
        resolvedBin = nil
        resolved = nil
        selectedOverride = nil
    }
}
