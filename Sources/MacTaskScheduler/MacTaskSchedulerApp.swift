import SwiftUI
import AppKit
import UserNotifications

final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        DiagnosticLogger.notification("UNUserNotificationCenterDelegate willPresent id=\(notification.request.identifier)")
        completionHandler([.banner, .list, .sound])
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hasRequestedNotificationPermission = false
    private let notificationDelegate = NotificationCenterDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticLogger.notification("applicationDidFinishLaunching bundleID=\(Bundle.main.bundleIdentifier ?? "nil")")
        UNUserNotificationCenter.current().delegate = notificationDelegate
        DiagnosticLogger.notification("UNUserNotificationCenter delegate configured")
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        DiagnosticLogger.notification("applicationDidBecomeActive")
        DiagnosticLogger.log("Diagnostic log file: \(DiagnosticLogger.logFilePath())", category: "startup")
        guard !hasRequestedNotificationPermission else { return }
        hasRequestedNotificationPermission = true
        DiagnosticLogger.notification("requesting notification permission on first activation")
        ReminderNotifier.requestAuthorizationIfNeeded()
    }
}

@main
struct MacTaskSchedulerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
