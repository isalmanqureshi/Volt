import Combine
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let environmentProvider: EnvironmentProviding
    let configuration: AppConfiguration
    let marketDataRepository: MarketDataRepository
    let portfolioRepository: PortfolioRepository
    let tradingSimulationService: TradingSimulationService

    private init(
        environmentProvider: EnvironmentProviding,
        configuration: AppConfiguration,
        marketDataRepository: MarketDataRepository,
        portfolioRepository: PortfolioRepository,
        tradingSimulationService: TradingSimulationService
    ) {
        self.environmentProvider = environmentProvider
        self.configuration = configuration
        self.marketDataRepository = marketDataRepository
        self.portfolioRepository = portfolioRepository
        self.tradingSimulationService = tradingSimulationService
    }

    static func bootstrap() -> AppContainer {
        let configuration = AppConfiguration.current()
        let environmentProvider = AppEnvironmentProvider(currentEnvironment: configuration.environment)
        let seedProvider: MarketSeedProvider
        let historicalDataProvider: HistoricalDataProvider
        switch environmentProvider.currentEnvironment {
        case .mock:
            seedProvider = MockMarketSeedProvider()
            historicalDataProvider = MockHistoricalDataProvider()
        case .twelveDataSeededSimulation:
            seedProvider = TwelveDataMarketSeedProvider(
                baseURL: configuration.twelveDataBaseURL,
                apiKey: configuration.twelveDataAPIKey
            )
            historicalDataProvider = TwelveDataHistoricalDataProvider(
                baseURL: configuration.twelveDataBaseURL,
                apiKey: configuration.twelveDataAPIKey
            )
        }

        let simulationEngine = DefaultMarketSimulationEngine(config: configuration.simulationConfig)
        let marketDataRepository = DefaultMarketDataRepository(
            seedProvider: seedProvider,
            historicalDataProvider: historicalDataProvider,
            simulationEngine: simulationEngine,
            symbols: configuration.enabledAssets.map(\.symbol),
            defaultCandleOutputSize: configuration.defaultCandleOutputSize
        )
        let portfolioRepository = InMemoryPortfolioRepository(
            marketDataRepository: marketDataRepository,
            cashBalance: configuration.demoInitialCashBalance,
            persistenceStore: FileBackedPortfolioPersistenceStore()
        )
        let tradingSimulationService = DefaultTradingSimulationService(
            marketDataRepository: marketDataRepository,
            portfolioRepository: portfolioRepository,
            supportedSymbols: configuration.enabledAssets.map(\.symbol)
        )

        let container = AppContainer(
            environmentProvider: environmentProvider,
            configuration: configuration,
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
        WatchlistViewModel(marketDataRepository: marketDataRepository, assets: configuration.enabledAssets)
    }

    func makePortfolioViewModel() -> PortfolioViewModel {
        PortfolioViewModel(portfolioRepository: portfolioRepository)
    }

    func makeOrdersViewModel() -> OrdersViewModel {
        OrdersViewModel(portfolioRepository: portfolioRepository)
    }

    func makeAssetDetailViewModel(asset: Asset) -> AssetDetailViewModel {
        AssetDetailViewModel(
            asset: asset,
            marketDataRepository: marketDataRepository,
            portfolioRepository: portfolioRepository,
            defaultCandleOutputSize: configuration.defaultCandleOutputSize
        )
    }

    func makeTradeTicketViewModel(asset: Asset, side: OrderSide) -> TradeTicketViewModel {
        TradeTicketViewModel(
            asset: asset,
            side: side,
            marketDataRepository: marketDataRepository,
            portfolioRepository: portfolioRepository,
            tradingSimulationService: tradingSimulationService
        )
    }

    func makeClosePositionViewModel(position: Position) -> ClosePositionViewModel {
        ClosePositionViewModel(
            position: position,
            marketDataRepository: marketDataRepository,
            tradingSimulationService: tradingSimulationService
        )
    }
}
