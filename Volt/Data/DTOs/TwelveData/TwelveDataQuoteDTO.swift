import Foundation

struct TwelveDataQuoteDTO: Decodable, Sendable {
    let symbol: String
    let name: String?
    let exchange: String?
    let currency: String?
    let datetime: String?
    let timestamp: Int?
    let close: String?
    let percentChange: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case name
        case exchange
        case currency
        case datetime
        case timestamp
        case close
        case percentChange = "percent_change"
    }
}
