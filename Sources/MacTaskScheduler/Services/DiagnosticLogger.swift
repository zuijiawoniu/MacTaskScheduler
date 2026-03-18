import Foundation

enum DiagnosticLogger {
    private static let queue = DispatchQueue(label: "com.local.MacTaskScheduler.diagnostic-logger")
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    static func log(_ message: String, category: String = "general") {
        let line = "[\(timestamp())] [\(category)] \(message)"
        print(line)
        appendToFile(line)
    }

    static func notification(_ message: String) {
        log(message, category: "notification")
    }

    static func logFilePath() -> String {
        guard let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return "~/Library/Logs/MacTaskScheduler/diagnostic.log"
        }
        return base
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("MacTaskScheduler", isDirectory: true)
            .appendingPathComponent("diagnostic.log", isDirectory: false)
            .path
    }

    private static func timestamp() -> String {
        dateFormatter.string(from: Date())
    }

    private static func appendToFile(_ line: String) {
        queue.async {
            let path = logFilePath()
            let fileURL = URL(fileURLWithPath: path)
            let directoryURL = fileURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                let data = (line + "\n").data(using: .utf8) ?? Data()
                if FileManager.default.fileExists(atPath: path) {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: fileURL, options: .atomic)
                }
            } catch {
                print("[\(timestamp())] [logger] Failed to write diagnostic log: \(error.localizedDescription)")
            }
        }
    }
}
