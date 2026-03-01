import Foundation
import Combine

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []

    private let fileURL: URL

    init() {
        self.fileURL = Self.makeStorageURL()
        load()
        recalculateNextRuns()
    }

    func upsert(_ task: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        recalculateNextRuns()
        save()
    }

    func delete(ids: Set<UUID>) {
        tasks.removeAll { ids.contains($0.id) }
        save()
    }

    func setEnabled(id: UUID, isEnabled: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isEnabled = isEnabled
        tasks[index].isRunning = false
        tasks[index].nextRunAt = isEnabled ? tasks[index].schedule.nextRunDate(after: Date()) : nil
        save()
    }

    func markRunning(id: UUID, running: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isRunning = running
        save()
    }

    func updateRunResult(id: UUID, exitCode: Int32, output: String, ranAt: Date) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].lastRunAt = ranAt
        tasks[index].lastExitCode = exitCode
        tasks[index].lastOutput = output
        tasks[index].isRunning = false

        if tasks[index].schedule.kind == .once {
            tasks[index].isEnabled = false
            tasks[index].nextRunAt = nil
        } else if tasks[index].isEnabled {
            tasks[index].nextRunAt = tasks[index].schedule.nextRunDate(after: ranAt)
        }

        save()
    }

    func recalculateNextRuns() {
        let now = Date()
        for index in tasks.indices {
            if tasks[index].isEnabled {
                tasks[index].nextRunAt = tasks[index].schedule.nextRunDate(after: now)
            } else {
                tasks[index].nextRunAt = nil
            }
            tasks[index].isRunning = false
        }
    }

    func task(by id: UUID) -> TaskItem? {
        tasks.first { $0.id == id }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            tasks = try JSONDecoder.iso8601.decode([TaskItem].self, from: data)
        } catch {
            tasks = []
        }
    }

    private func save() {
        do {
            let parent = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let data = try JSONEncoder.pretty.encode(tasks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save tasks: \(error)")
        }
    }

    private static func makeStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("MacTaskScheduler", isDirectory: true)
            .appendingPathComponent("tasks.json", isDirectory: false)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
