import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    var trend: TrendDirection? = nil
    var trendValue: String? = nil

    @State private var hovered = false
    @State private var appeared = false

    enum TrendDirection { case up, down, neutral }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                Spacer()
                if let trend, let trendValue {
                    HStack(spacing: 3) {
                        Image(systemName: trend == .up ? "arrow.up.right" : trend == .down ? "arrow.down.right" : "minus")
                            .font(.system(size: 10, weight: .bold))
                        Text(trendValue)
                            .font(.appCaption2)
                    }
                    .foregroundColor(trend == .up ? .appSuccess : trend == .down ? .appDanger : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        (trend == .up ? Color.appSuccess : trend == .down ? Color.appDanger : Color.secondary)
                            .opacity(0.1)
                    )
                    .cornerRadius(Radius.pill)
                }
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.appCaption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(color.opacity(hovered ? 0.3 : 0.0), lineWidth: 1.5)
        )
        .cornerRadius(Radius.lg)
        .appShadow(hovered ? .elevated : .card)
        .scaleEffect(hovered ? 1.02 : 1.0)
        .animation(AppAnimation.spring, value: hovered)
        .onHover { hovered = $0 }
        .onAppear {
            withAnimation(AppAnimation.spring.delay(0.1)) {
                appeared = true
            }
        }
    }
}
