import Combine
import Foundation
internal import os

/// Local order book fed by the shared tick stream. Orders rest per symbol and
/// fill at the price of the tick that crosses their trigger — never at the
/// trigger price itself, so a gapped tick fills at the actually-traded price,
/// and each order fills at most once (it is removed from the book before the
/// portfolio mutation runs).
///
/// Fills reuse `PortfolioRepository.applyFilledOrder`, the same single source
/// of truth market orders go through, and are re-validated there at fill time:
/// a buy that no longer fits the cash balance, or a sell whose position was
/// closed in the meantime, comes back as a `.rejected` order instead of
/// mutating the portfolio. Triggered fills execute at the crossing tick price
/// with no slippage applied — the tick *is* the traded price.
final class DefaultPendingOrderMatchingService: PendingOrderMatching {
    private let portfolioRepository: PortfolioRepository
    private let marketDataRepository: MarketDataRepository
    private let checkpointService: AccountSnapshotCheckpointing?
    private let supportedSymbols: Set<String>
    private let stateLock = NSLock()
    private var ordersBySymbol: [String: [PendingOrder]] = [:]
    private let ordersSubject = CurrentValueSubject<[PendingOrder], Never>([])
    private var cancellables = Set<AnyCancellable>()

    var pendingOrdersPublisher: AnyPublisher<[PendingOrder], Never> { ordersSubject.eraseToAnyPublisher() }
    var currentPendingOrders: [PendingOrder] { ordersSubject.value }

    init(
        portfolioRepository: PortfolioRepository,
        marketDataRepository: MarketDataRepository,
        checkpointService: AccountSnapshotCheckpointing? = nil,
        supportedSymbols: [String]
    ) {
        self.portfolioRepository = portfolioRepository
        self.marketDataRepository = marketDataRepository
        self.checkpointService = checkpointService
        self.supportedSymbols = Set(supportedSymbols)
        bind()
    }

    @discardableResult
    func place(_ request: PendingOrderRequest) throws -> PendingOrder {
        guard request.type == .limit || request.type == .stop else {
            throw PendingOrderError.unsupportedOrderType
        }
        guard request.quantity > 0 else {
            throw PendingOrderError.invalidQuantity
        }
        guard request.triggerPrice > 0 else {
            throw PendingOrderError.invalidTriggerPrice
        }
        guard supportedSymbols.contains(request.symbol) else {
            throw PendingOrderError.unsupportedAsset(symbol: request.symbol)
        }

        // Placement-time sanity checks; the fill re-validates against the state
        // at crossing time, which is the one that actually matters.
        switch request.side {
        case .sell:
            guard let position = portfolioRepository.position(for: request.symbol),
                  position.quantity >= request.quantity else {
                throw PendingOrderError.missingPosition(symbol: request.symbol)
            }
        case .buy:
            let required = request.triggerPrice * request.quantity
            let available = portfolioRepository.currentSummary.cashBalance
            guard required <= available else {
                throw PendingOrderError.insufficientFunds(required: required, available: available)
            }
        }

        let order = PendingOrder(
            id: UUID(),
            symbol: request.symbol,
            side: request.side,
            type: request.type,
            quantity: request.quantity,
            triggerPrice: request.triggerPrice,
            createdAt: request.submittedAt,
            status: .pending
        )

        stateLock.lock()
        ordersBySymbol[request.symbol, default: []].append(order)
        stateLock.unlock()
        publish()
        AppLogger.portfolio.info("Pending order placed \(order.id.uuidString, privacy: .public) \(request.symbol, privacy: .public) trigger=\(request.triggerPrice.description, privacy: .public)")
        return order
    }

    func cancel(id: UUID) {
        stateLock.lock()
        for (symbol, orders) in ordersBySymbol {
            let remaining = orders.filter { $0.id != id }
            if remaining.count != orders.count {
                ordersBySymbol[symbol] = remaining
            }
        }
        stateLock.unlock()
        publish()
        AppLogger.portfolio.info("Pending order cancelled \(id.uuidString, privacy: .public)")
    }

    private func bind() {
        // Per tick this costs one dictionary hit plus a scan of that symbol's
        // resting orders only; symbols with an empty book add nothing.
        marketDataRepository.tickPublisher
            .sink { [weak self] tick in
                self?.evaluate(tick: tick)
            }
            .store(in: &cancellables)
    }

    private func evaluate(tick: MarketTick) {
        stateLock.lock()
        guard let resting = ordersBySymbol[tick.symbol], resting.isEmpty == false else {
            stateLock.unlock()
            return
        }

        var triggered: [PendingOrder] = []
        var remaining: [PendingOrder] = []
        for order in resting {
            if case .pending = order.status, order.shouldTrigger(atPrice: tick.price) {
                triggered.append(order)
            } else {
                remaining.append(order)
            }
        }
        ordersBySymbol[tick.symbol] = remaining
        stateLock.unlock()

        guard triggered.isEmpty == false else { return }
        for order in triggered {
            fill(order, tick: tick)
        }
        publish()
    }

    private func fill(_ order: PendingOrder, tick: MarketTick) {
        let draft = OrderDraft(
            assetSymbol: order.symbol,
            side: order.side,
            type: order.type,
            quantity: order.quantity,
            estimatedPrice: tick.price,
            submittedAt: order.createdAt,
            limitPrice: order.type == .limit ? order.triggerPrice : nil,
            stopPrice: order.type == .stop ? order.triggerPrice : nil
        )

        do {
            _ = try portfolioRepository.applyFilledOrder(draft, executionPrice: tick.price, filledAt: tick.timestamp)
            checkpointService?.checkpoint(trigger: .orderExecution)
            AppLogger.portfolio.info("Pending order filled \(order.id.uuidString, privacy: .public) at \(tick.price.description, privacy: .public)")
        } catch {
            var rejected = order
            rejected.status = .rejected(reason: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            stateLock.lock()
            ordersBySymbol[order.symbol, default: []].append(rejected)
            stateLock.unlock()
            AppLogger.portfolio.error("Pending order fill rejected \(order.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func publish() {
        stateLock.lock()
        let all = ordersBySymbol.values.flatMap { $0 }.sorted(by: { $0.createdAt < $1.createdAt })
        stateLock.unlock()
        ordersSubject.send(all)
    }
}
