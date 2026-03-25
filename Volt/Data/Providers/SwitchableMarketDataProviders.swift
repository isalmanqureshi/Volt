import Foundation

final class SwitchableMarketSeedProvider: MarketSeedProvider {
    private let preferencesStore: AppPreferencesProviding
    private let mock: MarketSeedProvider
    private let twelveData: MarketSeedProvider

    init(preferencesStore: AppPreferencesProviding, mock: MarketSeedProvider, twelveData: MarketSeedProvider) {
        self.preferencesStore = preferencesStore
        self.mock = mock
        self.twelveData = twelveData
    }

    func fetchInitialQuotes(for symbols: [String]) async throws -> [Quote] {
        switch preferencesStore.currentPreferences.selectedEnvironment {
        case .mock:
            return try await mock.fetchInitialQuotes(for: symbols)
        case .twelveDataSeededSimulation:
            return try await twelveData.fetchInitialQuotes(for: symbols)
        }
    }
}

final class SwitchableHistoricalDataProvider: HistoricalDataProvider {
    private let preferencesStore: AppPreferencesProviding
    private let mock: HistoricalDataProvider
    private let twelveData: HistoricalDataProvider

    init(preferencesStore: AppPreferencesProviding, mock: HistoricalDataProvider, twelveData: HistoricalDataProvider) {
        self.preferencesStore = preferencesStore
        self.mock = mock
        self.twelveData = twelveData
    }

    func fetchRecentCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle] {
        switch preferencesStore.currentPreferences.selectedEnvironment {
        case .mock:
            return try await mock.fetchRecentCandles(symbol: symbol, interval: interval, outputSize: outputSize)
        case .twelveDataSeededSimulation:
            return try await twelveData.fetchRecentCandles(symbol: symbol, interval: interval, outputSize: outputSize)
        }
    }
}
