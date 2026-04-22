import SwiftUI
import Combine

// MARK: - Model
struct AppToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: Style
    var icon: String { style.icon }

    enum Style {
        case success, error, warning, info
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error:   return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info:    return "info.circle.fill"
            }
        }
        var color: Color {
            switch self {
            case .success: return .appSuccess
            case .error:   return .appDanger
            case .warning: return .appWarning
            case .info:    return .appPrimary
            }
        }
    }
}

// MARK: - Manager
@MainActor
class ToastManager: ObservableObject {
    @Published var toasts: [AppToast] = []

    func show(_ message: String, style: AppToast.Style = .info) {
        let toast = AppToast(message: message, style: style)
        withAnimation(AppAnimation.spring) {
            toasts.append(toast)
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            dismiss(toast)
        }
    }

    func dismiss(_ toast: AppToast) {
        withAnimation(AppAnimation.spring) {
            toasts.removeAll { $0.id == toast.id }
        }
    }
}

// MARK: - View
struct ToastContainerView: View {
    @ObservedObject var manager: ToastManager

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            ForEach(manager.toasts) { toast in
                ToastBubble(toast: toast) {
                    manager.dismiss(toast)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .allowsHitTesting(!manager.toasts.isEmpty)
    }
}

struct ToastBubble: View {
    let toast: AppToast
    let onDismiss: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: toast.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(toast.style.color)

            Text(toast.message)
                .font(.appBody)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovered ? 1 : 0.5)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: 360)
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                Color.cardBackground.opacity(0.6)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(Radius.lg)
        .appShadow(.elevated)
        .onHover { hovered = $0 }
    }
}
