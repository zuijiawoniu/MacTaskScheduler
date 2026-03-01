import SwiftUI
import AppKit

struct TaskEditorView: View {
    @State private var draft: TaskItem

    let onCancel: () -> Void
    let onSave: (TaskItem) -> Void

    @State private var errorMessage = ""

    init(task: TaskItem, onCancel: @escaping () -> Void, onSave: @escaping (TaskItem) -> Void) {
        _draft = State(initialValue: task)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.name.isEmpty ? "Create Task" : "Edit Task")
                .font(.title3)
                .bold()

            Form {
                TextField("Task Name", text: $draft.name)

                LabeledContent("Script Path") {
                    pathEditor(path: $draft.scriptPath, chooseDirectories: false)
                }

                TextField("Arguments (space-separated)", text: $draft.arguments)

                LabeledContent("Working Directory") {
                    pathEditor(path: $draft.workingDirectory, chooseDirectories: true)
                }

                Toggle("Enabled", isOn: $draft.isEnabled)

                Picker("Schedule Type", selection: $draft.schedule.kind) {
                    ForEach(ScheduleKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .onChange(of: draft.schedule.kind) { _, newValue in
                    if newValue == .weekly && draft.schedule.weekdays.isEmpty {
                        draft.schedule.weekdays = [2]
                    }
                }

                scheduleFields
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    saveAction()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var scheduleFields: some View {
        switch draft.schedule.kind {
        case .once:
            DatePicker("Run At", selection: $draft.schedule.runAt)

        case .everyInterval:
            Stepper(value: $draft.schedule.intervalMinutes, in: 1...10080) {
                Text("Every \(draft.schedule.intervalMinutes) minute(s)")
            }

        case .weekly:
            HStack {
                Text("Weekdays")
                ForEach(1...7, id: \.self) { day in
                    Button(WeekdayMapper.label(for: day)) {
                        toggleWeekday(day)
                    }
                    .buttonStyle(.bordered)
                    .tint(draft.schedule.weekdays.contains(day) ? .blue : .gray)
                }
            }
            timePicker

        case .monthly:
            Stepper(value: $draft.schedule.dayOfMonth, in: 1...31) {
                Text("Day of Month: \(draft.schedule.dayOfMonth)")
            }
            timePicker

        case .everyXDays:
            Stepper(value: $draft.schedule.everyXDays, in: 1...365) {
                Text("Every \(draft.schedule.everyXDays) day(s)")
            }
            DatePicker("Anchor Date", selection: $draft.schedule.anchorDate, displayedComponents: [.date])
            timePicker

        case .cron:
            TextField("Cron expression (m h dom mon dow)", text: $draft.schedule.cronExpression)
            Text("Example: */30 * * * *")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timePicker: some View {
        DatePicker(
            "Time",
            selection: Binding(
                get: {
                    Calendar.current.date(from: DateComponents(hour: draft.schedule.hour, minute: draft.schedule.minute)) ?? Date()
                },
                set: { newValue in
                    let comp = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    draft.schedule.hour = comp.hour ?? 0
                    draft.schedule.minute = comp.minute ?? 0
                }
            ),
            displayedComponents: [.hourAndMinute]
        )
    }

    private func saveAction() {
        errorMessage = ""

        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Task name is required."
            return
        }

        guard !draft.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Script path is required."
            return
        }

        if draft.schedule.kind == .weekly && draft.schedule.weekdays.isEmpty {
            errorMessage = "Please select at least one weekday."
            return
        }

        if draft.schedule.kind == .cron,
           CronCalculator.nextDate(expression: draft.schedule.cronExpression, after: Date()) == nil {
            errorMessage = "Cron expression is invalid or unsupported."
            return
        }

        onSave(draft)
    }

    private func toggleWeekday(_ day: Int) {
        if let index = draft.schedule.weekdays.firstIndex(of: day) {
            draft.schedule.weekdays.remove(at: index)
        } else {
            draft.schedule.weekdays.append(day)
            draft.schedule.weekdays.sort()
        }
    }

    private func pathEditor(path: Binding<String>, chooseDirectories: Bool) -> some View {
        HStack {
            TextField(chooseDirectories ? "Directory path" : "Script path", text: path)
            Button("Browse") {
                if let selected = openPanel(chooseDirectories: chooseDirectories) {
                    path.wrappedValue = selected
                }
            }
        }
    }

    private func openPanel(chooseDirectories: Bool) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !chooseDirectories
        panel.canChooseDirectories = chooseDirectories
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = chooseDirectories
        panel.prompt = "Select"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
