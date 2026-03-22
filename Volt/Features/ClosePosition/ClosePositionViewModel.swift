import Combine
import Foundation

@MainActor
final class ClosePositionViewModel: ObservableObject {
    enum CloseMode: String, CaseIterable {
        case partial
        case full
    }

    enum ValidationState: Equatable {
        case valid
        case invalid(String)
    }

    @Published private(set) var position: Position
    @Published private(set) var latestPrice: Decimal?
    @Published var quantityText: String
    @Published var closeMode: CloseMode = .full
    @Published private(set) var estimatedProceeds: Decimal = 0
    @Published private(set) var estimatedRealizedPnL: Decimal = 0
    @Published private(set) var remainingQuantity: Decimal = 0
    @Published private(set) var validationState: ValidationState = .valid
    @Published private(set) var isSubmitting = false
    @Published private(set) var submissionError: String?
    @Published private(set) var canSubmit = false
    @Published private(set) var didSubmitSuccessfully = false

    private let marketDataRepository: MarketDataRepository
    private let tradingSimulationService: TradingSimulationService
    private var cancellables = Set<AnyCancellable>()

    init(
        position: Position,
        marketDataRepository: MarketDataRepository,
        tradingSimulationService: TradingSimulationService
    ) {
        self.position = position
        self.marketDataRepository = marketDataRepository
        self.tradingSimulationService = tradingSimulationService
        self.quantityText = position.quantity.description

        bind()
    }

    func submit() {
        let quantity = selectedQuantity
        guard quantity > 0 else {
            submissionError = TradingSimulationError.invalidCloseQuantity.localizedDescription
            return
        }

        guard let latestPrice else {
            submissionError = TradingSimulationError.missingQuote(symbol: position.symbol).localizedDescription
            return
        }

        isSubmitting = true
        submissionError = nil
        let draft = OrderDraft(
            assetSymbol: position.symbol,
            side: .sell,
            type: .market,
            quantity: quantity,
            estimatedPrice: latestPrice,
            submittedAt: Date(),
            limitPrice: nil,
            stopPrice: nil
        )

        do {
            _ = try tradingSimulationService.placeOrder(draft)
            didSubmitSuccessfully = true
        } catch {
            submissionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSubmitting = false
    }

    private var selectedQuantity: Decimal {
        closeMode == .full ? position.quantity : (Decimal(string: quantityText) ?? 0)
    }

    private func bind() {
        marketDataRepository.quotePublisher(for: position.symbol)
            .receive(on: RunLoop.main)
            .sink { [weak self] quote in
                self?.latestPrice = quote?.lastPrice
                self?.revalidate()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($quantityText, $closeMode)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.revalidate()
            }
            .store(in: &cancellables)
    }

    private func revalidate() {
        guard let latestPrice else {
            validationState = .invalid("Waiting for quote…")
            canSubmit = false
            estimatedProceeds = 0
            estimatedRealizedPnL = 0
            remainingQuantity = position.quantity
            return
        }

        let quantity = selectedQuantity
        guard quantity > 0 else {
            validationState = .invalid("Enter close quantity.")
            canSubmit = false
            estimatedProceeds = 0
            estimatedRealizedPnL = 0
            remainingQuantity = position.quantity
            return
        }
        guard quantity <= position.quantity else {
            validationState = .invalid("Quantity exceeds open position.")
            canSubmit = false
            return
        }

        estimatedProceeds = quantity * latestPrice
        estimatedRealizedPnL = (latestPrice - position.averageEntryPrice) * quantity
        remainingQuantity = position.quantity - quantity
        validationState = .valid
        canSubmit = true
    }
}
