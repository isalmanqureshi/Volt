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
