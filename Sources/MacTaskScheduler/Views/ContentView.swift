import SwiftUI

enum TaskListColumn: String, CaseIterable, Identifiable {
    case name
    case enabled
    case modifiedAt
    case schedule
    case nextRun

    var id: String { rawValue }
}

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var i18n: I18N
    @EnvironmentObject private var uiState: UIState

    @AppStorage("list_show_name") private var showName = true
    @AppStorage("list_show_enabled") private var showEnabled = true
    @AppStorage("list_show_modified") private var showModified = false
    @AppStorage("list_show_schedule") private var showSchedule = false
    @AppStorage("list_show_next_run") private var showNextRun = false
    @AppStorage("list_sort_column") private var sortColumnRaw = TaskListColumn.modifiedAt.rawValue
    @AppStorage("list_sort_asc") private var sortAsc = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 10) {
                leftControlPanel

                TextField(i18n.t("search.placeholder"), text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)

                headerRow

                List(sortedTasks, selection: $viewModel.selectedTaskID) { task in
                    TaskRow(
                        task: task,
                        columns: activeColumns,
                        onEnableChanged: { value in
                            viewModel.setEnabled(id: task.id, enabled: value)
                        }
                    )
                        .tag(task.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedTaskID = task.id
                        }
                        .onTapGesture(count: 2) {
                            viewModel.openEdit(id: task.id)
                        }
                        .contextMenu {
                            Button(i18n.t("ctx.run_now")) {
                                viewModel.runTaskNow(id: task.id)
                            }
                            Button(i18n.t("ctx.duplicate")) {
                                viewModel.duplicateTask(id: task.id)
                            }
                            Divider()
                            Button(i18n.t("ctx.delete"), role: .destructive) {
                                viewModel.deleteTask(id: task.id)
                            }
                        }
                }
            }
            .padding()
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
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
        .navigationTitle(i18n.t("app.name"))
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
            .environmentObject(i18n)
            .frame(minWidth: 620, minHeight: 560)
        }
        .sheet(isPresented: $uiState.showHelp) {
            HelpView()
                .environmentObject(i18n)
                .frame(minWidth: 560, minHeight: 340)
        }
    }

    private var leftControlPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(i18n.t("btn.add")) {
                    viewModel.openCreate()
                }
                Button(i18n.t("btn.edit")) {
                    viewModel.openEdit()
                }
                .disabled(viewModel.selectedTaskID == nil)
                Button(i18n.t("btn.delete")) {
                    viewModel.deleteSelected()
                }
                .disabled(viewModel.selectedTaskID == nil)
                Button(i18n.t("btn.help")) {
                    uiState.showHelp = true
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Menu(i18n.t("column.settings")) {
                    Toggle(i18n.t("column.name"), isOn: $showName)
                    Toggle(i18n.t("column.enabled"), isOn: $showEnabled)
                    Toggle(i18n.t("column.modified"), isOn: $showModified)
                    Toggle(i18n.t("column.schedule"), isOn: $showSchedule)
                    Toggle(i18n.t("column.next_run"), isOn: $showNextRun)
                }

                Menu(i18n.t("sort.by")) {
                    ForEach(TaskListColumn.allCases) { col in
                        Button(columnTitle(col)) {
                            sortColumnRaw = col.rawValue
                        }
                    }
                    Divider()
                    Button(i18n.t("sort.asc")) {
                        sortAsc = true
                    }
                    Button(i18n.t("sort.desc")) {
                        sortAsc = false
                    }
                }

                Picker(i18n.t("language"), selection: $i18n.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .frame(width: 170)

                Spacer(minLength: 0)
            }
        }
    }

    private var activeColumns: [TaskListColumn] {
        var columns = [TaskListColumn]()
        if showName { columns.append(.name) }
        if showEnabled { columns.append(.enabled) }
        if showModified { columns.append(.modifiedAt) }
        if showSchedule { columns.append(.schedule) }
        if showNextRun { columns.append(.nextRun) }
        if columns.isEmpty {
            return [.name, .enabled]
        }
        return columns
    }

    private var selectedSortColumn: TaskListColumn {
        TaskListColumn(rawValue: sortColumnRaw) ?? .modifiedAt
    }

    private var sortedTasks: [TaskItem] {
        viewModel.filteredTasks.sorted { lhs, rhs in
            let order: ComparisonResult
            switch selectedSortColumn {
            case .name:
                order = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            case .enabled:
                let l = lhs.isEnabled ? 1 : 0
                let r = rhs.isEnabled ? 1 : 0
                order = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
            case .modifiedAt:
                order = lhs.modifiedAt == rhs.modifiedAt ? .orderedSame : (lhs.modifiedAt < rhs.modifiedAt ? .orderedAscending : .orderedDescending)
            case .schedule:
                order = lhs.schedule.descriptionText().localizedCaseInsensitiveCompare(rhs.schedule.descriptionText())
            case .nextRun:
                let l = lhs.nextRunAt ?? .distantFuture
                let r = rhs.nextRunAt ?? .distantFuture
                order = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
            }
            if order == .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return sortAsc ? (order == .orderedAscending) : (order == .orderedDescending)
        }
    }

    private var headerRow: some View {
        GeometryReader { proxy in
            let widths = ColumnWidthCalculator.make(total: max(proxy.size.width - 6, 100), columns: activeColumns)
            HStack(spacing: 8) {
                ForEach(activeColumns) { column in
                    Text(columnTitle(column))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: widths[column] ?? 80, alignment: .leading)
                        .lineLimit(1)
                }
            }
        }
        .frame(height: 18)
    }

    private func columnTitle(_ column: TaskListColumn) -> String {
        switch column {
        case .name: return i18n.t("column.name")
        case .enabled: return i18n.t("column.enabled")
        case .modifiedAt: return i18n.t("column.modified")
        case .schedule: return i18n.t("column.schedule")
        case .nextRun: return i18n.t("column.next_run")
        }
    }
}

