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

enum SlippagePreset: String, CaseIterable, Codable, Sendable {
    case off, low, medium, high

    var title: String { rawValue.capitalized }
    var basisPoints: Decimal {
        switch self {
        case .off: 0
        case .low: 5
        case .medium: 12
        case .high: 25
        }
    }
}

enum SimulatorVolatilityPreset: String, CaseIterable, Codable, Sendable {
    case calm, normal, aggressive

    var title: String { rawValue.capitalized }
}

enum TradeConfirmationMode: String, CaseIterable, Codable, Sendable {
    case alwaysConfirm
    case confirmOnlyLarge
    case minimal

    var title: String {
        switch self {
        case .alwaysConfirm: return "Always Confirm"
        case .confirmOnlyLarge: return "Only Large Orders"
        case .minimal: return "Minimal"
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
    var slippagePreset: SlippagePreset
    var volatilityPreset: SimulatorVolatilityPreset
    var tradeConfirmationMode: TradeConfirmationMode

    static let `default` = SimulatorRiskPreferences(
        orderSizeMode: .fixedQuantity,
        defaultOrderSizeValue: 0.1,
        maxRecommendedPositionPercent: 25,
        warningThresholdPercent: 15,
        requiresLargeOrderConfirmation: true,
        riskWarningsEnabled: true,
        slippagePreset: .low,
        volatilityPreset: .normal,
        tradeConfirmationMode: .confirmOnlyLarge
    )

    static let conservative = SimulatorRiskPreferences(
        orderSizeMode: .fixedQuantity,
        defaultOrderSizeValue: 0.05,
        maxRecommendedPositionPercent: 15,
        warningThresholdPercent: 10,
        requiresLargeOrderConfirmation: true,
        riskWarningsEnabled: true,
        slippagePreset: .off,
        volatilityPreset: .calm,
        tradeConfirmationMode: .alwaysConfirm
    )

    static let aggressive = SimulatorRiskPreferences(
        orderSizeMode: .fixedQuantity,
        defaultOrderSizeValue: 0.2,
        maxRecommendedPositionPercent: 40,
        warningThresholdPercent: 30,
        requiresLargeOrderConfirmation: false,
        riskWarningsEnabled: true,
        slippagePreset: .high,
        volatilityPreset: .aggressive,
        tradeConfirmationMode: .minimal
    )

    func validated() -> SimulatorRiskPreferences {
        var copy = self
        if copy.defaultOrderSizeValue <= 0 { copy.defaultOrderSizeValue = Self.default.defaultOrderSizeValue }
        if copy.maxRecommendedPositionPercent <= 0 || copy.maxRecommendedPositionPercent > 100 { copy.maxRecommendedPositionPercent = Self.default.maxRecommendedPositionPercent }
        if copy.warningThresholdPercent <= 0 || copy.warningThresholdPercent > 100 { copy.warningThresholdPercent = Self.default.warningThresholdPercent }
        return copy
    }
}
