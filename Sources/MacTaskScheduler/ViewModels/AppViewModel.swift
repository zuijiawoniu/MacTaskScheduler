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
    private var cancellables = Set<AnyCancellable>()

    init() {
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        scheduler.start { [weak self] in
            self?.tick()
        }
    }

    var filteredTasks: [TaskItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return store.tasks
        }

        let keyword = searchText.lowercased()
        return store.tasks.filter {
            $0.name.lowercased().contains(keyword) ||
            $0.scriptPath.lowercased().contains(keyword) ||
            $0.schedule.descriptionText().lowercased().contains(keyword)
        }
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

    func openEdit(id: UUID) {
        selectedTaskID = id
        guard let task = store.task(by: id) else { return }
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

    func setEnabled(id: UUID, enabled: Bool) {
        store.setEnabled(id: id, isEnabled: enabled)
    }

    func runSelectedNow() {
        guard let selectedTaskID else { return }
        self.selectedTaskID = selectedTaskID
        runTask(id: selectedTaskID, source: .manual)
    }

    func tick() {
        let now = Date()

        for task in store.tasks where task.isEnabled && !task.isRunning {
            guard let next = task.nextRunAt else { continue }
            if next <= now {
                runTask(id: task.id, source: .scheduled)
            }
        }
    }

    private func runTask(id: UUID, source: RunTriggerSource) {
        guard let task = store.task(by: id), !task.isRunning else { return }

        let runAt = Date()
        guard let running = store.markRunStarted(id: id, startedAt: runAt, source: source) else { return }

        TaskRunner.run(task: task) { [weak self] result in
            Task { @MainActor in
                self?.store.updateRunResult(id: id, batchID: running.batchID, startedAt: runAt, source: source, result: result)
            }
        }
    }
}
