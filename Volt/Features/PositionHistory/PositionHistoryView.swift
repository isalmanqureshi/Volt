import Combine
import SwiftUI

struct PositionHistoryView: View {
    @StateObject var viewModel: PositionHistoryViewModel

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Symbol", value: viewModel.summary.symbol)
                LabeledContent("Total Bought", value: viewModel.summary.totalBoughtQuantity.formatted())
                LabeledContent("Total Sold", value: viewModel.summary.totalSoldQuantity.formatted())
                LabeledContent("Average Entry", value: currency(viewModel.summary.averageEntryPrice))
                LabeledContent("Average Exit", value: currency(viewModel.summary.averageExitPrice))
                LabeledContent("Realized P&L", value: viewModel.summary.realizedPnL.formatted(.currency(code: "USD")))
            }

            Section("Activity") {
                if viewModel.summary.activities.isEmpty {
                    Text("No activity for this symbol")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.summary.activities) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.kind.rawValue.capitalized)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(event.timestamp, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Qty \(event.quantity.formatted())")
                                Spacer()
                                Text(event.price.formatted(.currency(code: "USD")))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.summary.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
    }

    private func currency(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        return value.formatted(.currency(code: "USD"))
    }
}

#Preview("Position History") {
    NavigationStack {
        PositionHistoryView(viewModel: PositionHistoryViewModel(symbol: "BTC/USD", analyticsService: PositionHistoryPreviewAnalyticsService()))
    }
}

private struct PositionHistoryPreviewAnalyticsService: PortfolioAnalyticsService {
    var summaryPublisher: AnyPublisher<PortfolioAnalyticsSummary, Never> { Just(.empty).eraseToAnyPublisher() }
    var performancePublisher: AnyPublisher<[PerformancePoint], Never> { Just([]).eraseToAnyPublisher() }
    var filteredOrdersPublisher: AnyPublisher<[OrderRecord], Never> { Just([]).eraseToAnyPublisher() }
    var filteredActivityPublisher: AnyPublisher<[ActivityEvent], Never> { Just([]).eraseToAnyPublisher() }
    var availableSymbolsPublisher: AnyPublisher<[String], Never> { Just(["BTC/USD"]).eraseToAnyPublisher() }
    var currentSummary: PortfolioAnalyticsSummary { .empty }
    var currentPerformance: [PerformancePoint] { [] }
    var currentFilter: HistoryFilter { .default }
    func updateFilter(_ filter: HistoryFilter) {}
    func positionHistory(symbol: String) -> PositionHistorySummary {
        PositionHistorySummary(
            symbol: symbol,
            totalBoughtQuantity: 1.5,
            totalSoldQuantity: 0.5,
            averageEntryPrice: 64_000,
            averageExitPrice: 67_500,
            realizedPnL: 1_750,
            orders: [],
            activities: [
                ActivityEvent(id: UUID(), kind: .buy, symbol: symbol, quantity: 1, price: 64_000, timestamp: .now.addingTimeInterval(-9_000), orderID: UUID(), relatedPositionID: UUID(), realizedPnL: nil),
                ActivityEvent(id: UUID(), kind: .partialClose, symbol: symbol, quantity: 0.5, price: 67_500, timestamp: .now.addingTimeInterval(-3_000), orderID: UUID(), relatedPositionID: UUID(), realizedPnL: 1_750)
            ]
        )
    }
}
