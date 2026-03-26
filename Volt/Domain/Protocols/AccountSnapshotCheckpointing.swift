import Foundation

protocol AccountSnapshotCheckpointing {
    var checkpoints: [AccountSnapshotCheckpoint] { get }
    func checkpoint(trigger: AccountSnapshotCheckpoint.Trigger)
}
