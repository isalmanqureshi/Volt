import XCTest
@testable import Volt

final class TwelveDataDTODecodingTests: XCTestCase {
    func testQuoteDTODecoding() throws {
        let json = """
        {
          "symbol": "BTC/USD",
          "name": "Bitcoin",
          "exchange": "CRYPTO",
          "currency": "USD",
          "datetime": "2026-03-19 10:00:00",
          "timestamp": 1773914400,
          "close": "70000.11",
          "percent_change": "0.62"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(TwelveDataQuoteDTO.self, from: json)
        XCTAssertEqual(dto.symbol, "BTC/USD")
        XCTAssertEqual(dto.close, "70000.11")
        XCTAssertEqual(dto.percentChange, "0.62")
    }

    func testTimeSeriesDTODecoding() throws {
        let json = """
        {
          "meta": { "symbol": "ETH/USD", "interval": "1min" },
          "values": [
            { "datetime": "2026-03-19 10:00:00", "open": "3550", "high": "3560", "low": "3540", "close": "3558", "volume": "123" },
            { "datetime": "2026-03-19 09:59:00", "open": "3548", "high": "3552", "low": "3545", "close": "3550", "volume": "121" }
          ],
          "status": "ok"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(TwelveDataTimeSeriesDTO.self, from: json)
        XCTAssertEqual(dto.meta.symbol, "ETH/USD")
        XCTAssertEqual(dto.values.count, 2)
    }
}
