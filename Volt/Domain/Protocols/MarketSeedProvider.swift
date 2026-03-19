import Foundation

protocol MarketSeedProvider {
    func fetchInitialQuotes(for symbols: [String]) async throws -> [Quote]
}
