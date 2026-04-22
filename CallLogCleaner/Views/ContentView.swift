import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        NavigationSplitView {
            BackupListView(viewModel: viewModel)
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            ZStack {
                BackupDetailView(viewModel: viewModel)
                ToastContainerView(manager: viewModel.toastManager)
            }
        }
        .onAppear { viewModel.scanBackups() }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $viewModel.showExport) {
            ExportView(viewModel: viewModel, isPresented: $viewModel.showExport)
        }
        .sheet(isPresented: $viewModel.showSmartSelect) {
            SmartSelectSheet(viewModel: viewModel, isPresented: $viewModel.showSmartSelect)
        }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeleteConfirmationView(viewModel: viewModel, isPresented: $viewModel.showDeleteConfirmation)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "phone.fill.arrow.down.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appPrimary)
                    Text("CallLog Cleaner")
                        .font(.appHeadline)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if case .ready = viewModel.state {
                    Button {
                        viewModel.showExport = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .help("Export call records")

                    Button {
                        viewModel.showSmartSelect = true
                    } label: {
                        Label("Smart Select", systemImage: "wand.and.sparkles")
                    }
                    .help("Smart select records")
                }
                Button {
                    viewModel.showSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .help("Settings")
            }
        }
    }
}
