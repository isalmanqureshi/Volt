import Foundation

struct FileBackedAccountSnapshotStore: AccountSnapshotStore {
    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileName: String = "account_snapshot_checkpoints.json",
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        if let baseDirectory {
            fileURL = baseDirectory.appendingPathComponent(fileName)
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            fileURL = appSupport.appendingPathComponent("Volt", isDirectory: true).appendingPathComponent(fileName)
        }
    }

    func loadCheckpoints() throws -> [AccountSnapshotCheckpoint] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([AccountSnapshotCheckpoint].self, from: data)
        } catch {
            AppLogger.analytics.error("Checkpoint load failed: \(error.localizedDescription, privacy: .public)")
            throw AccountSnapshotStoreError.decodeFailed
        }
    }

    func saveCheckpoints(_ checkpoints: [AccountSnapshotCheckpoint]) throws {
        do {
            let directory = fileURL.deletingLastPathComponent()
            if fileManager.fileExists(atPath: directory.path) == false {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(checkpoints)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            AppLogger.analytics.error("Checkpoint save failed: \(error.localizedDescription, privacy: .public)")
            throw AccountSnapshotStoreError.writeFailed
        }
    }
}
