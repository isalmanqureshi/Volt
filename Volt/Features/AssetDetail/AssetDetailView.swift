import Combine
import Foundation
import SwiftUI

struct AssetDetailView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject var viewModel: AssetDetailViewModel
    /// When provided (Chart tab), the header becomes a coin switcher and the
    /// navigation bar is hidden; pushed from Watchlist it keeps the back button.
    var availableAssets: [Asset] = []
    var onSelectAsset: ((Asset) -> Void)? = nil

    @State private var tradeSide: OrderSide?
    @State private var managePosition: Position?
    @State private var selectedCandle: Candle?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, Spacing.md)

                ohlcRow
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, Spacing.sm)

                chartSection
                    .padding(.top, Spacing.sm)

                rangePills
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, Spacing.sm)

                volumeSection
                    .padding(.top, Spacing.sm)

                if let position = viewModel.openPosition {
                    positionCard(position)
                        .padding(.horizontal, Spacing.gutter)
                        .padding(.top, Spacing.lg)
                }

                tradeActions
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.gutter)
            }
        }
        .voltScreen()
        .navigationTitle(viewModel.asset.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.voltBackground, for: .navigationBar)
        .toolbar(onSelectAsset == nil ? .automatic : .hidden, for: .navigationBar)
        .task {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(item: $tradeSide) { side in
            TradeTicketView(
                viewModel: container.makeTradeTicketViewModel(asset: viewModel.asset, side: side),
                dismissesOnSuccess: true
            )
        }
        .sheet(item: $managePosition) { position in
            NavigationStack {
                ClosePositionView(viewModel: container.makeClosePositionViewModel(position: position))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs + 2) {
            coinTitle
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm + 2) {
                Text("$" + viewModel.currentPriceText)
                    .font(Typography.heroValue)
                    .foregroundStyle(Color.voltTextPrimary)
                    .contentTransition(.numericText())
                if viewModel.latestQuote != nil {
                    ChangePill(
                        text: viewModel.isPriceUp ? "+" + viewModel.changeText : viewModel.changeText,
                        isPositive: viewModel.isPriceUp
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var coinTitle: some View {
        let row = HStack(spacing: Spacing.sm + 2) {
            CoinBadge(baseCurrency: viewModel.asset.baseCurrency, size: 28)
            Text(viewModel.asset.displayName)
                .font(Typography.emphasis.weight(.semibold))
                .foregroundStyle(Color.voltTextPrimary)
            Text(viewModel.asset.baseCurrency)
                .font(Typography.monoBodySecondary)
                .foregroundStyle(Color.voltTextSecondary)
            if onSelectAsset != nil {
                Image(systemName: "chevron.down")
                    .font(Typography.caption)
                    .foregroundStyle(Color.voltTextTertiary)
            }
        }

        if let onSelectAsset, availableAssets.isEmpty == false {
            Menu {
                ForEach(availableAssets) { asset in
                    Button("\(asset.displayName) (\(asset.baseCurrency))") {
                        onSelectAsset(asset)
                    }
                }
            } label: {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }

    // MARK: OHLC crosshair readout

    @ViewBuilder
    private var ohlcRow: some View {
        if let candle = selectedCandle {
            HStack(spacing: Spacing.md + 2) {
                ohlcField("O", candle.open, color: .voltTextPrimary)
                ohlcField("H", candle.high, color: .voltAccent)
                ohlcField("L", candle.low, color: .voltDanger)
                ohlcField("C", candle.close, color: .voltTextPrimary)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .voltSurfaceStyle(cornerRadius: Radius.button)
        } else {
            Text("Hold the chart for OHLC")
                .font(Typography.monoCaption)
                .foregroundStyle(Color.voltTextTertiary)
                .padding(.vertical, Spacing.sm)
        }
    }

    private func ohlcField(_ label: String, _ value: Decimal, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .foregroundStyle(Color.voltTextTertiary)
            Text(value.voltPriceString(precision: viewModel.asset.pricePrecision))
                .foregroundStyle(color)
        }
        .font(Typography.monoCaption)
    }

    // MARK: Chart

    @ViewBuilder
    private var chartSection: some View {
        switch viewModel.chartState {
        case .idle, .loading:
            SkeletonView(cornerRadius: 0)
                .frame(height: 300)
        case .empty:
            chartMessage("No candle data", detail: "Nothing to draw for \(viewModel.asset.symbol) yet.")
        case .failed(let message):
            chartMessage("Unable to load candles", detail: message)
        case .loaded:
            CandlestickChartView(
                candles: viewModel.candles,
                livePrice: viewModel.latestQuote?.lastPrice,
                selectedCandle: $selectedCandle
            )
            .frame(height: 300)
        }
    }

    private func chartMessage(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(Color.voltTextPrimary)
            Text(detail)
                .font(Typography.secondary)
                .foregroundStyle(Color.voltTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .leading)
        .padding(.horizontal, Spacing.gutter)
        .background(Color.voltSurfaceDeep)
    }

    private var rangePills: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(AssetDetailViewModel.ChartRange.allCases, id: \.self) { range in
                let isActive = viewModel.selectedRange == range
                Button {
                    selectedCandle = nil
                    viewModel.selectRange(range)
                } label: {
                    Text(range.rawValue)
                        .font(Typography.monoBodySecondary)
                        .foregroundStyle(isActive ? Color.voltAccent : Color.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            isActive ? Color.voltAccent.opacity(0.1) : .clear,
                            in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        )
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isActive ? Color.voltAccent : .clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var volumeSection: some View {
        if case .loaded = viewModel.chartState {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Volume")
                    .font(Typography.monoCaption)
                    .foregroundStyle(Color.voltTextTertiary)
                    .padding(.horizontal, Spacing.gutter)
                VolumeBarsView(candles: viewModel.candles)
                    .frame(height: 80)
            }
        }
    }

    // MARK: Position + trade actions

    private func positionCard(_ position: Position) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionLabel("Your position")
                positionRow("Open quantity", position.quantity.voltPriceString(precision: 8))
                positionRow("Avg entry", "$" + position.averageEntryPrice.voltPriceString(precision: viewModel.asset.pricePrecision))
                HStack {
                    Text("Unrealised P&L")
                        .font(Typography.bodySecondary)
                        .foregroundStyle(Color.voltTextSecondary)
                    Spacer()
                    Text(position.unrealizedPnL.voltSignedCurrencyString())
                        .font(Typography.monoBody)
                        .foregroundStyle(position.unrealizedPnL >= 0 ? Color.voltAccent : Color.voltDanger)
                }
                Button {
                    managePosition = position
                } label: {
                    Text("Manage position")
                        .font(Typography.bodySecondary)
                        .foregroundStyle(Color.white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func positionRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.bodySecondary)
                .foregroundStyle(Color.voltTextSecondary)
            Spacer()
            Text(value)
                .font(Typography.monoBody)
                .foregroundStyle(Color.voltTextPrimary)
        }
    }

    private var tradeActions: some View {
        HStack(spacing: Spacing.md) {
            PrimaryButton(title: "Buy \(viewModel.asset.baseCurrency)") {
                tradeSide = .buy
            }
            PrimaryButton(title: "Sell \(viewModel.asset.baseCurrency)", style: .danger) {
                tradeSide = .sell
            }
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
            portfolioRepository: AssetDetailPreviewPortfolioRepository(position: Position(id: UUID(), symbol: "BTC/USD", quantity: 0.2, averageEntryPrice: 65_000, currentPrice: 68_420, unrealizedPnL: 684, openedAt: .now.addingTimeInterval(-7200))),
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
            portfolioRepository: AssetDetailPreviewPortfolioRepository(position: nil),
            defaultCandleOutputSize: 90
        )
        viewModel.chartState = .loading
        return viewModel
    }

    static var previewError: AssetDetailViewModel {
        let viewModel = AssetDetailViewModel(
            asset: SupportedAssets.demoAssets[2],
            marketDataRepository: AssetDetailPreviewRepository(failCandles: true),
            portfolioRepository: AssetDetailPreviewPortfolioRepository(position: nil),
            defaultCandleOutputSize: 90
        )
        viewModel.latestQuote = Quote(symbol: "SOL/USD", lastPrice: 180.5, changePercent: -2.14, timestamp: .now, source: "preview", isSimulated: true)
        viewModel.chartState = .failed("Preview candle error")
        return viewModel
    }
}

private final class AssetDetailPreviewPortfolioRepository: PortfolioRepository {
    private let positionValue: Position?
    init(position: Position?) { self.positionValue = position }
    var positionsPublisher: AnyPublisher<[Position], Never> { Just(positionValue.map { [$0] } ?? []).eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { Just(.init(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 0, dayChange: 0)).eraseToAnyPublisher() }
    var orderHistoryPublisher: AnyPublisher<[OrderRecord], Never> { Just([]).eraseToAnyPublisher() }
    var activityTimelinePublisher: AnyPublisher<[ActivityEvent], Never> { Just([]).eraseToAnyPublisher() }
    var realizedPnLPublisher: AnyPublisher<[RealizedPnLEntry], Never> { Just([]).eraseToAnyPublisher() }
    var currentPositions: [Position] { positionValue.map { [$0] } ?? [] }
    var currentSummary: PortfolioSummary { .init(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 0, dayChange: 0) }
    var currentOrderHistory: [OrderRecord] { [] }
    var currentActivityTimeline: [ActivityEvent] { [] }
    var currentRealizedPnLHistory: [RealizedPnLEntry] { [] }
    func position(for symbol: String) -> Position? { positionValue?.symbol == symbol ? positionValue : nil }
    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> TradeExecutionResult {
        throw TradingSimulationError.repositoryUnavailable
    }
}

private final class AssetDetailPreviewRepository: MarketDataRepository {
    let previewCandles: [Candle]
    private let failCandles: Bool

    init(failCandles: Bool = false) {
        self.failCandles = failCandles
        let now = Date()
        self.previewCandles = (0..<90).map { index in
            let base = Decimal(68_000 + index * 9)
            let close = index.isMultiple(of: 2) ? (base + 42) : (base - 33)
            return Candle(
                symbol: "BTC/USD",
                interval: "1min",
                open: base,
                high: max(base, close) + 30,
                low: min(base, close) - 27,
                close: close,
                volume: Decimal(300 + (index * 53) % 800),
                timestamp: now.addingTimeInterval(TimeInterval(-60 * (90 - index))),
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
