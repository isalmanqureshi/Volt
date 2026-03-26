import Foundation

struct Asset: Identifiable, Equatable, Hashable, Sendable {
    enum AssetClass: String, Codable, Sendable {
        case crypto
    }

    var id: String { symbol }
    let symbol: String
    let displayName: String
    let baseCurrency: String
    let quoteCurrency: String
    let assetClass: AssetClass
    let pricePrecision: Int
}
