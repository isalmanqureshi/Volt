import Foundation

struct MockMarketSeedProvider: MarketSeedProvider {
    private let clock: ClockProviding

    init(clock: ClockProviding = SystemClock()) {
        self.clock = clock
    }

    func fetchInitialQuotes(for symbols: [String]) async throws -> [Quote] {
        symbols.enumerated().map { index, symbol in
            let basePrice: Decimal
            switch symbol {
            case "BTC/USD": basePrice = 68_500
            case "ETH/USD": basePrice = 3_550
            case "SOL/USD": basePrice = 185
            case "DOGE/USD": basePrice = 0.18
            default: basePrice = Decimal(100 + index)
            }

            return Quote(
                symbol: symbol,
                lastPrice: basePrice,
                changePercent: 0,
                timestamp: clock.now,
                source: "mock",
                isSimulated: false
            )
        }
    }
}
