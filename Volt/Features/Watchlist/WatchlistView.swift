import SwiftUI

struct WatchlistView: View {
    @StateObject var viewModel: WatchlistViewModel
    let detailViewFactory: (String) -> AssetDetailView

    var body: some View {
        Group {
            if case .seeding = viewModel.seedingState, viewModel.rows.isEmpty {
                ProgressView("Seeding live prices…")
            } else {
                List(viewModel.rows) { row in
                    NavigationLink(value: row.symbol) {
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
            }
        }
        .navigationTitle("Watchlist")
        .navigationDestination(for: String.self) { symbol in
            detailViewFactory(symbol)
        }
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
}
