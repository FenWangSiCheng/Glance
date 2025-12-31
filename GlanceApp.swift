import SwiftUI

@main
struct GlanceApp: App {
    @StateObject private var viewModel = AppViewModel.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(viewModel)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 900, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}

            // Add refresh command with Cmd+R
            CommandGroup(after: .toolbar) {
                Button("刷新待办") {
                    Task {
                        await viewModel.fetchAndGenerateTodos()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!viewModel.isConfigured || viewModel.isGeneratingTodos)
            }
        }

        // Standard macOS Settings scene (Cmd+,)
        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
