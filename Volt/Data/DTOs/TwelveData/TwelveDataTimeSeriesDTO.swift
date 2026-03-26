import Foundation

struct TwelveDataTimeSeriesDTO: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let symbol: String
        let interval: String
    }

    struct Value: Decodable, Sendable {
        let datetime: String
        let open: String
        let high: String
        let low: String
        let close: String
        let volume: String?
    }

    let meta: Meta
    let values: [Value]
    let status: String?
}
