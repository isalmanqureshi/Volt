import Combine
import Foundation
internal import os

final class DefaultPortfolioAnalyticsService: PortfolioAnalyticsService {
    private let repository: PortfolioRepository
    private let nowProvider: () -> Date

    private let summarySubject = CurrentValueSubject<PortfolioAnalyticsSummary, Never>(.empty)
    private let performanceSubject = CurrentValueSubject<[PerformancePoint], Never>([])
    private let filterSubject = CurrentValueSubject<HistoryFilter, Never>(.default)
    private let filteredOrdersSubject = CurrentValueSubject<[OrderRecord], Never>([])
    private let filteredActivitySubject = CurrentValueSubject<[ActivityEvent], Never>([])
    private let availableSymbolsSubject = CurrentValueSubject<[String], Never>([])

    private var latestOrders: [OrderRecord] = []
    private var latestActivity: [ActivityEvent] = []
    private var latestRealized: [RealizedPnLEntry] = []
    private var latestSummary: PortfolioSummary = .init(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 0, dayChange: 0)
    private var cancellables = Set<AnyCancellable>()

    var summaryPublisher: AnyPublisher<PortfolioAnalyticsSummary, Never> { summarySubject.eraseToAnyPublisher() }
    var performancePublisher: AnyPublisher<[PerformancePoint], Never> { performanceSubject.eraseToAnyPublisher() }
    var filteredOrdersPublisher: AnyPublisher<[OrderRecord], Never> { filteredOrdersSubject.eraseToAnyPublisher() }
    var filteredActivityPublisher: AnyPublisher<[ActivityEvent], Never> { filteredActivitySubject.eraseToAnyPublisher() }
    var availableSymbolsPublisher: AnyPublisher<[String], Never> { availableSymbolsSubject.eraseToAnyPublisher() }

    var currentSummary: PortfolioAnalyticsSummary { summarySubject.value }
    var currentPerformance: [PerformancePoint] { performanceSubject.value }
    var currentFilter: HistoryFilter { filterSubject.value }

    init(repository: PortfolioRepository, nowProvider: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.nowProvider = nowProvider
        bind()
    }

    func updateFilter(_ filter: HistoryFilter) {
        AppLogger.analytics.debug("Analytics filter updated to \(filter.timeRange.rawValue, privacy: .public)")
        filterSubject.send(filter)
        applyFilter()
    }

    func positionHistory(symbol: String) -> PositionHistorySummary {
        AppLogger.analytics.info("Position history opened for \(symbol, privacy: .public)")
        let symbolOrders = latestOrders
            .filter { $0.symbol == symbol }
            .sorted(by: { $0.executedAt > $1.executedAt })
        let symbolActivity = latestActivity
            .filter { $0.symbol == symbol }
            .sorted(by: { $0.timestamp > $1.timestamp })

        guard symbolOrders.isEmpty == false || symbolActivity.isEmpty == false else {
            return .empty(symbol: symbol)
        }

        let buys = symbolOrders.filter { $0.side == .buy }
        let sells = symbolOrders.filter { $0.side == .sell }

        let boughtQty = buys.reduce(Decimal.zero) { $0 + $1.quantity }
        let soldQty = sells.reduce(Decimal.zero) { $0 + $1.quantity }

        let averageEntry: Decimal?
        if boughtQty > 0 {
            let boughtNotional = buys.reduce(Decimal.zero) { $0 + $1.grossValue }
            averageEntry = boughtNotional / boughtQty
        } else {
            averageEntry = nil
        }

        let averageExit: Decimal?
        if soldQty > 0 {
            let soldNotional = sells.reduce(Decimal.zero) { $0 + $1.grossValue }
            averageExit = soldNotional / soldQty
        } else {
            averageExit = nil
        }

        let realized = latestRealized
            .filter { $0.symbol == symbol }
            .reduce(Decimal.zero) { $0 + $1.realizedPnL }

        return PositionHistorySummary(
            symbol: symbol,
            totalBoughtQuantity: boughtQty,
            totalSoldQuantity: soldQty,
            averageEntryPrice: averageEntry,
            averageExitPrice: averageExit,
            realizedPnL: realized,
            orders: symbolOrders,
            activities: symbolActivity
        )
    }

    private func bind() {
        repository.orderHistoryPublisher
            .sink { [weak self] orders in
                self?.latestOrders = orders
                self?.recompute()
            }
            .store(in: &cancellables)

        repository.activityTimelinePublisher
            .sink { [weak self] events in
                self?.latestActivity = events
                self?.recompute()
            }
            .store(in: &cancellables)

        repository.realizedPnLPublisher
            .sink { [weak self] realized in
                self?.latestRealized = realized
                self?.recompute()
            }
            .store(in: &cancellables)

        repository.summaryPublisher
            .sink { [weak self] summary in
                self?.latestSummary = summary
                self?.recompute()
            }
            .store(in: &cancellables)
    }

