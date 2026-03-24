import Combine
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let environmentProvider: EnvironmentProviding
    let configuration: AppConfiguration
    let marketDataRepository: MarketDataRepository
    let portfolioRepository: PortfolioRepository
    let tradingSimulationService: TradingSimulationService
    let analyticsService: PortfolioAnalyticsService
    let csvExportService: CSVExportService
    let checkpointService: AccountSnapshotCheckpointing
    let preferencesStore: AppPreferencesProviding
    let insightService: LocalInsightSummaryService
    let lifecycleCoordinator: AppLifecycleCoordinator

    private init(
        environmentProvider: EnvironmentProviding,
        configuration: AppConfiguration,
        marketDataRepository: MarketDataRepository,
        portfolioRepository: PortfolioRepository,
        tradingSimulationService: TradingSimulationService,
        analyticsService: PortfolioAnalyticsService,
        csvExportService: CSVExportService,
        checkpointService: AccountSnapshotCheckpointing,
        preferencesStore: AppPreferencesProviding,
        insightService: LocalInsightSummaryService,
        lifecycleCoordinator: AppLifecycleCoordinator
    ) {
        self.environmentProvider = environmentProvider
        self.configuration = configuration
        self.marketDataRepository = marketDataRepository
        self.portfolioRepository = portfolioRepository
        self.tradingSimulationService = tradingSimulationService
        self.analyticsService = analyticsService
        self.csvExportService = csvExportService
        self.checkpointService = checkpointService
        self.preferencesStore = preferencesStore
        self.insightService = insightService
        self.lifecycleCoordinator = lifecycleCoordinator
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
        let checkpointService = DefaultAccountSnapshotCheckpointService(
            portfolioRepository: portfolioRepository,
            environmentProvider: environmentProvider,
            snapshotStore: FileBackedAccountSnapshotStore()
        )
        let tradingSimulationService = DefaultTradingSimulationService(
            marketDataRepository: marketDataRepository,
            portfolioRepository: portfolioRepository,
            checkpointService: checkpointService,
            supportedSymbols: configuration.enabledAssets.map(\.symbol)
        )
        let analyticsService = DefaultPortfolioAnalyticsService(
            repository: portfolioRepository,
            checkpointService: checkpointService,
            environmentProvider: environmentProvider
        )
        let csvExportService = DefaultCSVExportService()
        let preferencesStore = UserDefaultsAppPreferencesStore()
        let insightService = LocalInsightSummaryService()

        let lifecycleCoordinator = AppLifecycleCoordinator(
            marketDataRepository: marketDataRepository,
            checkpointService: checkpointService,
            stateStore: UserDefaultsUIStateRestorationStore()
        )

        return AppContainer(
            environmentProvider: environmentProvider,
            configuration: configuration,
            marketDataRepository: marketDataRepository,
            portfolioRepository: portfolioRepository,
            tradingSimulationService: tradingSimulationService,
            analyticsService: analyticsService,
            csvExportService: csvExportService,
            checkpointService: checkpointService,
            preferencesStore: preferencesStore,
            insightService: insightService,
            lifecycleCoordinator: lifecycleCoordinator
        )
    }

    func makeWatchlistViewModel() -> WatchlistViewModel {
        WatchlistViewModel(marketDataRepository: marketDataRepository, assets: configuration.enabledAssets)
    }

    func makePortfolioViewModel() -> PortfolioViewModel {
        PortfolioViewModel(
            portfolioRepository: portfolioRepository,
            analyticsService: analyticsService,
            preferencesStore: preferencesStore,
            insightService: insightService
        )
    }

    func makeOrdersViewModel() -> OrdersViewModel {
        OrdersViewModel(
            analyticsService: analyticsService,
            csvExportService: csvExportService,
            initialRange: lifecycleCoordinator.restoreHistoryRange(),
            onRangeChanged: {[weak self] range in
                self?.lifecycleCoordinator.persistHistoryRange(range)
            }
        )
    }

    func makeAnalyticsViewModel() -> AnalyticsViewModel {
        AnalyticsViewModel(
            analyticsService: analyticsService,
            initialRange: lifecycleCoordinator.restoreAnalyticsRange(),
            onRangeChanged: { [weak self]range in
                self?.lifecycleCoordinator.persistAnalyticsRange(range)
            }
        )
    }

    func makePositionHistoryViewModel(symbol: String) -> PositionHistoryViewModel {
        PositionHistoryViewModel(symbol: symbol, analyticsService: analyticsService)
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
            tradingSimulationService: tradingSimulationService,
            preferencesStore: preferencesStore,
            tradeInsightService: insightService
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
