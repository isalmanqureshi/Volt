import Charts
import SwiftUI

/// Reusable candlestick chart that renders completed 1m candles and an optional live price overlay.
struct CandlestickChartView: View {
    let candles: [Candle]
    let livePrice: Decimal?

    private let candleHalfWidthSeconds: TimeInterval = 20

    var body: some View {
        Chart {
            ForEach(candles, id: \.timestamp) { candle in
            RuleMark(
                x: .value("Time", candle.timestamp),
                yStart: .value("Low", candle.low.doubleValue),
                yEnd: .value("High", candle.high.doubleValue)
            )
            .foregroundStyle(.secondary)
            .lineStyle(.init(lineWidth: 1))

            RectangleMark(
                xStart: .value("Start", candle.timestamp.addingTimeInterval(-candleHalfWidthSeconds)),
                xEnd: .value("End", candle.timestamp.addingTimeInterval(candleHalfWidthSeconds)),
                yStart: .value("Open", candle.open.doubleValue),
                yEnd: .value("Close", candle.close.doubleValue)
            )
            .foregroundStyle(candle.close >= candle.open ? .green : .red)
            .cornerRadius(2)
            }

            if let livePrice {
                RuleMark(y: .value("Live Price", livePrice.doubleValue))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.orange)
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Text(livePrice.formatted(.number.precision(.fractionLength(2...6))))
                            .font(.caption2.monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
    }
}

private extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

#Preview {
    let now = Date()
    let candles = (0..<90).map { index in
        let base = Decimal(68_000 + index)
        let close = index.isMultiple(of: 2) ? (base + 10) : (base - 12)
        return Candle(
            symbol: "BTC/USD",
            interval: "1min",
            open: base,
            high: max(base, close) + 15,
            low: min(base, close) - 18,
            close: close,
            volume: 1_000,
            timestamp: now.addingTimeInterval(TimeInterval(index * 60)),
            isComplete: true
        )
    }

    return CandlestickChartView(candles: candles, livePrice: 68_420)
        .frame(height: 280)
        .padding()
}