    private func recompute() {
        AppLogger.analytics.debug("Analytics recompute started")
        let summary = makeSummary()
        let performance = makePerformancePoints(summary: summary)
        summarySubject.send(summary)
        performanceSubject.send(performance)

        let symbols = Set(latestOrders.map(\.symbol)).union(latestActivity.map(\.symbol))
        availableSymbolsSubject.send(symbols.sorted())
        applyFilter()
        AppLogger.analytics.debug("Analytics recompute finished")
    }

    private func applyFilter() {
        let filter = filterSubject.value
        let now = nowProvider()
        let filteredOrders = latestOrders.filter { order in
            filter.contains(date: order.executedAt, referenceDate: now)
                && filter.allowsSymbol(order.symbol)
                && (filter.eventKinds.isEmpty || filter.allows(kind: order.side == .buy ? .buy : .sell))
        }
        let filteredActivity = latestActivity.filter { event in
            filter.contains(date: event.timestamp, referenceDate: now)
                && filter.allowsSymbol(event.symbol)
                && filter.allows(kind: event.kind)
        }

        filteredOrdersSubject.send(filteredOrders)
        filteredActivitySubject.send(filteredActivity)
    }

    private func makeSummary() -> PortfolioAnalyticsSummary {
        let closed = latestRealized
        let wins = closed.map(\.realizedPnL).filter { $0 > 0 }
        let losses = closed.map(\.realizedPnL).filter { $0 < 0 }

        let averageWin = wins.isEmpty ? nil : wins.reduce(Decimal.zero, +) / Decimal(wins.count)
        let averageLoss = losses.isEmpty ? nil : losses.reduce(Decimal.zero, +) / Decimal(losses.count)
        let totalWins = wins.reduce(Decimal.zero, +)
        let totalLossMagnitude = losses.reduce(Decimal.zero) { $0 + abs($1) }
        let winRate = closed.isEmpty ? nil : (Decimal(wins.count) / Decimal(closed.count))
        let profitFactor: Decimal?
        if totalLossMagnitude == 0 {
            profitFactor = totalWins > 0 ? Decimal.greatestFiniteMagnitude : nil
        } else {
            profitFactor = totalWins / totalLossMagnitude
        }

        let bestTrade = closed.map(\.realizedPnL).max()
        let worstTrade = closed.map(\.realizedPnL).min()

        let currentEquity = latestSummary.totalEquity
        let inferredStartingBalance = currentEquity - latestSummary.realizedPnL - latestSummary.unrealizedPnL
        let safeStartingBalance = inferredStartingBalance > 0 ? inferredStartingBalance : nil
        let netReturnPercent: Decimal?
        if let safeStartingBalance, safeStartingBalance > 0 {
            netReturnPercent = ((currentEquity - safeStartingBalance) / safeStartingBalance) * 100
        } else {
            netReturnPercent = nil
        }

        return PortfolioAnalyticsSummary(
            totalRealizedPnL: latestSummary.realizedPnL,
            totalUnrealizedPnL: latestSummary.unrealizedPnL,
            averageWin: averageWin,
            averageLoss: averageLoss,
            profitFactor: profitFactor,
            winRate: winRate,
            totalClosedTrades: closed.count,
            bestTrade: bestTrade,
            worstTrade: worstTrade,
            currentEquity: currentEquity,
            startingBalance: safeStartingBalance,
            netReturnPercent: netReturnPercent
        )
    }

    private func makePerformancePoints(summary: PortfolioAnalyticsSummary) -> [PerformancePoint] {
        let sortedActivity = latestActivity.sorted(by: { $0.timestamp < $1.timestamp })
        let ordersByID = Dictionary(uniqueKeysWithValues: latestOrders.map { ($0.id, $0) })

        let inferredStartingBalance = summary.startingBalance ?? latestSummary.cashBalance
        var runningCash = inferredStartingBalance
        var cumulativeRealized = Decimal.zero
        var points: [PerformancePoint] = []

        for event in sortedActivity {
            if let order = ordersByID[event.orderID] {
                switch order.side {
                case .buy:
                    runningCash -= order.grossValue
                case .sell:
                    runningCash += order.grossValue
                }
            }

            cumulativeRealized += event.realizedPnL ?? 0
            let equity = inferredStartingBalance + cumulativeRealized
            points.append(
                PerformancePoint(
                    timestamp: event.timestamp,
                    equity: equity,
                    cashBalance: runningCash,
                    unrealizedPnL: 0,
                    cumulativeRealizedPnL: cumulativeRealized
                )
            )
        }

        points.append(
            PerformancePoint(
                timestamp: nowProvider(),
                equity: latestSummary.totalEquity,
                cashBalance: latestSummary.cashBalance,
                unrealizedPnL: latestSummary.unrealizedPnL,
                cumulativeRealizedPnL: latestSummary.realizedPnL
            )
        )

        return points.sorted(by: { $0.timestamp < $1.timestamp })
    }
}
