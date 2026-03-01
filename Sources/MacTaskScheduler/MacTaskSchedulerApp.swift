import SwiftUI

@main
struct MacTaskSchedulerApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 980, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
    }
}
