import Foundation

/// Centralised BIN lookup module.
///
/// The web SDK splits BIN lookup across two files — `fetchBinLookup`
/// (the Web SDK, the raw call) and `BinLookupResolver`
/// (the Web SDK, the as-you-type orchestration). This type
/// merges both into a single module:
///
///   - `binLookup(bin:)` — raw one-shot POST to `links.binLookup`, no caching/throttling. Used by
///     `Payrails.Session.binLookup(_:)` for the public one-shot call.
///   - `resolve(bin:)` — the live card-form path layered on top of `binLookup(bin:)`:
///       • **Throttle** — bursts of keystrokes collapse into at most one network call per
///         `throttle` window (the first fires immediately, the rest are spaced).
///       • **Result cache** — a repeat lookup for the already-resolved BIN returns the cached
///         response with no network call.
///       • **In-flight de-duplication** — a second lookup for a BIN already being fetched is dropped.
///       • **Stale-response guard** — a lookup that lands after the user has typed past it (the BIN
///         is no longer the active one) is discarded, so a slow response can never overwrite a
///         newer card number's result.
///
/// The whole type is `@MainActor`, so its orchestration state (cache / in-flight / throttle) is
/// main-isolated and needs no locking (matching the web SDK's single-threaded model). The network
/// still runs off the main thread — `api.binLookup` suspends inside `URLSession`, so the main actor
/// only guards bookkeeping, not the I/O. `init` is `nonisolated` so it can be constructed anywhere.
@MainActor
final class BinLookupService {
    /// Minimum digits before a lookup is attempted. Mirrors web `BIN_LOOKUP_LENGTH`.
    static let binLookupLength = 6
    /// Default throttle window between successive network calls. Mirrors web `DEFAULT_THROTTLE_MS`.
    static let defaultThrottle: TimeInterval = 0.5

    private let apiProvider: () -> PayrailsAPI?
    private let getCurrentBin: (@MainActor () -> String)?
    private let throttle: TimeInterval

    // MARK: Orchestration state — `resolve(bin:)` path only, main-actor isolated.
    private var resolvedBin: String?
    private var resolvedLookup: BinLookupResponse?
    private var inFlightBin: String?
    private var lastFetchStartedAt: Date?

    /// - Parameters:
    ///   - throttle: minimum spacing between successive network calls on the `resolve(bin:)` path.
    ///   - getCurrentBin: returns the BIN currently in the field; used by `resolve(bin:)` to drop a
    ///     response that arrives after the user has typed past it. Pass `nil` for the one-shot path,
    ///     which never needs the stale-guard.
    ///   - apiProvider: supplies the live `PayrailsAPI` (re-read on every call so it survives a
    ///     session refresh that rebuilds the API).
    nonisolated init(
        throttle: TimeInterval = BinLookupService.defaultThrottle,
        getCurrentBin: (@MainActor () -> String)? = nil,
        apiProvider: @escaping () -> PayrailsAPI?
    ) {
        self.throttle = throttle
        self.getCurrentBin = getCurrentBin
        self.apiProvider = apiProvider
    }

    /// Raw one-shot lookup: POSTs `{ bin }` to the configured endpoint and decodes the response.
    /// Returns `nil` when the BIN is too short, the endpoint is missing, or the request fails.
    func binLookup(bin: String) async -> BinLookupResponse? {
        guard bin.count >= Self.binLookupLength else {
            return nil
        }

        guard let api = apiProvider() else {
            return nil
        }

        do {
            return try await api.binLookup(bin: bin)
        } catch {
            #if DEBUG
            Payrails.log("BIN lookup failed for bin \(bin): \(error)")
            #endif
            return nil
        }
    }

    /// As-you-type lookup with throttle + cache + in-flight de-dup + stale-response guard.
    /// Returns `nil` when the BIN is too short, already in flight, superseded by a newer card
    /// number, or the request failed. Cache hits return immediately with no network call.
    @MainActor
    func resolve(bin: String) async -> BinLookupResponse? {
        guard bin.count >= Self.binLookupLength else { return nil }
        if bin == resolvedBin { return resolvedLookup }
        if bin == inFlightBin { return nil }

        inFlightBin = bin
        await waitForThrottleWindow()

        // Superseded by a newer BIN, or this task was cancelled while throttled.
        guard !Task.isCancelled, inFlightBin == bin else {
            if inFlightBin == bin { inFlightBin = nil }
            return nil
        }

        lastFetchStartedAt = Date()
        let lookup = await binLookup(bin: bin)

        // A newer lookup started while this request was in flight — let that one win.
        guard inFlightBin == bin else { return nil }
        inFlightBin = nil

        // The user has since edited the card number — discard so we don't apply a stale result.
        guard !Task.isCancelled else { return nil }
        if let getCurrentBin, getCurrentBin() != bin { return nil }

        // Cache only real results. A `nil` here means the lookup errored (network blip / decode
        // failure); caching it would make the failure sticky for this BIN, so leave the cache
        // untouched and let the next keystroke retry.
        if let lookup {
            resolvedBin = bin
            resolvedLookup = lookup
        }
        return lookup
    }

    /// Clears all cached and in-flight state. Mirrors web `BinLookupResolver.reset()`. Available for
    /// explicit teardown; the form doesn't call it per-keystroke — the per-BIN cache self-heals when
    /// the BIN changes, and failed lookups are no longer cached (so they're not sticky).
    func reset() {
        inFlightBin = nil
        resolvedBin = nil
        resolvedLookup = nil
        lastFetchStartedAt = nil
    }

    /// Spaces successive network calls at least `throttle` apart (trailing edge). The first call
    /// (no prior fetch) runs immediately, matching the leading edge of the web SDK's `throttle()`.
    @MainActor
    private func waitForThrottleWindow() async {
        guard let last = lastFetchStartedAt else { return }
        let remaining = throttle - Date().timeIntervalSince(last)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }
}
