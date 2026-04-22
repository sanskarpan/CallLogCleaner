import SwiftUI

struct BackupListView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Group {
            if viewModel.state == .loadingBackups {
                loadingState
            } else if viewModel.backups.isEmpty {
                emptyState
            } else {
                backupList
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.scanBackups()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
    }

    private var backupList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(viewModel.backups) { backup in
                    BackupCard(
                        backup: backup,
                        isSelected: viewModel.selectedBackup?.id == backup.id
                    )
                    .onTapGesture {
                        withAnimation(AppAnimation.spring) {
                            viewModel.selectBackup(backup)
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .controlSize(.regular)
            Text("Scanning for backups…")
                .font(.appCaption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.07))
                    .frame(width: 72, height: 72)
                Image(systemName: "iphone.slash")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.secondary)
            }
            VStack(spacing: Spacing.xs) {
                Text("No Backups Found")
                    .font(.appHeadline)
                Text("Connect your iPhone and create an encrypted backup in Finder.")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }
            Button("Refresh") { viewModel.scanBackups() }
                .buttonStyle(.bordered)
                .font(.appCaption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.lg)
    }
}

// MARK: - BackupCard

struct BackupCard: View {
    let backup: BackupInfo
    let isSelected: Bool
    @State private var hovered = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Device icon
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isSelected ? Color.appPrimary : Color.appPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: deviceIcon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(isSelected ? .white : .appPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(backup.deviceName)
                        .font(.appHeadline)
                        .lineLimit(1)
                    Spacer()
                    encryptionBadge
                }
                Text("iOS \(backup.iOSVersion)")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(backup.formattedDate)
                        .font(.appCaption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(backup.formattedSize)
                        .font(.appCaption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(isSelected
                      ? Color.appPrimary.opacity(0.08)
                      : (hovered ? Color.primary.opacity(0.04) : Color.cardBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(isSelected ? Color.appPrimary.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .appShadow(isSelected ? .card : .subtle)
        .onHover { hovered = $0 }
        .animation(AppAnimation.fast, value: hovered)
        .animation(AppAnimation.spring, value: isSelected)
    }

    private var encryptionBadge: some View {
        Group {
            if backup.isEncrypted {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.appSuccess)
            } else {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.appWarning)
            }
        }
    }

    private var deviceIcon: String {
        let model = backup.deviceModel.lowercased()
        if model.contains("ipad") { return "ipad" }
        return "iphone"
    }
}
