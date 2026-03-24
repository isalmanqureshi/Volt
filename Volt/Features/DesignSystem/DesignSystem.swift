import SwiftUI

enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    enum Radius {
        static let card: CGFloat = 12
    }
}

struct DSCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(DS.Spacing.lg)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }
}

struct DSStatusMessage: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage)
            .padding(.vertical, DS.Spacing.sm)
    }
}
