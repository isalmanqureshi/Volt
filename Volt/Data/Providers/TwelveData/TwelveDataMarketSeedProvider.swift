import Foundation
internal import os

struct TwelveDataMarketSeedProvider: MarketSeedProvider {
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

    func fetchInitialQuotes(for symbols: [String]) async throws -> [Quote] {
        guard let apiKey, !apiKey.isEmpty else {
            throw TwelveDataProviderError.missingAPIKey
        }

        logger.info("Twelve Data seeding started for \(symbols.count, privacy: .public) symbols")
        var seededQuotes: [Quote] = []
        for symbol in symbols {
            guard let requestURL = TwelveDataEndpointBuilder.quoteURL(baseURL: baseURL, symbol: symbol, apiKey: apiKey) else {
                throw TwelveDataProviderError.invalidURL
            }

            var request = URLRequest(url: requestURL)
            request.httpMethod = "GET"
            logger.debug("GET \(requestURL.absoluteString, privacy: .private(mask: .hash))")
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TwelveDataProviderError.emptyResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw TwelveDataProviderError.requestFailed(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
            }

            do {
                let dto = try decoder.decode(TwelveDataQuoteDTO.self, from: data)
                let mapped = try TwelveDataMapper.mapQuote(dto)
                seededQuotes.append(mapped)
            } catch let error as TwelveDataMapperError {
                throw TwelveDataProviderError.mappingFailed(String(describing: error))
            } catch {
                throw TwelveDataProviderError.decodingFailed(error.localizedDescription)
            }
        }

        guard !seededQuotes.isEmpty else {
            throw TwelveDataProviderError.emptyResponse
        }

        logger.info("Twelve Data seeding succeeded with \(seededQuotes.count, privacy: .public) quotes")
        return seededQuotes
    }
}
