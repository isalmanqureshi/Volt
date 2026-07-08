import Foundation

/// Display-side number formatting shared by the screens. Presentation only —
/// all trade math stays in the domain layer.
extension Decimal {
    /// Grouped price string, e.g. 63842.1 → "63,842.10" (up to `precision` fraction digits).
    func voltPriceString(precision: Int) -> String {
        formatted(.number.precision(.fractionLength(0...precision)))
    }

    /// Signed currency string with the design's explicit "+" for gains, e.g. "+$412.80".
    func voltSignedCurrencyString(precision: Int = 2) -> String {
        let magnitude = (self < 0 ? -self : self).voltPriceString(precision: precision)
        return (self < 0 ? "-$" : "+$") + magnitude
    }

    /// Double bridge for Swift Charts plotting.
    var chartValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
