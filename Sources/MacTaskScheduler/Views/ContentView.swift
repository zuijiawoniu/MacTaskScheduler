import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                TextField("Search by name/path/schedule", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)

                List(viewModel.filteredTasks, selection: $viewModel.selectedTaskID) { task in
                    TaskRow(task: task)
                        .tag(task.id)
                }
            }
            .padding()
        } detail: {
            TaskDetailView(
                task: viewModel.selectedTaskID.flatMap { id in
                    viewModel.store.task(by: id)
                },
                onEnableChanged: { enabled in
                    viewModel.setEnabled(enabled)
                },
                onRunNow: {
                    viewModel.runSelectedNow()
                },
                onEdit: {
                    viewModel.openEdit()
                },
                onDelete: {
                    viewModel.deleteSelected()
                }
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Add") {
                    viewModel.openCreate()
                }

                Button("Edit") {
                    viewModel.openEdit()
                }
                .disabled(viewModel.selectedTaskID == nil)

                Button("Delete") {
                    viewModel.deleteSelected()
                }
                .disabled(viewModel.selectedTaskID == nil)
            }
        }
        .sheet(isPresented: $viewModel.showEditor) {
            TaskEditorView(
                task: viewModel.editingTask ?? TaskItem(name: "", scriptPath: "", schedule: ScheduleRule(kind: .once)),
                onCancel: {
                    viewModel.showEditor = false
                },
                onSave: { task in
                    viewModel.saveTask(task)
                    viewModel.showEditor = false
                }
            )
            .frame(minWidth: 620, minHeight: 540)
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack {
            Circle()
                .fill(task.isEnabled ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            Text(task.name)
                .font(.headline)
            Spacer()
            Text(task.schedule.descriptionText())
                .foregroundStyle(.secondary)
            Spacer()
            Text(task.nextRunAt.map { DateFormatters.full.string(from: $0) } ?? "-")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct TaskDetailView: View {
    let task: TaskItem?
    let onEnableChanged: (Bool) -> Void
    let onRunNow: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if let task {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(task.name)
                            .font(.title2)
                            .bold()

                        Spacer()
                        Toggle("Enabled", isOn: Binding(
                            get: { task.isEnabled },
                            set: { onEnableChanged($0) }
                        ))
                        .toggleStyle(.switch)
                        .frame(width: 150)
                    }

                    Group {
                        detailLine(title: "Script", value: task.scriptPath)
                        detailLine(title: "Args", value: task.arguments.isEmpty ? "-" : task.arguments)
                        detailLine(title: "Working Dir", value: task.workingDirectory.isEmpty ? "-" : task.workingDirectory)
                        detailLine(title: "Schedule", value: task.schedule.descriptionText())
                        detailLine(title: "Next Run", value: task.nextRunAt.map { DateFormatters.full.string(from: $0) } ?? "-")
                        detailLine(title: "Last Run", value: task.lastRunAt.map { DateFormatters.full.string(from: $0) } ?? "-")
                        detailLine(title: "Last Exit", value: task.lastExitCode.map(String.init) ?? "-")
                    }

                    HStack {
                        Button("Run Now", action: onRunNow)
                            .disabled(task.isRunning)
                        Button("Edit", action: onEdit)
                        Button("Delete", action: onDelete)
                        if task.isRunning {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }

                    Divider()

                    Text("Last Output")
                        .font(.headline)

                    ScrollView {
                        Text(task.lastOutput.isEmpty ? "No output yet." : task.lastOutput)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 220)
                }
                .padding(24)
            }
        } else {
            ContentUnavailableView("No Task Selected", systemImage: "clock.badge.questionmark", description: Text("Create or choose a task."))
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
