//  CardBrandResolver.swift
//  Co-branded cards — pure logic layer.
//  Maps a BIN lookup's (network, localNetwork) plus the merchant's preferred schemes into an
//  ordered, de-duplicated set of card brands. Stateless, no UIKit — deterministic and unit-testable.
//  Consumed by `CoBrandedSchemeState`.

import Foundation

internal struct ResolvedCardBrands {
    let availableSchemes: [String]
    let selectedScheme: String?
    let isCoBranded: Bool
}

internal enum CardBrandResolver {
    static func resolve(
        network: String?,
        localNetwork: String?,
        preferredSchemes: [String]
    ) -> ResolvedCardBrands {
        let detected = detectedSchemes(localNetwork: localNetwork, network: network)
        let ordered = orderSchemes(
            detected: detected,
            preferredSchemes: preferredSchemes,
            localNetwork: localNetwork
        )
        // Keep only schemes the SDK can render/route. An unrecognized scheme would otherwise
        // inflate `isCoBranded` (raw count) while being dropped from `availableCardTypes`, so the
        // selector could hide while a non-displayable scheme still gets sent as preferredScheme.
        let availableSchemes = ordered.filter { CardType.fromSchemeCode($0) != nil }

        return ResolvedCardBrands(
            availableSchemes: availableSchemes,
            selectedScheme: availableSchemes.first,
            isCoBranded: availableSchemes.count > 1
        )
    }

    static func schemeKey(_ value: String) -> String {
        CardType.schemeKey(value)
    }

    private static func detectedSchemes(localNetwork: String?, network: String?) -> [String] {
        let localScheme = localNetwork?.trimmingCharacters(in: .whitespacesAndNewlines)
        let internationalScheme = network?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let localScheme, !localScheme.isEmpty else {
            guard let internationalScheme, !internationalScheme.isEmpty else { return [] }
            return [internationalScheme]
        }

        guard let internationalScheme, !internationalScheme.isEmpty else {
            return [localScheme]
        }

        return schemeKey(localScheme) == schemeKey(internationalScheme)
            ? [localScheme]
            : [localScheme, internationalScheme]
    }

    private static func orderSchemes(
        detected: [String],
        preferredSchemes: [String],
        localNetwork: String?
    ) -> [String] {
        let preferredOrder = preferredSchemes.isEmpty
            ? (localNetwork.map { [$0] } ?? [])
            : preferredSchemes
        var seenPreferredKeys = Set<String>()
        let preferredKeys = preferredOrder
            .map(schemeKey)
            .filter { seenPreferredKeys.insert($0).inserted }

        let preferredDetected = preferredKeys.compactMap { key in
            detected.first { schemeKey($0) == key }
        }
        let remaining = detected.filter { scheme in
            !preferredKeys.contains(schemeKey(scheme))
        }

        return preferredDetected + remaining
    }
}
