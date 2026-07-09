import Combine
import Foundation
import OSLog
import SwiftUI

@MainActor
final class TradeTicketViewModel: ObservableObject {
    enum ValidationState: Equatable {
        case valid
        case invalid(String)
    }

    @Published private(set) var asset: Asset
    @Published var side: OrderSide
    @Published var quantityText: String = ""
    @Published private(set) var latestPrice: Decimal?
    @Published private(set) var estimatedCost: Decimal = 0
    @Published private(set) var estimatedExecutionPrice: Decimal = 0
    @Published private(set) var runtimeContextLabel: String = ""
    @Published private(set) var validationState: ValidationState = .invalid("Enter quantity")
    @Published private(set) var isSubmitting = false
    @Published private(set) var submissionError: String?
    @Published private(set) var canSubmit = false
    @Published private(set) var didSubmitSuccessfully = false
    @Published private(set) var availableCash: Decimal = 0
    @Published private(set) var riskWarning: String?
    @Published private(set) var tradeRecap: TradeRecap?
    @Published private(set) var lastFill: TradeExecutionResult?
    @Published private(set) var slippagePreset: SlippagePreset

    private let marketDataRepository: MarketDataRepository
    private let portfolioRepository: PortfolioRepository
    private let tradingSimulationService: TradingSimulationService
    private let preferencesStore: AppPreferencesProviding
    private let tradeInsightService: TradeSummaryInsightService
    private let logger = Logger(subsystem: "com.volt.app", category: "trade-ticket")
    private var cancellables = Set<AnyCancellable>()

    init(
        asset: Asset,
        side: OrderSide = .buy,
        marketDataRepository: MarketDataRepository,
        portfolioRepository: PortfolioRepository,
        tradingSimulationService: TradingSimulationService,
        preferencesStore: AppPreferencesProviding = UserDefaultsAppPreferencesStore(),
        tradeInsightService: TradeSummaryInsightService = LocalInsightSummaryService()
    ) {
        self.asset = asset
        self.side = side
        self.marketDataRepository = marketDataRepository
        self.portfolioRepository = portfolioRepository
        self.tradingSimulationService = tradingSimulationService
        self.preferencesStore = preferencesStore
        self.tradeInsightService = tradeInsightService
        self.slippagePreset = preferencesStore.currentPreferences.simulatorRisk.slippagePreset
        bind()
        applyRiskDefaults()
        logger.info("Trade ticket opened for \(asset.symbol, privacy: .public)")
    }

    func submitOrder() {
        guard let quantity = Decimal(string: quantityText), quantity > 0 else {
            submissionError = TradingSimulationError.invalidQuantity.localizedDescription
            return
        }
        guard let latestPrice else {
            submissionError = TradingSimulationError.missingQuote(symbol: asset.symbol).localizedDescription
            return
        }

        isSubmitting = true
        submissionError = nil
        let draft = OrderDraft(
            assetSymbol: asset.symbol,
            side: side,
            type: .market,
            quantity: quantity,
            estimatedPrice: latestPrice,
            submittedAt: Date(),
            limitPrice: nil,
            stopPrice: nil
        )

        do {
            let result = try tradingSimulationService.placeOrder(draft)
            tradeRecap = tradeInsightService.makeRecap(result: result, latestSummary: portfolioRepository.currentSummary)
            lastFill = result
            didSubmitSuccessfully = true
        } catch {
            logger.error("Trade ticket submission failed: \(error.localizedDescription, privacy: .public)")
            submissionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSubmitting = false
    }

    /// Routes through the same preferences path Settings uses; simulation reads the
    /// preset from preferences at execution time.
    func setSlippage(_ preset: SlippagePreset) {
        preferencesStore.update { $0.simulatorRisk.slippagePreset = preset }
    }

    private func bind() {
        marketDataRepository.quotePublisher(for: asset.symbol)
            .receive(on: RunLoop.main)
            .sink { [weak self] quote in
                self?.latestPrice = quote?.lastPrice
                self?.revalidate()
            }
            .store(in: &cancellables)

        portfolioRepository.summaryPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] summary in
                self?.availableCash = summary.cashBalance
                self?.revalidate()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($quantityText, $side)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.revalidate()
            }
            .store(in: &cancellables)

