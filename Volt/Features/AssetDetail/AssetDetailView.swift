import Combine
import Foundation
import SwiftUI

struct AssetDetailView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject var viewModel: AssetDetailViewModel
    @State private var tradeSide: OrderSide?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                chartCard
                summaryCard
                tradeActions
            }
            .padding()
        }
        .navigationTitle(viewModel.asset.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(item: $tradeSide) { side in
            NavigationStack {
                TradeTicketView(viewModel: container.makeTradeTicketViewModel(asset: viewModel.asset, side: side))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.asset.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline) {
                Text(viewModel.currentPriceText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(viewModel.asset.quoteCurrency)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(viewModel.changeText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(viewModel.isPriceUp ? .green : .red)

                Label(viewModel.liveStatusText, systemImage: "waveform.path.ecg")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("1m Candles")
                .font(.headline)

            switch viewModel.chartState {
            case .idle, .loading:
                ProgressView("Loading candles…")
                    .frame(maxWidth: .infinity, minHeight: 220)
            case .empty:
                ContentUnavailableView("No Candle Data", systemImage: "chart.xyaxis.line")
                    .frame(maxWidth: .infinity, minHeight: 220)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unable to load candles")
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let quote = viewModel.latestQuote {
                        Text("Live quote still available: \(quote.lastPrice.formatted(.number.precision(.fractionLength(2...6))))")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 220)
            case .loaded:
                CandlestickChartView(candles: viewModel.candles, livePrice: viewModel.latestQuote?.lastPrice)
                    .frame(height: 260)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)

            summaryRow(title: "Last Price", value: viewModel.currentPriceText)
            summaryRow(title: "Change", value: viewModel.changeText)
            summaryRow(title: "Updated", value: viewModel.lastUpdatedText)
            summaryRow(title: "Bars", value: "\(viewModel.candles.count)")
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var tradeActions: some View {
        HStack(spacing: 12) {
            Button("Buy") {
                tradeSide = .buy
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            Button("Sell") {
                tradeSide = .sell
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
        }
    }
}

extension OrderSide: Identifiable {
    var id: String { rawValue }
}

#Preview("Loaded") {
    NavigationStack {
        AssetDetailView(viewModel: .previewLoaded)
    }
    .environmentObject(AppContainer.bootstrap())
}

#Preview("Loading") {
    NavigationStack {
        AssetDetailView(viewModel: .previewLoading)
    }
    .environmentObject(AppContainer.bootstrap())
}

#Preview("Error") {
    NavigationStack {
        AssetDetailView(viewModel: .previewError)
    }
    .environmentObject(AppContainer.bootstrap())
}

private extension AssetDetailViewModel {
    static var previewLoaded: AssetDetailViewModel {
        let repository = AssetDetailPreviewRepository()
        let viewModel = AssetDetailViewModel(
            asset: SupportedAssets.demoAssets[0],
            marketDataRepository: repository,
            defaultCandleOutputSize: 90
        )
        viewModel.latestQuote = Quote(symbol: "BTC/USD", lastPrice: 68_420, changePercent: 1.34, timestamp: .now, source: "preview", isSimulated: true)
        viewModel.candles = repository.previewCandles.sorted(by: { $0.timestamp < $1.timestamp })
        viewModel.chartState = .loaded
        return viewModel
    }

    static var previewLoading: AssetDetailViewModel {
        let viewModel = AssetDetailViewModel(
            asset: SupportedAssets.demoAssets[1],
            marketDataRepository: AssetDetailPreviewRepository(),
            defaultCandleOutputSize: 90
        )
        viewModel.chartState = .loading
        return viewModel
    }

    static var previewError: AssetDetailViewModel {
        let viewModel = AssetDetailViewModel(
            asset: SupportedAssets.demoAssets[2],
            marketDataRepository: AssetDetailPreviewRepository(failCandles: true),
            defaultCandleOutputSize: 90
        )
        viewModel.latestQuote = Quote(symbol: "SOL/USD", lastPrice: 180.5, changePercent: -2.14, timestamp: .now, source: "preview", isSimulated: true)
        viewModel.chartState = .failed("Preview candle error")
        return viewModel
    }
}

private final class AssetDetailPreviewRepository: MarketDataRepository {
    let previewCandles: [Candle]
    private let failCandles: Bool

    init(failCandles: Bool = false) {
        self.failCandles = failCandles
        let now = Date()
        self.previewCandles = (0..<60).map { index in
            let base = Decimal(68_000 + index)
            let close = index.isMultiple(of: 2) ? (base + 8) : (base - 6)
            return Candle(
                symbol: "BTC/USD",
                interval: "1min",
                open: base,
                high: max(base, close) + 10,
                low: min(base, close) - 9,
                close: close,
                volume: 1_000,
                timestamp: now.addingTimeInterval(TimeInterval(-60 * (60 - index))),
                isComplete: true
            )
        }
    }

    var quotesPublisher: AnyPublisher<[Quote], Never> { Just([]).eraseToAnyPublisher() }
    var tickPublisher: AnyPublisher<MarketTick, Never> { Empty().eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { Just(.liveSimulated).eraseToAnyPublisher() }
    var seedingStatePublisher: AnyPublisher<MarketSeedingState, Never> { Just(.ready).eraseToAnyPublisher() }

    func start() async {}
    func quote(for symbol: String) -> Quote? { nil }
    func quotePublisher(for symbol: String) -> AnyPublisher<Quote?, Never> { Just(nil).eraseToAnyPublisher() }
    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never> { Just([]).eraseToAnyPublisher() }
    func fetchRecentCandles(symbol: String, outputSize: Int) async throws -> [Candle] {
        if failCandles {
            throw URLError(.cannotLoadFromNetwork)
        }
        return previewCandles
    }
}
