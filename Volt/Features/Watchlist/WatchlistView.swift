import SwiftUI

struct WatchlistView: View {
    @StateObject var viewModel: WatchlistViewModel

    var body: some View {
        Group {
            if case .seeding = viewModel.seedingState, viewModel.rows.isEmpty {
                ProgressView("Seeding live prices…")
            } else {
                List(viewModel.rows) { row in
                    if let route = viewModel.route(for: row) {
                        NavigationLink(value: route) {
                            rowContent(row)
                        }
                    } else {
                        rowContent(row)
                    }
                }
            }
        }
        .navigationTitle("Watchlist")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Text("State: \(String(describing: viewModel.connectionState))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if case .fallbackMocked(let message) = viewModel.seedingState {
                    Text("Fallback active: \(message)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }.padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func rowContent(_ row: WatchlistViewModel.RowState) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(row.symbol)
                    .font(.headline)
                Spacer()
                Text(row.priceText)
                    .font(.title3.monospacedDigit())
            }
            HStack {
                Text(row.name)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(row.changeText)
                    .foregroundStyle(row.changeText.hasPrefix("-") ? .red : .green)
                    .font(.caption)
                if row.isSimulated {
                    Label("Sim", systemImage: "waveform.path")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
