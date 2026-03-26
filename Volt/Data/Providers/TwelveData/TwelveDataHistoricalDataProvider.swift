import Foundation
internal import os

struct TwelveDataHistoricalDataProvider: HistoricalDataProvider {
    private let baseURL: URL
    private let apiKey: String?
    private let session: URLSession
    private let decoder: JSONDecoder
    private let logger = AppLogger.market

    init(
        baseURL: URL = URL(string: "https://api.twelvedata.com")!,
        apiKey: String? = nil,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
        self.decoder = decoder
    }

    func fetchRecentCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle] {
        guard let apiKey, !apiKey.isEmpty else {
            throw TwelveDataProviderError.missingAPIKey
        }
        guard let requestURL = TwelveDataEndpointBuilder.timeSeriesURL(
            baseURL: baseURL,
            symbol: symbol,
            interval: interval,
            outputSize: outputSize,
            apiKey: apiKey
        ) else {
            throw TwelveDataProviderError.invalidURL
        }

        logger.info("Twelve Data candle fetch started for \(symbol, privacy: .public)")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwelveDataProviderError.emptyResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TwelveDataProviderError.requestFailed(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
        }

        do {
            let dto = try decoder.decode(TwelveDataTimeSeriesDTO.self, from: data)
            let candles = try TwelveDataMapper.mapCandles(dto).sorted(by: { $0.timestamp < $1.timestamp })
            guard !candles.isEmpty else { throw TwelveDataProviderError.emptyResponse }
            logger.info("Twelve Data candle fetch succeeded for \(symbol, privacy: .public): \(candles.count, privacy: .public) bars")
            return candles
        } catch let error as TwelveDataMapperError {
            throw TwelveDataProviderError.mappingFailed(String(describing: error))
        } catch {
            throw TwelveDataProviderError.decodingFailed(error.localizedDescription)
        }
    }
}
