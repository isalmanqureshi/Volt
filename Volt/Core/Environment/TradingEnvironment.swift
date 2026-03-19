import Foundation

enum TradingEnvironment: String, CaseIterable, Codable, Sendable {
    case mock
    case twelveDataSeededSimulation

    var displayName: String {
        switch self {
        case .mock: return "Mock"
        case .twelveDataSeededSimulation: return "Twelve Data Seeded Simulation"
        }
    }
}
