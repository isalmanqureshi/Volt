import Foundation

enum OrderType: String, Codable, Sendable {
    case market
    case limit
    case stop
}
