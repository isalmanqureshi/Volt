import SwiftUI

// MARK: - Screen scaffold

extension View {
    /// Every screen: voltBackground behind everything, dark scheme.
    func voltScreen() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.voltBackground.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
}

/// 30px bold screen title with an optional trailing accessory, matching the mockup headers.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    private let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(Typography.screenTitle)
                .foregroundStyle(Color.voltTextPrimary)
            Spacer()
            trailing
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
    }
}

/// 11px uppercase muted section label ("OPEN POSITIONS", "ALLOCATION", …).
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Typography.caption)
            .kerning(0.5)
            .foregroundStyle(Color.voltTextTertiary)
    }
}

// MARK: - Live status

/// Small live-status dot: teal = live, gray = offline.
struct LiveDot: View {
    let isLive: Bool

    var body: some View {
        HStack(spacing: Spacing.xs + 2) {
            Circle()
                .fill(isLive ? Color.voltAccent : Color.voltTextTertiary)
                .frame(width: 8, height: 8)
            Text(isLive ? "LIVE" : "OFFLINE")
                .font(Typography.monoCaption)
                .kerning(0.5)
                .foregroundStyle(isLive ? Color.voltAccent : Color.voltTextTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLive ? "Live data" : "Offline")
    }
}

// MARK: - Pills

/// % change pill: teal background if positive, red if negative.
struct ChangePill: View {
    let text: String
    let isPositive: Bool

    var body: some View {
        Text(text)
            .font(Typography.monoCaption)
            .foregroundStyle(isPositive ? Color.voltAccent : Color.voltDanger)
            .padding(.horizontal, Spacing.xs + 2)
            .padding(.vertical, 2)
            .background(
                (isPositive ? Color.voltAccent : Color.voltDanger).opacity(0.14),
                in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
            )
    }
}

/// B/S trade-side tag used in history rows.
struct SidePill: View {
    let side: OrderSide

    var body: some View {
        Text(side == .buy ? "B" : "S")
            .font(Typography.monoCaption.weight(.bold))
            .foregroundStyle(side == .buy ? Color.voltAccent : Color.voltDanger)
            .frame(width: 20, height: 20)
            .background(
                (side == .buy ? Color.voltAccent : Color.voltDanger).opacity(0.14),
                in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
            )
            .accessibilityLabel(side == .buy ? "Buy" : "Sell")
    }
}

/// Selectable filter/segment pill (filters, slippage, time ranges, profiles).
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    var isMono = false
    /// Stretch to fill the available width (segmented layouts).
    var expands = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isMono ? Typography.monoBodySecondary : Typography.bodySecondary)
                .foregroundStyle(isSelected ? Color.voltAccent : Color.white.opacity(0.55))
                .padding(.horizontal, Spacing.md + 2)
                .padding(.vertical, Spacing.xs + 2)
                .frame(maxWidth: expands ? .infinity : nil)
                .frame(minHeight: 32)
                .background(
                    isSelected ? Color.voltAccent.opacity(0.14) : Color.voltSurface,
                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .strokeBorder(isSelected ? Color.voltAccent : Color.voltHairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Coin visuals

/// 32px circular coin logo — brand-colored disc with the base-currency initial.
struct CoinBadge: View {
    let baseCurrency: String
    var size: CGFloat = 32

    var body: some View {
        let brand = Color.brand(forBaseCurrency: baseCurrency)
        Text(String(baseCurrency.prefix(1)))
            .font(.system(size: size * 0.4, weight: .bold, design: .monospaced))
            .foregroundStyle(baseCurrency.uppercased() == "BTC" ? Color.voltBackground : Color.voltTextPrimary)
            .frame(width: size, height: size)
            .background(brand, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Thin sparkline (48×24 in rows). Teal for up, red for down — caller decides.
struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if values.count > 1,
               let min = values.min(), let max = values.max() {
                let range = max - min
                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = geo.size.width * CGFloat(index) / CGFloat(values.count - 1)
                        let normalized = range == 0 ? 0.5 : (value - min) / range
                        let y = geo.size.height * (1 - CGFloat(normalized))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            } else {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(Color.voltHairline, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Watchlist-style coin row: badge, name + symbol, sparkline, price + change pill.
struct CoinRow: View {
    let name: String
    let symbol: String
    let priceText: String
    let changeText: String
    let isPositive: Bool
    var sparkline: [Double] = []

    private var baseCurrency: String {
        String(symbol.split(separator: "/").first ?? "")
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            CoinBadge(baseCurrency: baseCurrency)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Typography.emphasis.weight(.semibold))
                    .foregroundStyle(Color.voltTextPrimary)
                Text(baseCurrency)
                    .font(Typography.monoSecondary)
                    .foregroundStyle(Color.voltTextSecondary)
            }
            .lineLimit(1)

            Spacer(minLength: Spacing.sm)

            SparklineView(values: sparkline, color: isPositive ? .voltAccent : .voltDanger)
                .frame(width: 48, height: 24)

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(priceText)
                    .font(Typography.monoBody.weight(.semibold))
                    .foregroundStyle(Color.voltTextPrimary)
                ChangePill(text: changeText, isPositive: isPositive)
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(priceText), change \(changeText)")
    }
}

/// Hairline row divider used between list rows (full-bleed, 1pt, white 6%).
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.voltHairline)
            .frame(height: 1)
    }
}

// MARK: - Buttons

/// Full-width 52pt confirm button. Teal for buy/positive intents, red for sell/destructive.
struct PrimaryButton: View {
    enum Style {
        case accent
        case danger

        var fill: Color { self == .accent ? .voltAccent : .voltDanger }
    }

    let title: String
    var style: Style = .accent
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.emphasis.weight(.bold))
                .foregroundStyle(Color.voltBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    style.fill.opacity(isEnabled ? 1 : 0.35),
                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Cards

/// Elevated content card: voltSurface fill, card radius, hairline border.
struct SectionCard<Content: View>: View {
    var padding: CGFloat = Spacing.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .voltSurfaceStyle()
    }
}

// MARK: - Skeleton shimmer

/// Loading placeholder — no spinners anywhere in the app.
struct SkeletonView: View {
    var cornerRadius: CGFloat = Radius.button
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.voltSurface)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.06), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: geo.size.width * phase)
                }
                .clipped()
            )
            .hairlineBorder(cornerRadius: cornerRadius)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
            .accessibilityLabel("Loading")
    }
}

