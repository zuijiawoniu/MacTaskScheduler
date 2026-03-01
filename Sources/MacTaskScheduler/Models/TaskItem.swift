import Foundation

struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var scriptPath: String
    var arguments: String
    var workingDirectory: String
    var isEnabled: Bool
    var schedule: ScheduleRule
    var nextRunAt: Date?
    var lastRunAt: Date?
    var lastExitCode: Int32?
    var lastOutput: String
    var isRunning: Bool

    init(
        id: UUID = UUID(),
        name: String,
        scriptPath: String,
        arguments: String = "",
        workingDirectory: String = "",
        isEnabled: Bool = true,
        schedule: ScheduleRule,
        nextRunAt: Date? = nil,
        lastRunAt: Date? = nil,
        lastExitCode: Int32? = nil,
        lastOutput: String = "",
        isRunning: Bool = false
    ) {
        self.id = id
        self.name = name
        self.scriptPath = scriptPath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.isEnabled = isEnabled
        self.schedule = schedule
        self.nextRunAt = nextRunAt
        self.lastRunAt = lastRunAt
        self.lastExitCode = lastExitCode
        self.lastOutput = lastOutput
        self.isRunning = isRunning
    }
}

extension TaskItem {
    var argumentArray: [String] {
        arguments
            .split(separator: " ")
            .map(String.init)
    }
}
