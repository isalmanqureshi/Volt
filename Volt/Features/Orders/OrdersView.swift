import Combine
import Foundation
import SwiftUI

struct OrdersView: View {
    private enum SideFilter: String, CaseIterable {
        case all = "All"
        case buys = "Buys"
        case sells = "Sells"
    }

    @EnvironmentObject private var container: AppContainer
    @StateObject var viewModel: OrdersViewModel
    @State private var showShareSheet = false
    @State private var sideFilter: SideFilter = .all

    private var visibleOrders: [OrderRecord] {
        switch sideFilter {
        case .all: return viewModel.orders
        case .buys: return viewModel.orders.filter { $0.side == .buy }
        case .sells: return viewModel.orders.filter { $0.side == .sell }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader("History")

            filterRow
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.sm)

            ordersList

            exportFooter
        }
        .voltScreen()
        .navigationTitle("")
        .toolbarBackground(Color.voltBackground, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            if let exportURL = viewModel.exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        .alert("Export Error", isPresented: Binding(get: {
            viewModel.exportError != nil
        }, set: { _ in
            viewModel.exportError = nil
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.exportError ?? "")
        }
    }

    // MARK: Filters

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(SideFilter.allCases, id: \.self) { filter in
                    FilterPill(title: filter.rawValue, isSelected: sideFilter == filter) {
                        sideFilter = filter
                    }
                }

                if viewModel.availableSymbols.isEmpty == false {
                    Menu {
                        Button("All coins") { viewModel.selectedSymbol = nil }
                        ForEach(viewModel.availableSymbols, id: \.self) { symbol in
                            Button(symbol) { viewModel.selectedSymbol = symbol }
                        }
                    } label: {
                        menuPillLabel(
                            title: viewModel.selectedSymbol.map(baseCurrency(of:)) ?? "Coin",
                            isActive: viewModel.selectedSymbol != nil
                        )
                    }
                    .buttonStyle(.plain)
                }

                Menu {
                    ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                        Button(range.title) { viewModel.selectedRange = range }
                    }
                } label: {
                    menuPillLabel(
                        title: viewModel.selectedRange.title,
                        isActive: viewModel.selectedRange != .all
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func menuPillLabel(title: String, isActive: Bool) -> some View {
        HStack(spacing: Spacing.xs + 2) {
            Text(title)
                .font(Typography.bodySecondary)
            Image(systemName: "chevron.down")
                .font(Typography.caption)
                .foregroundStyle(Color.voltTextTertiary)
        }
        .foregroundStyle(isActive ? Color.voltAccent : Color.white.opacity(0.55))
        .padding(.horizontal, Spacing.md + 2)
        .padding(.vertical, Spacing.xs + 2)
        .frame(minHeight: 32)
        .background(
            isActive ? Color.voltAccent.opacity(0.14) : Color.voltSurface,
            in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .strokeBorder(isActive ? Color.voltAccent : Color.voltHairline, lineWidth: 1)
        )
    }

    // MARK: List

    @ViewBuilder
    private var ordersList: some View {
        if visibleOrders.isEmpty {
            VStack(spacing: Spacing.sm) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Color.voltTextTertiary)
                Text("No trades yet")
                    .font(Typography.emphasis.weight(.semibold))
                    .foregroundStyle(Color.voltTextPrimary)
                Text("Fills will appear here after your first order.")
                    .font(Typography.bodySecondary)
                    .foregroundStyle(Color.voltTextSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleOrders) { order in
                        NavigationLink {
                            PositionHistoryView(viewModel: container.makePositionHistoryViewModel(symbol: order.symbol))
                        } label: {
                            tradeRow(order)
                        }
                        .buttonStyle(.plain)
                        RowDivider()
                    }
                }
            }
        }
    }

    private func tradeRow(_ order: OrderRecord) -> some View {
        let realized = realizedPnL(for: order)
        return VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                SidePill(side: order.side)
                Text(displayName(of: order.symbol))
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Color.voltTextPrimary)
                Text(baseCurrency(of: order.symbol))
                    .font(Typography.monoSecondary)
                    .foregroundStyle(Color.voltTextSecondary)
                Spacer()
                if let realized {
                    Text(realized.voltSignedCurrencyString())
                        .font(Typography.monoBody)
                        .foregroundStyle(realized >= 0 ? Color.voltAccent : Color.voltDanger)
                } else {
                    Text("$" + order.grossValue.voltPriceString(precision: 2))
                        .font(Typography.monoBody)
                        .foregroundStyle(Color.voltTextPrimary)
                }
            }
            HStack {
                Text(timestampText(order.executedAt))
                    .font(Typography.monoCaption)
                    .foregroundStyle(Color.voltTextTertiary)
                Spacer()
                Text("\(order.quantity.voltPriceString(precision: 8)) @ $\(order.executedPrice.voltPriceString(precision: 2))")
                    .font(Typography.monoSecondary)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }

    /// Realized P&L reported by the matching activity event (sell fills), presentation-only join.
    private func realizedPnL(for order: OrderRecord) -> Decimal? {
        viewModel.activity.first(where: { $0.orderID == order.id })?.realizedPnL
    }

    private func timestampText(_ date: Date) -> String {
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        let time = date.formatted(date: .omitted, time: .shortened)
        return "\(day) · \(time)"
    }

    private func baseCurrency(of symbol: String) -> String {
        String(symbol.split(separator: "/").first ?? "")
    }

    private func displayName(of symbol: String) -> String {
        container.configuration.enabledAssets.first(where: { $0.symbol == symbol })?.displayName
            ?? baseCurrency(of: symbol)
    }

    // MARK: Export

    private var exportFooter: some View {
        VStack(spacing: 0) {
            RowDivider()
            HStack {
                Menu {
                    ForEach(AnalyticsExportPreset.allCases, id: \.self) { preset in
                        Button(preset.title) { viewModel.selectedExportPreset = preset }
                    }
                } label: {
                    Text(viewModel.selectedExportPreset.title)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.voltTextTertiary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    viewModel.exportCSV()
                    if viewModel.exportURL != nil {
                        showShareSheet = true
                    }
                } label: {
                    HStack(spacing: Spacing.xs + 2) {
                        Image(systemName: "arrow.down.to.line")
                            .font(Typography.secondary)
                        Text("Export CSV")
                            .font(Typography.bodySecondary)
                    }
                    .foregroundStyle(Color.white.opacity(0.75))
                    .padding(.horizontal, Spacing.md + 2)
                    .padding(.vertical, Spacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.sm + 2)
        }
    }
}

#Preview("Populated") {
    NavigationStack {
        OrdersView(viewModel: OrdersViewModel(analyticsService: OrdersPreviewAnalyticsService.populated, csvExportService: DefaultCSVExportService()))
    }
    .environmentObject(AppContainer.bootstrap())
}

