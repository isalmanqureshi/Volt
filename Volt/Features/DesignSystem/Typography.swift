import SwiftUI

/// Two families only: SF Mono for every digit (prices, %, quantities, balances)
/// and SF Pro for everything else. Sizes map 1:1 to the mockup scale —
/// no screen hardcodes a font size.
enum Typography {
    // MARK: SF Pro (labels, names, copy)

    /// 11px — caption / labels.
    static let caption = Font.caption2
    /// 12px — secondary text.
    static let secondary = Font.caption
    /// 13px — body secondary.
    static let bodySecondary = Font.footnote
    /// 15px — body / row primary.
    static let body = Font.subheadline
    /// 16px — emphasis (row primary weight).
    static let emphasis = Font.callout
    /// 30px — screen titles ("Watchlist", "Trade", …).
    static let screenTitle = Font.system(size: 30, weight: .bold)

    // MARK: SF Mono (numbers / prices / data)

    /// 11px mono — data captions, timestamps, tag pills.
    static let monoCaption = Font.system(.caption2, design: .monospaced)
    /// 12px mono — secondary data (symbols, avg price).
    static let monoSecondary = Font.system(.caption, design: .monospaced)
    /// 13px mono — pill values, filter values.
    static let monoBodySecondary = Font.system(.footnote, design: .monospaced)
    /// 15px mono — row primary values (prices).
    static let monoBody = Font.system(.subheadline, design: .monospaced)
    /// 16px mono — emphasised values.
    static let monoEmphasis = Font.system(.callout, design: .monospaced)
    /// 26px mono — section numbers (analytics cards).
    static let sectionNumber = Font.system(size: 26, weight: .bold, design: .monospaced)
    /// 30px mono — large values.
    static let largeValue = Font.system(size: 30, weight: .semibold, design: .monospaced)
    /// 34px mono — hero values (portfolio total, asset price).
    static let heroValue = Font.system(size: 34, weight: .bold, design: .monospaced)
    /// 44px mono — trade-ticket amount entry.
    static let amountEntry = Font.system(size: 44, weight: .semibold, design: .monospaced)
}
