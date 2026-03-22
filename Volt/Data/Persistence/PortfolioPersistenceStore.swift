import Foundation

protocol PortfolioPersistenceStore {
    func loadState() throws -> PersistedPortfolioState?
    func saveState(_ state: PersistedPortfolioState) throws
}

enum PortfolioPersistenceError: Error {
    case failedToCreateDirectory
    case failedToDecode
    case failedToEncode
    case failedToWrite
}
