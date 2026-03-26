import XCTest
@testable import Volt

@MainActor
final class ClosePositionViewModelTests: XCTestCase {
    func testValidationFailsWhenQuantityExceedsOpenPosition() {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 110, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let vm = ClosePositionViewModel(
            position: Position(id: UUID(), symbol: "BTC/USD", quantity: 1, averageEntryPrice: 100, currentPrice: 110, unrealizedPnL: 10, openedAt: .now),
            marketDataRepository: market,
            tradingSimulationService: ClosePositionTradingServiceStub()
        )

        vm.closeMode = .partial
        vm.quantityText = "2"

        if case .invalid = vm.validationState {
            XCTAssertFalse(vm.canSubmit)
        } else {
            XCTFail("Expected invalid state")
        }
    }

    func testEstimateAndSubmit() {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 120, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let vm = ClosePositionViewModel(
            position: Position(id: UUID(), symbol: "BTC/USD", quantity: 2, averageEntryPrice: 100, currentPrice: 120, unrealizedPnL: 40, openedAt: .now),
            marketDataRepository: market,
            tradingSimulationService: ClosePositionTradingServiceStub()
        )

        vm.closeMode = .partial
        vm.quantityText = "1.5"
        XCTAssertEqual(vm.estimatedProceeds, 180)
        XCTAssertEqual(vm.estimatedRealizedPnL, 30)
        vm.submit()
        XCTAssertTrue(vm.didSubmitSuccessfully)
    }
}

private struct ClosePositionTradingServiceStub: TradingSimulationService {
    func placeOrder(_ draft: OrderDraft) throws -> TradeExecutionResult {
        let order = OrderRecord(id: UUID(), symbol: draft.assetSymbol, side: draft.side, type: draft.type, quantity: draft.quantity, executedPrice: draft.estimatedPrice ?? 0, grossValue: draft.quantity * (draft.estimatedPrice ?? 0), submittedAt: draft.submittedAt, executedAt: draft.submittedAt, status: .filled, source: .simulated, linkedPositionID: nil)
        let event = ActivityEvent(id: UUID(), kind: .partialClose, symbol: draft.assetSymbol, quantity: draft.quantity, price: draft.estimatedPrice ?? 0, timestamp: draft.submittedAt, orderID: order.id, relatedPositionID: nil, realizedPnL: 0)
        return TradeExecutionResult(resultingPosition: nil, orderRecord: order, activityEvent: event, realizedPnLEntry: nil)
    }
}