        preferencesStore.preferencesPublisher
            .map(\.simulatorRisk.slippagePreset)
            .receive(on: RunLoop.main)
            .sink { [weak self] preset in
                self?.slippagePreset = preset
                self?.revalidate()
            }
            .store(in: &cancellables)
    }

    private func revalidate() {
        guard let quantity = Decimal(string: quantityText), quantity > 0 else {
            validationState = .invalid("Enter a valid quantity.")
            estimatedCost = 0
            canSubmit = false
            return
        }
        guard let latestPrice else {
            validationState = .invalid("Waiting for quote…")
            estimatedCost = 0
            canSubmit = false
            return
        }

        let slippageBps = preferencesStore.currentPreferences.simulatorRisk.slippagePreset.basisPoints
        let slippedPrice = side == .buy ? latestPrice * (1 + (slippageBps / 10_000)) : latestPrice * (1 - (slippageBps / 10_000))
        estimatedExecutionPrice = slippedPrice
        let cost = slippedPrice * quantity
        estimatedCost = cost
        riskWarning = riskWarningMessage(orderValue: cost)
        if side == .buy, cost > availableCash {
            validationState = .invalid("Insufficient cash balance.")
            canSubmit = false
            return
        }
        validationState = .valid
        canSubmit = true
    }

    private func applyRiskDefaults() {
        let preferences = preferencesStore.currentPreferences.simulatorRisk.validated()
        runtimeContextLabel = "\(preferencesStore.currentPreferences.activeRuntimeProfile.name) • \(preferences.volatilityPreset.title) vol • \(preferences.slippagePreset.title) slip"
        switch preferences.orderSizeMode {
        case .fixedQuantity:
            quantityText = preferences.defaultOrderSizeValue.formatted(.number)
        case .fixedNotional, .percentOfCash:
            break
        }
    }

    private func riskWarningMessage(orderValue: Decimal) -> String? {
        let prefs = preferencesStore.currentPreferences.simulatorRisk.validated()
        guard prefs.riskWarningsEnabled else { return nil }
        guard availableCash > 0 else { return nil }
        let percent = (orderValue / availableCash) * 100
        if percent >= prefs.warningThresholdPercent {
            let base = "Order notional is \(percent.formatted(.number.precision(.fractionLength(1...2))))% of available cash."
            switch prefs.tradeConfirmationMode {
            case .alwaysConfirm:
                return base + " Confirmation is required."
            case .confirmOnlyLarge:
                return base + " Large-order confirmation mode is active."
            case .minimal:
                return base + " Minimal confirmation mode is active."
            }
        }
        return nil
    }
}

