import SwiftUI

struct PasswordEntryView: View {
    @ObservedObject var viewModel: AppViewModel
    let backup: BackupInfo

    @State private var password: String = ""
    @State private var isLoading = false
    @State private var showPassword = false
    @State private var lockRotation: Double = 0
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Left: decorative gradient panel
            ZStack {
                LinearGradient(
                    colors: [Color.appPrimary.opacity(0.8), Color.appPrimary.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: Spacing.xl) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 96, height: 96)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(lockRotation))
                    }
                    VStack(spacing: Spacing.sm) {
                        Text("Encrypted Backup")
                            .font(.appTitle.bold())
                            .foregroundColor(.white)
                        Text(backup.deviceName)
                            .font(.appCallout)
                            .foregroundColor(.white.opacity(0.8))
                        Text("iOS \(backup.iOSVersion) \u{00B7} \(backup.formattedDate)")
                            .font(.appCaption)
                            .foregroundColor(.white.opacity(0.65))
                    }
                }
            }
            .frame(width: 300)

            // Right: password form
            VStack(spacing: Spacing.xl) {
                Spacer()

                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Enter Backup Password")
                            .font(.appTitle2.bold())
                        Text("This is the password set when enabling encrypted backups in Finder.")
                            .font(.appCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .focused($fieldFocused)
                                    .textFieldStyle(.plain)
                            } else {
                                SecureField("Password", text: $password)
                                    .focused($fieldFocused)
                                    .textFieldStyle(.plain)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(Spacing.md)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(fieldFocused ? Color.appPrimary : Color.primary.opacity(0.1), lineWidth: 1.5)
                        )
                        .onSubmit { unlock() }

                        // Error hint from state
                        if case .awaitingPassword = viewModel.state {
                            // Normal state - no error shown yet unless we had a previous failure
                        }
                    }

                    Button(action: unlock) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView().controlSize(.small).tint(.white)
                                Text("Unlocking\u{2026}").foregroundColor(.white)
                            } else {
                                Image(systemName: "lock.open.fill")
                                Text("Unlock Backup")
                            }
                            Spacer()
                        }
                        .font(.appHeadline)
                        .foregroundColor(.white)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(password.isEmpty || isLoading ? Color.appPrimary.opacity(0.4) : Color.appPrimary)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(password.isEmpty || isLoading)
                    .keyboardShortcut(.return)
                }
                .frame(maxWidth: 320)

                Spacer()
            }
            .padding(Spacing.xxxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
        .onAppear {
            fieldFocused = true
            withAnimation(Animation.easeInOut(duration: 0.4)) {
                lockRotation = -15
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        isLoading = true
        let pwd = password
        Task {
            await viewModel.loadBackup(backup, password: pwd)
            await MainActor.run { isLoading = false }
        }
    }
}
