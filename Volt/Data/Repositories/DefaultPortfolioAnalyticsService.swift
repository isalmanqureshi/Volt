import Combine
import Foundation
internal import os

final class DefaultPortfolioAnalyticsService: PortfolioAnalyticsService {
    private let repository: PortfolioRepository
    private let checkpointService: AccountSnapshotCheckpointing?
    private let environmentProvider: EnvironmentProviding?
    private let nowProvider: () -> Date
    private let computeQueue = DispatchQueue(label: "com.volt.analytics.compute", qos: .utility)

    private let summarySubject = CurrentValueSubject<PortfolioAnalyticsSummary, Never>(.empty)
    private let performanceSubject = CurrentValueSubject<[PerformancePoint], Never>([])
    private let dailyPerformanceSubject = CurrentValueSubject<[DailyPerformanceBucket], Never>([])
    private let realizedDistributionSubject = CurrentValueSubject<[RealizedDistributionBucket], Never>([])
    private let filterSubject = CurrentValueSubject<HistoryFilter, Never>(.default)
    private let filteredOrdersSubject = CurrentValueSubject<[OrderRecord], Never>([])
    private let filteredActivitySubject = CurrentValueSubject<[ActivityEvent], Never>([])
    private let availableSymbolsSubject = CurrentValueSubject<[String], Never>([])

    private var latestOrders: [OrderRecord] = []
    private var latestActivity: [ActivityEvent] = []
    private var latestRealized: [RealizedPnLEntry] = []
    private var latestSummary: PortfolioSummary = .init(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 0, dayChange: 0)
    private var latestOrdersBySymbol: [String: [OrderRecord]] = [:]
    private var latestActivityBySymbol: [String: [ActivityEvent]] = [:]
    private var sortedActivityAscending: [ActivityEvent] = []
    private var basePerformancePoints: [PerformancePoint] = []
    private var realizedAggregates = RealizedAggregates()
    private var cancellables = Set<AnyCancellable>()

    private(set) var structuralRecomputeCount = 0
    private(set) var summaryOnlyUpdateCount = 0

    var summaryPublisher: AnyPublisher<PortfolioAnalyticsSummary, Never> { summarySubject.eraseToAnyPublisher() }
    var performancePublisher: AnyPublisher<[PerformancePoint], Never> { performanceSubject.eraseToAnyPublisher() }
    var dailyPerformancePublisher: AnyPublisher<[DailyPerformanceBucket], Never> { dailyPerformanceSubject.eraseToAnyPublisher() }
    var realizedDistributionPublisher: AnyPublisher<[RealizedDistributionBucket], Never> { realizedDistributionSubject.eraseToAnyPublisher() }
    var filteredOrdersPublisher: AnyPublisher<[OrderRecord], Never> { filteredOrdersSubject.eraseToAnyPublisher() }
    var filteredActivityPublisher: AnyPublisher<[ActivityEvent], Never> { filteredActivitySubject.eraseToAnyPublisher() }
    var availableSymbolsPublisher: AnyPublisher<[String], Never> { availableSymbolsSubject.eraseToAnyPublisher() }

    var currentSummary: PortfolioAnalyticsSummary { summarySubject.value }
    var currentPerformance: [PerformancePoint] { performanceSubject.value }
    var currentDailyPerformance: [DailyPerformanceBucket] { dailyPerformanceSubject.value }
    var currentRealizedDistribution: [RealizedDistributionBucket] { realizedDistributionSubject.value }
    var currentFilter: HistoryFilter { filterSubject.value }

    init(
        repository: PortfolioRepository,
        checkpointService: AccountSnapshotCheckpointing? = nil,
        environmentProvider: EnvironmentProviding? = nil,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.checkpointService = checkpointService
        self.environmentProvider = environmentProvider
        self.nowProvider = nowProvider
        bind()
    }

    func updateFilter(_ filter: HistoryFilter) {
        AppLogger.analytics.debug("Analytics filter updated to \(filter.timeRange.rawValue, privacy: .public)")
        computeQueue.async { [weak self] in
            guard let self else { return }
            self.filterSubject.send(filter)
            self.applyFilter()
        }
    }

