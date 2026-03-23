import Combine
import Foundation

final class InMemoryPortfolioRepository: PortfolioRepository {
    private let positionsSubject: CurrentValueSubject<[Position], Never>
    private let summarySubject: CurrentValueSubject<PortfolioSummary, Never>
    private let orderHistorySubject: CurrentValueSubject<[OrderRecord], Never>
    private let activityTimelineSubject: CurrentValueSubject<[ActivityEvent], Never>
    private let realizedPnLSubject: CurrentValueSubject<[RealizedPnLEntry], Never>

    private var cashBalance: Decimal
    private var latestQuotesBySymbol: [String: Quote] = [:]
    private let persistenceStore: PortfolioPersistenceStore?
    private var cancellables = Set<AnyCancellable>()

    var positionsPublisher: AnyPublisher<[Position], Never> { positionsSubject.eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { summarySubject.eraseToAnyPublisher() }
    var orderHistoryPublisher: AnyPublisher<[OrderRecord], Never> { orderHistorySubject.eraseToAnyPublisher() }
    var activityTimelinePublisher: AnyPublisher<[ActivityEvent], Never> { activityTimelineSubject.eraseToAnyPublisher() }
    var realizedPnLPublisher: AnyPublisher<[RealizedPnLEntry], Never> { realizedPnLSubject.eraseToAnyPublisher() }

    var currentPositions: [Position] { positionsSubject.value }
    var currentSummary: PortfolioSummary { summarySubject.value }
    var currentOrderHistory: [OrderRecord] { orderHistorySubject.value }
    var currentActivityTimeline: [ActivityEvent] { activityTimelineSubject.value }
    var currentRealizedPnLHistory: [RealizedPnLEntry] { realizedPnLSubject.value }

    init(
        marketDataRepository: MarketDataRepository,
        cashBalance: Decimal,
        initialPositions: [Position] = [],
        persistenceStore: PortfolioPersistenceStore? = nil
    ) {
        self.persistenceStore = persistenceStore

        if let persistenceStore, let restoredState = try? persistenceStore.loadState() {
            self.cashBalance = restoredState.cashBalance
            self.positionsSubject = CurrentValueSubject(restoredState.openPositions)
            self.orderHistorySubject = CurrentValueSubject(restoredState.orderHistory)
            self.activityTimelineSubject = CurrentValueSubject(restoredState.activityTimeline)
            self.realizedPnLSubject = CurrentValueSubject(restoredState.realizedPnLHistory)
        } else {
            if persistenceStore != nil {
                AppLogger.portfolio.warning("Recovered with default portfolio state")
            }
            self.cashBalance = cashBalance
            self.positionsSubject = CurrentValueSubject(initialPositions)
            self.orderHistorySubject = CurrentValueSubject([])
            self.activityTimelineSubject = CurrentValueSubject([])
            self.realizedPnLSubject = CurrentValueSubject([])
        }

        self.summarySubject = CurrentValueSubject(
            PortfolioSummary(
                cashBalance: self.cashBalance,
                positionsMarketValue: 0,
                unrealizedPnL: 0,
                realizedPnL: self.realizedPnLSubject.value.reduce(Decimal.zero) { $0 + $1.realizedPnL },
                totalEquity: self.cashBalance,
                dayChange: 0
            )
        )

        marketDataRepository.quotesPublisher
            .sink { [weak self] quotes in
                self?.recalculate(using: quotes)
            }
            .store(in: &cancellables)
    }

    func position(for symbol: String) -> Position? {
        positionsSubject.value.first(where: { $0.symbol == symbol })
    }

    @discardableResult
    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> TradeExecutionResult {
        switch draft.side {
        case .buy:
            return try applyBuyOrder(draft, executionPrice: executionPrice, filledAt: filledAt)
        case .sell:
            return try applySellOrder(draft, executionPrice: executionPrice, filledAt: filledAt)
        }
    }

    private func applyBuyOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> TradeExecutionResult {
        let requiredNotional = executionPrice * draft.quantity
        guard cashBalance >= requiredNotional else {
            throw TradingSimulationError.insufficientFunds(required: requiredNotional, available: cashBalance)
        }

        let updatedCashBalance = cashBalance - requiredNotional

        var positions = positionsSubject.value
        let updatedPosition: Position
        if let existingIndex = positions.firstIndex(where: { $0.symbol == draft.assetSymbol }) {
            let existing = positions[existingIndex]
            let totalQuantity = existing.quantity + draft.quantity
            let weightedCost = (existing.averageEntryPrice * existing.quantity) + (executionPrice * draft.quantity)
            let averagePrice = weightedCost / totalQuantity
            updatedPosition = Position(
                id: existing.id,
                symbol: existing.symbol,
                quantity: totalQuantity,
                averageEntryPrice: averagePrice,
                currentPrice: currentPrice(for: existing.symbol, fallback: executionPrice),
                unrealizedPnL: Self.unrealizedPnL(quantity: totalQuantity, averageEntryPrice: averagePrice, currentPrice: currentPrice(for: existing.symbol, fallback: executionPrice)),
                openedAt: existing.openedAt
            )
            positions[existingIndex] = updatedPosition
            AppLogger.portfolio.info("Position increased for \(draft.assetSymbol, privacy: .public)")
        } else {
            updatedPosition = Position(
                id: UUID(),
                symbol: draft.assetSymbol,
                quantity: draft.quantity,
                averageEntryPrice: executionPrice,
                currentPrice: currentPrice(for: draft.assetSymbol, fallback: executionPrice),
                unrealizedPnL: 0,
                openedAt: filledAt
            )
            positions.append(updatedPosition)
            AppLogger.portfolio.info("Position created for \(draft.assetSymbol, privacy: .public)")
        }

        let order = makeOrderRecord(draft: draft, executionPrice: executionPrice, filledAt: filledAt, linkedPositionID: updatedPosition.id)
        let event = ActivityEvent(
            id: UUID(),
            kind: .buy,
            symbol: draft.assetSymbol,
            quantity: draft.quantity,
            price: executionPrice,
            timestamp: filledAt,
            orderID: order.id,
            relatedPositionID: updatedPosition.id,
            realizedPnL: nil
        )

        var orders = orderHistorySubject.value
        orders.insert(order, at: 0)
        var timeline = activityTimelineSubject.value
        timeline.insert(event, at: 0)
        let realizedHistory = realizedPnLSubject.value

        try persistState(
            cashBalance: updatedCashBalance,
            positions: positions,
            orders: orders,
            realizedHistory: realizedHistory,
            activity: timeline
        )

        cashBalance = updatedCashBalance
        positionsSubject.send(positions)
        orderHistorySubject.send(orders)
        activityTimelineSubject.send(timeline)
        realizedPnLSubject.send(realizedHistory)
        AppLogger.portfolio.debug("History timeline updated")
        recalculate(using: Array(latestQuotesBySymbol.values))

        AppLogger.portfolio.info("Order recorded \(order.id.uuidString, privacy: .public)")
        return TradeExecutionResult(resultingPosition: updatedPosition, orderRecord: order, activityEvent: event, realizedPnLEntry: nil)
    }

    private func applySellOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> TradeExecutionResult {
        guard draft.quantity > 0 else {
            throw TradingSimulationError.invalidCloseQuantity
        }

        var positions = positionsSubject.value
        guard let existingIndex = positions.firstIndex(where: { $0.symbol == draft.assetSymbol }) else {
            throw TradingSimulationError.missingPosition(symbol: draft.assetSymbol)
        }
        let existing = positions[existingIndex]
        guard existing.quantity >= draft.quantity else {
            throw TradingSimulationError.closeQuantityExceedsOpenQuantity(symbol: draft.assetSymbol)
        }

        let updatedCashBalance = cashBalance + (executionPrice * draft.quantity)
        let remaining = existing.quantity - draft.quantity
        let realizedPnL = Self.realizedPnL(quantityClosed: draft.quantity, averageEntryPrice: existing.averageEntryPrice, exitPrice: executionPrice)

        let realizedEntry = RealizedPnLEntry(
            id: UUID(),
            symbol: draft.assetSymbol,
            quantityClosed: draft.quantity,
            averageEntryPrice: existing.averageEntryPrice,
            exitPrice: executionPrice,
            realizedPnL: realizedPnL,
            closedAt: filledAt,
            linkedPositionID: existing.id,
            note: remaining == 0 ? "full-close" : "partial-close"
        )

        let resultingPosition: Position?
        let eventKind: ActivityEvent.Kind
        if remaining == 0 {
            positions.remove(at: existingIndex)
            resultingPosition = nil
            eventKind = .fullClose
            AppLogger.portfolio.info("Position closed for \(draft.assetSymbol, privacy: .public)")
        } else {
            let markedPrice = currentPrice(for: existing.symbol, fallback: executionPrice)
            let updated = Position(
                id: existing.id,
                symbol: existing.symbol,
                quantity: remaining,
                averageEntryPrice: existing.averageEntryPrice,
                currentPrice: markedPrice,
                unrealizedPnL: Self.unrealizedPnL(quantity: remaining, averageEntryPrice: existing.averageEntryPrice, currentPrice: markedPrice),
                openedAt: existing.openedAt
            )
            positions[existingIndex] = updated
            resultingPosition = updated
            eventKind = .partialClose
            AppLogger.portfolio.info("Position reduced for \(draft.assetSymbol, privacy: .public)")
        }

        let order = makeOrderRecord(draft: draft, executionPrice: executionPrice, filledAt: filledAt, linkedPositionID: existing.id)
        let event = ActivityEvent(
            id: UUID(),
            kind: eventKind,
            symbol: draft.assetSymbol,
            quantity: draft.quantity,
            price: executionPrice,
            timestamp: filledAt,
            orderID: order.id,
            relatedPositionID: existing.id,
            realizedPnL: realizedPnL
        )

        var orders = orderHistorySubject.value
        orders.insert(order, at: 0)
        var timeline = activityTimelineSubject.value
        timeline.insert(event, at: 0)
        var realizedHistory = realizedPnLSubject.value
        realizedHistory.insert(realizedEntry, at: 0)

        try persistState(
            cashBalance: updatedCashBalance,
            positions: positions,
            orders: orders,
            realizedHistory: realizedHistory,
            activity: timeline
        )

        cashBalance = updatedCashBalance
        positionsSubject.send(positions)
        orderHistorySubject.send(orders)
        activityTimelineSubject.send(timeline)
        realizedPnLSubject.send(realizedHistory)
        AppLogger.portfolio.debug("History timeline updated")
        recalculate(using: Array(latestQuotesBySymbol.values))

        AppLogger.portfolio.info("Realized P&L recorded \(realizedPnL.description, privacy: .public)")
        return TradeExecutionResult(resultingPosition: resultingPosition, orderRecord: order, activityEvent: event, realizedPnLEntry: realizedEntry)
    }

    private func recalculate(using quotes: [Quote]) {
        latestQuotesBySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })

