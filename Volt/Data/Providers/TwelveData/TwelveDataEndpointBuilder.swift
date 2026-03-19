import Foundation

enum TwelveDataEndpointBuilder {
    static func quoteURL(baseURL: URL, symbol: String, apiKey: String) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("quote"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: wireSymbol(from: symbol)),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        return components?.url
    }

    static func timeSeriesURL(baseURL: URL, symbol: String, interval: String, outputSize: Int, apiKey: String) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("time_series"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: wireSymbol(from: symbol)),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "outputsize", value: String(outputSize)),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        return components?.url
    }

    static func wireSymbol(from appSymbol: String) -> String {
        appSymbol.replacingOccurrences(of: "/", with: "")
    }
}
