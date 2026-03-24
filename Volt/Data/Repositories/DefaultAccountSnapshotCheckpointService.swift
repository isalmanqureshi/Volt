import Combine
import Foundation
internal import os

final class DefaultAccountSnapshotCheckpointService: AccountSnapshotCheckpointing {
    private let portfolioRepository: PortfolioRepository
    private let environmentProvider: EnvironmentProviding
    private let snapshotStore: AccountSnapshotStore
    private let nowProvider: () -> Date
    private let minimumCheckpointInterval: TimeInterval
    private let maxCheckpointCount: Int

    private(set) var checkpoints: [AccountSnapshotCheckpoint]
    private var latestSummary: PortfolioSummary
    private var latestOpenPositionCount: Int
    private var cancellables = Set<AnyCancellable>()
    private var lastCheckpointDate: Date?

    init(
        portfolioRepository: PortfolioRepository,
        environmentProvider: EnvironmentProviding,
        snapshotStore: AccountSnapshotStore,
        minimumCheckpointInterval: TimeInterval = 60,
        maxCheckpointCount: Int = 2_000,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.portfolioRepository = portfolioRepository
        self.environmentProvider = environmentProvider
        self.snapshotStore = snapshotStore
        self.nowProvider = nowProvider
        self.minimumCheckpointInterval = minimumCheckpointInterval
        self.maxCheckpointCount = maxCheckpointCount
        self.latestSummary = portfolioRepository.currentSummary
        self.latestOpenPositionCount = portfolioRepository.currentPositions.count

        do {
            checkpoints = try snapshotStore.loadCheckpoints().sorted(by: { $0.timestamp < $1.timestamp })
            lastCheckpointDate = checkpoints.last?.timestamp
            AppLogger.analytics.info("Checkpoint restore succeeded count=\(self.checkpoints.count, privacy: .public)")
        } catch {
            checkpoints = []
            AppLogger.analytics.error("Checkpoint restore failed; continuing with empty set")
        }

        bind()
    }

    func checkpoint(trigger: AccountSnapshotCheckpoint.Trigger) {
        let now = nowProvider()
        if trigger == .periodic || trigger == .lifecycleResume {
            if let lastCheckpointDate,
               now.timeIntervalSince(lastCheckpointDate) < minimumCheckpointInterval {
                AppLogger.analytics.debug("Checkpoint throttled trigger=\(trigger.rawValue, privacy: .public)")
                return
            }
        }

        // Pull an immediate fresh snapshot to keep order-driven checkpoints internally
        // consistent even when publisher emission ordering differs during mutations.
        latestSummary = portfolioRepository.currentSummary
        latestOpenPositionCount = portfolioRepository.currentPositions.count

        let checkpoint = AccountSnapshotCheckpoint(
            timestamp: now,
            cashBalance: latestSummary.cashBalance,
            positionsMarketValue: latestSummary.positionsMarketValue,
            unrealizedPnL: latestSummary.unrealizedPnL,
            realizedPnL: latestSummary.realizedPnL,
            totalEquity: latestSummary.totalEquity,
            openPositionsCount: latestOpenPositionCount,
            environment: environmentProvider.currentEnvironment,
            trigger: trigger
        )
        checkpoints.append(checkpoint)
        if checkpoints.count > maxCheckpointCount {
            checkpoints = Array(checkpoints.suffix(maxCheckpointCount))
        }
        lastCheckpointDate = checkpoint.timestamp

        do {
            try snapshotStore.saveCheckpoints(checkpoints)
            AppLogger.analytics.info("Checkpoint persisted trigger=\(trigger.rawValue, privacy: .public)")
        } catch {
            AppLogger.analytics.error("Checkpoint persistence failed trigger=\(trigger.rawValue, privacy: .public)")
        }
    }

    private func bind() {
        portfolioRepository.summaryPublisher
            .sink { [weak self] summary in
                self?.latestSummary = summary
            }
            .store(in: &cancellables)

        portfolioRepository.positionsPublisher
            .sink { [weak self] positions in
                self?.latestOpenPositionCount = positions.count
            }
            .store(in: &cancellables)

        // Order execution checkpoints are intentionally triggered by the trading
        // service after repository mutation + summary recomputation completes.
    }
}
