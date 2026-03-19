import Combine
import Foundation
internal import os

final class InMemoryPortfolioRepository: PortfolioRepository {
    private let positionsSubject: CurrentValueSubject<[Position], Never>
    private let summarySubject: CurrentValueSubject<PortfolioSummary, Never>
    private let cashBalance: Decimal
    private var cancellables = Set<AnyCancellable>()

    var positionsPublisher: AnyPublisher<[Position], Never> { positionsSubject.eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { summarySubject.eraseToAnyPublisher() }

    init(marketDataRepository: MarketDataRepository, cashBalance: Decimal = 10_000) {
        self.cashBalance = cashBalance
        let initialPositions = Self.makeSeedPositions()
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

    private func recalculate(using quotes: [Quote]) {
        let quoteBySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })
        let updated = positionsSubject.value.map { position in
            guard let quote = quoteBySymbol[position.symbol] else { return position }
            let currentPrice = quote.lastPrice
            let unrealized = Self.unrealizedPnL(for: position.side, quantity: position.quantity, averageEntryPrice: position.averageEntryPrice, currentPrice: currentPrice)
            return Position(
                id: position.id,
                symbol: position.symbol,
                side: position.side,
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

    static func unrealizedPnL(for side: OrderSide, quantity: Decimal, averageEntryPrice: Decimal, currentPrice: Decimal) -> Decimal {
        switch side {
        case .buy:
            return (currentPrice - averageEntryPrice) * quantity
        case .sell:
            return (averageEntryPrice - currentPrice) * quantity
        }
    }

    private static func makeSeedPositions() -> [Position] {
        [
            Position(
                id: UUID(),
                symbol: "BTC/USD",
                side: .buy,
                quantity: 0.08,
                averageEntryPrice: 66_200,
                currentPrice: 66_200,
                unrealizedPnL: 0,
                openedAt: Date().addingTimeInterval(-86_400)
            ),
            Position(
                id: UUID(),
                symbol: "ETH/USD",
                side: .buy,
                quantity: 1.4,
                averageEntryPrice: 3_420,
                currentPrice: 3_420,
                unrealizedPnL: 0,
                openedAt: Date().addingTimeInterval(-72_000)
            ),
            Position(
                id: UUID(),
                symbol: "SOL/USD",
                side: .buy,
                quantity: 12,
                averageEntryPrice: 172,
                currentPrice: 172,
                unrealizedPnL: 0,
                openedAt: Date().addingTimeInterval(-54_000)
            )
        ]
    }
}
