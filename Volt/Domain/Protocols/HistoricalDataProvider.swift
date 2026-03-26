import Foundation

protocol HistoricalDataProvider {
    func fetchRecentCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle]
}
