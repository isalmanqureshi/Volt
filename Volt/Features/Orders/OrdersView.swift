import Combine
import Foundation
import SwiftUI

struct OrdersView: View {
    @StateObject var viewModel: OrdersViewModel

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

            switch viewModel.selectedSegment {
            case .orders:
                if viewModel.orders.isEmpty {
                    ContentUnavailableView("No Orders", systemImage: "list.bullet.rectangle")
                } else {
                    ForEach(viewModel.orders) { order in
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
                                Text(order.executedAt, style: .time)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            case .activity:
                if viewModel.activity.isEmpty {
                    ContentUnavailableView("No Activity", systemImage: "clock.arrow.circlepath")
                } else {
                    ForEach(viewModel.activity) { event in
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
                                Text(event.timestamp, style: .time)
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
        .navigationTitle("History")
    }
}

#Preview("Populated") {
    NavigationStack {
        OrdersView(viewModel: OrdersViewModel(portfolioRepository: OrdersPreviewRepository.populated))
    }
}

#Preview("Empty") {
    NavigationStack {
        OrdersView(viewModel: OrdersViewModel(portfolioRepository: OrdersPreviewRepository.empty))
    }
}

private final class OrdersPreviewRepository: PortfolioRepository {
    static let populated = OrdersPreviewRepository(
        orders: [
            OrderRecord(id: UUID(), symbol: "BTC/USD", side: .buy, type: .market, quantity: 0.25, executedPrice: 67_000, grossValue: 16_750, submittedAt: .now.addingTimeInterval(-4_000), executedAt: .now.addingTimeInterval(-4_000), status: .filled, source: .simulated, linkedPositionID: UUID()),
            OrderRecord(id: UUID(), symbol: "BTC/USD", side: .sell, type: .market, quantity: 0.1, executedPrice: 69_500, grossValue: 6_950, submittedAt: .now.addingTimeInterval(-2_000), executedAt: .now.addingTimeInterval(-2_000), status: .filled, source: .simulated, linkedPositionID: UUID())
        ],
        activity: [
            ActivityEvent(id: UUID(), kind: .buy, symbol: "BTC/USD", quantity: 0.25, price: 67_000, timestamp: .now.addingTimeInterval(-4_000), orderID: UUID(), relatedPositionID: UUID(), realizedPnL: nil),
            ActivityEvent(id: UUID(), kind: .partialClose, symbol: "BTC/USD", quantity: 0.1, price: 69_500, timestamp: .now.addingTimeInterval(-2_000), orderID: UUID(), relatedPositionID: UUID(), realizedPnL: 250)
        ]
    )
    static let empty = OrdersPreviewRepository(orders: [], activity: [])

    private let orders: [OrderRecord]
    private let activity: [ActivityEvent]

    init(orders: [OrderRecord], activity: [ActivityEvent]) {
        self.orders = orders
        self.activity = activity
    }

    var positionsPublisher: AnyPublisher<[Position], Never> { Just([]).eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { Just(.init(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 0, dayChange: 0)).eraseToAnyPublisher() }
    var orderHistoryPublisher: AnyPublisher<[OrderRecord], Never> { Just(orders).eraseToAnyPublisher() }
    var activityTimelinePublisher: AnyPublisher<[ActivityEvent], Never> { Just(activity).eraseToAnyPublisher() }
    var realizedPnLPublisher: AnyPublisher<[RealizedPnLEntry], Never> { Just([]).eraseToAnyPublisher() }
    var currentPositions: [Position] { [] }
    var currentSummary: PortfolioSummary { .init(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 0, dayChange: 0) }
    var currentOrderHistory: [OrderRecord] { orders }
    var currentActivityTimeline: [ActivityEvent] { activity }
    var currentRealizedPnLHistory: [RealizedPnLEntry] { [] }
    func position(for symbol: String) -> Position? { nil }
    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> TradeExecutionResult { throw TradingSimulationError.repositoryUnavailable }
}
