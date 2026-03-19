import Foundation

struct TwelveDataHistoricalDataProvider: HistoricalDataProvider {
    enum ProviderError: Error {
        case notImplemented
    }

    func fetchRecentCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle] {
        AppLogger.market.info("TwelveData historical provider scaffold for \(symbol, privacy: .public)")
        throw ProviderError.notImplemented
    }
}
