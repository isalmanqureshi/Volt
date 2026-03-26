import SwiftUI

struct WatchlistView: View {
    @StateObject var viewModel: WatchlistViewModel

    var body: some View {
        Group {
            if case .seeding = viewModel.seedingState, viewModel.rows.isEmpty {
                ContentUnavailableView("Loading Market Data", systemImage: "arrow.triangle.2.circlepath")
            } else if viewModel.rows.isEmpty {
                ContentUnavailableView("No Watchlist Quotes", systemImage: "chart.line.downtrend.xyaxis", description: Text("Pull to refresh seeded prices."))
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
                .refreshable {
                    viewModel.refresh()
                }
            }
        }
        .navigationTitle("Watchlist")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.refresh()
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Refresh quotes")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Text(viewModel.dataMode.bannerText)
                    .font(.caption)
                    .foregroundStyle(viewModel.dataMode == .liveSeeded ? AnyShapeStyle(.orange.tertiary) : AnyShapeStyle(.secondary))
                    .accessibilityIdentifier("watchlist_data_mode")
                Text("State: \(String(describing: viewModel.connectionState))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if case .fallbackMocked(let message) = viewModel.seedingState {
                    Text("Using fallback pricing. Pull to retry. \(message)")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.name), \(row.priceText), change \(row.changeText)")
    }
}
