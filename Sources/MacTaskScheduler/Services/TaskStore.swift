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
        var mutable = task
        mutable.modifiedAt = Date()

        if let index = tasks.firstIndex(where: { $0.id == mutable.id }) {
            tasks[index] = mutable
        } else {
            tasks.append(mutable)
        }
        recalculateNextRuns()
        publishNow()
        save()
    }

    func delete(ids: Set<UUID>) {
        tasks.removeAll { ids.contains($0.id) }
        publishNow()
        save()
    }

    func setEnabled(id: UUID, isEnabled: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isEnabled = isEnabled
        tasks[index].isRunning = false
        tasks[index].nextRunAt = isEnabled ? tasks[index].schedule.nextRunDate(after: Date()) : nil
        tasks[index].modifiedAt = Date()
        publishNow()
        save()
    }

    func markRunStarted(id: UUID, startedAt: Date, source: RunTriggerSource) -> (batchID: String, roundNumber: Int)? {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return nil }

        tasks[index].isRunning = true
        tasks[index].runSequence += 1
        let round = tasks[index].runSequence
        let batchID = "R\(round)-\(Int(startedAt.timeIntervalSince1970))"

        let startMessage = "[\(DateFormatters.log.string(from: startedAt))] Started"
        tasks[index].lastRunAt = startedAt
        tasks[index].lastOutput = startMessage
        tasks[index].modifiedAt = Date()

        let runningLog = ExecutionLog(
            roundNumber: round,
            batchID: batchID,
            source: source,
            startedAt: startedAt,
            finishedAt: startedAt,
            exitCode: ExecutionLog.runningExitCode,
            output: startMessage
        )
        tasks[index].logs.insert(runningLog, at: 0)
        if tasks[index].logs.count > 100 {
            tasks[index].logs = Array(tasks[index].logs.prefix(100))
        }

        publishNow()
        save()
        return (batchID, round)
    }

    func updateRunResult(id: UUID, batchID: String, startedAt: Date, source: RunTriggerSource, result: TaskRunResult) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        let stampedOutput = timestampOutput(result.output, time: result.finishedAt)
        tasks[index].lastRunAt = startedAt
        tasks[index].lastExitCode = result.exitCode
        tasks[index].lastOutput = stampedOutput
        tasks[index].isRunning = false
        tasks[index].modifiedAt = Date()

        if let logIndex = tasks[index].logs.firstIndex(where: { $0.batchID == batchID }) {
            tasks[index].logs[logIndex].finishedAt = result.finishedAt
            tasks[index].logs[logIndex].exitCode = result.exitCode
            tasks[index].logs[logIndex].output = stampedOutput
        } else {
            let round = max(tasks[index].runSequence, 1)
            let log = ExecutionLog(
                roundNumber: round,
                batchID: batchID,
                source: source,
                startedAt: startedAt,
                finishedAt: result.finishedAt,
                exitCode: result.exitCode,
                output: stampedOutput
            )
            tasks[index].logs.insert(log, at: 0)
        }

        if tasks[index].schedule.kind == .once {
            tasks[index].isEnabled = false
            tasks[index].nextRunAt = nil
        } else if tasks[index].isEnabled {
            tasks[index].nextRunAt = tasks[index].schedule.nextRunDate(after: startedAt)
        }

        publishNow()
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

    private func publishNow() {
        // Force a publish for in-place element mutations so UI updates immediately.
        tasks = Array(tasks)
    }

    private func timestampOutput(_ output: String, time: Date) -> String {
        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "[\(DateFormatters.log.string(from: time))] (No output)"
        }

        let stamp = "[\(DateFormatters.log.string(from: time))] "
        return output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { stamp + String($0) }
            .joined(separator: "\n")
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
