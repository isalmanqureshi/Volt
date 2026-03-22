import Combine
import Foundation
internal import os

final class InMemoryPortfolioRepository: PortfolioRepository {
    private let positionsSubject: CurrentValueSubject<[Position], Never>
    private let summarySubject: CurrentValueSubject<PortfolioSummary, Never>
    private var cashBalance: Decimal
    private var cancellables = Set<AnyCancellable>()

    var positionsPublisher: AnyPublisher<[Position], Never> { positionsSubject.eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { summarySubject.eraseToAnyPublisher() }
    var currentPositions: [Position] { positionsSubject.value }
    var currentSummary: PortfolioSummary { summarySubject.value }

    init(marketDataRepository: MarketDataRepository, cashBalance: Decimal, initialPositions: [Position] = []) {
        self.cashBalance = cashBalance
        self.positionsSubject = CurrentValueSubject(initialPositions)
        self.summarySubject = CurrentValueSubject(
            PortfolioSummary(cashBalance: cashBalance, positionsMarketValue: 0, unrealizedPnL: 0, totalEquity: cashBalance, dayChange: 0)
        )

        marketDataRepository.quotesPublisher
            .sink { [weak self] quotes in
                self?.recalculate(using: quotes)
            }
            .store(in: &cancellables)
    }

    @discardableResult
    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> Position {
        switch draft.side {
        case .buy:
            return try applyBuyOrder(draft, executionPrice: executionPrice, filledAt: filledAt)
        case .sell:
            return try applySellOrder(draft, executionPrice: executionPrice, filledAt: filledAt)
        }
    }

    private func applyBuyOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> Position {
        let requiredNotional = executionPrice * draft.quantity
        guard cashBalance >= requiredNotional else {
            throw TradingSimulationError.insufficientFunds(required: requiredNotional, available: cashBalance)
        }

        cashBalance -= requiredNotional

        var positions = positionsSubject.value
        if let existingIndex = positions.firstIndex(where: { $0.symbol == draft.assetSymbol }) {
            let existing = positions[existingIndex]
            let totalQuantity = existing.quantity + draft.quantity
            let weightedCost = (existing.averageEntryPrice * existing.quantity) + (executionPrice * draft.quantity)
            let updated = Position(
                id: existing.id,
                symbol: existing.symbol,
                quantity: totalQuantity,
                averageEntryPrice: weightedCost / totalQuantity,
                currentPrice: executionPrice,
                unrealizedPnL: (executionPrice - (weightedCost / totalQuantity)) * totalQuantity,
                openedAt: existing.openedAt
            )
            positions[existingIndex] = updated
            positionsSubject.send(positions)
            recalculate(using: [])
            AppLogger.portfolio.info("Position increased for \(draft.assetSymbol, privacy: .public)")
            return updated
        } else {
            let newPosition = Position(
                id: UUID(),
                symbol: draft.assetSymbol,
                quantity: draft.quantity,
                averageEntryPrice: executionPrice,
                currentPrice: executionPrice,
                unrealizedPnL: 0,
                openedAt: filledAt
            )
            positions.append(newPosition)
            positionsSubject.send(positions)
            recalculate(using: [])
            AppLogger.portfolio.info("Position created for \(draft.assetSymbol, privacy: .public)")
            return newPosition
        }
    }

    private func applySellOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> Position {
        var positions = positionsSubject.value
        guard let existingIndex = positions.firstIndex(where: { $0.symbol == draft.assetSymbol }) else {
            throw TradingSimulationError.insufficientPositionQuantity(symbol: draft.assetSymbol)
        }
        let existing = positions[existingIndex]
        guard existing.quantity >= draft.quantity else {
            throw TradingSimulationError.insufficientPositionQuantity(symbol: draft.assetSymbol)
        }

        cashBalance += executionPrice * draft.quantity
        let remaining = existing.quantity - draft.quantity
        if remaining == 0 {
            positions.remove(at: existingIndex)
            positionsSubject.send(positions)
            recalculate(using: [])
            AppLogger.portfolio.info("Position closed for \(draft.assetSymbol, privacy: .public)")
            return Position(
                id: existing.id,
                symbol: existing.symbol,
                quantity: 0,
                averageEntryPrice: existing.averageEntryPrice,
                currentPrice: executionPrice,
                unrealizedPnL: 0,
                openedAt: filledAt
            )
        }

        let updated = Position(
            id: existing.id,
            symbol: existing.symbol,
            quantity: remaining,
            averageEntryPrice: existing.averageEntryPrice,
            currentPrice: executionPrice,
            unrealizedPnL: (executionPrice - existing.averageEntryPrice) * remaining,
            openedAt: existing.openedAt
        )
        positions[existingIndex] = updated
        positionsSubject.send(positions)
        recalculate(using: [])
        AppLogger.portfolio.info("Position reduced for \(draft.assetSymbol, privacy: .public)")
        return updated
    }

    private func recalculate(using quotes: [Quote]) {
        let quoteBySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })
        let updated = positionsSubject.value.map { position in
            guard let quote = quoteBySymbol[position.symbol] else { return position }
            let currentPrice = quote.lastPrice
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
        let totalEquity = cashBalance + positionsMarketValue

        positionsSubject.send(updated)
        summarySubject.send(
            PortfolioSummary(
                cashBalance: cashBalance,
                positionsMarketValue: positionsMarketValue,
                unrealizedPnL: unrealized,
                totalEquity: totalEquity,
                dayChange: 0
            )
        )
        AppLogger.portfolio.debug("Portfolio recalculated from market tick stream")
    }

    static func unrealizedPnL(quantity: Decimal, averageEntryPrice: Decimal, currentPrice: Decimal) -> Decimal {
        (currentPrice - averageEntryPrice) * quantity
    }
}
