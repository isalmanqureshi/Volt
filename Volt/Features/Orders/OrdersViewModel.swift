import Combine
import Foundation

@MainActor
final class OrdersViewModel: ObservableObject {
    enum Segment: String, CaseIterable {
        case orders = "Orders"
        case activity = "Activity"
    }

    @Published var selectedSegment: Segment = .orders
    @Published var selectedRange: AnalyticsTimeRange = .all { didSet { applyFilter() } }
    @Published var selectedSymbol: String? = nil { didSet { applyFilter() } }
    @Published var selectedEventKinds: Set<ActivityEvent.Kind> = [] { didSet { applyFilter() } }
    @Published private(set) var orders: [OrderRecord] = []
    @Published private(set) var activity: [ActivityEvent] = []
    @Published private(set) var availableSymbols: [String] = []
    @Published private(set) var exportURL: URL?
    @Published var exportError: String?

    private let analyticsService: PortfolioAnalyticsService
    private let csvExportService: CSVExportService
    private var rawOrders: [OrderRecord] = []
    private var rawActivity: [ActivityEvent] = []

    init(analyticsService: PortfolioAnalyticsService, csvExportService: CSVExportService) {
        self.analyticsService = analyticsService
        self.csvExportService = csvExportService

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

        selectedRange = analyticsService.currentFilter.timeRange
        selectedSymbol = analyticsService.currentFilter.symbol
        selectedEventKinds = analyticsService.currentFilter.eventKinds
        applyFilter()
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
            exportURL = try csvExportService.exportLedger(orders: rawOrders, activity: rawActivity)
            exportError = nil
        } catch {
            exportError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private func applyFilter() {
        var filter = analyticsService.currentFilter
        filter.timeRange = selectedRange
        filter.symbol = selectedSymbol
        filter.eventKinds = selectedEventKinds
        analyticsService.updateFilter(filter)
    }
}
