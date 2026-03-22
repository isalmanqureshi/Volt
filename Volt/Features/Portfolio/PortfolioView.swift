import Combine
import Foundation
import SwiftUI

struct PortfolioView: View {
    @StateObject var viewModel: PortfolioViewModel

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Total Equity", value: viewModel.summary.totalEquity.formatted(.currency(code: "USD")))
                LabeledContent("Unrealized P&L", value: viewModel.summary.unrealizedPnL.formatted(.currency(code: "USD")))
                LabeledContent("Cash", value: viewModel.summary.cashBalance.formatted(.currency(code: "USD")))
                LabeledContent("Position Value", value: viewModel.summary.positionsMarketValue.formatted(.currency(code: "USD")))
            }

            Section("Open Positions") {
                if viewModel.positions.isEmpty {
                    Text("No open positions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.positions) { position in
                        VStack(alignment: .leading, spacing: 6) {
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
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Portfolio")
    }
}

#Preview("Empty") {
    NavigationStack {
        PortfolioView(viewModel: PortfolioViewModel(portfolioRepository: PortfolioPreviewRepository.empty))
    }
}

#Preview("With Positions") {
    NavigationStack {
        PortfolioView(viewModel: PortfolioViewModel(portfolioRepository: PortfolioPreviewRepository.withPositions))
    }
}

private final class PortfolioPreviewRepository: PortfolioRepository {
    static let empty = PortfolioPreviewRepository(
        summary: PortfolioSummary(cashBalance: 50_000, positionsMarketValue: 0, unrealizedPnL: 0, totalEquity: 50_000, dayChange: 0),
        positions: []
    )
    static let withPositions = PortfolioPreviewRepository(
        summary: PortfolioSummary(cashBalance: 32_000, positionsMarketValue: 21_000, unrealizedPnL: 420, totalEquity: 53_000, dayChange: 0),
        positions: [
            Position(id: UUID(), symbol: "BTC/USD", quantity: 0.15, averageEntryPrice: 67_000, currentPrice: 68_800, unrealizedPnL: 270, openedAt: .now.addingTimeInterval(-3_600)),
            Position(id: UUID(), symbol: "ETH/USD", quantity: 2.0, averageEntryPrice: 3_200, currentPrice: 3_275, unrealizedPnL: 150, openedAt: .now.addingTimeInterval(-7_200))
        ]
    )

    private let summary: PortfolioSummary
    private let positions: [Position]

    private init(summary: PortfolioSummary, positions: [Position]) {
        self.summary = summary
        self.positions = positions
    }

    var positionsPublisher: AnyPublisher<[Position], Never> { Just(positions).eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { Just(summary).eraseToAnyPublisher() }
    var currentPositions: [Position] { positions }
    var currentSummary: PortfolioSummary { summary }

    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> Position {
        Position(id: UUID(), symbol: draft.assetSymbol, quantity: draft.quantity, averageEntryPrice: executionPrice, currentPrice: executionPrice, unrealizedPnL: 0, openedAt: filledAt)
    }
}
