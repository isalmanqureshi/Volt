import Combine
import Foundation
import SwiftUI

struct ClosePositionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: ClosePositionViewModel

    var body: some View {
        Form {
            Section("Position") {
                LabeledContent("Symbol", value: viewModel.position.symbol)
                LabeledContent("Open Quantity", value: viewModel.position.quantity.formatted())
                LabeledContent("Average Entry", value: viewModel.position.averageEntryPrice.formatted(.currency(code: "USD")))
                LabeledContent("Latest Price", value: viewModel.latestPrice?.formatted(.currency(code: "USD")) ?? "--")
            }

            Section("Close") {
                Picker("Mode", selection: $viewModel.closeMode) {
                    Text("Partial").tag(ClosePositionViewModel.CloseMode.partial)
                    Text("Full").tag(ClosePositionViewModel.CloseMode.full)
                }
                .pickerStyle(.segmented)

                if viewModel.closeMode == .partial {
                    TextField("Quantity", text: $viewModel.quantityText)
                        .keyboardType(.decimalPad)
                }

                LabeledContent("Estimated Proceeds", value: viewModel.estimatedProceeds.formatted(.currency(code: "USD")))
                LabeledContent("Estimated Realized P&L", value: viewModel.estimatedRealizedPnL.formatted(.currency(code: "USD")))
                LabeledContent("Remaining Quantity", value: viewModel.remainingQuantity.formatted())
            }

            if case .invalid(let message) = viewModel.validationState {
                Section {
                    Text(message)
                        .foregroundStyle(.orange)
                }
            }

            if let submissionError = viewModel.submissionError {
                Section {
                    Text(submissionError)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(viewModel.closeMode == .full ? "Close Position" : "Reduce Position") {
                    viewModel.submit()
                }
                .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
            }
        }
        .navigationTitle("Manage Position")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.didSubmitSuccessfully) { _, success in
            if success { dismiss() }
        }
    }
}

#Preview("Valid") {
    NavigationStack {
        ClosePositionView(
            viewModel: ClosePositionViewModel(
                position: Position(id: UUID(), symbol: "BTC/USD", quantity: 1.2, averageEntryPrice: 65_000, currentPrice: 68_000, unrealizedPnL: 3_600, openedAt: .now),
                marketDataRepository: ClosePositionPreviewMarketDataRepository(),
                tradingSimulationService: ClosePositionPreviewTradingService()
            )
        )
    }
}

#Preview("Invalid") {
    NavigationStack {
        ClosePositionView(
            viewModel: {
                let vm = ClosePositionViewModel(
                    position: Position(id: UUID(), symbol: "ETH/USD", quantity: 2, averageEntryPrice: 3_000, currentPrice: 3_100, unrealizedPnL: 200, openedAt: .now),
                    marketDataRepository: ClosePositionPreviewMarketDataRepository(),
                    tradingSimulationService: ClosePositionPreviewTradingService()
                )
                vm.closeMode = .partial
                vm.quantityText = "99"
                return vm
            }()
        )
    }
}

private struct ClosePositionPreviewTradingService: TradingSimulationService {
    func placeOrder(_ draft: OrderDraft) throws -> TradeExecutionResult {
        let order = OrderRecord(id: UUID(), symbol: draft.assetSymbol, side: .sell, type: draft.type, quantity: draft.quantity, executedPrice: draft.estimatedPrice ?? 0, grossValue: (draft.estimatedPrice ?? 0) * draft.quantity, submittedAt: draft.submittedAt, executedAt: draft.submittedAt, status: .filled, source: .simulated, linkedPositionID: nil)
        let event = ActivityEvent(id: UUID(), kind: .partialClose, symbol: draft.assetSymbol, quantity: draft.quantity, price: draft.estimatedPrice ?? 0, timestamp: draft.submittedAt, orderID: order.id, relatedPositionID: nil, realizedPnL: 0)
        return TradeExecutionResult(resultingPosition: nil, orderRecord: order, activityEvent: event, realizedPnLEntry: nil)
    }
}

private struct ClosePositionPreviewMarketDataRepository: MarketDataRepository {
    private let quote = Quote(symbol: "BTC/USD", lastPrice: 68_000, changePercent: 0.5, timestamp: .now, source: "preview", isSimulated: true)
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
