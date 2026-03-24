import Combine
import XCTest
@testable import Volt

@MainActor
final class Milestone8ExperienceTests: XCTestCase {
    func testOnboardingCompletionPersistsAndResetWorks() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = UserDefaultsAppPreferencesStore(defaults: defaults, key: "prefs")

        XCTAssertFalse(store.currentPreferences.onboardingCompleted)
        store.completeOnboarding()
        XCTAssertTrue(store.currentPreferences.onboardingCompleted)

        store.resetOnboarding()
        XCTAssertFalse(store.currentPreferences.onboardingCompleted)
    }

    func testRiskPreferenceDefaultsFlowIntoTradeTicketQuantity() {
        let prefs = InMemoryPreferencesStore(
            .init(onboardingCompleted: true, aiSummariesEnabled: true, selectedEnvironment: .mock, simulatorRisk: .init(orderSizeMode: .fixedQuantity, defaultOrderSizeValue: 2.5, maxRecommendedPositionPercent: 25, warningThresholdPercent: 10, requiresLargeOrderConfirmation: true, riskWarningsEnabled: true))
        )

        let vm = TradeTicketViewModel(
            asset: SupportedAssets.demoAssets[0],
            marketDataRepository: TestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true)),
            portfolioRepository: TestPortfolioRepository(cash: 10_000),
            tradingSimulationService: TestTradingService(),
            preferencesStore: prefs,
            tradeInsightService: LocalInsightSummaryService()
        )

        XCTAssertEqual(vm.quantityText, "2.5")
    }

    func testInvalidRiskPreferencesAreValidatedSafely() {
        let prefs = SimulatorRiskPreferences(orderSizeMode: .fixedQuantity, defaultOrderSizeValue: 0, maxRecommendedPositionPercent: 500, warningThresholdPercent: -1, requiresLargeOrderConfirmation: true, riskWarningsEnabled: true)
        let valid = prefs.validated()
        XCTAssertGreaterThan(valid.defaultOrderSizeValue, 0)
        XCTAssertLessThanOrEqual(valid.maxRecommendedPositionPercent, 100)
        XCTAssertGreaterThan(valid.warningThresholdPercent, 0)
    }

    func testLocalPortfolioSummaryGroundedInInputData() {
        let service = LocalInsightSummaryService()
        let cards = service.makeInsights(
            summary: .init(cashBalance: 1_000, positionsMarketValue: 200, unrealizedPnL: 10, realizedPnL: 20, totalEquity: 1_200, dayChange: 0),
            positions: [.init(id: UUID(), symbol: "BTC/USD", quantity: 1, averageEntryPrice: 100, currentPrice: 200, unrealizedPnL: 100, openedAt: .now)],
            analytics: .init(totalRealizedPnL: 20, totalUnrealizedPnL: 10, averageWin: 20, averageLoss: -5, profitFactor: 2, winRate: 0.5, totalClosedTrades: 2, bestTrade: 20, worstTrade: -5, currentEquity: 1_200, startingBalance: 1_000, netReturnPercent: 20),
            recentActivity: []
        )
        XCTAssertTrue(cards.contains(where: { $0.body.contains("$1,200.00") }))
        XCTAssertTrue(cards.contains(where: { $0.body.contains("BTC/USD") }))
    }

    func testTradeRecapGenerationForBuyAndClose() {
        let service = LocalInsightSummaryService()
        let buyResult = TradeExecutionResult(
            resultingPosition: .init(id: UUID(), symbol: "BTC/USD", quantity: 1, averageEntryPrice: 100, currentPrice: 100, unrealizedPnL: 0, openedAt: .now),
            orderRecord: .init(id: UUID(), symbol: "BTC/USD", side: .buy, type: .market, quantity: 1, executedPrice: 100, grossValue: 100, submittedAt: .now, executedAt: .now, status: .filled, source: .simulated, linkedPositionID: nil),
            activityEvent: .init(id: UUID(), kind: .buy, symbol: "BTC/USD", quantity: 1, price: 100, timestamp: .now, orderID: UUID(), relatedPositionID: nil, realizedPnL: nil),
            realizedPnLEntry: nil
        )
        let closeResult = TradeExecutionResult(
            resultingPosition: nil,
            orderRecord: .init(id: UUID(), symbol: "BTC/USD", side: .sell, type: .market, quantity: 1, executedPrice: 110, grossValue: 110, submittedAt: .now, executedAt: .now, status: .filled, source: .simulated, linkedPositionID: nil),
            activityEvent: .init(id: UUID(), kind: .fullClose, symbol: "BTC/USD", quantity: 1, price: 110, timestamp: .now, orderID: UUID(), relatedPositionID: nil, realizedPnL: 10),
            realizedPnLEntry: .init(id: UUID(), symbol: "BTC/USD", quantityClosed: 1, averageEntryPrice: 100, exitPrice: 110, realizedPnL: 10, closedAt: .now, linkedPositionID: nil, note: nil)
        )
        let summary = PortfolioSummary(cashBalance: 1_000, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 10, totalEquity: 1_010, dayChange: 0)

        XCTAssertTrue(service.makeRecap(result: buyResult, latestSummary: summary).body.contains("Bought"))
        XCTAssertTrue(service.makeRecap(result: closeResult, latestSummary: summary).body.contains("Realized P&L"))
    }

    func testSettingsPersistenceRoundTrip() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = UserDefaultsAppPreferencesStore(defaults: defaults, key: "prefs")
        store.update {
            $0.aiSummariesEnabled = false
            $0.simulatorRisk.defaultOrderSizeValue = 3
        }

        let restored = UserDefaultsAppPreferencesStore(defaults: defaults, key: "prefs")
        XCTAssertFalse(restored.currentPreferences.aiSummariesEnabled)
        XCTAssertEqual(restored.currentPreferences.simulatorRisk.defaultOrderSizeValue, 3)
    }

    func testPortfolioViewModelDisablesInsightsWhenPreferenceOff() {
        let prefs = InMemoryPreferencesStore(.init(onboardingCompleted: true, aiSummariesEnabled: false, selectedEnvironment: .mock, simulatorRisk: .default))
        let vm = PortfolioViewModel(
            portfolioRepository: TestPortfolioRepository(cash: 10_000),
            analyticsService: TestAnalyticsService(),
            preferencesStore: prefs,
            insightService: LocalInsightSummaryService()
        )

        XCTAssertEqual(vm.insightCards, [])
        XCTAssertFalse(vm.aiSummariesEnabled)
    }
}

