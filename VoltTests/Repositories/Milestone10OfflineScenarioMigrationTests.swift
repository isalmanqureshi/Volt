import Combine
import XCTest
@testable import Volt

final class Milestone10OfflineScenarioMigrationTests: XCTestCase {
    func testOfflineFallbackUsesCachedQuotesWhenSeedFails() async {
        let cache = InMemoryMarketCacheStore(
            quotes: [Quote(symbol: "BTC/USD", lastPrice: 99_000, changePercent: 0, timestamp: Date(), source: "cache", isSimulated: false)]
        )
        let repository = DefaultMarketDataRepository(
            seedProvider: AlwaysFailSeedProvider(),
            historicalDataProvider: MockHistoricalDataProvider(),
            simulationEngine: PassiveSimulationEngine(),
            symbols: ["BTC/USD"],
            cacheStore: cache
        )

        await repository.start()

        let quote = repository.quote(for: "BTC/USD")
        XCTAssertEqual(quote?.source, "cache")
        let mode = await firstDataMode(from: repository)
        XCTAssertEqual(mode, .offlineCached)
    }

    func testPreferencesMigrationFromLegacyPayload() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let legacy = LegacyPreferencesForTest(
            onboardingCompleted: true,
            aiSummariesEnabled: true,
            selectedEnvironment: .mock,
            simulatorRisk: .default,
            activeRuntimeProfileID: RuntimeProfile.balanced.id
        )
        defaults.set(try JSONEncoder().encode(legacy), forKey: "prefs")

        let store = UserDefaultsAppPreferencesStore(defaults: defaults, key: "prefs")

        XCTAssertEqual(store.currentPreferences.selectedEnvironment, .mock)
        XCTAssertNil(store.currentPreferences.activeDemoScenarioID)
    }

    func testDeterministicScenarioCatalogIsStable() {
        XCTAssertEqual(DemoScenario.all.map(\.id), ["scenario.empty", "scenario.balanced", "scenario.analytics"])
    }

    private func firstDataMode(from repository: MarketDataRepository) async -> MarketDataMode {
        await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = repository.dataModePublisher.drop(while: { $0 == .liveSeeded }).first().sink { value in
                continuation.resume(returning: value)
                cancellable?.cancel()
            }
        }
    }
}

private struct LegacyPreferencesForTest: Codable {
    var onboardingCompleted: Bool
    var aiSummariesEnabled: Bool
    var selectedEnvironment: TradingEnvironment
    var simulatorRisk: SimulatorRiskPreferences
    var activeRuntimeProfileID: String
}

private struct AlwaysFailSeedProvider: MarketSeedProvider {
    func fetchInitialQuotes(for symbols: [String]) async throws -> [Quote] {
        _ = symbols
        throw URLError(.notConnectedToInternet)
    }
}

private final class PassiveSimulationEngine: MarketSimulationEngine {
    var ticksPublisher: AnyPublisher<MarketTick, Never> { Empty().eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { Just(.connected).eraseToAnyPublisher() }
    func start(with seedQuotes: [Quote]) { _ = seedQuotes }
    func reseed(with quotes: [Quote]) { _ = quotes }
}

private final class InMemoryMarketCacheStore: MarketCacheStore {
    private(set) var quotes: [Quote]
    private var candlesBySymbol: [String: [Candle]]

    init(quotes: [Quote] = [], candlesBySymbol: [String: [Candle]] = [:]) {
        self.quotes = quotes
        self.candlesBySymbol = candlesBySymbol
    }

    func loadQuotes() -> [Quote] { quotes }
    func saveQuotes(_ quotes: [Quote]) { self.quotes = quotes }
    func loadCandles(symbol: String) -> [Candle]? { candlesBySymbol[symbol] }
    func saveCandles(_ candles: [Candle], symbol: String) { candlesBySymbol[symbol] = candles }
}