struct TradeTicketView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: TradeTicketViewModel
    /// True when presented as a sheet (Asset Detail flow); the tab keeps the
    /// screen up so the "Last fill" recap stays visible.
    var dismissesOnSuccess = false
    /// When provided, the coin header becomes a switcher menu (tab usage).
    var availableAssets: [Asset] = []
    var onSelectAsset: ((Asset) -> Void)? = nil

    @State private var amountText = ""
    @State private var didSeedAmount = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader("Trade")
            coinHeader
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.gutter) {
                    sideToggle
                    amountCard
                    slippageSection
                    balanceRow
                    messages
                    PrimaryButton(
                        title: "\(viewModel.side == .buy ? "Buy" : "Sell") \(viewModel.asset.baseCurrency)",
                        style: viewModel.side == .buy ? .accent : .danger,
                        isEnabled: viewModel.canSubmit && viewModel.isSubmitting == false
                    ) {
                        viewModel.submitOrder()
                    }
                    if let fill = viewModel.lastFill {
                        recapCard(fill)
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .voltScreen()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: seedAmountIfNeeded)
        .onChange(of: viewModel.latestPrice) { _, _ in
            seedAmountIfNeeded()
            // Re-derive quantity from the entered amount whenever the live price
            // moves, so the estimate and submitted notional track the latest quote
            // instead of freezing at the price in effect when the user last typed.
            syncQuantityFromAmount()
        }
        .onChange(of: amountText) { _, _ in
            syncQuantityFromAmount()
        }
        .onChange(of: viewModel.didSubmitSuccessfully) { _, isSuccess in
            if isSuccess, dismissesOnSuccess {
                dismiss()
            }
        }
    }

    // MARK: Header

    @ViewBuilder
    private var coinHeader: some View {
        let row = HStack(spacing: Spacing.sm + 2) {
            CoinBadge(baseCurrency: viewModel.asset.baseCurrency, size: 24)
            Text(viewModel.asset.displayName)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(Color.voltTextPrimary)
            Text(viewModel.asset.baseCurrency)
                .font(Typography.monoSecondary)
                .foregroundStyle(Color.voltTextSecondary)
            if onSelectAsset != nil {
                Image(systemName: "chevron.down")
                    .font(Typography.caption)
                    .foregroundStyle(Color.voltTextTertiary)
            }
            Spacer()
            Text(viewModel.latestPrice.map { "$" + $0.voltPriceString(precision: viewModel.asset.pricePrecision) } ?? "—")
                .font(Typography.monoBody.weight(.semibold))
                .foregroundStyle(Color.voltTextPrimary)
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

    // MARK: Sections

    private var sideToggle: some View {
        HStack(spacing: Spacing.xs) {
            sideButton("Buy", side: .buy, color: .voltAccent)
            sideButton("Sell", side: .sell, color: .voltDanger)
        }
        .padding(Spacing.xs)
        .voltSurfaceStyle(cornerRadius: Radius.button)
    }

    private func sideButton(_ title: String, side: OrderSide, color: Color) -> some View {
        let isSelected = viewModel.side == side
        return Button {
            viewModel.side = side
        } label: {
            Text(title)
                .font(Typography.body.weight(isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? Color.voltBackground : color.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    isSelected ? color : .clear,
                    in: RoundedRectangle(cornerRadius: Radius.button - 2, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private var amountCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Amount (USD)")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.voltTextSecondary)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text("$")
                        .font(Typography.amountEntry)
                        .foregroundStyle(amountText.isEmpty ? Color.voltTextTertiary : Color.voltTextPrimary)
                    TextField(
                        "",
                        text: $amountText,
                        prompt: Text("0").foregroundStyle(Color.voltTextTertiary)
                    )
                    .keyboardType(.decimalPad)
                    .font(Typography.amountEntry)
                    .foregroundStyle(Color.voltTextPrimary)
                    .tint(Color.voltAccent)
                }
                Text("≈ \(estimatedQuantityText) \(viewModel.asset.baseCurrency)")
                    .font(Typography.monoBody)
                    .foregroundStyle(Color.voltTextSecondary)
            }
        }
    }

    private var estimatedQuantityText: String {
        guard let quantity = Decimal(string: viewModel.quantityText), quantity > 0 else { return "0" }
        return quantity.voltPriceString(precision: 8)
    }

    private var slippageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Slippage tolerance")
                .font(Typography.secondary)
                .foregroundStyle(Color.voltTextSecondary)
            HStack(spacing: Spacing.sm) {
                ForEach(SlippagePreset.allCases, id: \.self) { preset in
                    FilterPill(
                        title: slippageLabel(preset),
                        isSelected: viewModel.slippagePreset == preset,
                        isMono: true,
                        expands: true
                    ) {
                        viewModel.setSlippage(preset)
                    }
                }
            }
        }
    }

    private func slippageLabel(_ preset: SlippagePreset) -> String {
        guard preset != .off else { return "Off" }
        let percent = preset.basisPoints / 100
        return "\(percent.formatted(.number.precision(.fractionLength(0...2))))%"
    }

    private var balanceRow: some View {
        HStack {
            Text("Available balance")
                .font(Typography.bodySecondary)
                .foregroundStyle(Color.voltTextSecondary)
            Spacer()
            Text("$" + viewModel.availableCash.voltPriceString(precision: 2))
                .font(Typography.monoBodySecondary)
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }

    @ViewBuilder
    private var messages: some View {
        if case .invalid(let message) = viewModel.validationState, amountText.isEmpty == false {
            Text(message)
                .font(Typography.secondary)
                .foregroundStyle(Color.voltDanger)
        }
        if let riskWarning = viewModel.riskWarning {
            Text(riskWarning)
                .font(Typography.secondary)
                .foregroundStyle(Color.voltTextSecondary)
        }
        if let submissionError = viewModel.submissionError {
            Text(submissionError)
                .font(Typography.secondary)
                .foregroundStyle(Color.voltDanger)
        }
    }

    private func recapCard(_ fill: TradeExecutionResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Last fill")
                .font(Typography.secondary)
                .foregroundStyle(Color.voltTextSecondary)
            SectionCard {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(spacing: Spacing.sm + 2) {
                        CoinBadge(baseCurrency: viewModel.asset.baseCurrency, size: 24)
                        Text(viewModel.asset.displayName)
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(Color.voltTextPrimary)
                        Text(viewModel.asset.baseCurrency)
                            .font(Typography.monoSecondary)
                            .foregroundStyle(Color.voltTextSecondary)
                        Spacer()
                        Text(fill.orderRecord.side == .buy ? "BUY" : "SELL")
                            .font(Typography.monoCaption.weight(.bold))
                            .foregroundStyle(fill.orderRecord.side == .buy ? Color.voltAccent : Color.voltDanger)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(
                                (fill.orderRecord.side == .buy ? Color.voltAccent : Color.voltDanger).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                            )
                    }
                    HStack(spacing: Spacing.lg) {
                        recapField(
                            label: "Price filled",
                            value: "$" + fill.orderRecord.executedPrice.voltPriceString(precision: viewModel.asset.pricePrecision)
                        )
                        recapField(
                            label: "Quantity",
                            value: "\(fill.orderRecord.quantity.voltPriceString(precision: 8)) \(viewModel.asset.baseCurrency)"
                        )
                    }
                }
            }
        }
    }

    private func recapField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Color.voltTextTertiary)
            Text(value)
                .font(Typography.monoBody)
                .foregroundStyle(Color.voltTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Amount <-> quantity sync (presentation only)

    /// Prefills the USD amount once from the profile's default order size.
    private func seedAmountIfNeeded() {
        guard didSeedAmount == false,
              amountText.isEmpty,
              let price = viewModel.latestPrice,
              let quantity = Decimal(string: viewModel.quantityText), quantity > 0
        else { return }
        didSeedAmount = true
        var cost = quantity * price
        var rounded = Decimal()
        NSDecimalRound(&rounded, &cost, 2, .plain)
        amountText = NSDecimalNumber(decimal: rounded).stringValue
    }

    private func syncQuantityFromAmount() {
        didSeedAmount = true
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Decimal(string: normalized), amount > 0,
              let price = viewModel.latestPrice, price > 0
        else {
            viewModel.quantityText = ""
            return
        }
        var quantity = amount / price
        var rounded = Decimal()
        NSDecimalRound(&rounded, &quantity, 8, .plain)
        viewModel.quantityText = NSDecimalNumber(decimal: rounded).stringValue
    }
}

