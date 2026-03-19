import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let environmentProvider: EnvironmentProviding
    let marketDataRepository: MarketDataRepository
    let portfolioRepository: PortfolioRepository
    let tradingSimulationService: TradingSimulationService

    private init(
        environmentProvider: EnvironmentProviding,
        marketDataRepository: MarketDataRepository,
        portfolioRepository: PortfolioRepository,
        tradingSimulationService: TradingSimulationService
    ) {
        self.environmentProvider = environmentProvider
        self.marketDataRepository = marketDataRepository
        self.portfolioRepository = portfolioRepository
        self.tradingSimulationService = tradingSimulationService
    }

    static func bootstrap() -> AppContainer {
        let environmentProvider = AppEnvironmentProvider(currentEnvironment: .mock)
        let seedProvider: MarketSeedProvider
        switch environmentProvider.currentEnvironment {
        case .mock:
            seedProvider = MockMarketSeedProvider()
        case .twelveDataSeededSimulation:
            seedProvider = TwelveDataMarketSeedProvider()
        }

        let simulationEngine = DefaultMarketSimulationEngine()
        let marketDataRepository = DefaultMarketDataRepository(
            seedProvider: seedProvider,
            simulationEngine: simulationEngine,
            symbols: SupportedAssets.demoAssets.map(\.symbol)
        )
        let portfolioRepository = InMemoryPortfolioRepository()
        let tradingSimulationService = DefaultTradingSimulationService()

        let container = AppContainer(
            environmentProvider: environmentProvider,
            marketDataRepository: marketDataRepository,
            portfolioRepository: portfolioRepository,
            tradingSimulationService: tradingSimulationService
        )

        Task {
            await marketDataRepository.start()
        }

        return container
    }

    func makeWatchlistViewModel() -> WatchlistViewModel {
        WatchlistViewModel(marketDataRepository: marketDataRepository, assets: SupportedAssets.demoAssets)
    }

    func makePortfolioViewModel() -> PortfolioViewModel {
        PortfolioViewModel(portfolioRepository: portfolioRepository)
    }
}
