import SwiftUI

/// Design-token colors. All values live in the asset catalog (`Assets.xcassets/Colors`);
/// no screen should reference a raw hex value or a system semantic color directly.
extension Color {

    /// Secondary text — white at 45%, per mockup muted labels.
    static let voltTextSecondary = Color.white.opacity(0.45)
    /// Tertiary text / section labels — white at 40%.
    static let voltTextTertiary = Color.white.opacity(0.40)
    /// Hairline border — white at 6%. All separation comes from this + surface steps.
    static let voltHairline = Color.white.opacity(0.06)

    /// Brand accent for a coin, keyed by base currency (e.g. "BTC" from "BTC/USD").
    static func brand(forBaseCurrency base: String) -> Color {
        switch base.uppercased() {
        case "BTC": return .btcOrange
        case "ETH": return .ethBlue
        case "SOL": return .solPurple
        case "DOGE": return .dogeGold
        default: return .white.opacity(0.35)
        }
    }

    /// Brand accent from a full symbol like "BTC/USD".
    static func brand(forSymbol symbol: String) -> Color {
        brand(forBaseCurrency: String(symbol.split(separator: "/").first ?? ""))
    }
}

/// Hairline border used on every surface — 1pt white @ 6%.
struct HairlineBorder: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.voltHairline, lineWidth: 1)
            )
    }
}

extension View {
    /// Applies the standard hairline border (white @ 6%).
    func hairlineBorder(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(HairlineBorder(cornerRadius: cornerRadius))
    }

    /// Standard elevated surface: `voltSurface` fill + hairline border.
    func voltSurfaceStyle(cornerRadius: CGFloat = Radius.card) -> some View {
        background(Color.voltSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .hairlineBorder(cornerRadius: cornerRadius)
    }
}