#Preview("Buy") {
    TradeTicketView(
        viewModel: TradeTicketViewModel(
            asset: SupportedAssets.demoAssets[0],
            marketDataRepository: TradeTicketPreviewMarketDataRepository(
                quote: Quote(symbol: "BTC/USD", lastPrice: 63_842.10, changePercent: 2.34, timestamp: .now, source: "preview", isSimulated: true)
            ),
            portfolioRepository: TradeTicketPreviewPortfolioRepository(cash: 24_860),
            tradingSimulationService: TradeTicketPreviewTradingService()
        )
    )
}

#Preview("Sell") {
    TradeTicketView(viewModel: {
        let vm = TradeTicketViewModel(
            asset: SupportedAssets.demoAssets[1],
            marketDataRepository: TradeTicketPreviewMarketDataRepository(
                quote: Quote(symbol: "ETH/USD", lastPrice: 3_318.72, changePercent: 1.12, timestamp: .now, source: "preview", isSimulated: true)
            ),
            portfolioRepository: TradeTicketPreviewPortfolioRepository(cash: 100),
            tradingSimulationService: TradeTicketPreviewTradingService()
        )
        vm.side = .sell
        vm.quantityText = "1"
        return vm
    }())
}

#Preview("Filled") {
    TradeTicketView(viewModel: {
        let vm = TradeTicketViewModel(
            asset: SupportedAssets.demoAssets[2],
            marketDataRepository: TradeTicketPreviewMarketDataRepository(
                quote: Quote(symbol: "SOL/USD", lastPrice: 180, changePercent: 0.4, timestamp: .now, source: "preview", isSimulated: true)
            ),
            portfolioRepository: TradeTicketPreviewPortfolioRepository(cash: 10_000),
            tradingSimulationService: TradeTicketPreviewTradingService()
        )
        vm.quantityText = "2"
        vm.submitOrder()
        return vm
    }())
}

