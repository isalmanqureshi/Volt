import XCTest
@testable import Volt

final class DomainModelInitializationTests: XCTestCase {
    func testOrderDraftInitialization() {
        let draft = OrderDraft(
            assetSymbol: "BTC/USD",
            side: .buy,
            type: .limit,
            quantity: 1.5,
            estimatedPrice: 61_000,
            submittedAt: .now,
            limitPrice: 60_000,
            stopPrice: nil
        )
        XCTAssertEqual(draft.assetSymbol, "BTC/USD")
        XCTAssertEqual(draft.side, .buy)
        XCTAssertEqual(draft.type, .limit)
    }

    func testPortfolioSummaryCalculationShape() {
        let summary = PortfolioSummary(cashBalance: 10_000, positionsMarketValue: 1_000, unrealizedPnL: 150, realizedPnL: 50, totalEquity: 11_000, dayChange: 100)
        XCTAssertEqual(summary.totalEquity, 11_000)
    }
}