private enum ColumnWidthCalculator {
    static func make(total: CGFloat, columns: [TaskListColumn]) -> [TaskListColumn: CGFloat] {
        if columns.isEmpty { return [:] }

        var result: [TaskListColumn: CGFloat] = [:]
        let spacing = CGFloat(max(columns.count - 1, 0)) * 8
        let available = max(total - spacing, 100)

        let weights: [TaskListColumn: CGFloat] = [
            .name: 2.2,
            .enabled: 1.0,
            .modifiedAt: 1.6,
            .schedule: 1.8,
            .nextRun: 1.6
        ]

        let totalWeight = columns.reduce(CGFloat(0)) { $0 + (weights[$1] ?? 1) }
        for column in columns {
            let w = (available * (weights[column] ?? 1)) / max(totalWeight, 1)
            result[column] = max(90, w)
        }
        return result
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let columns: [TaskListColumn]
    let onEnableChanged: (Bool) -> Void

    var body: some View {
        GeometryReader { proxy in
            let widths = ColumnWidthCalculator.make(total: max(proxy.size.width - 6, 100), columns: columns)
            HStack(alignment: .top, spacing: 8) {
                ForEach(columns) { column in
                    cell(for: column)
                        .frame(width: widths[column] ?? 80, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: rowHeight)
    }

    private var rowHeight: CGFloat {
        columns.contains(.schedule) ? 44 : 34
    }

    @ViewBuilder
    private func cell(for column: TaskListColumn) -> some View {
        switch column {
        case .name:
            HStack(spacing: 6) {
                Circle()
                    .fill(task.isEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(task.name)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        case .enabled:
            Toggle("", isOn: Binding(
                get: { task.isEnabled },
                set: { onEnableChanged($0) }
            ))
            .labelsHidden()
        case .modifiedAt:
            Text(DateFormatters.editorDateTime.string(from: task.modifiedAt))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        case .schedule:
            Text(task.schedule.descriptionText())
                .foregroundStyle(.secondary)
                .lineLimit(2)
        case .nextRun:
            Text(task.nextRunAt.map { DateFormatters.editorDateTime.string(from: $0) } ?? "-")
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

private struct TaskDetailView: View {
    @EnvironmentObject private var i18n: I18N

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
                        Toggle(i18n.t("enabled"), isOn: Binding(
                            get: { task.isEnabled },
                            set: { onEnableChanged($0) }
                        ))
                        .toggleStyle(.switch)
                        .frame(width: 160)
                    }

                    Group {
                        detailLine(title: i18n.t("detail.script"), value: task.scriptPath)
                        detailLine(title: i18n.t("detail.args"), value: task.arguments.isEmpty ? "-" : task.arguments)
                        detailLine(title: i18n.t("detail.working_dir"), value: task.workingDirectory.isEmpty ? "-" : task.workingDirectory)
                        detailLine(title: i18n.t("detail.schedule"), value: task.schedule.descriptionText())
                        detailLine(title: i18n.t("detail.next_run"), value: task.nextRunAt.map { DateFormatters.editorDateTime.string(from: $0) } ?? "-")
                        detailLine(title: i18n.t("detail.last_run"), value: task.lastRunAt.map { DateFormatters.editorDateTime.string(from: $0) } ?? "-")
                        detailLine(title: i18n.t("detail.last_exit"), value: task.lastExitCode.map(String.init) ?? "-")
                        detailLine(title: i18n.t("column.modified"), value: DateFormatters.editorDateTime.string(from: task.modifiedAt))
                    }

                    HStack {
                        Button(i18n.t("btn.run_now"), action: onRunNow)
                            .disabled(task.isRunning)
                        Button(i18n.t("btn.edit"), action: onEdit)
                        Button(i18n.t("btn.delete"), action: onDelete)
                        if task.isRunning {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }

                    Divider()

                    Text(i18n.t("detail.logs"))
                        .font(.headline)

                    ScrollView {
                        Text(task.logsDisplayText.isEmpty ? i18n.t("detail.no_logs") : task.logsDisplayText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 240)
                }
                .padding(24)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
                Text(i18n.t("task.none.title"))
                    .font(.title3)
                    .bold()
                Text(i18n.t("task.none.desc"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

private struct HelpView: View {
    @EnvironmentObject private var i18n: I18N
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(i18n.t("help.title"))
                .font(.title3)
                .bold()

            detail(i18n.t("help.app_name"), i18n.t("app.name"))
            detail(i18n.t("help.version"), "v0.1")
            detail(i18n.t("help.release_date"), "2026-03-01")
            detail(i18n.t("help.contact"), "zuijiawoniu@github")

            Text(i18n.t("help.python"))
            codeLine("#!/usr/bin/env python3")

            Text(i18n.t("help.shell"))
            codeLine("#!/bin/bash")

            Text(i18n.t("help.chmod"))
            codeLine("chmod a+x <filename>")

            Spacer()

            HStack {
                Spacer()
                Button(i18n.t("help.close")) {
                    dismiss()
                }
            }
        }
        .padding(20)
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
        }
    }

    private func codeLine(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.12))
            .cornerRadius(8)
    }
}