private final class TradeTicketPreviewMarketDataRepository: MarketDataRepository {
    private let quote: Quote
    init(quote: Quote) { self.quote = quote }
    var quotesPublisher: AnyPublisher<[Quote], Never> { Just([quote]).eraseToAnyPublisher() }
    var tickPublisher: AnyPublisher<MarketTick, Never> { Empty().eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { Just(.liveSimulated).eraseToAnyPublisher() }
    var seedingStatePublisher: AnyPublisher<MarketSeedingState, Never> { Just(.ready).eraseToAnyPublisher() }
    func start() async {}
    func quote(for symbol: String) -> Quote? { quote }
    func quotePublisher(for symbol: String) -> AnyPublisher<Quote?, Never> { Just(quote).eraseToAnyPublisher() }
    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never> { Just([quote]).eraseToAnyPublisher() }
    func fetchRecentCandles(symbol: String, outputSize: Int) async throws -> [Candle] { [] }
}

private final class TradeTicketPreviewPortfolioRepository: PortfolioRepository {
    let summarySubject: CurrentValueSubject<PortfolioSummary, Never>
    init(cash: Decimal) {
        summarySubject = CurrentValueSubject(.init(cashBalance: cash, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: cash, dayChange: 0))
    }
    var positionsPublisher: AnyPublisher<[Position], Never> { Just([]).eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { summarySubject.eraseToAnyPublisher() }
    var orderHistoryPublisher: AnyPublisher<[OrderRecord], Never> { Just([]).eraseToAnyPublisher() }
    var activityTimelinePublisher: AnyPublisher<[ActivityEvent], Never> { Just([]).eraseToAnyPublisher() }
    var realizedPnLPublisher: AnyPublisher<[RealizedPnLEntry], Never> { Just([]).eraseToAnyPublisher() }
    var currentPositions: [Position] { [] }
    var currentSummary: PortfolioSummary { summarySubject.value }
    var currentOrderHistory: [OrderRecord] { [] }
    var currentActivityTimeline: [ActivityEvent] { [] }
    var currentRealizedPnLHistory: [RealizedPnLEntry] { [] }
    func position(for symbol: String) -> Position? { nil }
    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> TradeExecutionResult {
        let position = Position(id: UUID(), symbol: draft.assetSymbol, quantity: draft.quantity, averageEntryPrice: executionPrice, currentPrice: executionPrice, unrealizedPnL: 0, openedAt: filledAt)
        let order = OrderRecord(id: UUID(), symbol: draft.assetSymbol, side: draft.side, type: draft.type, quantity: draft.quantity, executedPrice: executionPrice, grossValue: executionPrice * draft.quantity, submittedAt: filledAt, executedAt: filledAt, status: .filled, source: .simulated, linkedPositionID: position.id)
        let event = ActivityEvent(id: UUID(), kind: .buy, symbol: draft.assetSymbol, quantity: draft.quantity, price: executionPrice, timestamp: filledAt, orderID: order.id, relatedPositionID: position.id, realizedPnL: nil)
        return TradeExecutionResult(resultingPosition: position, orderRecord: order, activityEvent: event, realizedPnLEntry: nil)
    }
}

private struct TradeTicketPreviewTradingService: TradingSimulationService {
    func placeOrder(_ draft: OrderDraft) throws -> TradeExecutionResult {
        let position = Position(id: UUID(), symbol: draft.assetSymbol, quantity: draft.quantity, averageEntryPrice: draft.estimatedPrice ?? 0, currentPrice: draft.estimatedPrice ?? 0, unrealizedPnL: 0, openedAt: draft.submittedAt)
        let order = OrderRecord(id: UUID(), symbol: draft.assetSymbol, side: draft.side, type: draft.type, quantity: draft.quantity, executedPrice: draft.estimatedPrice ?? 0, grossValue: (draft.estimatedPrice ?? 0) * draft.quantity, submittedAt: draft.submittedAt, executedAt: draft.submittedAt, status: .filled, source: .simulated, linkedPositionID: position.id)
        let event = ActivityEvent(id: UUID(), kind: .buy, symbol: draft.assetSymbol, quantity: draft.quantity, price: draft.estimatedPrice ?? 0, timestamp: draft.submittedAt, orderID: order.id, relatedPositionID: position.id, realizedPnL: nil)
        return TradeExecutionResult(resultingPosition: position, orderRecord: order, activityEvent: event, realizedPnLEntry: nil)
    }
}
