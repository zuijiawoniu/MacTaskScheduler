import Foundation

enum RunTriggerSource: String, Codable {
    case manual
    case scheduled

    var displayText: String {
        switch self {
        case .manual: return "Manual"
        case .scheduled: return "Scheduled"
        }
    }
}

struct ExecutionLog: Codable, Equatable, Identifiable {
    static let runningExitCode: Int32 = -99999

    var id: UUID
    var roundNumber: Int
    var batchID: String
    var source: RunTriggerSource
    var startedAt: Date
    var finishedAt: Date
    var exitCode: Int32
    var output: String
    var fullOutputRef: String?

    init(
        id: UUID = UUID(),
        roundNumber: Int,
        batchID: String,
        source: RunTriggerSource,
        startedAt: Date,
        finishedAt: Date,
        exitCode: Int32,
        output: String,
        fullOutputRef: String? = nil
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.batchID = batchID
        self.source = source
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.output = output
        self.fullOutputRef = fullOutputRef
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        roundNumber = try container.decodeIfPresent(Int.self, forKey: .roundNumber) ?? 0
        batchID = try container.decodeIfPresent(String.self, forKey: .batchID) ?? UUID().uuidString
        source = try container.decodeIfPresent(RunTriggerSource.self, forKey: .source) ?? .manual
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt) ?? startedAt
        exitCode = try container.decodeIfPresent(Int32.self, forKey: .exitCode) ?? 0
        output = try container.decodeIfPresent(String.self, forKey: .output) ?? ""
        fullOutputRef = try container.decodeIfPresent(String.self, forKey: .fullOutputRef)
    }

    func toDisplayText() -> String {
        if exitCode == Self.runningExitCode {
            return "Round: \(roundNumber) | Source: \(source.displayText) | Batch: \(batchID) | Start: \(DateFormatters.log.string(from: startedAt)) | Status: Running\n\(output)"
        }

        let header = "Round: \(roundNumber) | Source: \(source.displayText) | Batch: \(batchID) | Start: \(DateFormatters.log.string(from: startedAt)) | End: \(DateFormatters.log.string(from: finishedAt)) | Exit: \(exitCode)"
        let body = output.isEmpty ? "(No output)" : output
        return "\(header)\n\(body)"
    }
}

struct TaskItem: Identifiable, Codable, Equatable {
    static let defaultTimeoutSeconds: Int = 7200

    var id: UUID
    var name: String
    var isReminderOnly: Bool
    var reminderMessage: String
    var scriptPath: String
    var arguments: String
    var workingDirectory: String
    var timeoutSeconds: Int
    var isEnabled: Bool
    var schedule: ScheduleRule
    var nextRunAt: Date?
    var lastRunAt: Date?
    var lastExitCode: Int32?
    var lastOutput: String
    var logs: [ExecutionLog]
    var runSequence: Int
    var modifiedAt: Date
    var isRunning: Bool

    init(
        id: UUID = UUID(),
        name: String,
        isReminderOnly: Bool = false,
        reminderMessage: String = "",
        scriptPath: String,
        arguments: String = "",
        workingDirectory: String = "",
        timeoutSeconds: Int = TaskItem.defaultTimeoutSeconds,
        isEnabled: Bool = true,
        schedule: ScheduleRule,
        nextRunAt: Date? = nil,
        lastRunAt: Date? = nil,
        lastExitCode: Int32? = nil,
        lastOutput: String = "",
        logs: [ExecutionLog] = [],
        runSequence: Int = 0,
        modifiedAt: Date = Date(),
        isRunning: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isReminderOnly = isReminderOnly
        self.reminderMessage = reminderMessage
        self.scriptPath = scriptPath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.timeoutSeconds = max(1, timeoutSeconds)
        self.isEnabled = isEnabled
        self.schedule = schedule
        self.nextRunAt = nextRunAt
        self.lastRunAt = lastRunAt
        self.lastExitCode = lastExitCode
        self.lastOutput = lastOutput
        self.logs = logs
        self.runSequence = runSequence
        self.modifiedAt = modifiedAt
        self.isRunning = isRunning
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        isReminderOnly = try container.decodeIfPresent(Bool.self, forKey: .isReminderOnly) ?? false
        reminderMessage = try container.decodeIfPresent(String.self, forKey: .reminderMessage) ?? ""
        scriptPath = try container.decodeIfPresent(String.self, forKey: .scriptPath) ?? ""
        arguments = try container.decodeIfPresent(String.self, forKey: .arguments) ?? ""
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory) ?? ""
        timeoutSeconds = max(1, try container.decodeIfPresent(Int.self, forKey: .timeoutSeconds) ?? Self.defaultTimeoutSeconds)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        schedule = try container.decodeIfPresent(ScheduleRule.self, forKey: .schedule) ?? ScheduleRule(kind: .once)
        nextRunAt = try container.decodeIfPresent(Date.self, forKey: .nextRunAt)
        lastRunAt = try container.decodeIfPresent(Date.self, forKey: .lastRunAt)
        lastExitCode = try container.decodeIfPresent(Int32.self, forKey: .lastExitCode)
        lastOutput = try container.decodeIfPresent(String.self, forKey: .lastOutput) ?? ""
        logs = try container.decodeIfPresent([ExecutionLog].self, forKey: .logs) ?? []

        // Backfill round numbers for old logs whose roundNumber is 0.
        var maxRound = logs.map(\.roundNumber).max() ?? 0
        if maxRound < 0 { maxRound = 0 }
        for index in logs.indices {
            if logs[index].roundNumber <= 0 {
                maxRound += 1
                logs[index].roundNumber = maxRound
            }
        }

        let decodedRunSequence = try container.decodeIfPresent(Int.self, forKey: .runSequence)
        runSequence = max(decodedRunSequence ?? 0, logs.map(\.roundNumber).max() ?? 0)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
        isRunning = try container.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
    }
}

extension TaskItem {
    var argumentArray: [String] {
        arguments
            .split(separator: " ")
            .map(String.init)
    }

    var logsDisplayText: String {
        if logs.isEmpty {
            return lastOutput
        }

        return logs
            .sorted { $0.startedAt > $1.startedAt }
            .map { $0.toDisplayText() }
            .joined(separator: "\n\n----------------\n\n")
    }
}