private final class TestTradingService: TradingSimulationService {
    func placeOrder(_ draft: OrderDraft) throws -> TradeExecutionResult {
        .init(
            resultingPosition: Position(id: UUID(), symbol: draft.assetSymbol, quantity: draft.quantity, averageEntryPrice: draft.estimatedPrice ?? 0, currentPrice: draft.estimatedPrice ?? 0, unrealizedPnL: 0, openedAt: .now),
            orderRecord: OrderRecord(id: UUID(), symbol: draft.assetSymbol, side: draft.side, type: draft.type, quantity: draft.quantity, executedPrice: draft.estimatedPrice ?? 0, grossValue: (draft.estimatedPrice ?? 0) * draft.quantity, submittedAt: draft.submittedAt, executedAt: draft.submittedAt, status: .filled, source: .simulated, linkedPositionID: nil),
            activityEvent: ActivityEvent(id: UUID(), kind: .buy, symbol: draft.assetSymbol, quantity: draft.quantity, price: draft.estimatedPrice ?? 0, timestamp: draft.submittedAt, orderID: UUID(), relatedPositionID: nil, realizedPnL: nil),
            realizedPnLEntry: nil
        )
    }
}

private final class TestPortfolioRepository: PortfolioRepository {
    private let summary: PortfolioSummary
    init(cash: Decimal) {
        summary = PortfolioSummary(cashBalance: cash, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: cash, dayChange: 0)
    }
    var positionsPublisher: AnyPublisher<[Position], Never> { Just([]).eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { Just(summary).eraseToAnyPublisher() }
    var orderHistoryPublisher: AnyPublisher<[OrderRecord], Never> { Just([]).eraseToAnyPublisher() }
    var activityTimelinePublisher: AnyPublisher<[ActivityEvent], Never> { Just([]).eraseToAnyPublisher() }
    var realizedPnLPublisher: AnyPublisher<[RealizedPnLEntry], Never> { Just([]).eraseToAnyPublisher() }
    var currentPositions: [Position] { [] }
    var currentSummary: PortfolioSummary { summary }
    var currentOrderHistory: [OrderRecord] { [] }
    var currentActivityTimeline: [ActivityEvent] { [] }
    var currentRealizedPnLHistory: [RealizedPnLEntry] { [] }
    func position(for symbol: String) -> Position? { nil }
    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> TradeExecutionResult { throw TradingSimulationError.invalidQuantity }
}

private final class TestMarketDataRepository: MarketDataRepository {
    private let quote: Quote
    init(quote: Quote) { self.quote = quote }
    var quotesPublisher: AnyPublisher<[Quote], Never> { Just([quote]).eraseToAnyPublisher() }
    var tickPublisher: AnyPublisher<MarketTick, Never> { Empty().eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { Just(.liveSimulated).eraseToAnyPublisher() }
    var seedingStatePublisher: AnyPublisher<MarketSeedingState, Never> { Just(.ready).eraseToAnyPublisher() }
    func start() async {}
    func quote(for symbol: String) -> Quote? { quote }
    func quotePublisher(for symbol: String) -> AnyPublisher<Quote?, Never> { Just(quote).eraseToAnyPublisher() }
    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never> { Just([quote]).eraseToAnyPublisher() }
    func fetchRecentCandles(symbol: String, outputSize: Int) async throws -> [Candle] { [] }
}

private final class TestAnalyticsService: PortfolioAnalyticsService {
    var summaryPublisher: AnyPublisher<PortfolioAnalyticsSummary, Never> { Just(.empty).eraseToAnyPublisher() }
    var performancePublisher: AnyPublisher<[PerformancePoint], Never> { Just([]).eraseToAnyPublisher() }
    var dailyPerformancePublisher: AnyPublisher<[DailyPerformanceBucket], Never> { Just([]).eraseToAnyPublisher() }
    var realizedDistributionPublisher: AnyPublisher<[RealizedDistributionBucket], Never> { Just([]).eraseToAnyPublisher() }
    var filteredOrdersPublisher: AnyPublisher<[OrderRecord], Never> { Just([]).eraseToAnyPublisher() }
    var filteredActivityPublisher: AnyPublisher<[ActivityEvent], Never> { Just([]).eraseToAnyPublisher() }
    var availableSymbolsPublisher: AnyPublisher<[String], Never> { Just([]).eraseToAnyPublisher() }
    var currentSummary: PortfolioAnalyticsSummary { .empty }
    var currentPerformance: [PerformancePoint] { [] }
    var currentDailyPerformance: [DailyPerformanceBucket] { [] }
    var currentRealizedDistribution: [RealizedDistributionBucket] { [] }
    var currentFilter: HistoryFilter { .default }
    func updateFilter(_ filter: HistoryFilter) {}
    func positionHistory(symbol: String) -> PositionHistorySummary { .empty(symbol: symbol) }
}

private final class InMemoryPreferencesStore: AppPreferencesProviding {
    private let subject: CurrentValueSubject<AppPreferences, Never>
    init(_ value: AppPreferences) { subject = CurrentValueSubject(value) }
    var preferencesPublisher: AnyPublisher<AppPreferences, Never> { subject.eraseToAnyPublisher() }
    var currentPreferences: AppPreferences { subject.value }
    func update(_ mutate: (inout AppPreferences) -> Void) { var value = subject.value; mutate(&value); value.simulatorRisk = value.simulatorRisk.validated(); subject.send(value) }
    func resetOnboarding() { update { $0.onboardingCompleted = false } }
    func completeOnboarding() { update { $0.onboardingCompleted = true } }
}
