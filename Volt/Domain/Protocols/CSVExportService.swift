import Foundation

protocol CSVExportService {
    func exportLedger(orders: [OrderRecord], activity: [ActivityEvent]) throws -> URL
}

enum CSVExportError: LocalizedError {
    case noData
    case failedToEncode
    case failedToWrite

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No history data is available to export."
        case .failedToEncode:
            return "Could not build CSV export data."
        case .failedToWrite:
            return "Could not write CSV file to local storage."
        }
    }
}