        let updated = positionsSubject.value.map { position in
            let currentPrice = currentPrice(for: position.symbol, fallback: position.currentPrice)
            let unrealized = Self.unrealizedPnL(quantity: position.quantity, averageEntryPrice: position.averageEntryPrice, currentPrice: currentPrice)
            return Position(
                id: position.id,
                symbol: position.symbol,
                quantity: position.quantity,
                averageEntryPrice: position.averageEntryPrice,
                currentPrice: currentPrice,
                unrealizedPnL: unrealized,
                openedAt: position.openedAt
            )
        }

        let positionsMarketValue = updated.reduce(Decimal.zero) { partial, position in
            partial + (position.currentPrice * position.quantity)
        }
        let unrealized = updated.reduce(Decimal.zero) { $0 + $1.unrealizedPnL }
        let realized = realizedPnLSubject.value.reduce(Decimal.zero) { $0 + $1.realizedPnL }
        let totalEquity = cashBalance + positionsMarketValue

        positionsSubject.send(updated)
        summarySubject.send(
            PortfolioSummary(
                cashBalance: cashBalance,
                positionsMarketValue: positionsMarketValue,
                unrealizedPnL: unrealized,
                realizedPnL: realized,
                totalEquity: totalEquity,
                dayChange: 0
            )
        )
        AppLogger.portfolio.debug("Portfolio recalculated from shared quote stream")
    }

    private func persistState(
        cashBalance: Decimal,
        positions: [Position],
        orders: [OrderRecord],
        realizedHistory: [RealizedPnLEntry],
        activity: [ActivityEvent]
    ) throws {
        guard let persistenceStore else { return }
        do {
            try persistenceStore.saveState(
                PersistedPortfolioState(
                    cashBalance: cashBalance,
                    openPositions: positions,
                    orderHistory: orders,
                    realizedPnLHistory: realizedHistory,
                    activityTimeline: activity,
                    savedAt: Date()
                )
            )
        } catch {
            throw TradingSimulationError.persistenceSaveFailed
        }
    }

    private func makeOrderRecord(draft: OrderDraft, executionPrice: Decimal, filledAt: Date, linkedPositionID: UUID?) -> OrderRecord {
        OrderRecord(
            id: UUID(),
            symbol: draft.assetSymbol,
            side: draft.side,
            type: draft.type,
            quantity: draft.quantity,
            executedPrice: executionPrice,
            grossValue: executionPrice * draft.quantity,
            submittedAt: draft.submittedAt,
            executedAt: filledAt,
            status: .filled,
            source: .simulated,
            linkedPositionID: linkedPositionID
        )
    }

    private func currentPrice(for symbol: String, fallback: Decimal) -> Decimal {
        latestQuotesBySymbol[symbol]?.lastPrice ?? fallback
    }

    static func unrealizedPnL(quantity: Decimal, averageEntryPrice: Decimal, currentPrice: Decimal) -> Decimal {
        (currentPrice - averageEntryPrice) * quantity
    }

    static func realizedPnL(quantityClosed: Decimal, averageEntryPrice: Decimal, exitPrice: Decimal) -> Decimal {
        (exitPrice - averageEntryPrice) * quantityClosed
    }
}
