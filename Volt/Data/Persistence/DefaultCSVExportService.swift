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
            self.outputDirectory = fileManager.temporaryDirectory.appendingPathComponent("VoltExports", isDirectory: true)
        }
    }

    func exportLedger(orders: [OrderRecord], activity: [ActivityEvent]) throws -> URL {
        try export(preset: .fullActivity, orders: orders, activity: activity, summary: .empty)
    }

    func export(preset: AnalyticsExportPreset, orders: [OrderRecord], activity: [ActivityEvent], summary: PortfolioAnalyticsSummary) throws -> URL {
        AppLogger.analytics.info("CSV export requested preset=\(preset.rawValue, privacy: .public)")

        let csv: String
        switch preset {
        case .orderHistoryOnly:
            csv = makeOrderCSV(orders: orders)
        case .realizedLedgerOnly:
            csv = makeRealizedCSV(activity: activity)
        case .analyticsSummary:
            csv = makeSummaryCSV(summary: summary)
        case .fullActivity:
            csv = makeLedgerCSV(orders: orders, activity: activity)
        }

        guard let data = csv.data(using: .utf8), csv.isEmpty == false else {
            throw CSVExportError.failedToEncode
        }

        do {
            if fileManager.fileExists(atPath: outputDirectory.path) == false {
                try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            }
            let formatter = ISO8601DateFormatter()
            let fileName = "\(preset.rawValue)_\(formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")).csv"
            let url = outputDirectory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            AppLogger.analytics.info("CSV export succeeded")
            return url
        } catch {
            AppLogger.analytics.error("CSV export failed: \(error.localizedDescription, privacy: .public)")
            throw CSVExportError.failedToWrite
        }
    }

    private func makeLedgerCSV(orders: [OrderRecord], activity: [ActivityEvent]) -> String {
        guard orders.isEmpty == false || activity.isEmpty == false else { return "" }

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

    private func makeOrderCSV(orders: [OrderRecord]) -> String {
        guard orders.isEmpty == false else { return "" }
        let formatter = ISO8601DateFormatter()
        var lines = ["timestamp,symbol,side,type,quantity,price,gross_value"]
        lines.append(contentsOf: orders.map {
            [
                formatter.string(from: $0.executedAt),
                $0.symbol,
                $0.side.rawValue,
                $0.type.rawValue,
                $0.quantity.description,
                $0.executedPrice.description,
                $0.grossValue.description
            ].joined(separator: ",")
        })
        return lines.joined(separator: "\n")
    }

    private func makeRealizedCSV(activity: [ActivityEvent]) -> String {
        let realized = activity.filter { $0.realizedPnL != nil }
        guard realized.isEmpty == false else { return "" }

        let formatter = ISO8601DateFormatter()
        var lines = ["timestamp,symbol,event_type,quantity,price,realized_pnl"]
        lines.append(contentsOf: realized.map {
            [
                formatter.string(from: $0.timestamp),
                $0.symbol,
                $0.kind.rawValue,
                $0.quantity.description,
                $0.price.description,
                ($0.realizedPnL ?? 0).description
            ].joined(separator: ",")
        })
        return lines.joined(separator: "\n")
    }

    private func makeSummaryCSV(summary: PortfolioAnalyticsSummary) -> String {
        [
            "metric,value",
            "current_equity,\(summary.currentEquity)",
            "total_realized_pnl,\(summary.totalRealizedPnL)",
            "total_unrealized_pnl,\(summary.totalUnrealizedPnL)",
            "closed_trades,\(summary.totalClosedTrades)",
            "win_rate,\(summary.winRate?.description ?? "")",
            "profit_factor,\(summary.profitFactor?.description ?? "")",
            "net_return_percent,\(summary.netReturnPercent?.description ?? "")"
        ].joined(separator: "\n")
    }
}
