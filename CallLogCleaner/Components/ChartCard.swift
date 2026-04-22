import SwiftUI

struct ChartCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var trailingContent: AnyView? = nil
    @ViewBuilder var chartContent: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appTitle2)
                        .foregroundColor(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.appCaption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let trailing = trailingContent {
                    trailing
                }
            }
            chartContent()
        }
        .cardStyle()
    }
}
