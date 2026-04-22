import SwiftUI

struct RestoreInstructionsView: View {
    @ObservedObject var viewModel: AppViewModel
    let deletedCount: Int
    @State private var confettiCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Success hero
                ZStack {
                    RadialGradient(
                        colors: [Color.appSuccess.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 120
                    )
                    .frame(height: 200)

                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.appSuccess.opacity(0.15))
                                .frame(width: 88, height: 88)
                            Circle()
                                .stroke(Color.appSuccess.opacity(0.3), lineWidth: 2)
                                .frame(width: 88, height: 88)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.appSuccess)
                        }
                        Text("Deleted \(deletedCount) Record\(deletedCount == 1 ? "" : "s")")
                            .font(.appLargeTitle)
                        Text("Your backup has been modified. Now restore it to your iPhone.")
                            .font(.appBody)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 380)
                    }
                }
                .padding(.top, Spacing.xl)

                // Steps
                VStack(alignment: .leading, spacing: 0) {
                    Text("How to Apply Changes")
                        .font(.appTitle2.bold())
                        .padding(.bottom, Spacing.lg)

                    ForEach(restoreSteps, id: \.number) { step in
                        TimelineStep(step: step, isLast: step.number == restoreSteps.count)
                    }
                }
                .cardStyle()
                .frame(maxWidth: 520)

                // Warning card
                HStack(spacing: Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.appWarning)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Important")
                            .font(.appHeadline)
                        Text("Restoring a backup replaces all data on your iPhone with the backup content. Back up your current phone state first if needed.")
                            .font(.appCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Spacing.lg)
                .background(Color.appWarning.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(Color.appWarning.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(Radius.lg)
                .frame(maxWidth: 520)

                Button("Done — Return to Backup List") {
                    withAnimation(AppAnimation.spring) {
                        viewModel.resetToBackupSelection()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
                .padding(.bottom, Spacing.xxxl)
            }
            .padding(.horizontal, Spacing.xl)
        }
    }

    private var restoreSteps: [RestoreStep] {
        [
            RestoreStep(number: 1, icon: "cable.connector",
                        title: "Connect iPhone",
                        detail: "Connect your iPhone to this Mac with a USB cable."),
            RestoreStep(number: 2, icon: "sidebar.left",
                        title: "Open Finder",
                        detail: "Select your iPhone under Locations in the Finder sidebar."),
            RestoreStep(number: 3, icon: "arrow.counterclockwise.circle",
                        title: "Restore Backup",
                        detail: "Click \"Restore Backup\u{2026}\" in the Backups section."),
            RestoreStep(number: 4, icon: "externaldrive",
                        title: "Select This Backup",
                        detail: "Choose the backup you just modified from the list."),
            RestoreStep(number: 5, icon: "lock.open.fill",
                        title: "Enter Password",
                        detail: "Enter your backup password when prompted and wait for completion."),
        ]
    }
}

struct RestoreStep: Identifiable {
    let number: Int
    let icon: String
    let title: String
    let detail: String
    var id: Int { number }
}

struct TimelineStep: View {
    let step: RestoreStep
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            // Timeline indicator
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text("\(step.number)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appPrimary)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.appPrimary.opacity(0.15))
                        .frame(width: 2)
                        .frame(minHeight: 24)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: step.icon)
                        .font(.system(size: 13))
                        .foregroundColor(.appPrimary)
                    Text(step.title)
                        .font(.appHeadline)
                }
                Text(step.detail)
                    .font(.appBody)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Spacing.xs)
            .padding(.bottom, isLast ? 0 : Spacing.xl)
        }
    }
}
