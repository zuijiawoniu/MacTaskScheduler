import Foundation
import AppKit
@preconcurrency import UserNotifications

enum ReminderNotifier {
    static func requestAuthorizationIfNeeded() {
        DiagnosticLogger.notification("requestAuthorizationIfNeeded called")
        ensureAuthorizationStatus { _ in }
    }

    static func send(task: TaskItem, source: RunTriggerSource, completion: @Sendable @escaping (Result<String, Error>) -> Void) {
        DiagnosticLogger.notification("send called for task=\(task.name), id=\(task.id.uuidString), source=\(source.rawValue)")
        ensureAuthorizationStatus { status in
            handleAuthorizedStatus(status, task: task, source: source, completion: completion)
        }
    }

    static func sendRunCompletion(task: TaskItem, source: RunTriggerSource, result: TaskRunResult) {
        guard source == .manual else { return }
        let body: String
        if result.exitCode == 0 {
            body = "Run completed successfully."
        } else {
            body = "Run completed with exit code \(result.exitCode)."
        }

        ensureAuthorizationStatus { status in
            switch status {
            case .authorized, .provisional, .ephemeral, .notDetermined:
                sendRawNotification(
                    title: task.name,
                    body: body,
                    identifierPrefix: "task-run-complete",
                    userInfo: [
                        "taskID": task.id.uuidString,
                        "source": source.rawValue,
                        "exitCode": String(result.exitCode)
                    ]
                )
                showInfoPopup(title: task.name, message: body)
            case .denied:
                DiagnosticLogger.notification("sendRunCompletion skipped: status=denied")
                showInfoPopup(title: task.name, message: body)
            @unknown default:
                DiagnosticLogger.notification("sendRunCompletion skipped: status=unknown")
                showInfoPopup(title: task.name, message: body)
            }
        }
    }

    static func sendTest(completion: @Sendable @escaping (Result<String, Error>) -> Void) {
        DiagnosticLogger.notification("sendTest called")
        ensureAuthorizationStatus { status in
            switch status {
            case .authorized, .provisional, .ephemeral:
                DiagnosticLogger.notification("sendTest status=\(status.description)")
                sendTestNow(completion: completion)
            case .denied:
                DiagnosticLogger.notification("sendTest blocked by status=\(status.description)")
                let error = ReminderError.notificationsDenied
                showAlert(title: "MacTaskScheduler", message: "Test notification", error: error)
                completion(.failure(error))
            case .notDetermined:
                DiagnosticLogger.notification("sendTest status still notDetermined after request; trying direct add for diagnostics")
                sendTestNow(completion: completion)
            @unknown default:
                DiagnosticLogger.notification("sendTest blocked by unknown status")
                let error = ReminderError.notificationsDenied
                showAlert(title: "MacTaskScheduler", message: "Test notification", error: error)
                completion(.failure(error))
            }
        }
    }

