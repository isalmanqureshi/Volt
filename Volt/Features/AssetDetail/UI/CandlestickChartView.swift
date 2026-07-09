import Charts
import SwiftUI

/// Candlestick chart matching the Volt design: teal up / red down candles on the
/// deep-well background, with a long-press crosshair that reports the focused candle.
struct CandlestickChartView: View {
    let candles: [Candle]
    let livePrice: Decimal?
    @Binding var selectedCandle: Candle?

    /// Half-width of a candle body, derived from the median gap between candles so
    /// bodies stay proportional at any interval (1-minute through 1-day) instead of
    /// collapsing to a hairline on wider ranges.
    private var candleHalfWidthSeconds: TimeInterval {
        guard candles.count > 1 else { return 20 }
        let times = candles.map { $0.timestamp.timeIntervalSince1970 }.sorted()
        var gaps: [TimeInterval] = []
        gaps.reserveCapacity(times.count - 1)
        for index in 1..<times.count {
            let delta = times[index] - times[index - 1]
            if delta > 0 { gaps.append(delta) }
        }
        guard gaps.isEmpty == false else { return 20 }
        let medianGap = gaps.sorted()[gaps.count / 2]
        return max(medianGap * 0.3, 1)
    }

    var body: some View {
        Chart {
            ForEach(candles, id: \.timestamp) { candle in
                let isUp = candle.close >= candle.open
                let color: Color = isUp ? .voltAccent : .voltDanger

                RuleMark(
                    x: .value("Time", candle.timestamp),
                    yStart: .value("Low", candle.low.chartValue),
                    yEnd: .value("High", candle.high.chartValue)
                )
                .foregroundStyle(color)
                .lineStyle(.init(lineWidth: 1))

                RectangleMark(
                    xStart: .value("Start", candle.timestamp.addingTimeInterval(-candleHalfWidthSeconds)),
                    xEnd: .value("End", candle.timestamp.addingTimeInterval(candleHalfWidthSeconds)),
                    yStart: .value("Open", candle.open.chartValue),
                    yEnd: .value("Close", candle.close.chartValue)
                )
                .foregroundStyle(color)
                .cornerRadius(1)
            }

            if let selectedCandle {
                RuleMark(x: .value("Crosshair", selectedCandle.timestamp))
                    .foregroundStyle(Color.white.opacity(0.22))
                    .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
            }

            if let livePrice {
                RuleMark(y: .value("Live", livePrice.chartValue))
                    .foregroundStyle(Color.voltAccent.opacity(0.7))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Text(livePrice.voltPriceString(precision: 2))
                            .font(Typography.monoCaption)
                            .foregroundStyle(Color.voltAccent)
                            .padding(.horizontal, Spacing.xs + 2)
                            .padding(.vertical, 2)
                            .background(
                                Color.voltSurfaceDeep,
                                in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                            )
                            .hairlineBorder(cornerRadius: Radius.tag)
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.voltSurfaceDeep)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(crosshairGesture(proxy: proxy, geo: geo))
            }
        }
    }

    private func crosshairGesture(proxy: ChartProxy, geo: GeometryProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.15)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value, let drag else { return }
                guard let plotFrame = proxy.plotFrame else { return }
                let origin = geo[plotFrame].origin
                let xPosition = drag.location.x - origin.x
                guard let date: Date = proxy.value(atX: xPosition) else { return }
                selectedCandle = candles.min(by: {
                    abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
                })
            }
            .onEnded { _ in
                selectedCandle = nil
            }
    }
}

/// Volume pane below the candles — bars colored by candle direction.
struct VolumeBarsView: View {
    let candles: [Candle]

    var body: some View {
        Chart(candles, id: \.timestamp) { candle in
            BarMark(
                x: .value("Time", candle.timestamp),
                y: .value("Volume", candle.volume.chartValue),
                width: .fixed(4)
            )
            .foregroundStyle(
                (candle.close >= candle.open ? Color.voltAccent : Color.voltDanger).opacity(0.75)
            )
            .cornerRadius(1)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.voltSurfaceDeep)
        }
    }
}

#Preview {
    struct CrosshairPreview: View {
        @State private var selected: Candle?
        let candles: [Candle]

        var body: some View {
            VStack(spacing: Spacing.lg) {
                CandlestickChartView(candles: candles, livePrice: 68_420, selectedCandle: $selected)
                    .frame(height: 280)
                VolumeBarsView(candles: candles)
                    .frame(height: 70)
            }
            .padding(Spacing.lg)
            .voltScreen()
        }
    }

    let now = Date()
    let candles = (0..<60).map { index in
        let base = Decimal(68_000 + index * 12)
        let close = index.isMultiple(of: 2) ? (base + 60) : (base - 45)
        return Candle(
            symbol: "BTC/USD",
            interval: "1min",
            open: base,
            high: max(base, close) + 40,
            low: min(base, close) - 35,
            close: close,
            volume: Decimal(400 + (index * 37) % 900),
            timestamp: now.addingTimeInterval(TimeInterval(index * 60)),
            isComplete: true
        )
    }

    return CrosshairPreview(candles: candles)
}
