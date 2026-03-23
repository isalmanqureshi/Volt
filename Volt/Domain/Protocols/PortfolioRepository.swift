import Combine
import Foundation

protocol PortfolioRepository {
    var positionsPublisher: AnyPublisher<[Position], Never> { get }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { get }
    var orderHistoryPublisher: AnyPublisher<[OrderRecord], Never> { get }
    var activityTimelinePublisher: AnyPublisher<[ActivityEvent], Never> { get }
    var realizedPnLPublisher: AnyPublisher<[RealizedPnLEntry], Never> { get }

    var currentPositions: [Position] { get }
    var currentSummary: PortfolioSummary { get }
    var currentOrderHistory: [OrderRecord] { get }
    var currentActivityTimeline: [ActivityEvent] { get }
    var currentRealizedPnLHistory: [RealizedPnLEntry] { get }

    func position(for symbol: String) -> Position?

    @discardableResult
    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> TradeExecutionResult
}
