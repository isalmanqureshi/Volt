import Foundation

enum OrderSizeMode: String, CaseIterable, Codable, Sendable {
    case fixedQuantity
    case fixedNotional
    case percentOfCash

    var title: String {
        switch self {
        case .fixedQuantity: return "Fixed Quantity"
        case .fixedNotional: return "Fixed Notional"
        case .percentOfCash: return "% of Cash"
        }
    }
}

struct SimulatorRiskPreferences: Codable, Equatable, Sendable {
    var orderSizeMode: OrderSizeMode
    var defaultOrderSizeValue: Decimal
    var maxRecommendedPositionPercent: Decimal
    var warningThresholdPercent: Decimal
    var requiresLargeOrderConfirmation: Bool
    var riskWarningsEnabled: Bool

    static let `default` = SimulatorRiskPreferences(
        orderSizeMode: .fixedQuantity,
        defaultOrderSizeValue: 0.1,
        maxRecommendedPositionPercent: 25,
        warningThresholdPercent: 15,
        requiresLargeOrderConfirmation: true,
        riskWarningsEnabled: true
    )

    func validated() -> SimulatorRiskPreferences {
        var copy = self
        if copy.defaultOrderSizeValue <= 0 { copy.defaultOrderSizeValue = Self.default.defaultOrderSizeValue }
        if copy.maxRecommendedPositionPercent <= 0 || copy.maxRecommendedPositionPercent > 100 { copy.maxRecommendedPositionPercent = Self.default.maxRecommendedPositionPercent }
        if copy.warningThresholdPercent <= 0 || copy.warningThresholdPercent > 100 { copy.warningThresholdPercent = Self.default.warningThresholdPercent }
        return copy
    }
}