    static func getAuthorizationStatus(completion: @Sendable @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DiagnosticLogger.notification("getAuthorizationStatus=\(settings.authorizationStatus.description)")
            completion(settings.authorizationStatus)
        }
    }

    private static func ensureAuthorizationStatus(completion: @Sendable @escaping (UNAuthorizationStatus) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DiagnosticLogger.notification("ensureAuthorizationStatus current=\(settings.authorizationStatus.description)")
            guard settings.authorizationStatus == .notDetermined else {
                completion(settings.authorizationStatus)
                return
            }
            DiagnosticLogger.notification("authorization notDetermined, requesting authorization")
            DispatchQueue.main.async {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    let errorText: String
                    if let error {
                        let nsError = error as NSError
                        errorText = "domain=\(nsError.domain) code=\(nsError.code) desc=\(error.localizedDescription)"
                    } else {
                        errorText = "nil"
                    }
                    DiagnosticLogger.notification("authorization callback granted=\(granted) error=\(errorText)")
                    center.getNotificationSettings { refreshed in
                        DiagnosticLogger.notification("authorization request finished, refreshed=\(refreshed.authorizationStatus.description)")
                        completion(refreshed.authorizationStatus)
                    }
                }
            }
        }
    }

    private static func handleAuthorizedStatus(
        _ status: UNAuthorizationStatus,
        task: TaskItem,
        source: RunTriggerSource,
        completion: @Sendable @escaping (Result<String, Error>) -> Void
    ) {
        DiagnosticLogger.notification("handleAuthorizedStatus status=\(status.description), task=\(task.id.uuidString)")
        switch status {
        case .authorized, .provisional, .ephemeral:
            sendNow(task: task, source: source, completion: completion)
        case .denied:
            let error = ReminderError.notificationsDenied
            showAlert(task: task, error: error)
            completion(.failure(error))
        case .notDetermined:
            DiagnosticLogger.notification("status notDetermined when sending reminder, trying direct add for diagnostics")
            sendNow(task: task, source: source, completion: completion)
        @unknown default:
            let error = ReminderError.notificationsDenied
            showAlert(task: task, error: error)
            completion(.failure(error))
        }
    }

    private static func sendTestNow(completion: @Sendable @escaping (Result<String, Error>) -> Void) {
        let bodyText = "Test notification"
        sendRawNotification(
            title: "MacTaskScheduler",
            body: bodyText,
            identifierPrefix: "task-reminder-test",
            userInfo: [:]
        ) { error in
            if let error {
                let nsError = error as NSError
                DiagnosticLogger.notification("sendTest add failed: domain=\(nsError.domain) code=\(nsError.code) desc=\(error.localizedDescription)")
                if isNotificationDenied(error) {
                    showAlert(title: "MacTaskScheduler", message: bodyText, error: error)
                    completion(.success("Reminder shown via alert (notifications unavailable)."))
                } else {
                    showAlert(title: "MacTaskScheduler", message: bodyText, error: error)
                    completion(.failure(error))
                }
            } else {
                DiagnosticLogger.notification("sendTest add success")
                completion(.success("Test notification sent: \(bodyText)"))
            }
        }
    }

    private static func sendNow(task: TaskItem, source: RunTriggerSource, completion: @Sendable @escaping (Result<String, Error>) -> Void) {
        let body = task.reminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyText = body.isEmpty ? task.name : body
        sendRawNotification(
            title: task.name,
            body: bodyText,
            identifierPrefix: "task-reminder-\(task.id.uuidString)",
            userInfo: [
                "taskID": task.id.uuidString,
                "source": source.rawValue
            ]
        ) { error in
            if let error {
                let nsError = error as NSError
                DiagnosticLogger.notification("sendNow add failed: domain=\(nsError.domain) code=\(nsError.code) desc=\(error.localizedDescription)")
                if isNotificationDenied(error) {
                    showAlert(task: task, error: error)
                    completion(.success("Reminder shown via alert (notifications unavailable)."))
                } else {
                    showAlert(task: task, error: error)
                    completion(.failure(error))
                }
            } else {
                DiagnosticLogger.notification("sendNow add success")
                completion(.success("Reminder sent: \(bodyText)"))
            }
        }
    }

    private static func sendRawNotification(
        title: String,
        body: String,
        identifierPrefix: String,
        userInfo: [String: String],
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        DiagnosticLogger.notification("sendRawNotification add request id=\(request.identifier)")
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                let nsError = error as NSError
                DiagnosticLogger.notification("sendRawNotification failed: domain=\(nsError.domain) code=\(nsError.code) desc=\(error.localizedDescription)")
            } else {
                DiagnosticLogger.notification("sendRawNotification success id=\(request.identifier)")
            }
            completion?(error)
        }
    }

    private static func showAlert(task: TaskItem, error: Error) {
        let body = task.reminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = body.isEmpty ? "Reminder" : body
        showAlert(title: task.name, message: message, error: error)
    }

    private static func showAlert(title: String, message: String, error: Error) {
        DiagnosticLogger.notification("showAlert fallback triggered: title=\(title), error=\(error.localizedDescription)")
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            alert.informativeText = "\(message)\n\nNotification error: \(error.localizedDescription)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private static func showInfoPopup(title: String, message: String) {
        DiagnosticLogger.notification("showInfoPopup title=\(title) message=\(message)")
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private static func isNotificationDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        DiagnosticLogger.notification("isNotificationDenied check: domain=\(nsError.domain) code=\(nsError.code)")
        return nsError.domain == "UNErrorDomain" && nsError.code == 1
    }
}

private extension UNAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        case .provisional:
            return "provisional"
        case .ephemeral:
            return "ephemeral"
        @unknown default:
            return "unknown"
        }
    }
}

enum ReminderError: LocalizedError {
    case notificationsDenied

    var errorDescription: String? {
        switch self {
        case .notificationsDenied:
            return "Notifications are disabled. Enable them in System Settings -> Notifications -> MacTaskScheduler."
        }
    }
}
