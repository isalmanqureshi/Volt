import Foundation
internal import os

struct FileBackedPortfolioPersistenceStore: PortfolioPersistenceStore {
    private struct PersistedEnvelope: Codable {
        var version: Int
        var state: PersistedPortfolioState
    }

    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileName: String = "portfolio_state.json",
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        if let baseDirectory {
            self.fileURL = baseDirectory.appendingPathComponent(fileName)
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            self.fileURL = appSupport.appendingPathComponent("Volt", isDirectory: true).appendingPathComponent(fileName)
        }
    }

    func loadState() throws -> PersistedPortfolioState? {
        AppLogger.portfolio.info("Persistence load start")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            AppLogger.portfolio.info("Persistence load skipped (no file)")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state: PersistedPortfolioState
            if let envelope = try? decoder.decode(PersistedEnvelope.self, from: data) {
                state = envelope.state
            } else {
                state = try decoder.decode(PersistedPortfolioState.self, from: data)
                AppLogger.migration.info("Migrated legacy portfolio persistence payload")
            }
            AppLogger.portfolio.info("Persistence load success")
            return state
        } catch {
            AppLogger.portfolio.error("Persistence load failure: \(error.localizedDescription, privacy: .public)")
            throw PortfolioPersistenceError.failedToDecode
        }
    }

    func saveState(_ state: PersistedPortfolioState) throws {
        AppLogger.portfolio.info("Persistence save start")
        do {
            let directory = fileURL.deletingLastPathComponent()
            if fileManager.fileExists(atPath: directory.path) == false {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(PersistedEnvelope(version: 2, state: state))
            try data.write(to: fileURL, options: .atomic)
            AppLogger.portfolio.info("Persistence save success")
        } catch {
            AppLogger.portfolio.error("Persistence save failure: \(error.localizedDescription, privacy: .public)")
            throw PortfolioPersistenceError.failedToWrite
        }
    }
}
