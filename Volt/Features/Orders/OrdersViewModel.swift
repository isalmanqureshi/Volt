import Combine
import Foundation

@MainActor
final class OrdersViewModel: ObservableObject {
    enum Segment: String, CaseIterable {
        case orders = "Orders"
        case activity = "Activity"
    }

    @Published var selectedSegment: Segment = .orders
    @Published private(set) var orders: [OrderRecord] = []
    @Published private(set) var activity: [ActivityEvent] = []

    init(portfolioRepository: PortfolioRepository) {
        portfolioRepository.orderHistoryPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$orders)

        portfolioRepository.activityTimelinePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$activity)
    }
}
