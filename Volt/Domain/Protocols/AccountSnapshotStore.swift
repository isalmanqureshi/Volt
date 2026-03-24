import Foundation

protocol AccountSnapshotStore {
    func loadCheckpoints() throws -> [AccountSnapshotCheckpoint]
    func saveCheckpoints(_ checkpoints: [AccountSnapshotCheckpoint]) throws
}

enum AccountSnapshotStoreError: LocalizedError {
    case decodeFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .decodeFailed: "Saved account snapshot checkpoints were unreadable."
        case .writeFailed: "Failed to persist account snapshot checkpoints."
        }
    }
}
