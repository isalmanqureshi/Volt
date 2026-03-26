import Foundation

struct AccountSnapshotCheckpoint: Identifiable, Codable, Equatable, Sendable {
    enum Trigger: String, Codable, CaseIterable, Sendable {
        case appLaunch
        case appBackground
        case orderExecution
        case lifecycleResume
        case manualRefresh
        case periodic
    }

    let id: UUID
    let timestamp: Date
    let cashBalance: Decimal
    let positionsMarketValue: Decimal
    let unrealizedPnL: Decimal
    let realizedPnL: Decimal
    let totalEquity: Decimal
    let openPositionsCount: Int
    let environment: TradingEnvironment?
    let trigger: Trigger

    init(
        id: UUID = UUID(),
        timestamp: Date,
        cashBalance: Decimal,
        positionsMarketValue: Decimal,
        unrealizedPnL: Decimal,
        realizedPnL: Decimal,
        totalEquity: Decimal,
        openPositionsCount: Int,
        environment: TradingEnvironment?,
        trigger: Trigger
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cashBalance = cashBalance
        self.positionsMarketValue = positionsMarketValue
        self.unrealizedPnL = unrealizedPnL
        self.realizedPnL = realizedPnL
        self.totalEquity = totalEquity
        self.openPositionsCount = openPositionsCount
        self.environment = environment
        self.trigger = trigger
    }
}
