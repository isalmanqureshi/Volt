import XCTest
@testable import Volt

/// Regression tests for the flat-chart bug: Swift Charts' automatic Y domain
/// anchors at zero, so BTC candles spanning 95,000–95,400 rendered as a hairline.
/// The chart must derive its Y domain from the data's actual low/high instead.
final class CandleChartScaleTests: XCTestCase {
    func testDomainSpanStaysWithinSaneMultipleOfDataSpanForHighPricedAsset() {
        // BTC-like day: absolute price ~95k, intraday range ~400. Under a
        // zero-anchored domain the data occupies 0.4% of the plot; the derived
        // domain must keep it dominant.
        let candles = makeCandles(closes: stride(from: 95_000, through: 95_400, by: 25).map { Decimal($0) })
        let domain = CandleChartScale.yDomain(for: candles, livePrice: nil)

        let dataLow = candles.map { $0.low.chartValue }.min()!
        let dataHigh = candles.map { $0.high.chartValue }.max()!
        let dataSpan = dataHigh - dataLow
        let domainSpan = domain.upperBound - domain.lowerBound

        XCTAssertGreaterThan(dataSpan, 0)
        XCTAssertGreaterThanOrEqual(domainSpan, dataSpan, "Domain must contain the full data range")
        XCTAssertLessThanOrEqual(
            domainSpan, dataSpan * 3,
            "Domain span \(domainSpan) is more than 3x the data span \(dataSpan) — candles will render flat"
        )
        // The exact failure mode of the bug: data occupying a tiny fraction of the plot.
        XCTAssertGreaterThan(dataSpan / domainSpan, 0.05, "Candle range is compressed below the visibility threshold")
    }

    func testDomainContainsEveryCandleExtreme() {
        let candles = makeCandles(closes: [3_480, 3_550, 3_500, 3_530].map { Decimal($0) })
        let domain = CandleChartScale.yDomain(for: candles, livePrice: nil)

        for candle in candles {
            XCTAssertTrue(domain.contains(candle.low.chartValue))
            XCTAssertTrue(domain.contains(candle.high.chartValue))
        }
    }

    func testLivePriceOutsideCandleRangeExpandsDomain() {
        let candles = makeCandles(closes: [180, 182, 184].map { Decimal($0) })
        let livePrice: Decimal = 190
        let domain = CandleChartScale.yDomain(for: candles, livePrice: livePrice)

        XCTAssertTrue(domain.contains(livePrice.chartValue), "Live price rule mark must render inside the plot")
    }

    func testSinglePriceDataStillProducesRenderableDomain() {
        // Degenerate case: every candle at the same price (true flat data).
        let candles = (0..<10).map { index in
            Candle(
                symbol: "DOGE/USD", interval: "15min",
                open: 0.18, high: 0.18, low: 0.18, close: 0.18,
                volume: 100,
                timestamp: Date(timeIntervalSince1970: TimeInterval(index * 900)),
                isComplete: true
            )
        }
        let domain = CandleChartScale.yDomain(for: candles, livePrice: nil)

        XCTAssertGreaterThan(domain.upperBound, domain.lowerBound, "Domain must never be empty")
        XCTAssertTrue(domain.contains(Decimal(0.18).chartValue))
    }

    func testEmptyCandlesWithLivePriceCenterOnLivePrice() {
        let domain = CandleChartScale.yDomain(for: [], livePrice: 68_500)

        XCTAssertTrue(domain.contains(Decimal(68_500).chartValue))
        XCTAssertGreaterThan(domain.upperBound, domain.lowerBound)
    }

    func testEmptyInputFallsBackToNonEmptyDomain() {
        let domain = CandleChartScale.yDomain(for: [], livePrice: nil)

        XCTAssertGreaterThan(domain.upperBound, domain.lowerBound)
    }

    // MARK: Helpers

    /// Builds 15-minute candles around the given closes with a small wick either side.
    private func makeCandles(closes: [Decimal]) -> [Candle] {
        closes.enumerated().map { index, close in
            let open = index == 0 ? close : closes[index - 1]
            return Candle(
                symbol: "BTC/USD",
                interval: "15min",
                open: open,
                high: max(open, close) + 10,
                low: min(open, close) - 10,
                close: close,
                volume: Decimal(500 + index * 13),
                timestamp: Date(timeIntervalSince1970: TimeInterval(index * 900)),
                isComplete: true
            )
        }
    }
}
