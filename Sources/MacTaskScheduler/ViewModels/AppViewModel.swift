import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedTaskID: UUID?
    @Published var showEditor = false
    @Published var editingTask: TaskItem?

    let store = TaskStore()

    private let scheduler = SchedulerEngine()

    init() {
        scheduler.start { [weak self] in
            self?.tick()
        }
    }

    var filteredTasks: [TaskItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sorted(store.tasks)
        }

        let keyword = searchText.lowercased()
        return sorted(store.tasks.filter {
            $0.name.lowercased().contains(keyword) ||
            $0.scriptPath.lowercased().contains(keyword) ||
            $0.schedule.descriptionText().lowercased().contains(keyword)
        })
    }

    func openCreate() {
        editingTask = TaskItem(name: "", scriptPath: "", schedule: ScheduleRule(kind: .once))
        showEditor = true
    }

    func openEdit() {
        guard let selectedTaskID, let task = store.task(by: selectedTaskID) else { return }
        editingTask = task
        showEditor = true
    }

    func saveTask(_ task: TaskItem) {
        var mutable = task
        if mutable.isEnabled {
            mutable.nextRunAt = mutable.schedule.nextRunDate(after: Date())
        } else {
            mutable.nextRunAt = nil
        }
        store.upsert(mutable)
    }

    func deleteSelected() {
        guard let selectedTaskID else { return }
        store.delete(ids: [selectedTaskID])
        self.selectedTaskID = nil
    }

    func setEnabled(_ enabled: Bool) {
        guard let selectedTaskID else { return }
        store.setEnabled(id: selectedTaskID, isEnabled: enabled)
    }

    func runSelectedNow() {
        guard let selectedTaskID else { return }
        runTask(id: selectedTaskID)
    }

    func tick() {
        let now = Date()

        for task in store.tasks where task.isEnabled && !task.isRunning {
            guard let next = task.nextRunAt else { continue }
            if next <= now {
                runTask(id: task.id)
            }
        }
    }

    private func runTask(id: UUID) {
        guard let task = store.task(by: id), !task.isRunning else { return }

        store.markRunning(id: id, running: true)
        let runAt = Date()

        TaskRunner.run(task: task) { [weak self] result in
            Task { @MainActor in
                self?.store.updateRunResult(id: id, exitCode: result.exitCode, output: result.output, ranAt: runAt)
            }
        }
    }

    private func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            let lhsDate = lhs.nextRunAt ?? .distantFuture
            let rhsDate = rhs.nextRunAt ?? .distantFuture
            if lhsDate == rhsDate {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhsDate < rhsDate
        }
    }
}
