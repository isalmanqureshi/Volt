import Foundation

protocol MarketCacheStore {
    func loadQuotes() -> [Quote]
    func saveQuotes(_ quotes: [Quote])
    func loadCandles(symbol: String) -> [Candle]?
    func saveCandles(_ candles: [Candle], symbol: String)
}

struct FileBackedMarketCacheStore: MarketCacheStore {
    private struct CachedMarketPayload: Codable {
        var quotes: [Quote]
        var candlesBySymbol: [String: [Candle]]
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let maxCandlesPerSymbol: Int

    init(
        fileName: String = "market_cache.json",
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil,
        maxCandlesPerSymbol: Int = 180
    ) {
        self.fileManager = fileManager
        self.maxCandlesPerSymbol = maxCandlesPerSymbol
        if let baseDirectory {
            self.fileURL = baseDirectory.appendingPathComponent(fileName)
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            self.fileURL = appSupport.appendingPathComponent("Volt", isDirectory: true).appendingPathComponent(fileName)
        }
    }

    func loadQuotes() -> [Quote] {
        loadPayload()?.quotes ?? []
    }

    func saveQuotes(_ quotes: [Quote]) {
        var payload = loadPayload() ?? CachedMarketPayload(quotes: [], candlesBySymbol: [:])
        payload.quotes = quotes
        savePayload(payload)
    }

    func loadCandles(symbol: String) -> [Candle]? {
        loadPayload()?.candlesBySymbol[symbol]
    }

    func saveCandles(_ candles: [Candle], symbol: String) {
        var payload = loadPayload() ?? CachedMarketPayload(quotes: [], candlesBySymbol: [:])
        payload.candlesBySymbol[symbol] = Array(candles.sorted(by: { $0.timestamp < $1.timestamp }).suffix(maxCandlesPerSymbol))
        savePayload(payload)
    }

    private func loadPayload() -> CachedMarketPayload? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CachedMarketPayload.self, from: data)
    }

    private func savePayload(_ payload: CachedMarketPayload) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            if fileManager.fileExists(atPath: directory.path) == false {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            AppLogger.market.error("Market cache save failed")
        }
    }
}
