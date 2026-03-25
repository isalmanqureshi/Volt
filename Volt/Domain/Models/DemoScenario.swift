import Foundation

struct DemoScenario: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let detail: String
    let state: PersistedPortfolioState

    static let all: [DemoScenario] = [
        .emptyNewUser,
        .balancedStarter,
        .analyticsRich
    ]

    static let emptyNewUser = DemoScenario(
        id: "scenario.empty",
        name: "Empty New User",
        detail: "No positions or history, good for onboarding + empty states.",
        state: PersistedPortfolioState(cashBalance: 50_000, openPositions: [], orderHistory: [], realizedPnLHistory: [], activityTimeline: [], savedAt: Date(timeIntervalSince1970: 1_700_000_000))
    )

    static let balancedStarter = DemoScenario(
        id: "scenario.balanced",
        name: "Balanced Starter",
        detail: "A first-time diversified portfolio with small open exposure.",
        state: PersistedPortfolioState(
            cashBalance: 31_500,
            openPositions: [
                Position(id: stableUUID("11111111-1111-1111-1111-111111111111"), symbol: "BTC/USD", quantity: 0.12, averageEntryPrice: 66_200, currentPrice: 68_100, unrealizedPnL: 228, openedAt: Date(timeIntervalSince1970: 1_700_086_400)),
                Position(id: stableUUID("22222222-2222-2222-2222-222222222222"), symbol: "ETH/USD", quantity: 1.9, averageEntryPrice: 3_320, currentPrice: 3_460, unrealizedPnL: 266, openedAt: Date(timeIntervalSince1970: 1_700_172_800))
            ],
            orderHistory: [],
            realizedPnLHistory: [],
            activityTimeline: [],
            savedAt: Date(timeIntervalSince1970: 1_700_259_200)
        )
    )

    static let analyticsRich = DemoScenario(
        id: "scenario.analytics",
        name: "Analytics Rich",
        detail: "Mature account with mixed realized history and open risk.",
        state: PersistedPortfolioState(
            cashBalance: 42_700,
            openPositions: [
                Position(id: stableUUID("33333333-3333-3333-3333-333333333333"), symbol: "SOL/USD", quantity: 40, averageEntryPrice: 145, currentPrice: 181, unrealizedPnL: 1_440, openedAt: Date(timeIntervalSince1970: 1_699_913_600))
            ],
            orderHistory: [],
            realizedPnLHistory: [
                RealizedPnLEntry(id: stableUUID("44444444-4444-4444-4444-444444444444"), symbol: "BTC/USD", quantityClosed: 0.06, averageEntryPrice: 61_300, exitPrice: 66_900, realizedPnL: 336, closedAt: Date(timeIntervalSince1970: 1_699_740_800), linkedPositionID: stableUUID("11111111-1111-1111-1111-111111111111"), note: "full-close"),
                RealizedPnLEntry(id: stableUUID("55555555-5555-5555-5555-555555555555"), symbol: "ETH/USD", quantityClosed: 1.2, averageEntryPrice: 3_540, exitPrice: 3_410, realizedPnL: -156, closedAt: Date(timeIntervalSince1970: 1_699_827_200), linkedPositionID: stableUUID("22222222-2222-2222-2222-222222222222"), note: "partial-close")
            ],
            activityTimeline: [],
            savedAt: Date(timeIntervalSince1970: 1_700_259_200)
        )
    )

    private static func stableUUID(_ string: String) -> UUID {
        UUID(uuidString: string) ?? UUID()
    }
}
