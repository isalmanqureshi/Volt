import SwiftUI
import Foundation
internal import os

@MainActor
final class AppLifecycleCoordinator {
    enum Tab: String, Codable {
        case watchlist
        case portfolio
        case history
        case analytics
        case settings
    }

    private let marketDataRepository: MarketDataRepository
    private let checkpointService: AccountSnapshotCheckpointing
    private let stateStore: UIStateRestorationStore

    init(
        marketDataRepository: MarketDataRepository,
        checkpointService: AccountSnapshotCheckpointing,
        stateStore: UIStateRestorationStore
    ) {
        self.marketDataRepository = marketDataRepository
        self.checkpointService = checkpointService
        self.stateStore = stateStore
    }

    func onLaunch() async {
        AppLogger.app.info("Lifecycle launch start")
        await marketDataRepository.start()
        checkpointService.checkpoint(trigger: .appLaunch)
    }


    func applyRuntimeProfileSwitch(to environment: TradingEnvironment) async {
        AppLogger.app.info("Runtime profile switch orchestration start env=\(environment.rawValue, privacy: .public)")
        await marketDataRepository.manualRefresh()
        checkpointService.checkpoint(trigger: .manualRefresh)
        AppLogger.app.info("Runtime profile switch orchestration end env=\(environment.rawValue, privacy: .public)")
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            AppLogger.app.info("Lifecycle scene active")
            Task {
                await marketDataRepository.handleForegroundResume(at: Date())
                checkpointService.checkpoint(trigger: .lifecycleResume)
            }
        case .background:
            AppLogger.app.info("Lifecycle scene background")
            marketDataRepository.handleBackgroundTransition(at: Date())
            checkpointService.checkpoint(trigger: .appBackground)
        case .inactive:
            AppLogger.app.debug("Lifecycle scene inactive")
        @unknown default:
            AppLogger.app.warning("Lifecycle scene unknown case")
        }
    }

    func restoreTab() -> Tab {
        stateStore.loadState()?.selectedTab ?? .watchlist
    }

    func persistTab(_ tab: Tab) {
        var state = stateStore.loadState() ?? .init(selectedTab: .watchlist, analyticsRange: .thirtyDays, historyRange: .all, selectedEnvironment: nil)
        state.selectedTab = tab
        stateStore.saveState(state)
    }

    func restoreAnalyticsRange() -> AnalyticsTimeRange {
        stateStore.loadState()?.analyticsRange ?? .thirtyDays
    }

    func persistAnalyticsRange(_ range: AnalyticsTimeRange) {
        var state = stateStore.loadState() ?? .init(selectedTab: .watchlist, analyticsRange: .thirtyDays, historyRange: .all, selectedEnvironment: nil)
        state.analyticsRange = range
        stateStore.saveState(state)
    }

    func restoreHistoryRange() -> AnalyticsTimeRange {
        stateStore.loadState()?.historyRange ?? .all
    }

    func persistHistoryRange(_ range: AnalyticsTimeRange) {
        var state = stateStore.loadState() ?? .init(selectedTab: .watchlist, analyticsRange: .thirtyDays, historyRange: .all, selectedEnvironment: nil)
        state.historyRange = range
        stateStore.saveState(state)
    }
}

struct UIStateRestorationPayload: Codable, Sendable {
    var selectedTab: AppLifecycleCoordinator.Tab
    var analyticsRange: AnalyticsTimeRange
    var historyRange: AnalyticsTimeRange
    var selectedEnvironment: TradingEnvironment?
}

protocol UIStateRestorationStore {
    func loadState() -> UIStateRestorationPayload?
    func saveState(_ payload: UIStateRestorationPayload)
}

struct UserDefaultsUIStateRestorationStore: UIStateRestorationStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "volt.ui_restoration") {
        self.defaults = defaults
        self.key = key
    }

    func loadState() -> UIStateRestorationPayload? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(UIStateRestorationPayload.self, from: data)
        } catch {
            AppLogger.app.error("UI restoration decode failed; clearing payload")
            defaults.removeObject(forKey: key)
            return nil
        }
    }

    func saveState(_ payload: UIStateRestorationPayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.app.error("UI restoration save failed")
        }
    }
}
