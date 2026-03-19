import Combine
import Foundation

protocol PortfolioRepository {
    var positionsPublisher: AnyPublisher<[Position], Never> { get }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { get }
}
