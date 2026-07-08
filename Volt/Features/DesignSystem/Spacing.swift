import SwiftUI

/// 8px base grid from the design. No screen hardcodes spacing.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    /// Horizontal screen gutter used by every mockup.
    static let gutter: CGFloat = 20
}

/// Corner radii from the design.
enum Radius {
    /// Small pills / tags.
    static let tag: CGFloat = 4
    /// Buttons, controls.
    static let button: CGFloat = 8
    /// Cards, rows.
    static let card: CGFloat = 12
}
