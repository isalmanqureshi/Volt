import Foundation

enum SupportedAssets {
    static let demoAssets: [Asset] = [
        Asset(symbol: "BTC/USD", displayName: "Bitcoin", baseCurrency: "BTC", quoteCurrency: "USD", assetClass: .crypto, pricePrecision: 2),
        Asset(symbol: "ETH/USD", displayName: "Ethereum", baseCurrency: "ETH", quoteCurrency: "USD", assetClass: .crypto, pricePrecision: 2),
        Asset(symbol: "SOL/USD", displayName: "Solana", baseCurrency: "SOL", quoteCurrency: "USD", assetClass: .crypto, pricePrecision: 3),
        Asset(symbol: "DOGE/USD", displayName: "Dogecoin", baseCurrency: "DOGE", quoteCurrency: "USD", assetClass: .crypto, pricePrecision: 5)
    ]

    static func resolve(from symbolsCSV: String) -> [Asset] {
        let requested = Set(symbolsCSV.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() })
        let resolved = demoAssets.filter { requested.contains($0.symbol.uppercased()) }
        return resolved.isEmpty ? demoAssets.filter { ["BTC/USD", "ETH/USD", "SOL/USD"].contains($0.symbol) } : resolved
    }
}
