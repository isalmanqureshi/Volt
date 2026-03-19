import Foundation

enum StreamConnectionState: Equatable, Sendable {
    case idle
    case seeding
    case liveSimulated
    case stale
    case failed(String)
}
