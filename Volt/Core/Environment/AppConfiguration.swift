import Foundation

/// Runtime configuration used to wire dependencies without hardcoded secrets.
struct AppConfiguration: Sendable {
    let environment: TradingEnvironment
    let twelveDataBaseURL: URL
    let twelveDataAPIKey: String?
    let enabledAssets: [Asset]
    let defaultCandleOutputSize: Int
    let simulationConfig: PriceSimulationConfig
    let demoInitialCashBalance: Decimal

    static func current(processInfo: ProcessInfo = .processInfo) -> AppConfiguration {
        let selectedEnvironment = TradingEnvironment(rawValue: processInfo.environment["VOLT_ENV"] ?? "") ?? .twelveDataSeededSimulation
        let baseURL = URL(string: processInfo.environment["TWELVE_DATA_BASE_URL"] ?? "https://api.twelvedata.com") ?? URL(string: "https://api.twelvedata.com")!
        let apiKey = processInfo.environment["TWELVE_DATA_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let configuredSymbols = processInfo.environment["VOLT_SYMBOLS"]
            .map(SupportedAssets.resolve)
            ?? SupportedAssets.demoAssets

        return AppConfiguration(
            environment: selectedEnvironment,
            twelveDataBaseURL: baseURL,
            twelveDataAPIKey: (apiKey?.isEmpty == true) ? nil : apiKey,
            enabledAssets: configuredSymbols,
            defaultCandleOutputSize: 90,
            simulationConfig: .default,
            demoInitialCashBalance: 50_000
        )
    }
}