    func positionHistory(symbol: String) -> PositionHistorySummary {
        AppLogger.analytics.info("Position history opened for \(symbol, privacy: .public)")
        let symbolOrders = latestOrdersBySymbol[symbol] ?? []
        let symbolActivity = latestActivityBySymbol[symbol] ?? []

        guard symbolOrders.isEmpty == false || symbolActivity.isEmpty == false else {
            return .empty(symbol: symbol)
        }

        let buys = symbolOrders.filter { $0.side == .buy }
        let sells = symbolOrders.filter { $0.side == .sell }

        let boughtQty = buys.reduce(Decimal.zero) { $0 + $1.quantity }
        let soldQty = sells.reduce(Decimal.zero) { $0 + $1.quantity }

        let averageEntry = boughtQty > 0 ? buys.reduce(Decimal.zero) { $0 + $1.grossValue } / boughtQty : nil
        let averageExit = soldQty > 0 ? sells.reduce(Decimal.zero) { $0 + $1.grossValue } / soldQty : nil

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
            .receive(on: computeQueue)
            .sink { [weak self] orders in
                self?.latestOrders = orders
                self?.recomputeStructural()
            }
            .store(in: &cancellables)

        repository.activityTimelinePublisher
            .receive(on: computeQueue)
            .sink { [weak self] events in
                self?.latestActivity = events
                self?.recomputeStructural()
            }
            .store(in: &cancellables)

        repository.realizedPnLPublisher
            .receive(on: computeQueue)
            .sink { [weak self] realized in
                self?.latestRealized = realized
                self?.recomputeStructural()
            }
            .store(in: &cancellables)

        repository.summaryPublisher
            .receive(on: computeQueue)
            .sink { [weak self] summary in
                self?.latestSummary = summary
                self?.publishSummaryDrivenUpdate()
            }
            .store(in: &cancellables)
    }

    private func recomputeStructural() {
        let startedAt = Date()
        structuralRecomputeCount += 1

        latestOrdersBySymbol = Dictionary(grouping: latestOrders.sorted(by: { $0.executedAt > $1.executedAt }), by: \.symbol)
        latestActivityBySymbol = Dictionary(grouping: latestActivity.sorted(by: { $0.timestamp > $1.timestamp }), by: \.symbol)
        sortedActivityAscending = latestActivity.sorted(by: { $0.timestamp < $1.timestamp })
        basePerformancePoints = makeBasePerformancePoints()
        realizedAggregates = RealizedAggregates(entries: latestRealized)

        dailyPerformanceSubject.send(makeDailyBuckets())
        realizedDistributionSubject.send(makeDistributionBuckets())

        let symbols = Set(latestOrders.map(\.symbol)).union(latestActivity.map(\.symbol))
        availableSymbolsSubject.send(symbols.sorted())
        applyFilter()
        publishSummaryDrivenUpdate()

        AppLogger.analytics.debug("Analytics structural recompute duration=\(Date().timeIntervalSince(startedAt), privacy: .public)s orders=\(self.latestOrders.count, privacy: .public) activity=\(self.latestActivity.count, privacy: .public) count=\(self.structuralRecomputeCount, privacy: .public)")
    }

    private func publishSummaryDrivenUpdate() {
        summaryOnlyUpdateCount += 1
        let summary = makeSummary()
        summarySubject.send(summary)
        performanceSubject.send(makePerformancePoints(summary: summary))
    }

    private func applyFilter() {
        let filter = filterSubject.value
        let now = nowProvider()
        filteredOrdersSubject.send(
            latestOrders.filter { order in
                filter.contains(date: order.executedAt, referenceDate: now)
                    && filter.allowsSymbol(order.symbol)
                    && filter.allowsSide(order.side)
                    && (filter.eventKinds.isEmpty || filter.allows(kind: order.side == .buy ? .buy : .sell))
            }
        )
        filteredActivitySubject.send(
            latestActivity.filter { event in
                filter.contains(date: event.timestamp, referenceDate: now)
                    && filter.allowsSymbol(event.symbol)
                    && filter.allowsSide(ofKind: event.kind)
                    && filter.allows(kind: event.kind)
            }
        )
    }

