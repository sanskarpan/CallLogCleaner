import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var color: Color = .secondary

    @State private var iconBounce = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.08))
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(color.opacity(0.7))
                    .scaleEffect(iconBounce ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                        value: iconBounce
                    )
            }
            .onAppear { iconBounce = true }

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.appTitle2)
                    .foregroundColor(.primary)
                Text(message)
                    .font(.appBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
