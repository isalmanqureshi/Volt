import SwiftUI

struct WatchlistView: View {
    @StateObject var viewModel: WatchlistViewModel

    var body: some View {
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
                        if row.isSimulated {
                            Label("Sim", systemImage: "waveform.path")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("Watchlist")
        .navigationDestination(for: String.self) { symbol in
            AssetDetailView(symbol: symbol)
        }
        .safeAreaInset(edge: .bottom) {
            Text("State: \(String(describing: viewModel.connectionState))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
    }
}
