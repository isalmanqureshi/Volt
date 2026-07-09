import Foundation

struct MockHistoricalDataProvider: HistoricalDataProvider {
    private let clock: ClockProviding

    init(clock: ClockProviding = SystemClock()) {
        self.clock = clock
    }

    func fetchRecentCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle] {
        let now = clock.now
        let step = Self.seconds(forInterval: interval)
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
                timestamp: now.addingTimeInterval(-step * TimeInterval(offset)),
                isComplete: true
            )
        }
    }

    /// Spacing between mock candles so the generated series actually spans the
    /// labeled period (e.g. a "1day" range yields day-apart bars, not minute-apart).
    static func seconds(forInterval interval: String) -> TimeInterval {
        switch interval {
        case "1min": return 60
        case "5min": return 300
        case "15min": return 900
        case "30min": return 1_800
        case "45min": return 2_700
        case "1h": return 3_600
        case "2h": return 7_200
        case "4h": return 14_400
        case "1day": return 86_400
        case "1week": return 604_800
        case "1month": return 2_592_000
        default: return 60
        }
    }
}
