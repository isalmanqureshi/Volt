import Combine
import Foundation

protocol PortfolioRepository {
    var positionsPublisher: AnyPublisher<[Position], Never> { get }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { get }
    var currentPositions: [Position] { get }
    var currentSummary: PortfolioSummary { get }

    @discardableResult
    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> Position
}
