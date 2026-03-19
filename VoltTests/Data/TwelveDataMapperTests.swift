import XCTest
@testable import Volt

final class TwelveDataMapperTests: XCTestCase {
    func testQuoteMapping() throws {
        let dto = TwelveDataQuoteDTO(
            symbol: "BTC/USD",
            name: "Bitcoin",
            exchange: "CRYPTO",
            currency: "USD",
            datetime: "2026-03-19 10:00:00",
            timestamp: nil,
            close: "67890.12",
            percentChange: "1.25"
        )

        let quote = try TwelveDataMapper.mapQuote(dto)

        XCTAssertEqual(quote.symbol, "BTC/USD")
        XCTAssertEqual(quote.lastPrice, Decimal(string: "67890.12"))
        XCTAssertEqual(quote.changePercent, Decimal(string: "1.25"))
        XCTAssertFalse(quote.isSimulated)
    }

    func testTimeSeriesMapping() throws {
        let dto = TwelveDataTimeSeriesDTO(
            meta: .init(symbol: "ETH/USD", interval: "1min"),
            values: [
                .init(datetime: "2026-03-19 10:00:00", open: "100", high: "110", low: "99", close: "105", volume: "1234")
            ],
            status: "ok"
        )

        let candles = try TwelveDataMapper.mapCandles(dto)

        XCTAssertEqual(candles.count, 1)
        XCTAssertEqual(candles[0].symbol, "ETH/USD")
        XCTAssertEqual(candles[0].close, 105)
        XCTAssertEqual(candles[0].interval, "1min")
    }
}
