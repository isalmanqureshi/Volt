import Combine
import Foundation
import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject var viewModel: PortfolioViewModel
    @State private var managePosition: Position?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader("Portfolio") {
                NavigationLink {
                    OrdersView(viewModel: container.makeOrdersViewModel())
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.voltTextSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Trade history")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    totalValue
                        .padding(.horizontal, Spacing.gutter)
                        .padding(.bottom, Spacing.lg)

                    SectionLabel("Open positions")
                        .padding(.horizontal, Spacing.gutter)
                        .padding(.bottom, Spacing.xs)

                    positionsList

                    if viewModel.positions.isEmpty == false {
                        allocation
                            .padding(Spacing.gutter)
                    }

                    if viewModel.aiSummariesEnabled, viewModel.insightCards.isEmpty == false {
                        insights
                            .padding(.horizontal, Spacing.gutter)
                            .padding(.bottom, Spacing.gutter)
                    }
                }
            }
        }
        .voltScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $managePosition) { position in
            NavigationStack {
                ClosePositionView(viewModel: container.makeClosePositionViewModel(position: position))
            }
        }
    }

    // MARK: Hero

    private var totalValue: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Total Value")
                .font(Typography.secondary)
                .foregroundStyle(Color.voltTextSecondary)
            Text("$" + viewModel.summary.totalEquity.voltPriceString(precision: 2))
                .font(Typography.heroValue)
                .foregroundStyle(Color.voltTextPrimary)
                .contentTransition(.numericText())
            HStack(spacing: Spacing.sm) {
                Text(unrealizedText)
                    .font(Typography.monoBodySecondary)
                    .foregroundStyle(viewModel.summary.unrealizedPnL >= 0 ? Color.voltAccent : Color.voltDanger)
                Text("Unrealised P&L")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.voltTextTertiary)
            }
        }
    }

    private var unrealizedText: String {
        let pnl = viewModel.summary.unrealizedPnL
        var text = pnl.voltSignedCurrencyString()
        let basis = viewModel.summary.totalEquity - pnl
        if basis > 0 {
            let percent = (pnl / basis) * 100
            let sign = percent >= 0 ? "+" : ""
            text += "  \(sign)\(percent.voltPriceString(precision: 2))%"
        }
        return text
    }

    // MARK: Positions

    @ViewBuilder
    private var positionsList: some View {
        if viewModel.positions.isEmpty {
            Text("No open positions yet")
                .font(Typography.bodySecondary)
                .foregroundStyle(Color.voltTextSecondary)
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.lg)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.positions) { position in
                    Button {
                        managePosition = position
                    } label: {
                        positionRow(position)
                    }
                    .buttonStyle(.plain)
                    RowDivider()
                }
            }
        }
    }

    private func positionRow(_ position: Position) -> some View {
        let base = baseCurrency(of: position.symbol)
        return HStack(spacing: Spacing.md) {
            CoinBadge(baseCurrency: base)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(of: position.symbol))
                    .font(Typography.emphasis.weight(.semibold))
                    .foregroundStyle(Color.voltTextPrimary)
                Text(base)
                    .font(Typography.monoSecondary)
                    .foregroundStyle(Color.voltTextSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(position.quantity.voltPriceString(precision: 8)) \(base)")
                    .font(Typography.monoBody.weight(.semibold))
                    .foregroundStyle(Color.voltTextPrimary)
                Text("avg $" + position.averageEntryPrice.voltPriceString(precision: 2))
                    .font(Typography.monoSecondary)
                    .foregroundStyle(Color.voltTextSecondary)
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName(of: position.symbol)) position, \(position.quantity.voltPriceString(precision: 8)) \(base)")
    }

    // MARK: Allocation

    private struct AllocationSlice: Identifiable {
        let id: String
        let base: String
        let fraction: Double
    }

    private var allocationSlices: [AllocationSlice] {
        let values = viewModel.positions.map { position in
            (position, (position.quantity * position.currentPrice).chartValue)
        }
        let total = values.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return [] }
        return values.map { position, value in
            AllocationSlice(
                id: position.id.uuidString,
                base: baseCurrency(of: position.symbol),
                fraction: value / total
            )
        }
    }

    @ViewBuilder
    private var allocation: some View {
        let slices = allocationSlices
        if slices.isEmpty == false {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionLabel("Allocation")
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(slices) { slice in
                            Rectangle()
                                .fill(Color.brand(forBaseCurrency: slice.base))
                                .frame(width: max(2, (geo.size.width - CGFloat(slices.count - 1) * 2) * slice.fraction))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
                }
                .frame(height: 12)

                HStack(spacing: Spacing.lg) {
                    ForEach(slices) { slice in
                        HStack(spacing: Spacing.xs + 2) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color.brand(forBaseCurrency: slice.base))
                                .frame(width: 8, height: 8)
                            Text(slice.base)
                                .font(Typography.secondary)
                                .foregroundStyle(Color.white.opacity(0.6))
                            Text("\(Int((slice.fraction * 100).rounded()))%")
                                .font(Typography.monoSecondary)
                                .foregroundStyle(Color.voltTextPrimary)
                        }
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
    }

    // MARK: Insights

    private var insights: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel("Insights")
            ForEach(viewModel.insightCards) { card in
                SectionCard {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(card.title)
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(Color.voltTextPrimary)
                        Text(card.body)
                            .font(Typography.secondary)
                            .foregroundStyle(Color.voltTextSecondary)
                    }
                }
            }
        }
    }

    // MARK: Symbol helpers

    private func baseCurrency(of symbol: String) -> String {
        String(symbol.split(separator: "/").first ?? "")
    }

    private func displayName(of symbol: String) -> String {
        container.configuration.enabledAssets.first(where: { $0.symbol == symbol })?.displayName
            ?? baseCurrency(of: symbol)
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
        summary: PortfolioSummary(cashBalance: 7_400, positionsMarketValue: 21_017, unrealizedPnL: 1_204.30, realizedPnL: 860, totalEquity: 28_417.62, dayChange: 0),
        positions: [
            Position(id: UUID(), symbol: "BTC/USD", quantity: 0.2048, averageEntryPrice: 59_120, currentPrice: 63_842, unrealizedPnL: 967, openedAt: .now.addingTimeInterval(-3_600)),
            Position(id: UUID(), symbol: "ETH/USD", quantity: 2.41, averageEntryPrice: 3_180, currentPrice: 3_318, unrealizedPnL: 333, openedAt: .now.addingTimeInterval(-7_200)),
            Position(id: UUID(), symbol: "SOL/USD", quantity: 18.5, averageEntryPrice: 152, currentPrice: 146.29, unrealizedPnL: -105, openedAt: .now.addingTimeInterval(-9_600))
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
