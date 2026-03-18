import Foundation
import Combine

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []

    private let fileURL: URL
    private let logsDirectoryURL: URL
    private let fullOutputDirectoryURL: URL
    private var lastStreamingSaveAt: [String: Date] = [:]
    private var logsCache: [UUID: [ExecutionLog]] = [:]
    private var expandedOutputCache: [UUID: [String: String]] = [:]
    private var loadedLogTaskIDs = Set<UUID>()
    private var loadingLogTaskIDs = Set<UUID>()
    private var loadingFullOutputTaskIDs = Set<UUID>()

    init() {
        self.fileURL = Self.makeStorageURL()
        self.logsDirectoryURL = Self.makeLogsDirectoryURL()
        self.fullOutputDirectoryURL = Self.makeFullOutputDirectoryURL()
        load()
        recalculateNextRuns()
    }

    func upsert(_ task: TaskItem) {
        var mutable = task
        mutable.modifiedAt = Date()
        mutable.logs = []

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
        for id in ids {
            logsCache.removeValue(forKey: id)
            expandedOutputCache.removeValue(forKey: id)
            loadedLogTaskIDs.remove(id)
            loadingLogTaskIDs.remove(id)
            try? FileManager.default.removeItem(at: logFileURL(for: id))
            try? FileManager.default.removeItem(at: fullOutputTaskDirectoryURL(for: id))
        }
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
        ensureLogsLoaded(taskID: id)

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
        var logs = logsCache[id] ?? []
        logs.insert(runningLog, at: 0)
        if logs.count > 100 {
            logs = Array(logs.prefix(100))
        }
        logsCache[id] = logs

        publishNow()
        save()
        saveLogs(taskID: id)
        return (batchID, round)
    }

    func updateRunResult(id: UUID, batchID: String, startedAt: Date, source: RunTriggerSource, result: TaskRunResult) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        ensureLogsLoaded(taskID: id)

        let stampedOutput = timestampOutput(result.output, time: result.finishedAt)
        tasks[index].lastRunAt = startedAt
        tasks[index].lastExitCode = result.exitCode
        tasks[index].lastOutput = stampedOutput
        tasks[index].isRunning = false
        tasks[index].modifiedAt = Date()

        var logs = logsCache[id] ?? []
        if let logIndex = logs.firstIndex(where: { $0.batchID == batchID }) {
            logs[logIndex].finishedAt = result.finishedAt
            logs[logIndex].exitCode = result.exitCode
            let stored = storeFullOutputIfNeeded(taskID: id, batchID: batchID, output: stampedOutput)
            logs[logIndex].output = stored.preview
            logs[logIndex].fullOutputRef = stored.fullOutputRef
        } else {
            let round = max(tasks[index].runSequence, 1)
            let stored = storeFullOutputIfNeeded(taskID: id, batchID: batchID, output: stampedOutput)
            let log = ExecutionLog(
                roundNumber: round,
                batchID: batchID,
                source: source,
                startedAt: startedAt,
                finishedAt: result.finishedAt,
                exitCode: result.exitCode,
                output: stored.preview,
                fullOutputRef: stored.fullOutputRef
            )
            logs.insert(log, at: 0)
        }
        if logs.count > 100 {
            logs = Array(logs.prefix(100))
        }
        logsCache[id] = logs

        if tasks[index].schedule.kind == .once {
            tasks[index].isEnabled = false
            tasks[index].nextRunAt = nil
        } else if tasks[index].isEnabled {
            tasks[index].nextRunAt = tasks[index].schedule.nextRunDate(after: startedAt)
        }

        lastStreamingSaveAt.removeValue(forKey: streamSaveKey(taskID: id, batchID: batchID))
        publishNow()
        save()
        saveLogs(taskID: id)
    }

    func appendRunOutput(id: UUID, batchID: String, chunk: TaskOutputChunk) {
        guard !chunk.text.isEmpty else { return }
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        ensureLogsLoaded(taskID: id)

        var logs = logsCache[id] ?? []
        if let logIndex = logs.firstIndex(where: { $0.batchID == batchID }) {
            logs[logIndex].output += LogMarkup.encode(stream: chunk.stream, text: chunk.text)
            logsCache[id] = logs
            tasks[index].lastOutput = logs[logIndex].output
            tasks[index].modifiedAt = Date()
            publishNow()
            maybeSaveStreaming(id: id, batchID: batchID)
        }
    }

    func preloadLogsIfNeeded(id: UUID) {
        guard task(by: id) != nil else { return }
        guard !loadedLogTaskIDs.contains(id), !loadingLogTaskIDs.contains(id) else { return }

        loadingLogTaskIDs.insert(id)
        publishNow()
        let logURL = logFileURL(for: id)
        DispatchQueue.global(qos: .utility).async {
            let logs = Self.readLogs(at: logURL)
            Task { @MainActor in
                self.loadingLogTaskIDs.remove(id)
                self.loadedLogTaskIDs.insert(id)
                self.logsCache[id] = logs
                self.publishNow()
            }
        }
    }

    func isLogsLoading(id: UUID) -> Bool {
        loadingLogTaskIDs.contains(id)
    }

    func loadFullOutputsIfNeeded(id: UUID) {
        guard task(by: id) != nil else { return }
        guard !loadingFullOutputTaskIDs.contains(id) else { return }

        ensureLogsLoaded(taskID: id)
        let refs = (logsCache[id] ?? [])
            .compactMap { log -> (batchID: String, ref: String)? in
                guard let ref = log.fullOutputRef else { return nil }
                return (log.batchID, ref)
            }
        guard !refs.isEmpty else { return }
        let existingExpanded = expandedOutputCache[id] ?? [:]
        let missingRefs = refs.filter { existingExpanded[$0.batchID] == nil }
        guard !missingRefs.isEmpty else { return }

        loadingFullOutputTaskIDs.insert(id)
        publishNow()

        let taskDirectoryURL = fullOutputTaskDirectoryURL(for: id)
        DispatchQueue.global(qos: .utility).async {
            var expanded = existingExpanded
            for item in missingRefs {
                let fileURL = taskDirectoryURL.appendingPathComponent(item.ref, isDirectory: false)
                if let data = try? Data(contentsOf: fileURL),
                   let text = String(data: data, encoding: .utf8) {
                    expanded[item.batchID] = text
                }
            }
            Task { @MainActor in
                self.expandedOutputCache[id] = expanded
                self.loadingFullOutputTaskIDs.remove(id)
                self.publishNow()
            }
        }
    }

    func isFullOutputLoading(id: UUID) -> Bool {
        loadingFullOutputTaskIDs.contains(id)
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
        guard let task = tasks.first(where: { $0.id == id }) else { return nil }
        var mutable = task
        var logs = logsCache[id] ?? []
        if let expanded = expandedOutputCache[id], !expanded.isEmpty {
            for index in logs.indices {
                if let full = expanded[logs[index].batchID] {
                    logs[index].output = full
                }
            }
        }
        mutable.logs = logs
        return mutable
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder.iso8601.decode([TaskItem].self, from: data)
            tasks = loaded.map { task in
                var mutable = task
                if !task.logs.isEmpty {
                    logsCache[task.id] = task.logs
                    loadedLogTaskIDs.insert(task.id)
                    saveLogs(taskID: task.id)
                }
                mutable.logs = []
                return mutable
            }
            save()
        } catch {
            tasks = []
        }
    }

    private func save() {
        do {
            let parent = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let taskConfigs = tasks.map { task -> TaskItem in
                var mutable = task
                mutable.logs = []
                return mutable
            }
            let data = try JSONEncoder.pretty.encode(taskConfigs)
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
        return LogMarkup.parse(output)
            .map { chunk in
                let stamped = chunk.text
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map { stamp + String($0) }
                    .joined(separator: "\n")
                return LogMarkup.encode(stream: chunk.stream, text: stamped)
            }
            .joined()
    }

    private func streamSaveKey(taskID: UUID, batchID: String) -> String {
        "\(taskID.uuidString)|\(batchID)"
    }

    private func maybeSaveStreaming(id: UUID, batchID: String) {
        let key = streamSaveKey(taskID: id, batchID: batchID)
        let now = Date()
        let last = lastStreamingSaveAt[key] ?? .distantPast
        if now.timeIntervalSince(last) >= 1 {
            lastStreamingSaveAt[key] = now
            saveLogs(taskID: id)
        }
    }

    private static func makeStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("MacTaskScheduler", isDirectory: true)
            .appendingPathComponent("tasks.json", isDirectory: false)
    }

    private static func makeLogsDirectoryURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("MacTaskScheduler", isDirectory: true)
            .appendingPathComponent("logs", isDirectory: true)
    }

    private static func makeFullOutputDirectoryURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("MacTaskScheduler", isDirectory: true)
            .appendingPathComponent("full_logs", isDirectory: true)
    }

    private func logFileURL(for taskID: UUID) -> URL {
        logsDirectoryURL.appendingPathComponent("\(taskID.uuidString).json", isDirectory: false)
    }

    private func fullOutputTaskDirectoryURL(for taskID: UUID) -> URL {
        fullOutputDirectoryURL.appendingPathComponent(taskID.uuidString, isDirectory: true)
    }

    private func ensureLogsLoaded(taskID: UUID) {
        guard !loadedLogTaskIDs.contains(taskID) else { return }
        let logs = Self.readLogs(at: logFileURL(for: taskID))
        logsCache[taskID] = logs
        loadedLogTaskIDs.insert(taskID)
    }

    private func saveLogs(taskID: UUID) {
        let logs = logsCache[taskID] ?? []
        do {
            try FileManager.default.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
            let data = try PropertyListCodec.binary.encode(logs)
            try data.write(to: logFileURL(for: taskID), options: .atomic)
        } catch {
            print("Failed to save logs for task \(taskID): \(error)")
        }
    }

    nonisolated private static func readLogs(at url: URL) -> [ExecutionLog] {
        do {
            let data = try Data(contentsOf: url)
            if let logs = try? PropertyListCodec.binary.decode([ExecutionLog].self, from: data) {
                return logs
            }
            if let logs = try? JSONDecoder.iso8601.decode([ExecutionLog].self, from: data) {
                return logs
            }
            return []
        } catch {
            return []
        }
    }

    private func storeFullOutputIfNeeded(taskID: UUID, batchID: String, output: String) -> (preview: String, fullOutputRef: String?) {
        let previewLimit = 16 * 1024
        let (preview, truncated) = truncateEncodedOutput(output, maxVisibleChars: previewLimit)
        guard truncated else {
            return (preview: output, fullOutputRef: nil)
        }

        let filename = sanitizedFilename(for: batchID) + ".log"
        let taskDirectory = fullOutputTaskDirectoryURL(for: taskID)
        let fileURL = taskDirectory.appendingPathComponent(filename, isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: taskDirectory, withIntermediateDirectories: true)
            let data = output.data(using: .utf8) ?? Data(output.utf8)
            try data.write(to: fileURL, options: .atomic)
            return (preview: preview, fullOutputRef: filename)
        } catch {
            print("Failed to persist full output for task \(taskID), batch \(batchID): \(error)")
            return (preview: output, fullOutputRef: nil)
        }
    }

    private func truncateEncodedOutput(_ text: String, maxVisibleChars: Int) -> (String, Bool) {
        guard maxVisibleChars > 0 else { return ("", !text.isEmpty) }

        let chunks = LogMarkup.parse(text)
        if chunks.isEmpty {
            if text.count <= maxVisibleChars {
                return (text, false)
            }
            return (String(text.prefix(maxVisibleChars)) + "\n...", true)
        }

        let totalVisibleChars = chunks.reduce(0) { $0 + $1.text.count }
        if totalVisibleChars <= maxVisibleChars {
            return (text, false)
        }

        var remaining = maxVisibleChars
        var output = ""
        for chunk in chunks where remaining > 0 {
            if chunk.text.count <= remaining {
                output += LogMarkup.encode(stream: chunk.stream, text: chunk.text)
                remaining -= chunk.text.count
            } else {
                let endIndex = chunk.text.index(chunk.text.startIndex, offsetBy: remaining)
                let partial = String(chunk.text[..<endIndex])
                output += LogMarkup.encode(stream: chunk.stream, text: partial)
                remaining = 0
            }
        }
        output += LogMarkup.encode(stream: .system, text: "\n...")
        return (output, true)
    }

    private func sanitizedFilename(for raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(sanitized)
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

private enum PropertyListCodec {
    static let binary: PropertyListCodecAdapter = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let decoder = PropertyListDecoder()
        return PropertyListCodecAdapter(encoder: encoder, decoder: decoder)
    }()
}

private struct PropertyListCodecAdapter {
    let encoder: PropertyListEncoder
    let decoder: PropertyListDecoder

    func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}
