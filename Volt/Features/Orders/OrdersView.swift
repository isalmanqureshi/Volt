import Combine
import Foundation
import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject var viewModel: OrdersViewModel
    @State private var showShareSheet = false

    var body: some View {
        List {
            Section {
                Picker("Type", selection: $viewModel.selectedSegment) {
                    ForEach(OrdersViewModel.Segment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Filters") {
                Picker("Range", selection: $viewModel.selectedRange) {
                    ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.availableSymbols.isEmpty == false {
                    Picker("Symbol", selection: Binding(get: {
                        viewModel.selectedSymbol ?? "All"
                    }, set: { newValue in
                        viewModel.selectedSymbol = newValue == "All" ? nil : newValue
                    })) {
                        Text("All").tag("All")
                        ForEach(viewModel.availableSymbols, id: \.self) { symbol in
                            Text(symbol).tag(symbol)
                        }
                    }
                }

                if viewModel.selectedSegment == .activity {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(ActivityEvent.Kind.allCases, id: \.self) { kind in
                                let selected = viewModel.selectedEventKinds.contains(kind)
                                Button(kind.rawValue.capitalized) {
                                    viewModel.toggleEventKind(kind)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(selected ? .blue : .gray.opacity(0.5))
                            }
                        }
                    }
                }
            }


            if viewModel.insightCards.isEmpty == false {
                Section("Insights") {
                    ForEach(viewModel.insightCards) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title).font(.subheadline.weight(.semibold))
                            Text(card.body).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Export") {
                Picker("Preset", selection: $viewModel.selectedExportPreset) {
                    ForEach(AnalyticsExportPreset.allCases, id: \.self) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
            }

            switch viewModel.selectedSegment {
            case .orders:
                if viewModel.orders.isEmpty {
                    ContentUnavailableView("No Orders", systemImage: "list.bullet.rectangle")
                } else {
                    ForEach(viewModel.orders) { order in
                        NavigationLink {
                            PositionHistoryView(viewModel: container.makePositionHistoryViewModel(symbol: order.symbol))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(order.symbol)
                                        .font(.headline)
                                    Spacer()
                                    Text(order.side.rawValue.uppercased())
                                        .font(.caption.weight(.semibold))
                                }
                                HStack {
                                    Text("Qty \(order.quantity.formatted())")
                                    Spacer()
                                    Text(order.executedPrice.formatted(.currency(code: "USD")))
                                    Spacer()
                                    Text(order.executedAt, style: .date)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            case .activity:
                if viewModel.activity.isEmpty {
                    ContentUnavailableView("No Activity", systemImage: "clock.arrow.circlepath")
                } else {
                    ForEach(viewModel.activity) { event in
                        NavigationLink {
                            PositionHistoryView(viewModel: container.makePositionHistoryViewModel(symbol: event.symbol))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(event.symbol)
                                        .font(.headline)
                                    Spacer()
                                    Text(event.kind.rawValue.capitalized)
                                        .font(.caption.weight(.semibold))
                                }
                                HStack {
                                    Text("Qty \(event.quantity.formatted())")
                                    Spacer()
                                    Text(event.price.formatted(.currency(code: "USD")))
                                    Spacer()
                                    Text(event.timestamp, style: .date)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                if let realized = event.realizedPnL {
                                    Text("Realized P&L: \(realized.formatted(.currency(code: "USD")))")
                                        .font(.caption)
                                        .foregroundStyle(realized >= 0 ? .green : .red)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Export CSV") {
                    viewModel.exportCSV()
                    if viewModel.exportURL != nil {
                        showShareSheet = true
                    }
                }
            }
        }
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
    static let populated = OrdersPreviewAnalyticsService(
        orders: [
            OrderRecord(id: UUID(), symbol: "BTC/USD", side: .buy, type: .market, quantity: 0.25, executedPrice: 67_000, grossValue: 16_750, submittedAt: .now.addingTimeInterval(-4_000), executedAt: .now.addingTimeInterval(-4_000), status: .filled, source: .simulated, linkedPositionID: UUID()),
            OrderRecord(id: UUID(), symbol: "BTC/USD", side: .sell, type: .market, quantity: 0.1, executedPrice: 69_500, grossValue: 6_950, submittedAt: .now.addingTimeInterval(-2_000), executedAt: .now.addingTimeInterval(-2_000), status: .filled, source: .simulated, linkedPositionID: UUID())
        ],
        activity: [
            ActivityEvent(id: UUID(), kind: .buy, symbol: "BTC/USD", quantity: 0.25, price: 67_000, timestamp: .now.addingTimeInterval(-4_000), orderID: UUID(), relatedPositionID: UUID(), realizedPnL: nil),
            ActivityEvent(id: UUID(), kind: .partialClose, symbol: "BTC/USD", quantity: 0.1, price: 69_500, timestamp: .now.addingTimeInterval(-2_000), orderID: UUID(), relatedPositionID: UUID(), realizedPnL: 250)
        ]
    )
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