#Preview("Empty") {
    NavigationStack {
        OrdersView(viewModel: OrdersViewModel(analyticsService: OrdersPreviewAnalyticsService.empty, csvExportService: DefaultCSVExportService()))
    }
    .environmentObject(AppContainer.bootstrap())
}

private final class OrdersPreviewAnalyticsService: PortfolioAnalyticsService {
    static let populated: OrdersPreviewAnalyticsService = {
        let buyOrderID = UUID()
        let sellOrderID = UUID()
        return OrdersPreviewAnalyticsService(
            orders: [
                OrderRecord(id: sellOrderID, symbol: "BTC/USD", side: .sell, type: .market, quantity: 0.1, executedPrice: 63_842, grossValue: 6_384, submittedAt: .now.addingTimeInterval(-2_000), executedAt: .now.addingTimeInterval(-2_000), status: .filled, source: .simulated, linkedPositionID: UUID()),
                OrderRecord(id: buyOrderID, symbol: "BTC/USD", side: .buy, type: .market, quantity: 0.25, executedPrice: 59_120, grossValue: 14_780, submittedAt: .now.addingTimeInterval(-4_000), executedAt: .now.addingTimeInterval(-4_000), status: .filled, source: .simulated, linkedPositionID: UUID())
            ],
            activity: [
                ActivityEvent(id: UUID(), kind: .partialClose, symbol: "BTC/USD", quantity: 0.1, price: 63_842, timestamp: .now.addingTimeInterval(-2_000), orderID: sellOrderID, relatedPositionID: UUID(), realizedPnL: 412.80),
                ActivityEvent(id: UUID(), kind: .buy, symbol: "BTC/USD", quantity: 0.25, price: 59_120, timestamp: .now.addingTimeInterval(-4_000), orderID: buyOrderID, relatedPositionID: UUID(), realizedPnL: nil)
            ]
        )
    }()
    static let empty = OrdersPreviewAnalyticsService(orders: [], activity: [])

    private let orders: [OrderRecord]
    private let activity: [ActivityEvent]
    private let filterSubject = CurrentValueSubject<HistoryFilter, Never>(.default)

    init(orders: [OrderRecord], activity: [ActivityEvent]) {
        self.orders = orders
        self.activity = activity
    }

    var summaryPublisher: AnyPublisher<PortfolioAnalyticsSummary, Never> { Just(.empty).eraseToAnyPublisher() }
    var performancePublisher: AnyPublisher<[PerformancePoint], Never> { Just([]).eraseToAnyPublisher() }
    var dailyPerformancePublisher: AnyPublisher<[DailyPerformanceBucket], Never> { Just([]).eraseToAnyPublisher() }
    var realizedDistributionPublisher: AnyPublisher<[RealizedDistributionBucket], Never> { Just([]).eraseToAnyPublisher() }
    var filteredOrdersPublisher: AnyPublisher<[OrderRecord], Never> { Just(orders).eraseToAnyPublisher() }
    var filteredActivityPublisher: AnyPublisher<[ActivityEvent], Never> { Just(activity).eraseToAnyPublisher() }
    var availableSymbolsPublisher: AnyPublisher<[String], Never> { Just(["BTC/USD"]).eraseToAnyPublisher() }
    var currentSummary: PortfolioAnalyticsSummary { .empty }
    var currentPerformance: [PerformancePoint] { [] }
    var currentDailyPerformance: [DailyPerformanceBucket] { [] }
    var currentRealizedDistribution: [RealizedDistributionBucket] { [] }
    var currentFilter: HistoryFilter { filterSubject.value }
    func updateFilter(_ filter: HistoryFilter) { filterSubject.send(filter) }
    func positionHistory(symbol: String) -> PositionHistorySummary { .empty(symbol: symbol) }
}
