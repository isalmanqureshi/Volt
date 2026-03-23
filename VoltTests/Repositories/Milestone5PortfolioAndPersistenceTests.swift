import XCTest
@testable import Volt

final class Milestone5PortfolioAndPersistenceTests: XCTestCase {
    func testBuyDoesNotMutateMemoryIfPersistenceSaveFails() {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(
            marketDataRepository: market,
            cashBalance: 10_000,
            persistenceStore: FailingPortfolioPersistenceStore()
        )

        XCTAssertThrowsError(
            try repository.applyFilledOrder(
                .init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil),
                executionPrice: 100,
                filledAt: .now
            )
        ) { error in
            XCTAssertEqual(error as? TradingSimulationError, .persistenceSaveFailed)
        }

        XCTAssertTrue(repository.currentPositions.isEmpty)
        XCTAssertEqual(repository.currentSummary.cashBalance, 10_000)
        XCTAssertTrue(repository.currentOrderHistory.isEmpty)
        XCTAssertTrue(repository.currentActivityTimeline.isEmpty)
    }

    func testFullCloseRemovesPositionAndRecordsRealizedPnL() throws {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 10_000)

        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 2, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: .now)
        let closeResult = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .sell, type: .market, quantity: 2, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 110, filledAt: .now)

        XCTAssertNil(closeResult.resultingPosition)
        XCTAssertTrue(repository.currentPositions.isEmpty)
        XCTAssertEqual(repository.currentRealizedPnLHistory.first?.realizedPnL, 20)
    }

    func testPartialReduceKeepsPositionOpenAndUpdatesQuantity() throws {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "ETH/USD", lastPrice: 2000, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 20_000)

        _ = try repository.applyFilledOrder(.init(assetSymbol: "ETH/USD", side: .buy, type: .market, quantity: 4, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 2_000, filledAt: .now)
        let reduce = try repository.applyFilledOrder(.init(assetSymbol: "ETH/USD", side: .sell, type: .market, quantity: 1.5, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 2_200, filledAt: .now)

        XCTAssertEqual(reduce.resultingPosition?.quantity, 2.5)
        XCTAssertEqual(repository.currentPositions.first?.quantity, 2.5)
    }

    func testSellIncreasesCashAndCreatesOrderAndActivity() throws {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "SOL/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 1_000)

        _ = try repository.applyFilledOrder(.init(assetSymbol: "SOL/USD", side: .buy, type: .market, quantity: 5, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: .now)
        _ = try repository.applyFilledOrder(.init(assetSymbol: "SOL/USD", side: .sell, type: .market, quantity: 2, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 130, filledAt: .now)

        XCTAssertEqual(repository.currentSummary.cashBalance, 760)
        XCTAssertEqual(repository.currentOrderHistory.count, 2)
        XCTAssertEqual(repository.currentActivityTimeline.count, 2)
    }

    func testNewBuyReturnsMarkedToMarketPnLInResultingPosition() throws {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 102, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 10_000)

        let result = try repository.applyFilledOrder(
            .init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil),
            executionPrice: 100,
            filledAt: .now
        )

        XCTAssertEqual(result.resultingPosition?.currentPrice, 102)
        XCTAssertEqual(result.resultingPosition?.unrealizedPnL, 2)
        XCTAssertEqual(repository.currentPositions.first?.unrealizedPnL, 2)
    }

    func testPersistenceRoundTripAndCorruptedRecovery() throws {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = FileBackedPortfolioPersistenceStore(baseDirectory: tempDir)

        do {
            let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 5_000, persistenceStore: store)
            _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: .now)
        }

        let restored = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 5_000, persistenceStore: store)
        XCTAssertEqual(restored.currentPositions.first?.symbol, "BTC/USD")
        XCTAssertEqual(restored.currentOrderHistory.count, 1)

        let fileURL = tempDir.appendingPathComponent("portfolio_state.json")
        try "not-json".data(using: .utf8)?.write(to: fileURL)
        let recovered = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 5_000, persistenceStore: store)
        XCTAssertTrue(recovered.currentPositions.isEmpty)
        XCTAssertEqual(recovered.currentSummary.cashBalance, 5_000)
    }

    func testOpenPositionsRevalueAfterRestore() throws {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = FileBackedPortfolioPersistenceStore(baseDirectory: tempDir)

        do {
            let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 5_000, persistenceStore: store)
            _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: .now)
        }

        let restored = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 5_000, persistenceStore: store)
        market.emit(quote: .init(symbol: "BTC/USD", lastPrice: 120, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        XCTAssertEqual(restored.currentPositions.first?.currentPrice, 120)
        XCTAssertEqual(restored.currentSummary.unrealizedPnL, 20)
    }

    func testRealizedPnLFormulaForReducedLongPosition() throws {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 10_000)

        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 3, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: .now)
        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .sell, type: .market, quantity: 1.2, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 108, filledAt: .now)

        XCTAssertEqual(repository.currentRealizedPnLHistory.first?.realizedPnL, 9.6)
    }

    func testPortfolioSummaryRemainsCoherentAfterBuyReduceAndFullClose() throws {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 1_000)

        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 5, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: .now)
        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .sell, type: .market, quantity: 2, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 110, filledAt: .now)
        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .sell, type: .market, quantity: 3, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 90, filledAt: .now)

        XCTAssertTrue(repository.currentPositions.isEmpty)
        XCTAssertEqual(repository.currentSummary.cashBalance, 990)
        XCTAssertEqual(repository.currentSummary.positionsMarketValue, 0)
        XCTAssertEqual(repository.currentSummary.unrealizedPnL, 0)
        XCTAssertEqual(repository.currentSummary.realizedPnL, -10)
        XCTAssertEqual(repository.currentSummary.totalEquity, 990)
    }
}

private struct FailingPortfolioPersistenceStore: PortfolioPersistenceStore {
    func loadState() throws -> PersistedPortfolioState? { nil }
    func saveState(_ state: PersistedPortfolioState) throws { throw PortfolioPersistenceError.failedToWrite }
}