    private func makeSummary() -> PortfolioAnalyticsSummary {
        // Aggregates are maintained by recomputeStructural (per trade event), so
        // this stays O(1) even though it runs on every summary emission.
        let aggregates = realizedAggregates
        let averageWin = aggregates.winCount > 0 ? aggregates.totalWins / Decimal(aggregates.winCount) : nil
        let averageLoss = aggregates.lossCount > 0 ? aggregates.totalLosses / Decimal(aggregates.lossCount) : nil
        let winRate = aggregates.closedCount > 0 ? (Decimal(aggregates.winCount) / Decimal(aggregates.closedCount)) : nil
        let profitFactor: Decimal? = aggregates.totalLossMagnitude == 0
            ? (aggregates.totalWins > 0 ? Decimal.greatestFiniteMagnitude : nil)
            : (aggregates.totalWins / aggregates.totalLossMagnitude)

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
            totalClosedTrades: aggregates.closedCount,
            bestTrade: aggregates.bestTrade,
            worstTrade: aggregates.worstTrade,
            currentEquity: currentEquity,
            startingBalance: safeStartingBalance,
            netReturnPercent: netReturnPercent
        )
    }

    private func makeBasePerformancePoints() -> [PerformancePoint] {
        let filteredCheckpoints: [AccountSnapshotCheckpoint] = {
            guard let checkpointService else { return [] }
            guard let environmentProvider else {
                return checkpointService.checkpoints
            }
            let environment = environmentProvider.currentEnvironment
            let matching = checkpointService.checkpoints.filter { $0.environment == environment }
            AppLogger.analytics.debug("Performance checkpoint filter env=\(environment.rawValue, privacy: .public) matched=\(matching.count, privacy: .public)")
            return matching
        }()

        var points: [PerformancePoint] = filteredCheckpoints.map {
            PerformancePoint(
                timestamp: $0.timestamp,
                equity: $0.totalEquity,
                cashBalance: $0.cashBalance,
                unrealizedPnL: $0.unrealizedPnL,
                cumulativeRealizedPnL: $0.realizedPnL
            )
        }

        if points.isEmpty {
            let inferredStartingBalance = latestSummary.totalEquity - latestSummary.realizedPnL - latestSummary.unrealizedPnL
            let safeStartingBalance = inferredStartingBalance > 0 ? inferredStartingBalance : latestSummary.cashBalance
            var cumulativeRealized = Decimal.zero
            for event in sortedActivityAscending {
                cumulativeRealized += event.realizedPnL ?? 0
                points.append(
                    PerformancePoint(
                        timestamp: event.timestamp,
                        equity: safeStartingBalance + cumulativeRealized,
                        cashBalance: latestSummary.cashBalance,
                        unrealizedPnL: 0,
                        cumulativeRealizedPnL: cumulativeRealized
                    )
                )
            }
        }

        return points.sorted(by: { $0.timestamp < $1.timestamp })
    }

    private func makePerformancePoints(summary: PortfolioAnalyticsSummary) -> [PerformancePoint] {
        // basePerformancePoints is kept sorted by recomputeStructural and the live
        // point is stamped "now", so appending preserves order without re-sorting
        // O(n log n) on every summary emission. The insert branch only runs if the
        // injected clock lags the newest checkpoint.
        var points = basePerformancePoints
        let livePoint = PerformancePoint(
            timestamp: nowProvider(),
            equity: latestSummary.totalEquity,
            cashBalance: latestSummary.cashBalance,
            unrealizedPnL: latestSummary.unrealizedPnL,
            cumulativeRealizedPnL: latestSummary.realizedPnL
        )
        if let last = points.last, last.timestamp > livePoint.timestamp {
            let insertionIndex = points.firstIndex(where: { $0.timestamp > livePoint.timestamp }) ?? points.endIndex
            points.insert(livePoint, at: insertionIndex)
        } else {
            points.append(livePoint)
        }
        return points
    }

    private func makeDailyBuckets(calendar: Calendar = .current) -> [DailyPerformanceBucket] {
        let grouped = Dictionary(grouping: latestRealized) { entry in
            calendar.startOfDay(for: entry.closedAt)
        }

        return grouped
            .map { day, entries in
                DailyPerformanceBucket(
                    day: day,
                    realizedPnL: entries.reduce(Decimal.zero) { $0 + $1.realizedPnL },
                    tradeCount: entries.count
                )
            }
            .sorted(by: { $0.day < $1.day })
    }

    /// Single-pass rollup of the realized-trade history. Recomputed only when the
    /// history changes (per trade), so the per-tick summary path never walks the
    /// full — unbounded — trade list.
    private struct RealizedAggregates {
        var closedCount = 0
        var winCount = 0
        var lossCount = 0
        var totalWins = Decimal.zero
        var totalLosses = Decimal.zero
        var totalLossMagnitude = Decimal.zero
        var bestTrade: Decimal?
        var worstTrade: Decimal?

        init() {}

        init(entries: [RealizedPnLEntry]) {
            closedCount = entries.count
            for entry in entries {
                let pnl = entry.realizedPnL
                if pnl > 0 {
                    winCount += 1
                    totalWins += pnl
                } else if pnl < 0 {
                    lossCount += 1
                    totalLosses += pnl
                    totalLossMagnitude += abs(pnl)
                }
                bestTrade = bestTrade.map { max($0, pnl) } ?? pnl
                worstTrade = worstTrade.map { min($0, pnl) } ?? pnl
            }
        }
    }

    private func makeDistributionBuckets() -> [RealizedDistributionBucket] {
        let gains = latestRealized.filter { $0.realizedPnL > 0 }
        let losses = latestRealized.filter { $0.realizedPnL < 0 }
        let flat = latestRealized.filter { $0.realizedPnL == 0 }

        return [
            RealizedDistributionBucket(id: "gains", label: "Gains", count: gains.count, totalPnL: gains.reduce(0) { $0 + $1.realizedPnL }, outcome: .gain),
            RealizedDistributionBucket(id: "losses", label: "Losses", count: losses.count, totalPnL: losses.reduce(0) { $0 + $1.realizedPnL }, outcome: .loss),
            RealizedDistributionBucket(id: "flat", label: "Flat", count: flat.count, totalPnL: flat.reduce(0) { $0 + $1.realizedPnL }, outcome: .flat)
        ]
    }
}
