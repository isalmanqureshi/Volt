import Foundation
internal import os

@MainActor
final class DefaultDemoScenarioBootstrapService: DemoScenarioBootstrapping {
    let scenarios: [DemoScenario] = DemoScenario.all

    private let portfolioRepository: PortfolioRepository
    private let preferencesStore: AppPreferencesProviding
    private let marketDataRepository: MarketDataRepository

    init(
        portfolioRepository: PortfolioRepository,
        preferencesStore: AppPreferencesProviding,
        marketDataRepository: MarketDataRepository
    ) {
        self.portfolioRepository = portfolioRepository
        self.preferencesStore = preferencesStore
        self.marketDataRepository = marketDataRepository
    }

    func applyScenario(id: String) {
        guard let scenario = scenarios.first(where: { $0.id == id }) else { return }
        portfolioRepository.replaceState(scenario.state)
        preferencesStore.update {
            $0.selectedEnvironment = .mock
            $0.activeDemoScenarioID = scenario.id
        }
        AppLogger.scenario.info("Deterministic scenario applied id=\(scenario.id, privacy: .public)")
        Task { await marketDataRepository.manualRefresh() }
    }

    func resetScenario() {
        portfolioRepository.replaceState(DemoScenario.emptyNewUser.state)
        preferencesStore.update { $0.activeDemoScenarioID = nil }
        AppLogger.scenario.info("Deterministic scenario reset")
    }
}
