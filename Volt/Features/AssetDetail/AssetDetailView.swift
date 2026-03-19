import Charts
import SwiftUI

struct AssetDetailView: View {
    @StateObject var viewModel: AssetDetailViewModel

    var body: some View {
        List {
            Section("Asset") {
                Text(viewModel.symbol)
                if let latestQuote = viewModel.latestQuote {
                    Text("Last: \(latestQuote.lastPrice.formatted(.number.precision(.fractionLength(2...6))))")
                }
            }

            Section("Recent 1m candles") {
                if viewModel.isLoadingCandles {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                } else {
                    Chart(viewModel.candles, id: \.timestamp) { candle in
                        LineMark(
                            x: .value("Time", candle.timestamp),
                            y: .value("Price", decimalToDouble(candle.close))
                        )
                    }
                    .frame(height: 200)
                }
            }
        }
        .navigationTitle("Asset Detail")
        .task {
            await viewModel.loadCandlesIfNeeded()
        }
    }

    private func decimalToDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