/// Skeleton stand-in for a coin row while quotes seed.
struct CoinRowSkeleton: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            SkeletonView(cornerRadius: 16).frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SkeletonView(cornerRadius: Radius.tag).frame(width: 96, height: 14)
                SkeletonView(cornerRadius: Radius.tag).frame(width: 40, height: 10)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                SkeletonView(cornerRadius: Radius.tag).frame(width: 84, height: 14)
                SkeletonView(cornerRadius: Radius.tag).frame(width: 52, height: 14)
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
    }
}

#Preview("Components") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                LiveDot(isLive: true)
                LiveDot(isLive: false)
            }
            CoinRow(
                name: "Bitcoin",
                symbol: "BTC/USD",
                priceText: "$63,842.10",
                changeText: "+2.34%",
                isPositive: true,
                sparkline: [1, 3, 2, 5, 4, 7, 6, 9]
            )
            RowDivider()
            CoinRow(
                name: "Solana",
                symbol: "SOL/USD",
                priceText: "$146.29",
                changeText: "-3.48%",
                isPositive: false,
                sparkline: [9, 7, 8, 5, 6, 3, 4, 1]
            )
            HStack {
                FilterPill(title: "All", isSelected: true) {}
                FilterPill(title: "Buys", isSelected: false) {}
                FilterPill(title: "0.5%", isSelected: true, isMono: true) {}
                SidePill(side: .buy)
                SidePill(side: .sell)
            }
            .padding(.horizontal, Spacing.gutter)
            SectionCard {
                SectionLabel("Section card")
            }
            .padding(.horizontal, Spacing.gutter)
            PrimaryButton(title: "Buy BTC") {}
                .padding(.horizontal, Spacing.gutter)
            PrimaryButton(title: "Sell BTC", style: .danger) {}
                .padding(.horizontal, Spacing.gutter)
            CoinRowSkeleton()
        }
        .padding(.vertical, Spacing.gutter)
    }
    .voltScreen()
}
