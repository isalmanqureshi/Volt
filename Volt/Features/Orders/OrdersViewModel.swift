import Combine
import Foundation

@MainActor
final class OrdersViewModel: ObservableObject {
    enum Segment: String, CaseIterable {
        case orders = "Orders"
        case activity = "Activity"
    }

    @Published var selectedSegment: Segment = .orders
    @Published var selectedRange: AnalyticsTimeRange = .all {
        didSet {
            applyFilter()
            onRangeChanged?(selectedRange)
        }
    }
    @Published var selectedSymbol: String? = nil { didSet { applyFilter() } }
    @Published var selectedEventKinds: Set<ActivityEvent.Kind> = [] { didSet { applyFilter() } }
    @Published var selectedExportPreset: AnalyticsExportPreset = .fullActivity
    @Published private(set) var orders: [OrderRecord] = []
    @Published private(set) var activity: [ActivityEvent] = []
    @Published private(set) var availableSymbols: [String] = []
    @Published private(set) var exportURL: URL?
    @Published var exportError: String?
    @Published private(set) var insightCards: [InsightCardModel] = []

    private let analyticsService: PortfolioAnalyticsService
    private let csvExportService: CSVExportService
    private let onRangeChanged: ((AnalyticsTimeRange) -> Void)?
    private let preferencesStore: AppPreferencesProviding
    private let insightService: HistoryInsightService
    private var rawOrders: [OrderRecord] = []
    private var rawActivity: [ActivityEvent] = []
    private var cancellables = Set<AnyCancellable>()

    init(
        analyticsService: PortfolioAnalyticsService,
        csvExportService: CSVExportService,
        initialRange: AnalyticsTimeRange? = nil,
        preferencesStore: AppPreferencesProviding = UserDefaultsAppPreferencesStore(),
        insightService: HistoryInsightService = LocalInsightSummaryService(),
        onRangeChanged: ((AnalyticsTimeRange) -> Void)? = nil
    ) {
        self.analyticsService = analyticsService
        self.csvExportService = csvExportService
        self.preferencesStore = preferencesStore
        self.insightService = insightService
        self.onRangeChanged = onRangeChanged

        analyticsService.filteredOrdersPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$orders)

        analyticsService.filteredActivityPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$activity)

        analyticsService.availableSymbolsPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$availableSymbols)

        analyticsService.filteredOrdersPublisher
            .sink { [weak self] value in
                self?.rawOrders = value
            }
            .store(in: &cancellables)

        analyticsService.filteredActivityPublisher
            .sink { [weak self] value in
                self?.rawActivity = value
            }
            .store(in: &cancellables)

        selectedRange = initialRange ?? analyticsService.currentFilter.timeRange
        selectedSymbol = analyticsService.currentFilter.symbol
        selectedEventKinds = analyticsService.currentFilter.eventKinds
        applyFilter()

        Publishers.CombineLatest3(analyticsService.filteredOrdersPublisher, analyticsService.filteredActivityPublisher, preferencesStore.preferencesPublisher)
            .map { [weak self] orders, activity, prefs in
                guard let self else { return [] }
                let ctx = RuntimeProfileInsightContext(profileName: prefs.activeRuntimeProfile.name, environmentName: prefs.selectedEnvironment.displayName, slippage: prefs.simulatorRisk.slippagePreset, volatility: prefs.simulatorRisk.volatilityPreset)
                return self.insightService.makeInsights(orders: orders, activity: activity, context: ctx)
            }
            .receive(on: RunLoop.main)
            .assign(to: &$insightCards)
    }

    func toggleEventKind(_ kind: ActivityEvent.Kind) {
        if selectedEventKinds.contains(kind) {
            selectedEventKinds.remove(kind)
        } else {
            selectedEventKinds.insert(kind)
        }
    }

    func clearSymbolFilter() {
        selectedSymbol = nil
    }

    func exportCSV() {
        do {
            exportURL = try csvExportService.export(
                preset: selectedExportPreset,
                orders: rawOrders,
                activity: rawActivity,
                summary: analyticsService.currentSummary
            )
            exportError = nil
        } catch {
            exportError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func applyFilter() {
        var filter = analyticsService.currentFilter
        filter.timeRange = selectedRange
        filter.symbol = selectedSymbol
        filter.eventKinds = selectedEventKinds
        analyticsService.updateFilter(filter)
    }
}
