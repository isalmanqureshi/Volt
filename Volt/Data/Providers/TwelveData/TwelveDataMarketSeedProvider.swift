import Foundation
internal import os

struct TwelveDataMarketSeedProvider: MarketSeedProvider {
    enum ProviderError: Error {
        case notImplemented
    }

    func fetchInitialQuotes(for symbols: [String]) async throws -> [Quote] {
        AppLogger.market.info("TwelveData provider scaffold called for symbols: \(symbols, privacy: .public)")
        throw ProviderError.notImplemented
    }
}
