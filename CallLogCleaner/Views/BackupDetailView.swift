import SwiftUI

struct BackupDetailView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                idlePlaceholder
            case .loadingBackups:
                loadingView("Scanning…")
            case .awaitingPassword(let backup):
                PasswordEntryView(viewModel: viewModel, backup: backup)
            case .loadingCallHistory:
                loadingView("Decrypting backup\u{2026}")
            case .ready:
                readyView
            case .deleting(let progress):
                deletingView(progress)
            case .done(let count):
                RestoreInstructionsView(viewModel: viewModel, deletedCount: count)
            case .error(let message):
                errorView(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ready (Tab Switcher)

    private var readyView: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    tabButton(tab)
                }
                Spacer()
                if !viewModel.selectedIDs.isEmpty {
                    Button {
                        viewModel.showDeleteConfirmation = true
                    } label: {
                        Label("Delete (\(viewModel.selectedIDs.count))", systemImage: "trash")
                            .font(.appCallout.weight(.medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.appDanger)
                    .controlSize(.small)
                    .padding(.trailing, Spacing.lg)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.leading, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            // Content
            switch viewModel.selectedTab {
            case .records:
                CallHistoryTableView(viewModel: viewModel)
            case .analytics:
                AnalyticsDashboardView(viewModel: viewModel)
            }
        }
        .animation(AppAnimation.fast, value: viewModel.selectedIDs.isEmpty)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = viewModel.selectedTab == tab
        return Button {
            withAnimation(AppAnimation.fast) {
                viewModel.selectedTab = tab
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                Text(tab.rawValue)
                    .font(isSelected ? .appCallout.weight(.semibold) : .appCallout)
            }
            .foregroundColor(isSelected ? .appPrimary : .secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(Color.appPrimary.opacity(0.1))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - State Views

    private var idlePlaceholder: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.07))
                    .frame(width: 96, height: 96)
                Image(systemName: "arrow.left")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.appPrimary.opacity(0.6))
            }
            VStack(spacing: Spacing.sm) {
                Text("Select a Backup")
                    .font(.appTitle2)
                Text("Choose an encrypted iPhone backup from the sidebar to view and edit its call history.")
                    .font(.appBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
                PillBadge(text: "Encrypted backups only", color: .appSuccess, icon: "lock.fill")
                    .padding(.top, Spacing.xs)
            }
        }
    }

    private func loadingView(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .controlSize(.large)
                .scaleEffect(1.2)
            Text(message)
                .font(.appTitle2)
                .foregroundColor(.secondary)
        }
    }

    private func deletingView(_ progress: String) -> some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .stroke(Color.appDanger.opacity(0.15), lineWidth: 3)
                    .frame(width: 80, height: 80)
                ProgressView()
                    .controlSize(.large)
                    .scaleEffect(1.3)
            }
            VStack(spacing: Spacing.sm) {
                Text("Modifying Backup")
                    .font(.appTitle2.bold())
                Text(progress)
                    .font(.appBody)
                    .foregroundColor(.secondary)
                Text("Do not close this window.")
                    .font(.appCaption)
                    .foregroundColor(.appWarning)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.appWarning.opacity(0.1))
                    .cornerRadius(Radius.sm)
            }
        }
        .padding(Spacing.xxxl)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.appWarning.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.appWarning)
            }
            VStack(spacing: Spacing.sm) {
                Text("Something Went Wrong")
                    .font(.appTitle2.bold())
                Text(message)
                    .font(.appBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            Button("Try Again") {
                viewModel.resetToBackupSelection()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(Spacing.xxxl)
    }
}
