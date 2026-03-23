import Foundation
internal import os

struct DefaultCSVExportService: CSVExportService {
    private let fileManager: FileManager
    private let outputDirectory: URL

    init(fileManager: FileManager = .default, outputDirectory: URL? = nil) {
        self.fileManager = fileManager
        if let outputDirectory {
            self.outputDirectory = outputDirectory
        } else {
            let temp = fileManager.temporaryDirectory.appendingPathComponent("VoltExports", isDirectory: true)
            self.outputDirectory = temp
        }
    }

    func exportLedger(orders: [OrderRecord], activity: [ActivityEvent]) throws -> URL {
        AppLogger.analytics.info("CSV export requested")
        guard orders.isEmpty == false || activity.isEmpty == false else {
            throw CSVExportError.noData
        }

        let activityByOrderID = Dictionary(uniqueKeysWithValues: activity.map { ($0.orderID, $0) })
        let rows: [ExportableLedgerRow] = orders.map { order in
            let linkedActivity = activityByOrderID[order.id]
            return ExportableLedgerRow(
                timestamp: order.executedAt,
                symbol: order.symbol,
                eventType: linkedActivity?.kind.rawValue ?? "order",
                side: order.side.rawValue,
                quantity: order.quantity,
                price: order.executedPrice,
                grossValue: order.grossValue,
                realizedPnL: linkedActivity?.realizedPnL
            )
        }
        .sorted(by: { $0.timestamp > $1.timestamp })

        let csv = makeCSV(rows: rows)
        guard let data = csv.data(using: .utf8) else {
            throw CSVExportError.failedToEncode
        }

        do {
            if fileManager.fileExists(atPath: outputDirectory.path) == false {
                try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            }
            let formatter = ISO8601DateFormatter()
            let fileName = "ledger_export_\(formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")).csv"
            let url = outputDirectory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            AppLogger.analytics.info("CSV export succeeded")
            return url
        } catch {
            AppLogger.analytics.error("CSV export failed: \(error.localizedDescription, privacy: .public)")
            throw CSVExportError.failedToWrite
        }
    }

    private func makeCSV(rows: [ExportableLedgerRow]) -> String {
        var lines = ["timestamp,symbol,event_type,side,quantity,price,gross_value,realized_pnl"]
        let formatter = ISO8601DateFormatter()
        lines.append(contentsOf: rows.map { row in
            let realized = row.realizedPnL?.description ?? ""
            return [
                formatter.string(from: row.timestamp),
                row.symbol,
                row.eventType,
                row.side,
                row.quantity.description,
                row.price.description,
                row.grossValue.description,
                realized
            ].joined(separator: ",")
        })
        return lines.joined(separator: "\n")
    }
}
