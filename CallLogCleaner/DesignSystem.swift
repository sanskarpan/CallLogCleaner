import SwiftUI
import AppKit

// MARK: - Color Tokens
extension Color {
    // Background layers
    static let appBackground      = Color(NSColor.windowBackgroundColor)
    static let cardBackground     = Color(NSColor.controlBackgroundColor)
    static let elevatedBackground = Color(NSColor.underPageBackgroundColor)

    // Semantic
    static let appPrimary   = Color.accentColor
    static let appDanger    = Color(red: 1.0, green: 0.23, blue: 0.19)   // #FF3B30
    static let appSuccess   = Color(red: 0.20, green: 0.78, blue: 0.35)  // #34C759
    static let appWarning   = Color(red: 1.0, green: 0.58, blue: 0.0)    // #FF9500

    // Call types
    static let callPhone         = Color(red: 0.20, green: 0.50, blue: 0.95)  // blue
    static let callFaceTimeVideo = Color(red: 0.60, green: 0.25, blue: 0.95)  // purple
    static let callFaceTimeAudio = Color(red: 0.18, green: 0.72, blue: 0.72)  // teal

    // Status
    static let statusAnswered = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let statusMissed   = Color(red: 1.0, green: 0.23, blue: 0.19)

    // Chart palette
    static let chartPalette: [Color] = [
        Color(red: 0.20, green: 0.50, blue: 0.95),
        Color(red: 0.60, green: 0.25, blue: 0.95),
        Color(red: 0.18, green: 0.72, blue: 0.72),
        Color(red: 1.0, green: 0.58, blue: 0.0),
        Color(red: 0.20, green: 0.78, blue: 0.35),
    ]
}

// MARK: - Typography
extension Font {
    static let appLargeTitle  = Font.system(size: 26, weight: .bold,      design: .default)
    static let appTitle       = Font.system(size: 20, weight: .semibold,  design: .default)
    static let appTitle2      = Font.system(size: 17, weight: .semibold,  design: .default)
    static let appHeadline    = Font.system(size: 14, weight: .semibold,  design: .default)
    static let appBody        = Font.system(size: 13, weight: .regular,   design: .default)
    static let appCallout     = Font.system(size: 12, weight: .regular,   design: .default)
    static let appCaption     = Font.system(size: 11, weight: .regular,   design: .default)
    static let appCaption2    = Font.system(size: 10, weight: .regular,   design: .default)
    static let appMono        = Font.system(size: 12, weight: .regular,   design: .monospaced)
    static let appMonoSmall   = Font.system(size: 11, weight: .regular,   design: .monospaced)
}

// MARK: - Spacing
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Corner Radius
enum Radius {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 6
    static let md:  CGFloat = 10
    static let lg:  CGFloat = 14
    static let xl:  CGFloat = 18
    static let pill: CGFloat = 999
}

// MARK: - Shadows
struct AppShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let card = AppShadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    static let elevated = AppShadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 4)
    static let subtle = AppShadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
}

extension View {
    func appShadow(_ shadow: AppShadow = .card) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Animation
enum AppAnimation {
    static let fast     = Animation.easeOut(duration: 0.15)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let spring   = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let slowSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
}

// MARK: - Card Modifier
struct CardModifier: ViewModifier {
    var padding: CGFloat = Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBackground)
            .cornerRadius(Radius.lg)
            .appShadow()
    }
}

extension View {
    func cardStyle(padding: CGFloat = Spacing.lg) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Divider style helper
extension View {
    func sectionDivider() -> some View {
        self.overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
