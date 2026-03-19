import Charts
import SwiftUI

struct AssetDetailView: View {
    let symbol: String

    private var previewPoints: [PricePoint] {
        (0..<15).map { idx in
            PricePoint(timestamp: Date().addingTimeInterval(Double(-idx * 60)), price: Decimal(100 + idx))
        }
    }

    var body: some View {
        List {
            Section("Asset") {
                Text(symbol)
            }

            Section("Chart Placeholder") {
                Chart(previewPoints, id: \.timestamp) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Price", decimalToDouble(point.price))
                    )
                }
                .frame(height: 200)
            }
        }
        .navigationTitle("Asset Detail")
    }

    private func decimalToDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
