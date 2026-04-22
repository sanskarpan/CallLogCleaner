import SwiftUI

struct PillBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil
    var size: Size = .medium

    enum Size { case small, medium }

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: fontSize - 1, weight: .semibold))
            }
            Text(text)
                .font(.system(size: fontSize, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .background(color.opacity(0.12))
        .cornerRadius(Radius.pill)
    }

    private var fontSize: CGFloat { size == .small ? 10 : 11 }
    private var hPad: CGFloat { size == .small ? 5 : 7 }
    private var vPad: CGFloat { size == .small ? 2 : 3 }
}
