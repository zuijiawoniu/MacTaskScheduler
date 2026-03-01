import SwiftUI
import AppKit

@main
struct MacTaskSchedulerApp: App {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var i18n = I18N()
    @StateObject private var uiState = UIState()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environmentObject(i18n)
                .environmentObject(uiState)
                .frame(minWidth: 1200, minHeight: 700)
        }
        .windowResizability(.contentMinSize)
    }

    var commands: some Commands {
        CommandGroup(replacing: .help) {
            Button(i18n.t("btn.help")) {
                uiState.showHelp = true
            }
            .keyboardShortcut("?", modifiers: [.command])
        }
    }
}
