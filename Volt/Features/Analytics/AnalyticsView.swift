import Charts
import Combine
import Foundation
import SwiftUI

struct AnalyticsView: View {
    @StateObject var viewModel: AnalyticsViewModel

    var body: some View {
        List {
            Section("Range") {
                Picker("Range", selection: $viewModel.selectedRange) {
                    ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Equity Curve") {
                if viewModel.performancePoints.isEmpty {
                    ContentUnavailableView("No performance data", systemImage: "chart.line.uptrend.xyaxis")
                } else {
                    Chart(viewModel.performancePoints) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Equity", NSDecimalNumber(decimal: point.equity).doubleValue)
                        )
                        .foregroundStyle(.blue)
                    }
                    .frame(height: 200)
                    .accessibilityLabel("Equity curve chart")
                }
            }

            Section("Daily Realized P&L") {
                if viewModel.dailyBuckets.isEmpty {
                    Text("No realized history yet")
                        .foregroundStyle(.secondary)
                } else {
                    Chart(viewModel.dailyBuckets) { bucket in
                        BarMark(
                            x: .value("Day", bucket.day),
                            y: .value("Realized", NSDecimalNumber(decimal: bucket.realizedPnL).doubleValue)
                        )
                        .foregroundStyle(bucket.realizedPnL >= 0 ? .green : .red)
                    }
                    .frame(height: 180)
                }
            }

            Section("Realized Distribution") {
                if viewModel.realizedDistribution.allSatisfy({ $0.count == 0 }) {
                    Text("No closed trades yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.realizedDistribution) { bucket in
                        LabeledContent(bucket.label, value: "\(bucket.count) trades")
                    }
                }
            }


            if viewModel.insightCards.isEmpty == false {
                Section("Insights") {
                    ForEach(viewModel.insightCards) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title).font(.subheadline.weight(.semibold))
                            Text(card.body).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Summary") {
                LabeledContent("Current Equity", value: viewModel.summary.currentEquity.formatted(.currency(code: "USD")))
                LabeledContent("Realized P&L", value: viewModel.summary.totalRealizedPnL.formatted(.currency(code: "USD")))
                LabeledContent("Unrealized P&L", value: viewModel.summary.totalUnrealizedPnL.formatted(.currency(code: "USD")))
                LabeledContent("Closed Trades", value: String(viewModel.summary.totalClosedTrades))
                LabeledContent("Win Rate", value: percent(viewModel.summary.winRate))
                LabeledContent("Average Win", value: currency(viewModel.summary.averageWin))
                LabeledContent("Average Loss", value: currency(viewModel.summary.averageLoss))
                LabeledContent("Best Trade", value: currency(viewModel.summary.bestTrade))
                LabeledContent("Worst Trade", value: currency(viewModel.summary.worstTrade))
                LabeledContent("Net Return", value: percent(viewModel.summary.netReturnPercent))
            }
        }
        .navigationTitle("Analytics")
    }

    private func percent(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        return "\(value.formatted(.number.precision(.fractionLength(2))))%"
    }

    private func currency(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        return value.formatted(.currency(code: "USD"))
    }
}

#Preview("Populated") {
    NavigationStack {
        AnalyticsView(viewModel: AnalyticsViewModel(analyticsService: AnalyticsPreviewService.populated))
    }
}

#Preview("Empty") {
    NavigationStack {
        AnalyticsView(viewModel: AnalyticsViewModel(analyticsService: AnalyticsPreviewService.empty))
    }
}

private final class AnalyticsPreviewService: PortfolioAnalyticsService {
    static let populated: PortfolioAnalyticsService = AnalyticsPreviewService(
        summary: PortfolioAnalyticsSummary(
            totalRealizedPnL: 450,
            totalUnrealizedPnL: 120,
            averageWin: 180,
            averageLoss: -95,
            profitFactor: 2.2,
            winRate: 0.67,
            totalClosedTrades: 6,
            bestTrade: 330,
            worstTrade: -120,
            currentEquity: 52_300,
            startingBalance: 50_000,
            netReturnPercent: 4.6
        ),
        points: [
            PerformancePoint(timestamp: .now.addingTimeInterval(-86_400 * 2), equity: 50_100, cashBalance: 49_800, unrealizedPnL: 0, cumulativeRealizedPnL: 100),
            PerformancePoint(timestamp: .now.addingTimeInterval(-86_400), equity: 51_200, cashBalance: 50_900, unrealizedPnL: 0, cumulativeRealizedPnL: 1_200),
            PerformancePoint(timestamp: .now, equity: 52_300, cashBalance: 41_000, unrealizedPnL: 120, cumulativeRealizedPnL: 450)
        ]
    )

    static let empty: PortfolioAnalyticsService = AnalyticsPreviewService(summary: .empty, points: [])

    private let summaryValue: PortfolioAnalyticsSummary
    private let pointsValue: [PerformancePoint]
    private let filterSubject = CurrentValueSubject<HistoryFilter, Never>(.default)

    init(summary: PortfolioAnalyticsSummary, points: [PerformancePoint]) {
        summaryValue = summary
        pointsValue = points
    }

    var summaryPublisher: AnyPublisher<PortfolioAnalyticsSummary, Never> { Just(summaryValue).eraseToAnyPublisher() }
    var performancePublisher: AnyPublisher<[PerformancePoint], Never> { Just(pointsValue).eraseToAnyPublisher() }
    var dailyPerformancePublisher: AnyPublisher<[DailyPerformanceBucket], Never> { Just([]).eraseToAnyPublisher() }
    var realizedDistributionPublisher: AnyPublisher<[RealizedDistributionBucket], Never> { Just([]).eraseToAnyPublisher() }
    var filteredOrdersPublisher: AnyPublisher<[OrderRecord], Never> { Just([]).eraseToAnyPublisher() }
    var filteredActivityPublisher: AnyPublisher<[ActivityEvent], Never> { Just([]).eraseToAnyPublisher() }
    var availableSymbolsPublisher: AnyPublisher<[String], Never> { Just(["BTC/USD"]).eraseToAnyPublisher() }
    var currentSummary: PortfolioAnalyticsSummary { summaryValue }
    var currentPerformance: [PerformancePoint] { pointsValue }
    var currentDailyPerformance: [DailyPerformanceBucket] { [] }
    var currentRealizedDistribution: [RealizedDistributionBucket] { [] }
    var currentFilter: HistoryFilter { filterSubject.value }
    func updateFilter(_ filter: HistoryFilter) { filterSubject.send(filter) }
    func positionHistory(symbol: String) -> PositionHistorySummary { .empty(symbol: symbol) }
}
