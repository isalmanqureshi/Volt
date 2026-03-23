import Foundation
internal import os

final class DefaultTradingSimulationService: TradingSimulationService {
    private let marketDataRepository: MarketDataRepository
    private let portfolioRepository: PortfolioRepository
    private let supportedSymbols: Set<String>
    private let slippageBps: Decimal

    init(
        marketDataRepository: MarketDataRepository,
        portfolioRepository: PortfolioRepository,
        supportedSymbols: [String],
        slippageBps: Decimal = 0
    ) {
        self.marketDataRepository = marketDataRepository
        self.portfolioRepository = portfolioRepository
        self.supportedSymbols = Set(supportedSymbols)
        self.slippageBps = slippageBps
    }

    @discardableResult
    func placeOrder(_ draft: OrderDraft) throws -> TradeExecutionResult {
        AppLogger.portfolio.info("Order submitted: \(draft.assetSymbol, privacy: .public) \(String(describing: draft.side), privacy: .public) qty=\(draft.quantity.description, privacy: .public)")

        guard draft.quantity > 0 else {
            AppLogger.portfolio.error("Order validation failed: invalid quantity")
            throw TradingSimulationError.invalidQuantity
        }
        guard supportedSymbols.contains(draft.assetSymbol) else {
            AppLogger.portfolio.error("Order validation failed: unsupported symbol \(draft.assetSymbol, privacy: .public)")
            throw TradingSimulationError.unsupportedAsset(symbol: draft.assetSymbol)
        }

        if draft.side == .sell {
            guard let existingPosition = portfolioRepository.position(for: draft.assetSymbol) else {
                throw TradingSimulationError.missingPosition(symbol: draft.assetSymbol)
            }
            guard draft.quantity <= existingPosition.quantity else {
                throw TradingSimulationError.closeQuantityExceedsOpenQuantity(symbol: draft.assetSymbol)
            }
        }

        guard let quote = marketDataRepository.quote(for: draft.assetSymbol) else {
            AppLogger.portfolio.error("Order validation failed: missing quote \(draft.assetSymbol, privacy: .public)")
            throw TradingSimulationError.missingQuote(symbol: draft.assetSymbol)
        }

        let executionPrice = applySlippage(to: quote.lastPrice, side: draft.side)
        let result = try portfolioRepository.applyFilledOrder(draft, executionPrice: executionPrice, filledAt: draft.submittedAt)
        AppLogger.portfolio.info("Order filled locally: \(draft.assetSymbol, privacy: .public) at \(executionPrice.description, privacy: .public)")
        return result
    }

    private func applySlippage(to price: Decimal, side: OrderSide) -> Decimal {
        guard slippageBps != 0 else { return price }
        let multiplier = (slippageBps / 10_000)
        switch side {
        case .buy:
            return price * (1 + multiplier)
        case .sell:
            return price * (1 - multiplier)
        }
    }
}
