import SwiftUI

struct DeleteConfirmationView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isPresented: Bool
    @State private var isDeleting = false

    private var selectedRecords: [CallRecord] {
        let ids = viewModel.selectedIDs
        return viewModel.allRecords.filter { ids.contains($0.id) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Danger header
            ZStack {
                LinearGradient(
                    colors: [Color.appDanger.opacity(0.12), Color.appDanger.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.appDanger.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.appDanger)
                    }
                    VStack(spacing: Spacing.xs) {
                        Text("Delete \(viewModel.selectedIDs.count) Call Record\(viewModel.selectedIDs.count == 1 ? "" : "s")")
                            .font(.appTitle2.bold())
                        Text("This removes records from your backup file. Restore the backup in Finder to apply changes to your iPhone.")
                            .font(.appCaption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 380)
                    }
                }
                .padding(.vertical, Spacing.xl)
            }
            .frame(height: 170)

            Divider()

            // Record preview list
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Records to delete")
                        .font(.appCaption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    let extra = selectedRecords.count - 50
                    if extra > 0 {
                        Text("and \(extra) more")
                            .font(.appCaption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Color(NSColor.controlBackgroundColor))

                List(Array(selectedRecords.prefix(50))) { record in
                    HStack(spacing: Spacing.md) {
                        Image(systemName: record.isAnswered ? "phone.fill" : "phone.down.fill")
                            .font(.system(size: 12))
                            .foregroundColor(record.isAnswered ? .appSuccess : .appDanger)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(record.displayName)
                                .font(.appBody.weight(.medium))
                                .lineLimit(1)
                            Text(record.formattedDate)
                                .font(.appCaption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(record.formattedDuration)
                            .font(.appMonoSmall)
                            .foregroundColor(.secondary)
                        Image(systemName: record.direction == .outgoing ? "arrow.up.right" : "arrow.down.left")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
                .frame(height: 200)
            }

            Divider()

            // Actions
            HStack(spacing: Spacing.md) {
                // Warning
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.appWarning)
                    Text("This cannot be undone without a separate backup copy.")
                        .font(.appCaption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Button {
                    isDeleting = true
                    isPresented = false
                    Task {
                        await viewModel.deleteSelected()
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if isDeleting {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "trash.fill")
                        }
                        Text("Delete \(viewModel.selectedIDs.count) Records")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.appDanger)
                .keyboardShortcut(.return)
            }
            .padding(Spacing.lg)
        }
        .frame(width: 540)
        .background(Color.appBackground)
    }
}
