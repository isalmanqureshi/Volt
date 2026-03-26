import Combine
import Foundation
import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject var viewModel: PortfolioViewModel
    @State private var managePosition: Position?

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Total Equity", value: viewModel.summary.totalEquity.formatted(.currency(code: "USD")))
                LabeledContent("Unrealized P&L", value: viewModel.summary.unrealizedPnL.formatted(.currency(code: "USD")))
                LabeledContent("Realized P&L", value: viewModel.summary.realizedPnL.formatted(.currency(code: "USD")))
                LabeledContent("Cash", value: viewModel.summary.cashBalance.formatted(.currency(code: "USD")))
                LabeledContent("Position Value", value: viewModel.summary.positionsMarketValue.formatted(.currency(code: "USD")))
            }

            if viewModel.aiSummariesEnabled {
                Section("AI-style Insights") {
                    if viewModel.insightCards.isEmpty {
                        DSStatusMessage(title: "No insights yet", systemImage: "sparkles")
                    } else {
                        ForEach(viewModel.insightCards) { card in
                            DSCard(title: card.title) {
                                Text(card.body)
                                    .font(.subheadline)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section("Analytics Snapshot") {
                LabeledContent("Closed Trades", value: String(viewModel.analyticsSummary.totalClosedTrades))
                LabeledContent("Win Rate", value: percent(viewModel.analyticsSummary.winRate))
                LabeledContent("Avg Win", value: currency(viewModel.analyticsSummary.averageWin))
                LabeledContent("Avg Loss", value: currency(viewModel.analyticsSummary.averageLoss))
                LabeledContent("Net Return", value: percent(viewModel.analyticsSummary.netReturnPercent))

                NavigationLink("Open Full Analytics") {
                    AnalyticsView(viewModel: container.makeAnalyticsViewModel())
                }
            }

            Section("Open Positions") {
                if viewModel.positions.isEmpty {
                    Text("No open positions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.positions) { position in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(position.symbol)
                                    .font(.headline)
                                Spacer()
                                Text(position.unrealizedPnL.formatted(.currency(code: "USD")))
                                    .foregroundStyle(position.unrealizedPnL >= 0 ? .green : .red)
                            }
                            HStack {
                                Text("Qty: \(position.quantity.formatted())")
                                Spacer()
                                Text("Avg: \(position.averageEntryPrice.formatted(.number.precision(.fractionLength(2...5))))")
                                Spacer()
                                Text("Now: \(position.currentPrice.formatted(.number.precision(.fractionLength(2...5))))")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Button("Manage Position") {
                                managePosition = position
                            }
                            .buttonStyle(.bordered)

                            NavigationLink("View Position History") {
                                PositionHistoryView(viewModel: container.makePositionHistoryViewModel(symbol: position.symbol))
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Recent Activity") {
                if viewModel.recentActivity.isEmpty {
                    Text("No activity yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.recentActivity) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.symbol)
                                    .font(.subheadline.weight(.semibold))
                                Text(event.kind.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(event.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Portfolio")
        .toolbar {
            NavigationLink("History") {
                OrdersView(viewModel: container.makeOrdersViewModel())
            }
        }
        .sheet(item: $managePosition) { position in
            NavigationStack {
                ClosePositionView(viewModel: container.makeClosePositionViewModel(position: position))
            }
        }
    }

    private func percent(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        return "\(value.formatted(.number.precision(.fractionLength(2))))%"
    }

    private func currency(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        return value.formatted(.currency(code: "USD"))
    }
}

#Preview("Empty") {
    NavigationStack {
        PortfolioView(viewModel: PortfolioViewModel(portfolioRepository: PortfolioPreviewRepository.empty, analyticsService: PortfolioPreviewAnalyticsService.empty))
    }
    .environmentObject(AppContainer.bootstrap())
}

#Preview("With Positions") {
    NavigationStack {
        PortfolioView(viewModel: PortfolioViewModel(portfolioRepository: PortfolioPreviewRepository.withPositions, analyticsService: PortfolioPreviewAnalyticsService.populated))
    }
    .environmentObject(AppContainer.bootstrap())
}

private final class PortfolioPreviewRepository: PortfolioRepository {
    static let empty = PortfolioPreviewRepository(
        summary: PortfolioSummary(cashBalance: 50_000, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 230, totalEquity: 50_000, dayChange: 0),
        positions: [],
        activity: []
    )
    static let withPositions = PortfolioPreviewRepository(
        summary: PortfolioSummary(cashBalance: 32_000, positionsMarketValue: 21_000, unrealizedPnL: 420, realizedPnL: 860, totalEquity: 53_000, dayChange: 0),
        positions: [
            Position(id: UUID(), symbol: "BTC/USD", quantity: 0.15, averageEntryPrice: 67_000, currentPrice: 68_800, unrealizedPnL: 270, openedAt: .now.addingTimeInterval(-3_600)),
            Position(id: UUID(), symbol: "ETH/USD", quantity: 2.0, averageEntryPrice: 3_200, currentPrice: 3_275, unrealizedPnL: 150, openedAt: .now.addingTimeInterval(-7_200))
        ],
        activity: [
            ActivityEvent(id: UUID(), kind: .buy, symbol: "BTC/USD", quantity: 0.15, price: 67_000, timestamp: .now.addingTimeInterval(-2_500), orderID: UUID(), relatedPositionID: UUID(), realizedPnL: nil),
            ActivityEvent(id: UUID(), kind: .partialClose, symbol: "ETH/USD", quantity: 0.5, price: 3_290, timestamp: .now.addingTimeInterval(-1_200), orderID: UUID(), relatedPositionID: UUID(), realizedPnL: 45)
        ]
    )

    private let summary: PortfolioSummary
    private let positions: [Position]
    private let activity: [ActivityEvent]

    private init(summary: PortfolioSummary, positions: [Position], activity: [ActivityEvent]) {
        self.summary = summary
        self.positions = positions
        self.activity = activity
    }

    var positionsPublisher: AnyPublisher<[Position], Never> { Just(positions).eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { Just(summary).eraseToAnyPublisher() }
    var orderHistoryPublisher: AnyPublisher<[OrderRecord], Never> { Just([]).eraseToAnyPublisher() }
    var activityTimelinePublisher: AnyPublisher<[ActivityEvent], Never> { Just(activity).eraseToAnyPublisher() }
    var realizedPnLPublisher: AnyPublisher<[RealizedPnLEntry], Never> { Just([]).eraseToAnyPublisher() }

    var currentPositions: [Position] { positions }
    var currentSummary: PortfolioSummary { summary }
    var currentOrderHistory: [OrderRecord] { [] }
    var currentActivityTimeline: [ActivityEvent] { activity }
    var currentRealizedPnLHistory: [RealizedPnLEntry] { [] }

    func position(for symbol: String) -> Position? { positions.first(where: { $0.symbol == symbol }) }

    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> TradeExecutionResult {
        let position = Position(id: UUID(), symbol: draft.assetSymbol, quantity: draft.quantity, averageEntryPrice: executionPrice, currentPrice: executionPrice, unrealizedPnL: 0, openedAt: filledAt)
        let order = OrderRecord(id: UUID(), symbol: draft.assetSymbol, side: draft.side, type: draft.type, quantity: draft.quantity, executedPrice: executionPrice, grossValue: executionPrice * draft.quantity, submittedAt: draft.submittedAt, executedAt: filledAt, status: .filled, source: .simulated, linkedPositionID: position.id)
        let event = ActivityEvent(id: UUID(), kind: .buy, symbol: draft.assetSymbol, quantity: draft.quantity, price: executionPrice, timestamp: filledAt, orderID: order.id, relatedPositionID: position.id, realizedPnL: nil)
        return TradeExecutionResult(resultingPosition: position, orderRecord: order, activityEvent: event, realizedPnLEntry: nil)
    }
}

private final class PortfolioPreviewAnalyticsService: PortfolioAnalyticsService {
    static let populated = PortfolioPreviewAnalyticsService(summary: PortfolioAnalyticsSummary(totalRealizedPnL: 860, totalUnrealizedPnL: 420, averageWin: 180, averageLoss: -90, profitFactor: 2.0, winRate: 0.66, totalClosedTrades: 12, bestTrade: 420, worstTrade: -210, currentEquity: 53_000, startingBalance: 50_000, netReturnPercent: 6))
    static let empty = PortfolioPreviewAnalyticsService(summary: .empty)
    private let summaryValue: PortfolioAnalyticsSummary
    private let filterSubject = CurrentValueSubject<HistoryFilter, Never>(.default)
    init(summary: PortfolioAnalyticsSummary) { summaryValue = summary }
    var summaryPublisher: AnyPublisher<PortfolioAnalyticsSummary, Never> { Just(summaryValue).eraseToAnyPublisher() }
    var performancePublisher: AnyPublisher<[PerformancePoint], Never> { Just([]).eraseToAnyPublisher() }
    var dailyPerformancePublisher: AnyPublisher<[DailyPerformanceBucket], Never> { Just([]).eraseToAnyPublisher() }
    var realizedDistributionPublisher: AnyPublisher<[RealizedDistributionBucket], Never> { Just([]).eraseToAnyPublisher() }
    var filteredOrdersPublisher: AnyPublisher<[OrderRecord], Never> { Just([]).eraseToAnyPublisher() }
    var filteredActivityPublisher: AnyPublisher<[ActivityEvent], Never> { Just([]).eraseToAnyPublisher() }
    var availableSymbolsPublisher: AnyPublisher<[String], Never> { Just(["BTC/USD"]).eraseToAnyPublisher() }
    var currentSummary: PortfolioAnalyticsSummary { summaryValue }
    var currentPerformance: [PerformancePoint] { [] }
    var currentDailyPerformance: [DailyPerformanceBucket] { [] }
    var currentRealizedDistribution: [RealizedDistributionBucket] { [] }
    var currentFilter: HistoryFilter { filterSubject.value }
    func updateFilter(_ filter: HistoryFilter) { filterSubject.send(filter) }
    func positionHistory(symbol: String) -> PositionHistorySummary { .empty(symbol: symbol) }
}
