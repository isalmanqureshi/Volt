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
            didSubmitSuccessfully = true
        } catch {
            logger.error("Trade ticket submission failed: \(error.localizedDescription, privacy: .public)")
            submissionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSubmitting = false
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

    var body: some View {
        Form {
            Section("Asset") {
                LabeledContent("Symbol", value: viewModel.asset.symbol)
                LabeledContent("Name", value: viewModel.asset.displayName)
                LabeledContent("Latest Price", value: viewModel.latestPrice?.formatted(.currency(code: "USD")) ?? "--")
            }

            Section("Order") {
                Picker("Side", selection: $viewModel.side) {
                    Text("Buy").tag(OrderSide.buy)
                    Text("Sell").tag(OrderSide.sell)
                }
                .pickerStyle(.segmented)

                TextField("Quantity", text: $viewModel.quantityText)
                    .keyboardType(.decimalPad)

                LabeledContent("Estimated Fill", value: viewModel.estimatedExecutionPrice.formatted(.currency(code: "USD")))
                LabeledContent("Estimated Value", value: viewModel.estimatedCost.formatted(.currency(code: "USD")))
                Text(viewModel.runtimeContextLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Available Cash", value: viewModel.availableCash.formatted(.currency(code: "USD")))
            }

            if case .invalid(let message) = viewModel.validationState {
                Section {
                    Text(message)
                        .foregroundStyle(.orange)
                }
            }
            if let riskWarning = viewModel.riskWarning {
                Section("Risk Warning") {
                    Text(riskWarning)
                        .foregroundStyle(.orange)
                }
            }

            if let submissionError = viewModel.submissionError {
                Section {
                    Text(submissionError)
                        .foregroundStyle(.red)
                }
            }
            if let recap = viewModel.tradeRecap {
                Section(recap.title) {
                    Text(recap.body)
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    viewModel.submitOrder()
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Text(viewModel.side == .buy ? "Place Buy Order" : "Place Sell Order")
                    }
                }
                .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
            }
        }
        .navigationTitle("Trade Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.didSubmitSuccessfully) { _, isSuccess in
            if isSuccess {
                dismiss()
            }
        }
    }
}

#Preview("Valid") {
    NavigationStack {
        TradeTicketView(
            viewModel: TradeTicketViewModel(
                asset: SupportedAssets.demoAssets[0],
                marketDataRepository: TradeTicketPreviewMarketDataRepository(
                    quote: Quote(symbol: "BTC/USD", lastPrice: 68_000, changePercent: 0.3, timestamp: .now, source: "preview", isSimulated: true)
                ),
                portfolioRepository: TradeTicketPreviewPortfolioRepository(cash: 50_000),
                tradingSimulationService: TradeTicketPreviewTradingService()
            )
        )
    }
}

#Preview("Invalid") {
    NavigationStack {
        TradeTicketView(viewModel: {
            let vm = TradeTicketViewModel(
                asset: SupportedAssets.demoAssets[1],
                marketDataRepository: TradeTicketPreviewMarketDataRepository(
                    quote: Quote(symbol: "ETH/USD", lastPrice: 3_200, changePercent: 0, timestamp: .now, source: "preview", isSimulated: true)
                ),
                portfolioRepository: TradeTicketPreviewPortfolioRepository(cash: 100),
                tradingSimulationService: TradeTicketPreviewTradingService()
            )
            vm.quantityText = "1"
            return vm
        }())
    }
}

#Preview("Submitted") {
    NavigationStack {
        TradeTicketView(viewModel: {
            let vm = TradeTicketViewModel(
                asset: SupportedAssets.demoAssets[2],
                marketDataRepository: TradeTicketPreviewMarketDataRepository(
                    quote: Quote(symbol: "SOL/USD", lastPrice: 180, changePercent: 0, timestamp: .now, source: "preview", isSimulated: true)
                ),
                portfolioRepository: TradeTicketPreviewPortfolioRepository(cash: 10_000),
                tradingSimulationService: TradeTicketPreviewTradingService()
            )
            vm.quantityText = "2"
            vm.submitOrder()
            return vm
        }())
    }
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
