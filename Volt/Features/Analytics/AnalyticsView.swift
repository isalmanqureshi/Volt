import Charts
import Combine
import Foundation
import SwiftUI

struct AnalyticsView: View {
    @StateObject var viewModel: AnalyticsViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader("Analytics")

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    rangePills
                        .padding(.bottom, Spacing.md)

                    summaryGrid

                    SectionLabel("Equity curve")
                        .padding(.top, Spacing.gutter)
                        .padding(.bottom, Spacing.sm)
                    equityCurve

                    SectionLabel("Daily P&L")
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, Spacing.sm)
                    dailyPnL

                    if viewModel.insightCards.isEmpty == false {
                        SectionLabel("Insights")
                            .padding(.top, Spacing.gutter)
                            .padding(.bottom, Spacing.sm)
                        insights
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.gutter)
            }
        }
        .voltScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Range

    private var rangePills: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                FilterPill(
                    title: range.title,
                    isSelected: viewModel.selectedRange == range,
                    isMono: true
                ) {
                    viewModel.selectedRange = range
                }
            }
        }
    }

    // MARK: Summary cards

    private var summaryGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Spacing.md),
                GridItem(.flexible(), spacing: Spacing.md)
            ],
            spacing: Spacing.md
        ) {
            summaryCard(
                label: "Win Rate",
                value: viewModel.summary.winRate.map { "\((($0) * 100).voltPriceString(precision: 0))%" } ?? "--",
                valueColor: .voltTextPrimary,
                detail: "\(viewModel.summary.totalClosedTrades) closed",
                detailColor: .voltTextSecondary
            )
            summaryCard(
                label: "Net Return",
                value: viewModel.summary.netReturnPercent.map { signedPercent($0) } ?? "--",
                valueColor: (viewModel.summary.netReturnPercent ?? 0) >= 0 ? .voltAccent : .voltDanger,
                detail: "since start",
                detailColor: .voltTextSecondary
            )
            summaryCard(
                label: "Best Trade",
                value: viewModel.summary.bestTrade.map { $0.voltSignedCurrencyString() } ?? "--",
                valueColor: .voltAccent,
                detail: viewModel.summary.averageWin.map { "avg win " + $0.voltSignedCurrencyString() } ?? "no wins yet",
                detailColor: .voltTextSecondary
            )
            summaryCard(
                label: "Worst Trade",
                value: viewModel.summary.worstTrade.map { $0.voltSignedCurrencyString() } ?? "--",
                valueColor: .voltDanger,
                detail: viewModel.summary.averageLoss.map { "avg loss " + $0.voltSignedCurrencyString() } ?? "no losses yet",
                detailColor: .voltTextSecondary
            )
        }
    }

    private func summaryCard(label: String, value: String, valueColor: Color, detail: String, detailColor: Color) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Spacing.xs + 2) {
                Text(label)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.voltTextSecondary)
                Text(value)
                    .font(Typography.sectionNumber)
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(detail)
                    .font(Typography.monoSecondary)
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }
        }
    }

    private func signedPercent(_ value: Decimal) -> String {
        (value >= 0 ? "+" : "") + value.voltPriceString(precision: 2) + "%"
    }

    // MARK: Charts

    @ViewBuilder
    private var equityCurve: some View {
        if viewModel.performancePoints.isEmpty {
            chartPlaceholder("No performance data yet")
        } else {
            Chart(viewModel.performancePoints) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Equity", point.equity.chartValue)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.voltAccent.opacity(0.14), Color.voltAccent.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Equity", point.equity.chartValue)
                )
                .foregroundStyle(Color.voltAccent)
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 140)
            .accessibilityLabel("Equity curve chart")
        }
    }

    @ViewBuilder
    private var dailyPnL: some View {
        if viewModel.dailyBuckets.isEmpty {
            chartPlaceholder("No realized history yet")
        } else {
            Chart {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.white.opacity(0.1))
                    .lineStyle(.init(lineWidth: 1))

                ForEach(viewModel.dailyBuckets) { bucket in
                    BarMark(
                        x: .value("Day", bucket.day, unit: .day),
                        y: .value("Realized", bucket.realizedPnL.chartValue)
                    )
                    .foregroundStyle(bucket.realizedPnL >= 0 ? Color.voltAccent : Color.voltDanger)
                    .cornerRadius(1)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 120)
            .accessibilityLabel("Daily profit and loss chart")
        }
    }

    private func chartPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(Typography.bodySecondary)
            .foregroundStyle(Color.voltTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 120)
            .voltSurfaceStyle()
    }

    // MARK: Insights

    private var insights: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(viewModel.insightCards) { card in
                SectionCard {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(card.title)
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(Color.voltTextPrimary)
                        Text(card.body)
                            .font(Typography.secondary)
                            .foregroundStyle(Color.voltTextSecondary)
                    }
                }
            }
        }
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
            winRate: 0.62,
            totalClosedTrades: 21,
            bestTrade: 1_840,
            worstTrade: -920,
            currentEquity: 52_300,
            startingBalance: 50_000,
            netReturnPercent: 4.6
        ),
        points: (0..<32).map { index in
            PerformancePoint(
                timestamp: .now.addingTimeInterval(Double(index - 32) * 86_400),
                equity: Decimal(50_000 + index * 90 - (index % 5) * 160),
                cashBalance: 40_000,
                unrealizedPnL: 0,
                cumulativeRealizedPnL: Decimal(index * 40)
            )
        },
        buckets: (0..<16).map { index in
            DailyPerformanceBucket(
                day: Calendar.current.startOfDay(for: .now.addingTimeInterval(Double(index - 16) * 86_400)),
                realizedPnL: Decimal((index * 37) % 90 - 40),
                tradeCount: 1 + index % 3
            )
        }
    )

    static let empty: PortfolioAnalyticsService = AnalyticsPreviewService(summary: .empty, points: [], buckets: [])

    private let summaryValue: PortfolioAnalyticsSummary
    private let pointsValue: [PerformancePoint]
    private let bucketsValue: [DailyPerformanceBucket]
    private let filterSubject = CurrentValueSubject<HistoryFilter, Never>(.default)

    init(summary: PortfolioAnalyticsSummary, points: [PerformancePoint], buckets: [DailyPerformanceBucket]) {
        summaryValue = summary
        pointsValue = points
        bucketsValue = buckets
    }

    var summaryPublisher: AnyPublisher<PortfolioAnalyticsSummary, Never> { Just(summaryValue).eraseToAnyPublisher() }
    var performancePublisher: AnyPublisher<[PerformancePoint], Never> { Just(pointsValue).eraseToAnyPublisher() }
    var dailyPerformancePublisher: AnyPublisher<[DailyPerformanceBucket], Never> { Just(bucketsValue).eraseToAnyPublisher() }
    var realizedDistributionPublisher: AnyPublisher<[RealizedDistributionBucket], Never> { Just([]).eraseToAnyPublisher() }
    var filteredOrdersPublisher: AnyPublisher<[OrderRecord], Never> { Just([]).eraseToAnyPublisher() }
    var filteredActivityPublisher: AnyPublisher<[ActivityEvent], Never> { Just([]).eraseToAnyPublisher() }
    var availableSymbolsPublisher: AnyPublisher<[String], Never> { Just(["BTC/USD"]).eraseToAnyPublisher() }
    var currentSummary: PortfolioAnalyticsSummary { summaryValue }
    var currentPerformance: [PerformancePoint] { pointsValue }
    var currentDailyPerformance: [DailyPerformanceBucket] { bucketsValue }
    var currentRealizedDistribution: [RealizedDistributionBucket] { [] }
    var currentFilter: HistoryFilter { filterSubject.value }
    func updateFilter(_ filter: HistoryFilter) { filterSubject.send(filter) }
    func positionHistory(symbol: String) -> PositionHistorySummary { .empty(symbol: symbol) }
}
