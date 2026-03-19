import SwiftUI

struct PortfolioView: View {
    @StateObject var viewModel: PortfolioViewModel

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Cash", value: viewModel.summary.cashBalance.formatted(.currency(code: "USD")))
                LabeledContent("Equity", value: viewModel.summary.totalEquity.formatted(.currency(code: "USD")))
                LabeledContent("Unrealized P&L", value: viewModel.summary.unrealizedPnL.formatted(.currency(code: "USD")))
            }

            Section("Positions") {
                if viewModel.positions.isEmpty {
                    Text("No open positions yet")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Portfolio")
    }
}
