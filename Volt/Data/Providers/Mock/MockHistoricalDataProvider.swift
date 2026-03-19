import Foundation

struct MockHistoricalDataProvider: HistoricalDataProvider {
    private let clock: ClockProviding

    init(clock: ClockProviding = SystemClock()) {
        self.clock = clock
    }

    func fetchRecentCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle] {
        let now = clock.now
        return (0..<outputSize).map { offset in
            let close = Decimal(100 + offset)
            return Candle(
                symbol: symbol,
                interval: interval,
                open: close - 1,
                high: close + 1,
                low: close - 2,
                close: close,
                volume: Decimal(1_000 + offset),
                timestamp: now.addingTimeInterval(TimeInterval(-60 * offset)),
                isComplete: true
            )
        }
    }
}
