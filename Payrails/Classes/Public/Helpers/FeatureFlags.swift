import Foundation

enum FeatureFlag: Hashable {
    case coBrandedCards
}

final class FeatureFlagEvaluator {
    typealias RandomPercentageProvider = () -> Double

    private var decisions: [FeatureFlag: Bool] = [:]
    private let randomPercentageProvider: RandomPercentageProvider

    init(
        randomPercentageProvider: @escaping RandomPercentageProvider = { Double.random(in: 0..<100) }
    ) {
        self.randomPercentageProvider = randomPercentageProvider
    }

    func isEnabled(_ flag: FeatureFlag, config: SDKConfig) -> Bool {
        if let decision = decisions[flag] {
            return decision
        }

        let decision = evaluate(flag, config: config)
        decisions[flag] = decision
        return decision
    }

    func reset() {
        decisions.removeAll()
    }

    /// Reports purely the feature-flag rollout decision as configured by the backend
    /// (`featureConfig.*Rollout`). Config prerequisites
    /// such as `links.binLookup` are NOT considered here — callers combine those separately
    /// (e.g. `Session.isCoBrandedCardsEnabled()`).
    private func evaluate(_ flag: FeatureFlag, config: SDKConfig) -> Bool {
        let rollout = normalizedRollout(rolloutValue(for: flag, config: config))
        return randomPercentageProvider() < rollout
    }

    private func rolloutValue(for flag: FeatureFlag, config: SDKConfig) -> Double {
        switch flag {
        case .coBrandedCards:
            return config.featureConfig?.coBrandedCardsRollout ?? 0
        }
    }

    private func normalizedRollout(_ rollout: Double) -> Double {
        min(max(rollout, 0), 100)
    }
}
